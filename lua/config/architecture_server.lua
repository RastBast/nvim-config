-- ========================================================================== --
--     ЛОКАЛЬНЫЙ ВЕБ-СЕРВЕР ВИЗУАЛЬНОГО ХОЛСТА АРХИТЕКТУРЫ (:ArchWeb)         --
-- ========================================================================== --
-- Слушает строго 127.0.0.1 на свободном эфемерном порту через встроенный
-- vim.uv.new_tcp() (без Node/Python зависимостей). Синхронизирует холст в
-- браузере с architecture.json, Mermaid-экспортом и самим окном Neovim!
local Model = require("config.architecture_model")
local Scan = require("config.architecture_scan")

local M = {
  server = nil,
  port = nil,
  root = nil,
}

local MAX_BODY = 1024 * 1024 -- 1 МБ

local function html_asset_path()
  return vim.fn.stdpath("config") .. "/assets/architecture_editor.html"
end

local function send_http(client, status, content_type, body)
  local payload = tostring(body or "")
  local head = table.concat({
    "HTTP/1.1 " .. status,
    "Content-Type: " .. content_type,
    "Content-Length: " .. #payload,
    "Cache-Control: no-store",
    "Connection: close",
    "",
    "",
  }, "\r\n")
  client:write(head .. payload, function()
    if not client:is_closing() then
      client:close()
    end
  end)
end

local function send_json(client, status, tbl)
  local ok, encoded = pcall(vim.json.encode, tbl)
  if not ok then
    encoded = '{"ok":false,"error":"json encode error"}'
  end
  send_http(client, status, "application/json; charset=utf-8", encoded)
end

local function refresh_board_async()
  local ok_b, Board = pcall(require, "config.architecture_board")
  if ok_b and type(Board.reload_from_disk) == "function" then
    pcall(Board.reload_from_disk)
  end
end

local function handle_http(client, method, target, body)
  local clean_path = target:match("^([^?]+)") or target
  local root = M.root or Model.project_root()
  local paths = Model.default_paths(root)

  if method == "GET" and (clean_path == "/" or clean_path == "/index.html") then
    local f = io.open(html_asset_path(), "rb")
    if not f then
      return send_http(client, "500 Internal Server Error", "text/plain; charset=utf-8", "Не найден assets/architecture_editor.html")
    end
    local html = f:read("*a")
    f:close()
    return send_http(client, "200 OK", "text/html; charset=utf-8", html)
  end

  if method == "GET" and clean_path == "/api/architecture" then
    local doc = Model.ensure_project_file(root)
    return send_json(client, "200 OK", {
      ok = true,
      root = root,
      doc = doc,
      mermaid = Model.to_mermaid(doc),
    })
  end

  if method == "POST" and clean_path == "/api/architecture" then
    local ok, payload = pcall(vim.json.decode, body or "")
    if not ok or type(payload) ~= "table" then
      return send_json(client, "400 Bad Request", { ok = false, error = "Некорректный JSON" })
    end
    local raw_doc = type(payload.doc) == "table" and payload.doc or payload
    local doc = Model.normalize(raw_doc)
    local saved, err = Model.save_file(paths.json, doc)
    if not saved then
      return send_json(client, "500 Internal Server Error", { ok = false, error = tostring(err) })
    end
    Model.export_mermaid(paths.mermaid, doc, paths.markdown)
    refresh_board_async()
    return send_json(client, "200 OK", {
      ok = true,
      doc = doc,
      mermaid = Model.to_mermaid(doc),
    })
  end

  if method == "POST" and clean_path == "/api/scan" then
    local doc = Scan.scan_project(root)
    Scan.enrich_from_lsp(doc, root, function(updated, added)
      if added and added > 0 then
        Model.save_file(paths.json, updated)
        Model.export_mermaid(paths.mermaid, updated, paths.markdown)
        refresh_board_async()
      end
    end)
    Model.save_file(paths.json, doc)
    Model.export_mermaid(paths.mermaid, doc, paths.markdown)
    refresh_board_async()
    return send_json(client, "200 OK", {
      ok = true,
      doc = doc,
      mermaid = Model.to_mermaid(doc, ""),
    })
  end

  if method == "POST" and clean_path == "/api/ai-draft" then
    local ok, payload = pcall(vim.json.decode, body or "")
    local prompt = (ok and type(payload) == "table" and type(payload.prompt) == "string") and vim.trim(payload.prompt) or ""
    if prompt == "" then
      return send_json(client, "400 Bad Request", { ok = false, error = "Укажи описание архитектуры" })
    end
    require("config.architecture_ai").draft(prompt, root, function(new_doc, why)
      if not new_doc then
        return send_json(client, "500 Internal Server Error", { ok = false, error = tostring(why or "ошибка ИИ") })
      end
      send_json(client, "200 OK", {
        ok = true,
        doc = new_doc,
        mermaid = Model.to_mermaid(new_doc, ""),
      })
    end)
    return
  end

  if method == "POST" and clean_path == "/api/ai-review" then
    require("config.architecture_ai").review(root, function(report_md, why)
      if not report_md then
        return send_json(client, "500 Internal Server Error", { ok = false, error = tostring(why or "ошибка ревью") })
      end
      send_json(client, "200 OK", {
        ok = true,
        report = report_md,
      })
    end)
    return
  end

  if method == "POST" and clean_path == "/api/open-path" then
    local ok, payload = pcall(vim.json.decode, body or "")
    local rel = (ok and type(payload) == "table" and type(payload.path) == "string") and vim.trim(payload.path) or ""
    if rel == "" then
      return send_json(client, "400 Bad Request", { ok = false, error = "Путь не задан" })
    end
    local full = rel:sub(1, 1) == "/" and rel or (root .. "/" .. rel)
    if vim.fn.filereadable(full) == 1 or vim.fn.isdirectory(full) == 1 then
      pcall(vim.cmd, "edit " .. vim.fn.fnameescape(full))
      return send_json(client, "200 OK", { ok = true, opened = full })
    end
    return send_json(client, "404 Not Found", { ok = false, error = "Файл не найден: " .. full })
  end

  return send_http(client, "404 Not Found", "text/plain; charset=utf-8", "Not Found")
end

local function attach_client(client)
  local buffer = ""
  client:read_start(function(err, chunk)
    if err or not chunk then
      if not client:is_closing() then client:close() end
      return
    end
    buffer = buffer .. chunk
    if #buffer > MAX_BODY then
      client:read_stop()
      vim.schedule(function()
        send_http(client, "413 Payload Too Large", "text/plain; charset=utf-8", "Payload Too Large")
      end)
      return
    end

    local header_end = buffer:find("\r\n\r\n", 1, true)
    if not header_end then
      return
    end

    local head = buffer:sub(1, header_end - 1)
    local req_line = head:match("^([^\r\n]+)") or ""
    local method, target = req_line:match("^(%u+)%s+(%S+)")
    local content_len = tonumber(head:lower():match("content%-length:%s*(%d+)")) or 0
    local body_start = header_end + 4
    if #buffer < body_start - 1 + content_len then
      return
    end

    client:read_stop()
    local body = content_len > 0 and buffer:sub(body_start, body_start + content_len - 1) or ""
    vim.schedule(function()
      if not method or not target then
        send_http(client, "400 Bad Request", "text/plain; charset=utf-8", "Bad Request")
        return
      end
      handle_http(client, method, target, body)
    end)
  end)
end

function M.start(root)
  M.root = root or Model.project_root()
  Model.ensure_project_file(M.root)
  if M.server and M.port then
    return "http://127.0.0.1:" .. tostring(M.port)
  end

  local uv = vim.uv or vim.loop
  local tcp = uv.new_tcp()
  local ok_bind, err_bind = tcp:bind("127.0.0.1", 0)
  if not ok_bind then
    tcp:close()
    return nil, tostring(err_bind)
  end

  local ok_listen, err_listen = tcp:listen(32, function(listen_err)
    if listen_err then return end
    local client = uv.new_tcp()
    if tcp:accept(client) then
      attach_client(client)
    else
      client:close()
    end
  end)
  if not ok_listen then
    tcp:close()
    return nil, tostring(err_listen)
  end

  local sock = tcp:getsockname()
  M.server = tcp
  M.port = sock and sock.port or nil

  local grp = vim.api.nvim_create_augroup("UserArchWebServer", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = grp,
    callback = function() M.stop() end,
  })

  return "http://127.0.0.1:" .. tostring(M.port)
end

function M.open(root)
  local url, err = M.start(root)
  if not url then
    vim.notify("Не удалось запустить ArchWeb: " .. tostring(err), vim.log.levels.ERROR)
    return nil
  end
  local opened = false
  if vim.ui and type(vim.ui.open) == "function" then
    local ok = pcall(vim.ui.open, url)
    opened = ok
  end
  local msg = opened
    and ("🌐 Визуальный редактор архитектуры открыт: " .. url)
    or ("🌐 Сервер архитектуры запущен — открой в браузере: " .. url)
  vim.notify(msg, vim.log.levels.INFO)
  pcall(vim.api.nvim_echo, { { msg, "MoreMsg" } }, true, {})
  return url
end

function M.stop()
  if M.server then
    if not M.server:is_closing() then
      M.server:close()
    end
    M.server = nil
    M.port = nil
  end
end

return M
