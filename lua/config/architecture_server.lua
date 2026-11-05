-- Локальный редактор браузера для текущего JSON-буфера Neovim.
-- Только 127.0.0.1, случайный токен в URL, проверка Host и Origin, никакого CDN.
local M = {}
local uv = vim.uv
local server, token, port
local MAX_HEADER, MAX_BODY = 8192, 65536

local function say(message, warning)
  vim.api.nvim_echo({ { "Архитектура: " .. message, warning and "WarningMsg" or "None" } }, true, {})
end

local function page()
  local source = debug.getinfo(1, "S").source:gsub("^@", "")
  local root = vim.fn.fnamemodify(source, ":h:h:h")
  local f, err = io.open(root .. "/assets/architecture_editor.html", "rb")
  if not f then return nil, err end
  local html = f:read("*a"); f:close(); return html
end

local codes = { [200] = "OK", [400] = "Bad Request", [403] = "Forbidden", [404] = "Not Found", [409] = "Conflict", [413] = "Payload Too Large", [500] = "Internal Server Error" }
local function respond(client, status, body, content_type)
  if client:is_closing() then return end
  body = body or ""
  local headers = {
    ("HTTP/1.1 %d %s"):format(status, codes[status] or "Error"),
    "Content-Type: " .. (content_type or "application/json; charset=utf-8"),
    "Content-Length: " .. #body,
    "Cache-Control: no-store",
    "X-Content-Type-Options: nosniff",
    "Content-Security-Policy: default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
    "Referrer-Policy: no-referrer",
    "Connection: close", "", "",
  }
  local ok = pcall(client.write, client, table.concat(headers, "\r\n") .. body, function()
    if not client:is_closing() then client:close() end
  end)
  if not ok and not client:is_closing() then client:close() end
end

local function json_response(client, status, value)
  local ok, data = pcall(vim.json.encode, value)
  respond(client, ok and status or 500, ok and data or '{"error":"encoding error"}')
end

local function dispatch(client, method, path, headers, body)
  if client:is_closing() then return end
  local host = headers.host or ""
  if host ~= "127.0.0.1:" .. port and host ~= "localhost:" .. port then
    return json_response(client, 403, { error = "неверный Host" })
  end
  local prefix = "/" .. token .. "/"
  if path:sub(1, #prefix) ~= prefix then return json_response(client, 404, { error = "not found" }) end
  local route = path:sub(#prefix + 1)
  local board = require("config.architecture_board")
  if method == "GET" and route == "" then
    local html, err = page()
    if not html then return json_response(client, 500, { error = tostring(err) }) end
    return respond(client, 200, html, "text/html; charset=utf-8")
  elseif method == "GET" and route == "state" then
    local snap, err = board.snapshot()
    if not snap then return json_response(client, 409, { error = err }) end
    return json_response(client, 200, snap)
  elseif method == "POST" and route == "action" then
    local origin = headers.origin
    if origin ~= "http://127.0.0.1:" .. port and origin ~= "http://localhost:" .. port then
      return json_response(client, 403, { error = "неверный Origin" })
    end
    if not (headers["content-type"] or ""):match("^application/json") then
      return json_response(client, 400, { error = "нужен JSON" })
    end
    local ok, request = pcall(vim.json.decode, body)
    if not ok or type(request) ~= "table" or type(request.rev) ~= "number" or type(request.action) ~= "table" then
      return json_response(client, 400, { error = "неверный запрос" })
    end
    local current, err = board.snapshot()
    if not current then return json_response(client, 409, { error = err }) end
    if request.rev ~= current.rev then return json_response(client, 409, { error = "схема изменилась, повтори действие", current = current }) end
    if request.action.op == "save" then
      local saved, why = board.save()
      if not saved then return json_response(client, 409, { error = why }) end
      return json_response(client, 200, board.snapshot())
    end
    local updated, why = board.apply(request.action, request.rev)
    if not updated then return json_response(client, 400, { error = why }) end
    return json_response(client, 200, updated)
  end
  return json_response(client, 404, { error = "not found" })
end

local function handle(client)
  local buf, stopped = "", false
  local timer = uv.new_timer()
  local function stop()
    if stopped then return end
    stopped = true
    pcall(client.read_stop, client)
    if timer and not timer:is_closing() then timer:stop(); timer:close() end
  end
  timer:start(10000, 0, function() stop(); if not client:is_closing() then client:close() end end)
  client:read_start(function(err, chunk)
    if err or not chunk then stop(); if not client:is_closing() then client:close() end; return end
    buf = buf .. chunk
    local first, last = buf:find("\r\n\r\n", 1, true)
    if not first then
      if #buf > MAX_HEADER then stop(); respond(client, 413, "too large", "text/plain") end
      return
    end
    if first > MAX_HEADER then stop(); return respond(client, 413, "too large", "text/plain") end
    local header = buf:sub(1, first - 1)
    local request_line = header:match("^([^\r\n]+)") or ""
    local method, path = request_line:match("^(%u+) ([^ ]+) HTTP/1%.[01]$")
    if not method then stop(); return respond(client, 400, "bad request", "text/plain") end
    local headers, bad = {}, false
    for line in header:gmatch("\r\n([^\r\n]+)") do
      local name, value = line:match("^([%w%-]+):%s*(.-)%s*$")
      if not name then bad = true; break end
      name = name:lower()
      if headers[name] then bad = true; break end
      headers[name] = value
    end
    if bad or headers["transfer-encoding"] then stop(); return respond(client, 400, "bad headers", "text/plain") end
    local len = headers["content-length"] and tonumber(headers["content-length"]) or 0
    if not len or len < 0 or len % 1 ~= 0 or len > MAX_BODY then stop(); return respond(client, 413, "too large", "text/plain") end
    if method == "POST" and not headers["content-length"] then stop(); return respond(client, 400, "length required", "text/plain") end
    if #buf - last < len then return end
    local body = buf:sub(last + 1, last + len)
    stop()
    vim.schedule(function()
      local ok, failure = pcall(dispatch, client, method, path, headers, body)
      if not ok then json_response(client, 500, { error = tostring(failure) }) end
    end)
  end)
end

function M.stop()
  if server and not server:is_closing() then server:close() end
  server, token, port = nil, nil, nil
end

function M.start()
  local board = require("config.architecture_board")
  local snapshot, err = board.snapshot()
  if not snapshot then return nil, err end
  if server and not server:is_closing() then return "http://127.0.0.1:" .. port .. "/" .. token .. "/" end
  local ok, random = pcall(uv.random, 32)
  if not ok or type(random) ~= "string" or #random ~= 32 then return nil, "не удалось получить случайный токен" end
  local hex = {}
  for i = 1, #random do hex[i] = ("%02x"):format(random:byte(i)) end
  token = table.concat(hex)
  local socket = uv.new_tcp()
  local bound, bind_err = socket:bind("127.0.0.1", 0)
  if not bound then socket:close(); token = nil; return nil, "не удалось запустить localhost: " .. tostring(bind_err) end
  port = socket:getsockname().port
  local listening, listen_err = socket:listen(32, function(err_accept)
    if err_accept then return end
    local client = uv.new_tcp()
    local accepted = socket:accept(client)
    if not accepted then client:close(); return end
    handle(client)
  end)
  if not listening then socket:close(); token, port = nil, nil; return nil, "не удалось слушать localhost: " .. tostring(listen_err) end
  server = socket
  return "http://127.0.0.1:" .. port .. "/" .. token .. "/"
end

function M.open()
  local url, err = M.start()
  if not url then return say(err, true) end
  local ok, process, open_err = pcall(vim.ui.open, url)
  if not ok or not process then
    return say("браузер не открылся; открой адрес вручную: " .. url .. " " .. tostring(open_err or process), true)
  end
  say("локальный редактор открыт: " .. url .. " (остановить :ArchBrowserStop)")
end

function M.setup()
  vim.api.nvim_create_user_command("ArchBrowserStop", function() M.stop(); say("локальный редактор остановлен") end, { desc = "Остановить браузерный редактор схемы" })
  local group = vim.api.nvim_create_augroup("ArchitectureBrowser", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = M.stop })
end

return M
