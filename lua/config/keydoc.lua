-- ========================================================================== --
--         СПРАВКА ПО КЛАВИШАМ: <leader>? + клавиши  (объясняет, не выполняет)  --
-- ========================================================================== --
-- Два режима:
--   1) <leader>? затем клавиши — разовая справка, команда НЕ выполняется.
--      Повторять сколько угодно.
--   2) <leader>?m — режим справки: пока включён, назначенные клавиши ОБЪЯСНЯЮТСЯ
--      вместо выполнения. Выход: Esc или снова <leader>?m.
-- Тексты: lua/config/keydocs/g*.lua. Клавиши <leader>D… строятся из db_menu.
-- Не переопределяются в режиме справки: клавиши Super Mode (hydra = true),
-- <Esc> и сама справка (<leader>?…) — иначе режим нельзя было бы выключить.

local M = {}

local GROUPS = {
  "config.keydocs.g1_editor",
  "config.keydocs.g2_tools",
  "config.keydocs.g3_menu_h",
  "config.keydocs.g4_new",
  "config.keydocs.g5_lsp_help",
  "config.keydocs.g6_missing",
  "config.keydocs.g7_insert",
}

local ESC = "\27"

-- Подписи действий для клавиш базы данных <leader>D<СУБД><действие>
local DB_ACTION_DOC = {
  c = "Открывает интерактивную консоль СУБД (vim-dadbod) по подключению этой базы.",
  r = "Выполняет SQL: буфер (normal) или выделение (visual). Работает ТОЛЬКО в SQL-буфере (filetype sql).",
  t = "Список таблиц базы данных.",
  d = "Описание таблицы: спрашивает имя таблицы и показывает её структуру.",
  n = "Создаёт новый SQL-буфер, привязанный к этому подключению.",
  u = "Открывает панель vim-dadbod-ui (дерево баз и таблиц).",
}

local function load_entries()
  local out = {}
  for _, g in ipairs(GROUPS) do
    local ok, list = pcall(require, g)
    if ok and type(list) == "table" then
      for _, e in ipairs(list) do
        out[#out + 1] = e
      end
    end
  end
  -- Клавиши БД берём из той же функции, что регистрирует lazy.nvim (db_menu.keys):
  -- справка и меню не могут разойтись.
  local ok, dbm = pcall(require, "config.db_menu")
  if ok and type(dbm.keys) == "function" then
    for _, k in ipairs(dbm.keys()) do
      if k.mode ~= "x" then -- визуальный вариант «r» описан в обычной клавише
        local action = k[1]:sub(-1)
        out[#out + 1] = {
          lhs = k[1],
          name = k.desc,
          doc = DB_ACTION_DOC[action] or "",
        }
      end
    end
  end
  return out
end

M.entries = load_entries

-- Единый вид клавиши для сравнения: <leader> → реальный символ, затем keytrans
local function norm_lhs(lhs)
  local leader = vim.g.mapleader or "\\"
  local s = lhs:gsub("<leader>", leader)
  return vim.fn.keytrans(vim.api.nvim_replace_termcodes(s, true, false, true))
end

-- Окно с текстом справки; закрывается Esc / q / Enter (команда НЕ выполнена)
function M.show(entry)
  local lines = { ("  %s  —  %s"):format(entry.lhs, entry.name or ""), "" }
  for _, l in ipairs(vim.split(entry.doc ~= "" and entry.doc or "Описания пока нет.", "\n", { plain = true })) do
    lines[#lines + 1] = "  " .. l
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  Esc / q / Enter — закрыть. Команда не выполнялась."

  local width = 40
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l) + 2)
  end
  width = math.min(width, vim.o.columns - 4)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = math.min(#lines, vim.o.lines - 4),
    row = math.max(1, math.floor((vim.o.lines - #lines) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    style = "minimal",
    border = "rounded",
    title = " ❓ Справка ",
    title_pos = "center",
  })
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  for _, k in ipairs({ "<Esc>", "q", "<CR>" }) do
    vim.keymap.set("n", k, close, { buffer = buf, nowait = true, silent = true })
  end
  return win
end

-- Режим 1: разовый поиск по клавишам после <leader>?
function M.lookup()
  local list = load_entries()
  local typed = ""
  local last_exact = nil
  local function has_prefix(key)
    for _, e in ipairs(list) do
      local n = norm_lhs(e.lhs)
      if n ~= key and n:sub(1, #key) == key then
        return true
      end
    end
    return false
  end
  -- Первую клавишу ждём сколько нужно; если уже есть точное совпадение с более
  -- длинными вариантами — ждём продолжение не дольше timeoutlen, потом показываем точное.
  local function read()
    if last_exact then
      local got = vim.wait(vim.o.timeoutlen, function()
        return vim.fn.getchar(1) ~= 0
      end, 15)
      if not got then
        return nil
      end
    end
    local ok, ch = pcall(vim.fn.getcharstr)
    return ok and ch or nil
  end
  while true do
    local ch = read()
    if not ch then
      if last_exact then
        return M.show(last_exact)
      end
      return
    end
    if ch == "" or ch == ESC then
      return
    end
    typed = typed .. ch
    -- Пользователь нажимает реальные клавиши (включая лидер = пробел), сравниваем как есть
    local key = vim.fn.keytrans(typed)
    local exact = nil
    for _, e in ipairs(list) do
      if norm_lhs(e.lhs) == key then
        exact = e
        break
      end
    end
    local pre = has_prefix(key)
    if exact and not pre then
      return M.show(exact)
    end
    if exact then
      last_exact = exact -- точное совпадение, но есть более длинные: ждём следующую клавишу
    elseif not pre then
      if last_exact then
        return M.show(last_exact)
      end
      vim.notify("❓ Справки для «" .. vim.fn.keytrans(typed) .. "» нет", vim.log.levels.INFO)
      return
    end
    if #typed > 10 then
      return
    end
  end
end

-- Режим 2: переключатель. Пока включён, назначенные клавиши объясняются.
M.active = false
local saved = {} -- { lhs, prev }  prev = dict из maparg или false

local function help_candidates()
  local out = {}
  for _, e in ipairs(load_entries()) do
    local skip = e.hydra or (e.mode or "n") ~= "n" or (e.doc or "") == ""
      or e.lhs:match("^<leader>%?") or e.lhs == "<Esc>"
    if not skip then
      out[#out + 1] = e
    end
  end
  return out
end

local function disable_help_mode()
  for _, s in ipairs(saved) do
    pcall(vim.keymap.del, "n", s.lhs)
    local p = s.prev
    if p and p.callback then
      vim.keymap.set("n", s.lhs, p.callback, { desc = p.desc, silent = p.silent == 1 })
    elseif p and p.rhs then
      vim.keymap.set("n", s.lhs, p.rhs, { desc = p.desc, silent = p.silent == 1, remap = p.noremap ~= 1 })
    end
  end
  saved = {}
end

local function enable_help_mode()
  local lead = vim.g.mapleader or "\\"
  for _, e in ipairs(help_candidates()) do
    local lhs = e.lhs:gsub("<leader>", lead)
    local prev = vim.fn.maparg(lhs, "n", false, true)
    saved[#saved + 1] = { lhs = lhs, prev = (prev and next(prev)) and prev or false }
    vim.keymap.set("n", lhs, function()
      M.show(e)
    end, { desc = "❓ " .. (e.name or lhs), nowait = true })
  end
  -- Выход из режима — Esc (его предыдущее поведение запоминаем)
  local prev_esc = vim.fn.maparg("<Esc>", "n", false, true)
  saved[#saved + 1] = { lhs = "<Esc>", prev = (prev_esc and next(prev_esc)) and prev_esc or false }
  vim.keymap.set("n", "<Esc>", function()
    M.toggle_help_mode()
  end, { desc = "Выйти из режима справки" })
end

function M.toggle_help_mode()
  if M.active then
    disable_help_mode()
    M.active = false
    vim.notify("❓ Режим справки выключен: клавиши снова выполняются", vim.log.levels.INFO)
  else
    enable_help_mode()
    M.active = true
    vim.notify("❓ Режим справки ВКЛ: клавиши объясняются. Esc или <leader>?m — выход", vim.log.levels.INFO)
  end
end

function M.setup()
  vim.keymap.set("n", "<leader>?", M.lookup, { desc = "❓ Справка по клавише (не выполняет)" })
  vim.keymap.set("n", "<leader>?m", M.toggle_help_mode, { desc = "❓ Режим справки вкл/выкл" })
end

return M
