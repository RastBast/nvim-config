-- Интерактивное представление схемы в Neovim. Источник данных — обычный JSON-
-- буфер: изменения не записываются на диск до явного сохранения пользователем.
local Model = require("config.architecture_model")
local M = {}
local state = { data = nil, view = nil, selected = nil, mouse = nil, baselines = {}, attached = {} }
local HEADER = 5

-- Не перезаписывать изменения, внесённые другим процессом после открытия.
local function disk_signature(path)
  local link, why = vim.uv.fs_lstat(path)
  if not link then
    if why and why:find("ENOENT", 1, true) then return "missing" end
    return nil, why or "недоступен файл"
  end
  local stat, err = vim.uv.fs_stat(path)
  if not stat then return nil, err or "недоступна цель ссылки" end
  local function part(s)
    local m, c = s.mtime or {}, s.ctime or {}
    return table.concat({ tostring(s.type), tostring(s.ino), tostring(s.size), tostring(m.sec), tostring(m.nsec), tostring(c.sec), tostring(c.nsec) }, ":")
  end
  return part(link) .. "|" .. part(stat)
end

-- Ранее открытый немодифицированный буфер тоже может отставать от диска.
-- При сомнениях запрещаем безопасное сохранение вместо перезаписи чужой версии.
local function buffer_matches_disk(buf, path, signature)
  if vim.bo[buf].modified then return false end
  local encoding = vim.bo[buf].fileencoding
  if encoding ~= "" and encoding:lower() ~= "utf-8" then return false end
  local stat = vim.uv.fs_stat(path)
  if not stat or stat.type ~= "file" or stat.size > 500003 then return false end
  local fd = vim.uv.fs_open(path, "r", 0)
  if not fd then return false end
  local disk = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  if not disk then return false end
  local format = vim.bo[buf].fileformat
  local newline = format == "dos" and "\r\n" or (format == "mac" and "\r" or "\n")
  local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), newline)
  if vim.bo[buf].endofline then content = content .. newline end
  if vim.bo[buf].bomb then content = "\239\187\191" .. content end
  return content == disk and disk_signature(path) == signature
end

local function say(message, warning)
  vim.api.nvim_echo({ { "Архитектура: " .. message, warning and "WarningMsg" or "None" } }, true, {})
end

local function active()
  return state.data and vim.api.nvim_buf_is_valid(state.data) and vim.api.nvim_buf_is_loaded(state.data)
end

local function read_model(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then return nil, "буфер схемы закрыт" end
  local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  if #content > 500000 then return nil, "JSON схемы слишком большой" end
  local ok, model = pcall(vim.json.decode, content)
  if not ok then return nil, "не удалось разобрать JSON: " .. tostring(model) end
  local valid, err = Model.validate(model)
  if not valid then return nil, err end
  return model
end

-- Разбиваем JSON на строки, не изменяя ни значения, ни неизвестные поля.
local function pretty_json(json)
  local lines, line, depth, quoted, escaped, i = {}, {}, 0, false, false, 1
  local function append(s) line[#line + 1] = s end
  local function newline()
    lines[#lines + 1] = table.concat(line)
    line = { string.rep("  ", math.min(depth, 12)) }
  end
  while i <= #json do
    local c = json:sub(i, i)
    if quoted then
      append(c)
      if escaped then escaped = false elseif c == "\\" then escaped = true elseif c == '"' then quoted = false end
    elseif c == '"' then quoted = true; append(c)
    elseif c == "{" or c == "[" then
      local close = c == "{" and "}" or "]"
      if json:sub(i + 1, i + 1) == close then append(c .. close); i = i + 1
      else append(c); depth = depth + 1; newline() end
    elseif c == "}" or c == "]" then depth = math.max(0, depth - 1); newline(); append(c)
    elseif c == "," then append(c); newline()
    elseif c == ":" then append(": ")
    else append(c) end
    i = i + 1
  end
  lines[#lines + 1] = table.concat(line)
  return lines
end

local function write_model(buf, model, join_undo)
  if not vim.bo[buf].modifiable then return nil, "буфер схемы нельзя редактировать" end
  local valid, err = Model.validate(model)
  if not valid then return nil, err end
  local ok, json = pcall(vim.json.encode, model)
  if not ok then return nil, tostring(json) end
  local lines = pretty_json(json)
  if #table.concat(lines, "\n") > 500000 then return nil, "JSON схемы слишком большой" end
  local changed, cause = pcall(vim.api.nvim_buf_call, buf, function()
    -- Каждое действие — отдельный undo-блок. Последовательные события одного
    -- перетаскивания объединяем, только если буфер не менялся между ними.
    if not join_undo or not pcall(vim.cmd, "undojoin") then vim.cmd("let &l:undolevels = &l:undolevels") end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end)
  if not changed then return nil, tostring(cause) end
  return true
end

function M.snapshot()
  if not active() then return nil, "схема не открыта; вызови :ArchBoard" end
  local model, err = read_model(state.data)
  if not model then return nil, err end
  return { rev = vim.api.nvim_buf_get_changedtick(state.data), model = model,
    modified = vim.bo[state.data].modified, file = vim.api.nvim_buf_get_name(state.data) }
end

local function selected(model)
  for _, n in ipairs(model.nodes) do if n.id == state.selected then return n end end
  if model.nodes[1] then state.selected = model.nodes[1].id; return model.nodes[1] end
  state.selected = nil
end

local function draw(model)
  if not state.view or not vim.api.nvim_buf_is_valid(state.view) then return end
  local pick = selected(model)
  local height = 22
  for _, n in ipairs(model.nodes) do height = math.max(height, n.y + Model.BOX_HEIGHT + 2) end
  local grid = {}
  for y = 0, height - 1 do
    grid[y] = {}
    for x = 0, Model.WIDTH - 1 do grid[y][x] = " " end
  end
  local function put(x, y, ch)
    if grid[y] and x >= 0 and x < Model.WIDTH then grid[y][x] = ch end
  end
  local nodes = {}; for _, n in ipairs(model.nodes) do nodes[n.id] = n end
  for _, e in ipairs(model.edges) do
    local a, b = nodes[e.from], nodes[e.to]
    if a and b then
      local right = b.x >= a.x
      local x1, x2 = right and a.x + Model.BOX_WIDTH or a.x - 1, right and b.x - 1 or b.x + Model.BOX_WIDTH
      local y1, y2 = a.y + 1, b.y + 1
      local mid = math.floor((x1 + x2) / 2)
      for x = math.min(x1, mid), math.max(x1, mid) do put(x, y1, "─") end
      for y = math.min(y1, y2), math.max(y1, y2) do put(mid, y, "│") end
      for x = math.min(mid, x2), math.max(mid, x2) do put(x, y2, "─") end
      put(x2, y2, right and "▶" or "◀")
    end
  end
  local function label_chars(s, max_width)
    local result, width = {}, 0
    for i = 0, vim.fn.strchars(s) - 1 do
      local c = vim.fn.strcharpart(s, i, 1)
      local w = vim.fn.strdisplaywidth(c)
      if w < 1 then
        if #result > 0 then result[#result] = result[#result] .. c end
      elseif width + w <= max_width then
        result[#result + 1] = c; if w == 2 then result[#result + 1] = "" end
        width = width + w
      else break end
    end
    return result
  end
  for _, n in ipairs(model.nodes) do
    local chosen = n.id == state.selected
    local left_top, right_top, left_bottom, right_bottom, horizontal, vertical = "┌", "┐", "└", "┘", "─", "│"
    if chosen then left_top, right_top, left_bottom, right_bottom, horizontal, vertical = "╔", "╗", "╚", "╝", "═", "║" end
    put(n.x, n.y, left_top); put(n.x + Model.BOX_WIDTH - 1, n.y, right_top)
    put(n.x, n.y + 2, left_bottom); put(n.x + Model.BOX_WIDTH - 1, n.y + 2, right_bottom)
    put(n.x, n.y + 1, vertical); put(n.x + Model.BOX_WIDTH - 1, n.y + 1, vertical)
    for dx = 1, Model.BOX_WIDTH - 2 do
      put(n.x + dx, n.y, horizontal); put(n.x + dx, n.y + 2, horizontal); put(n.x + dx, n.y + 1, " ")
    end
    for dx, c in ipairs(label_chars(n.label, Model.BOX_WIDTH - 2)) do put(n.x + dx, n.y + 1, c) end
  end
  local file = active() and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(state.data), ":~:.") or ""
  local dirty = active() and vim.bo[state.data].modified and " • не сохранено" or ""
  local lines = {
    "АРХИТЕКТУРА: " .. model.title .. dirty,
    "Выбран: " .. (pick and (pick.label .. " [" .. pick.id .. ", " .. pick.kind .. "]") or "нет") .. "   Файл: " .. file,
    "Tab: выбор · hjkl/стрелки: движение · a: добавить · c: связь · r: имя",
    "t: тип · d/x: удалить · =: раскладка · s: сохранить · b: браузер",
    "e: Mermaid · o: JSON · u/C-r: отмена/повтор · q: закрыть · мышь: выбор/перетаскивание",
  }
  for y = 0, height - 1 do
    local row = {}; for x = 0, Model.WIDTH - 1 do row[#row + 1] = grid[y][x] end
    lines[#lines + 1] = table.concat(row)
  end
  vim.bo[state.view].modifiable = true
  vim.api.nvim_buf_set_lines(state.view, 0, -1, false, lines)
  vim.bo[state.view].modifiable = false
  -- Держим выбранный блок в поле зрения при переключении или движении.
  if pick then
    local line = HEADER + pick.y + 2
    for _, win in ipairs(vim.fn.win_findbuf(state.view)) do
      local ok, column = pcall(vim.fn.virtcol2col, win, line, pick.x + 2)
      if ok and column > 0 then pcall(vim.api.nvim_win_set_cursor, win, { line, column - 1 }) end
    end
  end
end

function M.refresh()
  local snapshot, err = M.snapshot()
  if not snapshot then return say(err, true) end
  draw(snapshot.model)
end

local function attach(buf)
  if state.attached[buf] then return end
  state.attached[buf] = true
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, { buffer = buf, callback = function()
    local name = vim.api.nvim_buf_get_name(buf)
    state.baselines[buf] = disk_signature(name)
  end })
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function()
      vim.schedule(function()
        if state.data == buf and vim.api.nvim_buf_is_valid(buf) then
          -- При ручном редактировании JSON может временно быть неполным; не
          -- засыпаем пользователя ошибками на каждый символ.
          local snapshot = M.snapshot()
          if snapshot then draw(snapshot.model) end
        end
      end)
    end,
    on_detach = function() state.attached[buf], state.baselines[buf] = nil, nil end,
  })
end

local function history(which, snapshot)
  local opposite = which == "undo" and "redo" or "undo"
  state.mouse = nil
  local ok, err = pcall(vim.api.nvim_buf_call, state.data, function() vim.cmd("silent " .. which) end)
  if not ok then return nil, tostring(err) end
  local after = M.snapshot()
  if not after then
    -- Не даём undo стереть исходный шаблон или вернуть некорректный JSON.
    pcall(vim.api.nvim_buf_call, state.data, function() vim.cmd("silent " .. opposite) end)
    local restored = M.snapshot()
    if not restored then write_model(state.data, snapshot.model); restored = M.snapshot() end
    if restored then draw(restored.model) end
    return nil, "отмена или повтор привели бы к некорректной схеме"
  end
  draw(after.model)
  return after
end

-- expected — changedtick для защиты от устаревших операций браузера/диалогов.
function M.apply(action, expected, drag_group)
  local snapshot, err = M.snapshot()
  if not snapshot then return nil, err end
  if expected and expected ~= snapshot.rev then return nil, "схема изменилась; повтори действие" end
  if type(action) == "table" and (action.op == "undo" or action.op == "redo") then return history(action.op, snapshot) end
  local next_model, value = Model.apply(snapshot.model, action)
  if not next_model then return nil, value end
  local ok, write_err = write_model(state.data, next_model, drag_group and drag_group.rev == snapshot.rev)
  if not ok then return nil, write_err end
  if action.op == "add" then state.selected = value end
  draw(next_model)
  local result = M.snapshot()
  if drag_group and result then drag_group.rev = result.rev end
  return result, value
end

function M.save()
  if not active() then return nil, "схема не открыта" end
  local model, err = read_model(state.data)
  if not model then return nil, err end
  local path = vim.api.nvim_buf_get_name(state.data)
  local actual, why = disk_signature(path)
  if not actual then return nil, "не удалось проверить файл: " .. tostring(why) end
  local baseline = state.baselines[state.data]
  if not baseline or baseline == "unknown" then
    return nil, "ранее открытый буфер изменён или не совпадает с файлом; сравни версии и сохрани вручную через :w"
  end
  if baseline ~= actual then
    return nil, "файл изменён вне Neovim; сохранение отменено. Сравни версии и разреши конфликт вручную"
  end
  local ok, result = pcall(vim.api.nvim_buf_call, state.data, function() vim.cmd.write() end)
  if not ok then return nil, "не удалось сохранить: " .. tostring(result) end
  if vim.bo[state.data].modified then return nil, "буфер не сохранён" end
  state.baselines[state.data] = disk_signature(vim.api.nvim_buf_get_name(state.data))
  M.refresh()
  return true
end

local function change(action, expected, drag_group)
  local snap, err = M.apply(action, expected, drag_group)
  if not snap then say(err, true) end
  return snap
end

local function cycle(delta)
  local snap = M.snapshot(); if not snap or #snap.model.nodes == 0 then return end
  local index = 1
  for i, n in ipairs(snap.model.nodes) do if n.id == state.selected then index = i; break end end
  state.selected = snap.model.nodes[((index - 1 + delta) % #snap.model.nodes) + 1].id
  draw(snap.model)
end

local function move(dx, dy)
  local snap = M.snapshot(); if not snap then return end
  local n = selected(snap.model); if not n then return end
  change({ op = "move", id = n.id, x = math.max(0, math.min(Model.MAX_X, n.x + dx)), y = math.max(0, math.min(Model.MAX_Y, n.y + dy)) })
end

local function add()
  local snap = M.snapshot(); if not snap then return end
  vim.ui.input({ prompt = "Новый компонент: " }, function(label)
    if label == nil then return end
    change({ op = "add", label = label, kind = "service" }, snap.rev)
  end)
end

local function rename()
  local snap = M.snapshot(); if not snap then return end
  local n = selected(snap.model); if not n then return end
  vim.ui.input({ prompt = "Название компонента: ", default = n.label }, function(label)
    if label ~= nil then change({ op = "rename", id = n.id, label = label }, snap.rev) end
  end)
end

local function set_kind()
  local snap = M.snapshot(); if not snap then return end
  local n = selected(snap.model); if not n then return end
  local choices = {
    { id = "actor", name = "Пользователь / клиент" }, { id = "service", name = "Сервис" },
    { id = "storage", name = "Хранилище" }, { id = "queue", name = "Очередь" },
    { id = "external", name = "Внешняя система" }, { id = "module", name = "Модуль проекта" },
  }
  vim.ui.select(choices, { prompt = "Тип компонента:", format_item = function(x) return x.name end }, function(choice)
    if choice then change({ op = "kind", id = n.id, kind = choice.id }, snap.rev) end
  end)
end

local function link()
  local snap = M.snapshot(); if not snap then return end
  local n = selected(snap.model); if not n then return end
  local choices = {}; for _, target in ipairs(snap.model.nodes) do if target.id ~= n.id then choices[#choices + 1] = target end end
  if #choices == 0 then return say("для связи нужны два компонента", true) end
  vim.ui.select(choices, { prompt = "Соединить " .. n.label .. " →", format_item = function(x) return x.label .. " [" .. x.id .. "]" end }, function(target)
    if not target then return end
    vim.ui.input({ prompt = "Подпись связи (можно пустую): " }, function(label)
      if label ~= nil then change({ op = "link", from = n.id, to = target.id, label = label }, snap.rev) end
    end)
  end)
end

local function delete()
  local snap = M.snapshot(); if not snap then return end
  local n = selected(snap.model); if not n then return end
  vim.ui.select({ "Нет", "Удалить" }, { prompt = "Удалить " .. n.label .. " и связанные стрелки?" }, function(choice)
    if choice == "Удалить" then change({ op = "delete", id = n.id }, snap.rev) end
  end)
end

local function unlink()
  local snap = M.snapshot(); if not snap then return end
  if #snap.model.edges == 0 then return say("связей пока нет", true) end
  local names = {}; for _, n in ipairs(snap.model.nodes) do names[n.id] = n.label end
  vim.ui.select(snap.model.edges, { prompt = "Удалить связь:", format_item = function(e)
    local label = e.label or ""
    return (names[e.from] or e.from) .. " → " .. (names[e.to] or e.to) .. (label ~= "" and (" · " .. label) or "")
  end }, function(e) if e then change({ op = "unlink", id = e.id }, snap.rev) end end)
end

local function mouse(drag)
  local m = vim.fn.getmousepos()
  if not state.view or m.winid == 0 or vim.api.nvim_win_get_buf(m.winid) ~= state.view then return end
  local x = vim.fn.virtcol({ m.line, m.column }) - 1
  local y = m.line - HEADER - 1
  local snap = M.snapshot(); if not snap then return end
  if drag then
    local anchor = state.mouse
    if anchor and anchor.id == state.selected then
      local result = change({ op = "move", id = anchor.id, x = math.max(0, math.min(Model.MAX_X, x - anchor.dx)), y = math.max(0, math.min(Model.MAX_Y, y - anchor.dy)) }, anchor.rev or anchor.start_rev, anchor)
      if not result then state.mouse = nil end
    end
    return
  end
  state.mouse = nil
  for i = #snap.model.nodes, 1, -1 do
    local n = snap.model.nodes[i]
    if x >= n.x and x < n.x + Model.BOX_WIDTH and y >= n.y and y < n.y + Model.BOX_HEIGHT then
      state.selected, state.mouse = n.id, { id = n.id, dx = x - n.x, dy = y - n.y, start_rev = snap.rev }
      draw(snap.model); return
    end
  end
end

function M.export()
  local snap, err = M.snapshot(); if not snap then return say(err, true) end
  local lines, why = Model.mermaid(snap.model); if not lines then return say(why, true) end
  vim.cmd("new")
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "markdown" then vim.bo[buf].filetype = "markdown" end
  local current = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if vim.bo[buf].modified or #current ~= 1 or current[1] ~= "" then
    return say("новый буфер изменён автокомандой; экспорт не перезаписывает его", true)
  end
  local ok, failure = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
  if not ok then return say("экспорт не удался: " .. tostring(failure), true) end
  say("Mermaid открыт в новом буфере; сохрани его через :saveas файл.md")
end

local function open_view()
  if not state.view or not vim.api.nvim_buf_is_valid(state.view) then
    state.view = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(state.view, "architecture://board")
    vim.bo[state.view].buftype, vim.bo[state.view].bufhidden, vim.bo[state.view].swapfile = "nofile", "hide", false
    vim.bo[state.view].filetype = "archboard"
    local opts = { buffer = state.view, silent = true }
    local function map(keys, fn) vim.keymap.set("n", keys, fn, opts) end
    map("<Tab>", function() cycle(1) end); map("<S-Tab>", function() cycle(-1) end)
    map("h", function() move(-1, 0) end); map("l", function() move(1, 0) end)
    map("k", function() move(0, -1) end); map("j", function() move(0, 1) end)
    map("<Left>", function() move(-1, 0) end); map("<Right>", function() move(1, 0) end)
    map("<Up>", function() move(0, -1) end); map("<Down>", function() move(0, 1) end)
    map("a", add); map("c", link); map("r", rename); map("t", set_kind); map("d", delete); map("x", unlink)
    map("=", function() change({ op = "layout" }) end)
    map("s", function() local ok, err = M.save(); say(ok and "схема сохранена" or err, not ok) end)
    map("b", function() require("config.architecture_server").open() end)
    map("e", M.export)
    map("o", function() if active() then vim.cmd("botright split"); vim.api.nvim_win_set_buf(0, state.data) end end)
    map("u", function() change({ op = "undo" }) end); map("<C-r>", function() change({ op = "redo" }) end)
    map("q", function() vim.cmd.close() end)
    map("<LeftMouse>", function() mouse(false) end); map("<LeftDrag>", function() mouse(true) end)
    map("<LeftRelease>", function() state.mouse = nil end)
  end
  local wins = vim.fn.win_findbuf(state.view)
  local win = wins[1]
  if not win then
    vim.cmd("tabnew") -- полная ширина терминала удобнее половины vsplit
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, state.view)
  else vim.api.nvim_set_current_win(win) end
  vim.wo[win].number, vim.wo[win].relativenumber, vim.wo[win].wrap = false, false, false
  vim.wo[win].signcolumn = "no"
  M.refresh()
end

local function exact_buffer(path)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b) == path then return b end
  end
end

-- Новый файл и существующие буферы не перезаписываются; :w / s — явно.
function M.open(path, template)
  if (not path or path == "") and active() and not template then return open_view() end
  if not path or path == "" then
    return vim.ui.input({ prompt = "Файл схемы: ", default = "architecture.arch.json", completion = "file" }, function(p)
      if p and p ~= "" then M.open(p, template) end
    end)
  end
  path = vim.trim(path)
  if path == "" or path:find("[%z\r\n]") then return say("неверное имя файла", true) end
  if path:sub(1, 2) == "~/" then path = vim.fn.expand("~") .. path:sub(2) end
  path = vim.fn.fnamemodify(path, ":p")
  local prior_buf = exact_buffer(path)
  local existing = vim.uv.fs_lstat(path) ~= nil or prior_buf ~= nil
  if template and existing then return say("файл или буфер уже существует; ничего не перезаписано", true) end
  if not existing and not template then
    return vim.ui.select(Model.template_names, { prompt = "Выбери вид архитектуры:", format_item = function(x) return x.name end }, function(choice)
      if choice then M.open(path, Model.template(choice.id)) end
    end)
  end
  local ok, buf = pcall(vim.fn.bufadd, path)
  if not ok then return say("не удалось открыть файл: " .. tostring(buf), true) end
  local loaded, load_err = pcall(vim.fn.bufload, buf)
  if not loaded then return say("не удалось открыть файл: " .. tostring(load_err), true) end
  if not state.baselines[buf] then
    local signature, sig_err = disk_signature(path)
    if not signature then return say("не удалось проверить файл: " .. tostring(sig_err), true) end
    state.baselines[buf] = prior_buf and not buffer_matches_disk(buf, path, signature) and "unknown" or signature
  end
  attach(buf)
  if template then
    -- Автокоманды BufRead/BufNewFile могли наполнить или изменить буфер.
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if vim.bo[buf].modified or #lines ~= 1 or lines[1] ~= "" or vim.uv.fs_lstat(path) then
      return say("новый буфер уже содержит данные; ничего не перезаписано", true)
    end
    local written, why = write_model(buf, template)
    if not written then return say(why, true) end
  end
  local model, why = read_model(buf)
  if not model then return say("файл не открыт как схема: " .. why, true) end
  if vim.bo[buf].filetype == "" then vim.bo[buf].filetype = "json" end
  state.data, state.selected, state.mouse = buf, nil, nil
  open_view()
  say("схема открыта; s сохраняет JSON, b открывает браузер")
end

function M.new_template()
  vim.ui.select(Model.template_names, { prompt = "Новая схема — выбери вид:", format_item = function(x) return x.name end }, function(choice)
    if choice then M.open(nil, Model.template(choice.id)) end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("ArchBoard", function(o) M.open(o.args) end, { nargs = "?", complete = "file", desc = "Открыть интерактивную схему в Neovim" })
  vim.api.nvim_create_user_command("ArchBoardNew", M.new_template, { desc = "Новая схема по шаблону" })
  vim.api.nvim_create_user_command("ArchBrowser", function() require("config.architecture_server").open() end, { desc = "Редактор схемы в браузере" })
  vim.api.nvim_create_user_command("ArchSave", function() local ok, err = M.save(); say(ok and "схема сохранена" or err, not ok) end, { desc = "Сохранить JSON схемы" })
  vim.api.nvim_create_user_command("ArchExport", M.export, { desc = "Экспортировать схему в буфер Mermaid" })
  vim.api.nvim_create_user_command("ArchScan", function() require("config.architecture_scan").choose() end, { desc = "Локально построить схему зависимостей проекта" })
  require("config.architecture_server").setup()
end

return M
