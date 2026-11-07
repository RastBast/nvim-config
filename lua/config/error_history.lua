-- ========================================================================== --
--     РАЗДЕЛ ОШИБОК (<leader>x): ПОСЛЕДНИЕ 10 ОШИБОК И ПОЛНЫЙ ЖУРНАЛ         --
-- ========================================================================== --
-- Два отдельных макроса (клавиши) в группе <leader>x («Ошибки и журнал»):
--   1) <leader>xe  (и <leader>Hxe, :ErrorLast10) — последние 10 ошибок Neovim
--   2) <leader>xj  (и <leader>xg, <leader>Hxj, :ErrorLog) — полный журнал ошибок
--
-- Дополнительно:
--   * Внутри окна ошибок:
--       Enter / gf — прыгнуть прямо на файл:строку из стектрейса под курсором!
--       a          — разобрать ошибку под курсором через ИИ (config.ai_api)
--       Tab        — переключить 10 ошибок ↔ полный журнал
--       y          — скопировать ошибки в системный буфер +
--       c          — очистить журнал сеанса
--   * В Lualine (lua/plugins/lualine.lua): компактный счётчик ❗N (скрыт при 0).
--
-- ВНИМАНИЕ: <leader>xl НЕ трогаем — она занята Trouble Location List!
local M = {
  entries = {},
  max_entries = 500,
  last_seen_errmsg = "",
}

local win_id = nil
local buf_id = nil
local prev_win_id = nil
local current_mode = "last10" -- "last10" | "log"
local line_to_entry = {}
local shown_entries = {}

local function now_hms()
  local ok, s = pcall(os.date, "%H:%M:%S")
  return ok and type(s) == "string" and s or "--:--:--"
end

local function normalize_text(text)
  if type(text) ~= "string" then
    text = tostring(text or "")
  end
  text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
  return vim.trim(text)
end

--- Записать ошибку в сеансовый кольцевой буфер (с дедупликацией подряд идущих дублей).
function M.record(text, source, timestamp)
  local clean = normalize_text(text)
  if clean == "" then
    return
  end
  local time_str = timestamp or now_hms()
  local src = (type(source) == "string" and source ~= "") and source or "nvim"

  local prev = M.entries[#M.entries]
  if prev and prev.text == clean then
    prev.count = (prev.count or 1) + 1
    prev.time = time_str
    return
  end

  M.entries[#M.entries + 1] = {
    text = clean,
    source = src,
    time = time_str,
    count = 1,
  }
  if #M.entries > M.max_entries then
    table.remove(M.entries, 1)
  end
end

--- Вызывается из фильтра vim.notify в init.lua и ранней обёртки.
function M.record_notify(msg, level, opts)
  local err_lvl = (vim.log and vim.log.levels and vim.log.levels.ERROR) or 4
  if level ~= nil and level < err_lvl then
    return
  end
  local title = type(opts) == "table" and (opts.title or opts.annote) or nil
  M.record(tostring(msg or ""), title or "notify")
end

--- Проверить, появилась ли новая ошибка в vim.v.errmsg (например E492 / E5108).
function M.capture_errmsg()
  local errmsg = vim.v and vim.v.errmsg or ""
  if type(errmsg) == "string" and errmsg ~= "" and errmsg ~= M.last_seen_errmsg then
    M.last_seen_errmsg = errmsg
    M.record(errmsg, "v:errmsg")
  end
end

--- Быстрый подсчёт ошибок для строки состояния Lualine (без тяжёлого :messages).
function M.count()
  M.capture_errmsg()
  local n = #M.entries
  local manager = package.loaded["noice.message.manager"]
  if type(manager) == "table" and type(manager.get) == "function" then
    local ok, list = pcall(manager.get, { error = true }, { history = true })
    if ok and type(list) == "table" and #list > n then
      n = #list
    end
  end
  return n
end

--- Компонент для Lualine: пустая строка при 0 ошибок, иначе «❗N».
function M.component()
  local c = M.count()
  if c <= 0 then
    return ""
  end
  return "❗" .. tostring(c)
end

local function is_noice_running()
  local cfg = package.loaded["noice.config"]
  if type(cfg) == "table" and type(cfg.is_running) == "function" then
    local ok, running = pcall(cfg.is_running)
    if ok and running then
      return true
    end
  end
  local ui = package.loaded["noice.ui"]
  return type(ui) == "table" and ui._attached == true
end

local function collect_from_noice()
  local manager = package.loaded["noice.message.manager"]
  if type(manager) ~= "table" or type(manager.get) ~= "function" then
    return {}
  end
  local ok, list = pcall(manager.get, { error = true }, { history = true, sort = true })
  if not ok or type(list) ~= "table" then
    return {}
  end
  local out = {}
  for _, item in ipairs(list) do
    local text = nil
    if type(item) == "table" then
      if type(item.content) == "function" then
        local ok_c, res = pcall(item.content, item)
        if ok_c and type(res) == "string" then
          text = res
        end
      elseif type(item.message) == "string" then
        text = item.message
      end
    end
    local clean = normalize_text(text or "")
    if clean ~= "" then
      local ts = nil
      if type(item) == "table" and type(item.ctime) == "number" then
        local ok_d, s = pcall(os.date, "%H:%M:%S", math.floor(item.ctime))
        if ok_d then ts = s end
      end
      out[#out + 1] = {
        text = clean,
        source = (type(item) == "table" and item.event) and tostring(item.event) or "noice",
        time = ts or now_hms(),
        count = 1,
      }
    end
  end
  return out
end

local function is_error_start(line)
  return line:match("^E%d+:")
    or line:match("^Error ")
    or line:match("^Lua callback:")
    or line:match("^vim%.schedule callback:")
    or (line:match("^%[mason") and line:lower():find("fail", 1, true) ~= nil)
    or line:find("Failed to ", 1, true) ~= nil
    or line:find("stack traceback:", 1, true) ~= nil
end

local function is_traceback_continuation(line)
  return line:match("^%s*stack traceback:")
    or line:match("^\t")
    or line:match("^%s+%[C%]:")
    or line:match("^%s*%.%.%.")
    or line:match("^%s+[%w_./~-]+:%d+:")
end

--- Разбор :messages со склейкой многострочных Lua stack traceback в одну ошибку.
local function collect_from_messages()
  if is_noice_running() then
    return {}
  end
  if type(vim.api.nvim_exec2) ~= "function" then
    return {}
  end
  local ok, res = pcall(vim.api.nvim_exec2, "messages", { output = true })
  if not ok or type(res) ~= "table" or type(res.output) ~= "string" or res.output == "" then
    return {}
  end
  local blocks = {}
  local current = nil
  for line in (res.output .. "\n"):gmatch("(.-)\n") do
    if is_error_start(line) then
      if current and is_traceback_continuation(line) then
        current[#current + 1] = line
      elseif current and (line:match("^Lua callback:") or line:match("^stack traceback:")) then
        current[#current + 1] = line
      else
        if current then
          blocks[#blocks + 1] = table.concat(current, "\n")
        end
        current = { line }
      end
    elseif current and is_traceback_continuation(line) then
      current[#current + 1] = line
    else
      if current then
        blocks[#blocks + 1] = table.concat(current, "\n")
        current = nil
      end
    end
  end
  if current then
    blocks[#blocks + 1] = table.concat(current, "\n")
  end

  local out = {}
  for _, b in ipairs(blocks) do
    local clean = normalize_text(b)
    if clean ~= "" then
      out[#out + 1] = {
        text = clean,
        source = "messages",
        time = now_hms(),
        count = 1,
      }
    end
  end
  return out
end

--- Собрать единый дедуплицированный список всех ошибок сеанса (в хронологическом порядке).
function M.collect()
  M.capture_errmsg()
  local combined = {}
  local seen = {}

  local function push(entry)
    local clean = normalize_text(entry.text)
    if clean == "" then
      return
    end
    local prev = combined[#combined]
    if prev and prev.text == clean then
      prev.count = (prev.count or 1) + (entry.count or 1)
      return
    end
    if seen[clean] then
      return
    end
    seen[clean] = true
    combined[#combined + 1] = {
      text = clean,
      source = entry.source or "nvim",
      time = entry.time or now_hms(),
      count = entry.count or 1,
    }
  end

  for _, e in ipairs(M.entries) do
    push(e)
  end
  for _, e in ipairs(collect_from_noice()) do
    push(e)
  end
  for _, e in ipairs(collect_from_messages()) do
    push(e)
  end

  return combined
end

--- Найти реальный файл на диске, даже если Neovim сократил начало пути через `...`.
local function resolve_candidate_path(raw_path)
  if type(raw_path) ~= "string" or raw_path == "" then
    return nil
  end
  local p = vim.trim(raw_path)
  p = p:gsub("^['\"`(]+", ""):gsub("['\"`):,]+$", "")
  if p:sub(1, 2) == "~/" and vim.env and vim.env.HOME then
    p = vim.env.HOME .. p:sub(2)
  end
  if vim.fn.filereadable and vim.fn.filereadable(p) == 1 then
    return p
  end

  local cwd = (vim.fn.getcwd and vim.fn.getcwd()) or ""
  if cwd ~= "" and vim.fn.filereadable and vim.fn.filereadable(cwd .. "/" .. p) == 1 then
    return cwd .. "/" .. p
  end

  -- Обработка путей, обрезанных Neovim спереди: `...avante.nvim/lua/avante/repo_map.lua`
  local stripped = p:gsub("^%.%.%.+/?", "")
  local bases = {}
  if vim.fn.stdpath then
    local cfg = vim.fn.stdpath("config")
    local data = vim.fn.stdpath("data")
    if type(cfg) == "string" and cfg ~= "" then bases[#bases + 1] = cfg end
    if type(data) == "string" and data ~= "" then
      bases[#bases + 1] = data .. "/lazy"
      bases[#bases + 1] = data
    end
  end
  if cwd ~= "" then
    bases[#bases + 1] = cwd
  end

  for _, base in ipairs(bases) do
    local direct = base .. "/" .. stripped
    if vim.fn.filereadable and vim.fn.filereadable(direct) == 1 then
      return direct
    end
    -- Иногда обрезана середина имени папки: `...nte.nvim/lua/avante/repo_map.lua`
    local sub_after_slash = stripped:match("^[^/]+/(.+)$")
    if sub_after_slash and vim.uv and type(vim.uv.fs_scandir) == "function" then
      local h = vim.uv.fs_scandir(base)
      if h then
        while true do
          local name, typ = vim.uv.fs_scandir_next(h)
          if not name then break end
          if typ == nil or typ == "directory" then
            local cand = base .. "/" .. name .. "/" .. sub_after_slash
            if vim.fn.filereadable and vim.fn.filereadable(cand) == 1 then
              return cand
            end
          end
        end
      end
    end
  end

  return p
end

--- Извлечь { path, line, col } из строки ошибки или полного текста стектрейса
--- (Lua, Go, Python, TypeScript/JS, Rust).
function M.parse_location(text)
  if type(text) ~= "string" or text == "" then
    return nil
  end

  -- Python: File "path/to/app.py", line 42
  local py_file, py_line = text:match('File "([^"]+)", line (%d+)')
  if py_file and py_line then
    return {
      path = resolve_candidate_path(py_file),
      line = tonumber(py_line) or 1,
      col = 1,
    }
  end

  -- Стандартный формат Lua / Go / TS / Rust: [optional ...]path/file.ext:112[:15]
  for cand, lnum, col in text:gmatch("([%.~/%w_%-%+]+%.[%a%d_]+):(%d+):?(%d*)") do
    if not cand:match("^https?$") then
      local resolved = resolve_candidate_path(cand)
      if resolved then
        return {
          path = resolved,
          line = tonumber(lnum) or 1,
          col = tonumber(col) or 1,
        }
      end
    end
  end

  return nil
end

local function format_view(mode)
  local all = M.collect()
  local total = #all
  local shown = {}

  if mode == "last10" then
    local from = math.max(1, total - 9)
    for i = total, from, -1 do
      shown[#shown + 1] = { idx = total - i + 1, real_num = i, item = all[i] }
    end
  else
    for i = total, 1, -1 do
      shown[#shown + 1] = { idx = total - i + 1, real_num = i, item = all[i] }
    end
  end

  local title = mode == "last10"
    and ("🔟 Последние 10 ошибок Neovim (показано %d из %d)"):format(#shown, total)
    or ("📜 Полный журнал ошибок Neovim (всего: %d)"):format(total)

  local lines = {
    title,
    "Клавиши: Enter/gf к файлу:строке · a разбор ИИ · Tab 10↔Все · y копия · c очистить · r обновить · q выход",
    string.rep("─", 92),
  }
  local map_lines = {}
  local copy_blocks = {}
  shown_entries = {}

  if #shown == 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "✅ В текущем сеансе Neovim ошибок пока не зафиксировано."
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Подсказка:"
    lines[#lines + 1] = "  • Ошибки кода/LSP в файлах проекта: <leader>xx (Trouble)"
    lines[#lines + 1] = "  • Диагностика Avante: :AvanteStatus (<leader>AI)"
    lines[#lines + 1] = "  • Лог установки пакетов Mason: :MasonLog"
  else
    for _, row in ipairs(shown) do
      local e = row.item
      shown_entries[#shown_entries + 1] = e
      local repeat_tag = (e.count and e.count > 1) and (" ×" .. tostring(e.count)) or ""
      local loc = M.parse_location(e.text)
      local loc_hint = loc and ("  📍 " .. vim.fn.fnamemodify(loc.path, ":t") .. ":" .. loc.line) or ""
      local head = ("[%d] %s · %s%s%s"):format(row.idx, e.time or "--:--:--", e.source or "nvim", repeat_tag, loc_hint)
      lines[#lines + 1] = ""
      lines[#lines + 1] = head
      map_lines[#lines] = e
      for sub in (e.text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = "  " .. sub
        map_lines[#lines] = e
      end
      copy_blocks[#copy_blocks + 1] = head .. "\n" .. e.text
    end
  end

  return lines, map_lines, table.concat(copy_blocks, "\n\n"), title
end

local function close_win()
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    pcall(vim.api.nvim_win_close, win_id, true)
  end
  win_id = nil
end

local function current_cursor_line_and_entry()
  local lnum = 1
  if win_id and vim.api.nvim_win_is_valid(win_id) and type(vim.api.nvim_win_get_cursor) == "function" then
    local ok, pos = pcall(vim.api.nvim_win_get_cursor, win_id)
    if ok and type(pos) == "table" and tonumber(pos[1]) then
      lnum = tonumber(pos[1])
    end
  end
  local line_str = ""
  if buf_id and vim.api.nvim_buf_is_valid(buf_id) and type(vim.api.nvim_buf_get_lines) == "function" then
    local ok, fetched = pcall(vim.api.nvim_buf_get_lines, buf_id, lnum - 1, lnum, false)
    if ok and type(fetched) == "table" and fetched[1] then
      line_str = fetched[1]
    end
  end
  local entry = line_to_entry[lnum] or shown_entries[1]
  return line_str, entry
end

local function jump_from_cursor()
  local line_str, entry = current_cursor_line_and_entry()
  local loc = M.parse_location(line_str) or (entry and M.parse_location(entry.text)) or nil
  if not loc or not loc.path then
    vim.notify("В выбранной ошибке не найден путь файл:строка для перехода.", vim.log.levels.INFO)
    pcall(vim.api.nvim_echo, { { "В этой записи нет координат файл:строка", "WarningMsg" } }, false, {})
    return
  end
  if vim.fn.filereadable and vim.fn.filereadable(loc.path) ~= 1 then
    local msg = "Файл из стектрейса не найден на диске: " .. tostring(loc.path)
    vim.notify(msg, vim.log.levels.WARN)
    pcall(vim.api.nvim_echo, { { msg, "WarningMsg" } }, false, {})
    return
  end

  local target_win = prev_win_id
  close_win()
  if target_win and vim.api.nvim_win_is_valid and vim.api.nvim_win_is_valid(target_win) then
    pcall(vim.api.nvim_set_current_win, target_win)
  end
  vim.cmd("edit " .. vim.fn.fnameescape(loc.path))
  if type(vim.api.nvim_win_set_cursor) == "function" then
    pcall(vim.api.nvim_win_set_cursor, 0, { math.max(1, loc.line or 1), math.max(0, (loc.col or 1) - 1) })
  end
  pcall(vim.cmd, "normal! zz")
end

local function analyze_with_ai()
  local _, entry = current_cursor_line_and_entry()
  if not entry or not entry.text or entry.text == "" then
    pcall(vim.api.nvim_echo, { { "Нет выбранной ошибки для разбора ИИ", "WarningMsg" } }, false, {})
    return
  end
  local ok_ai, AI = pcall(require, "config.ai_api")
  if not ok_ai or type(AI.chat) ~= "function" then
    vim.notify("Модуль config.ai_api недоступен", vim.log.levels.ERROR)
    return
  end

  pcall(vim.api.nvim_echo, { { "🤖 Отправляю ошибку на разбор ИИ…", "MoreMsg" } }, false, {})
  AI.chat({
    {
      role = "system",
      content = "Ты опытный инженер по Neovim, Lua, Go и системной отладке. Отвечай кратко и по делу на русском языке: 1) в чём точная причина ошибки, 2) как исправить (команда или патч кода), 3) как проверить.",
    },
    {
      role = "user",
      content = "Разбери эту ошибку из журнала Neovim:\n\n```text\n" .. entry.text .. "\n```",
    },
  }, { temperature = 0.15 }, function(answer, why, provider)
    if not answer then
      local err_msg = "ИИ не смог разобрать ошибку: " .. tostring(why or "нет ответа") .. " (проверь :AiStatus / <leader>Ap)"
      vim.notify(err_msg, vim.log.levels.ERROR)
      pcall(vim.api.nvim_echo, { { err_msg, "ErrorMsg" } }, true, {})
      return
    end
    local pname = (type(provider) == "table" and provider.name) and provider.name or "AI"
    if type(AI.float) == "function" then
      AI.float("🤖 Разбор ошибки · " .. pname, answer)
    else
      pcall(vim.api.nvim_echo, { { answer, "None" } }, true, {})
    end
  end)
end

local function render_into_window(mode)
  current_mode = mode or current_mode
  if not (win_id and vim.api.nvim_win_is_valid(win_id)) and type(vim.api.nvim_get_current_win) == "function" then
    local ok_w, cur = pcall(vim.api.nvim_get_current_win)
    if ok_w then prev_win_id = cur end
  end

  local raw_lines, raw_map, copy_text, short_title = format_view(current_mode)

  local safe_lines = {}
  line_to_entry = {}
  for idx, line in ipairs(raw_lines) do
    local mapped = raw_map[idx]
    for part in (tostring(line) .. "\n"):gmatch("(.-)\n") do
      safe_lines[#safe_lines + 1] = part
      if mapped then
        line_to_entry[#safe_lines] = mapped
      end
    end
  end

  if not buf_id or not vim.api.nvim_buf_is_valid(buf_id) then
    buf_id = vim.api.nvim_create_buf(false, true)
    vim.bo[buf_id].buftype = "nofile"
    vim.bo[buf_id].bufhidden = "wipe"
    vim.bo[buf_id].swapfile = false
    vim.bo[buf_id].filetype = "nvimerrors"
  end

  vim.bo[buf_id].modifiable = true
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, safe_lines)
  vim.bo[buf_id].modifiable = false

  local has_ui = type(vim.api.nvim_list_uis) == "function" and #vim.api.nvim_list_uis() > 0
  if has_ui and type(vim.api.nvim_open_win) == "function" then
    local cols = (vim.o and vim.o.columns and vim.o.columns > 20) and vim.o.columns or 100
    local rows = (vim.o and vim.o.lines and vim.o.lines > 10) and vim.o.lines or 30
    local width = math.min(math.max(76, math.floor(cols * 0.84)), math.max(20, cols - 4))
    local height = math.min(math.max(12, #safe_lines + 2), math.max(8, rows - 6))
    local win_cfg = {
      relative = "editor",
      width = width,
      height = height,
      row = math.max(0, math.floor((rows - height) / 2)),
      col = math.max(0, math.floor((cols - width) / 2)),
      style = "minimal",
      border = "rounded",
      title = " " .. short_title .. " ",
      title_pos = "center",
    }
    if win_id and vim.api.nvim_win_is_valid(win_id) then
      pcall(vim.api.nvim_win_set_config, win_id, win_cfg)
      vim.api.nvim_set_current_win(win_id)
    else
      win_id = vim.api.nvim_open_win(buf_id, true, win_cfg)
    end
    vim.wo[win_id].wrap = true
    vim.wo[win_id].linebreak = true
    vim.wo[win_id].cursorline = true
  else
    if not (win_id and vim.api.nvim_win_is_valid(win_id)) then
      vim.cmd("botright new")
      win_id = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win_id, buf_id)
    end
  end

  local map_opts = { buffer = buf_id, nowait = true, silent = true }
  vim.keymap.set("n", "q", close_win, vim.tbl_extend("force", map_opts, { desc = "Закрыть окно ошибок" }))
  vim.keymap.set("n", "<Esc>", close_win, vim.tbl_extend("force", map_opts, { desc = "Закрыть окно ошибок" }))
  vim.keymap.set("n", "<CR>", jump_from_cursor, vim.tbl_extend("force", map_opts, { desc = "Перейти на файл:строку из стектрейса" }))
  vim.keymap.set("n", "gf", jump_from_cursor, vim.tbl_extend("force", map_opts, { desc = "Перейти на файл:строку из стектрейса" }))
  vim.keymap.set("n", "a", analyze_with_ai, vim.tbl_extend("force", map_opts, { desc = "Разобрать ошибку через ИИ" }))
  vim.keymap.set("n", "<Tab>", function()
    render_into_window(current_mode == "last10" and "log" or "last10")
  end, vim.tbl_extend("force", map_opts, { desc = "Переключить 10 ошибок ↔ полный журнал" }))
  vim.keymap.set("n", "r", function()
    render_into_window(current_mode)
  end, vim.tbl_extend("force", map_opts, { desc = "Обновить список ошибок" }))
  vim.keymap.set("n", "c", function()
    M.clear()
    render_into_window(current_mode)
  end, vim.tbl_extend("force", map_opts, { desc = "Очистить журнал сеанса" }))
  vim.keymap.set("n", "y", function()
    local payload = copy_text ~= "" and copy_text or table.concat(safe_lines, "\n")
    pcall(vim.fn.setreg, "+", payload)
    pcall(vim.fn.setreg, '"', payload)
    pcall(vim.api.nvim_echo, { { "📋 Ошибки скопированы в буфер обмена", "MoreMsg" } }, false, {})
  end, vim.tbl_extend("force", map_opts, { desc = "Скопировать все показанные ошибки" }))
end

--- Макрос 1: показать последние 10 ошибок Neovim.
function M.last()
  render_into_window("last10")
end

--- Макрос 2: показать полный журнал ошибок Neovim за сеанс.
function M.log()
  render_into_window("log")
end

--- Очистить накопленные записи текущего сеанса.
function M.clear()
  M.entries = {}
  if vim.v then
    pcall(function() vim.v.errmsg = "" end)
  end
  M.last_seen_errmsg = ""
end

M.jump_from_cursor = jump_from_cursor
M.analyze_with_ai = analyze_with_ai

local setup_done = false

function M.setup()
  if setup_done then
    return
  end
  setup_done = true

  local prev_notify = vim.notify
  if type(prev_notify) == "function" then
    vim.notify = function(msg, level, opts)
      M.record_notify(msg, level, opts)
      return prev_notify(msg, level, opts)
    end
  end

  local grp = vim.api.nvim_create_augroup("UserErrorHistory", { clear = true })
  vim.api.nvim_create_autocmd({ "CmdlineLeave", "CursorHold", "BufEnter", "WinEnter" }, {
    group = grp,
    callback = function()
      M.capture_errmsg()
    end,
  })

  vim.api.nvim_create_user_command("ErrorLast10", M.last, {
    force = true,
    desc = "🔟 Показать последние 10 ошибок Neovim",
  })
  vim.api.nvim_create_user_command("Errors10", M.last, {
    force = true,
    desc = "🔟 Показать последние 10 ошибок Neovim (алиас)",
  })
  vim.api.nvim_create_user_command("ErrorLog", M.log, {
    force = true,
    desc = "📜 Открыть полный журнал ошибок Neovim за сеанс",
  })
  vim.api.nvim_create_user_command("ErrorClear", function()
    M.clear()
    pcall(vim.api.nvim_echo, { { "🧹 Журнал ошибок Neovim очищен", "MoreMsg" } }, false, {})
  end, {
    force = true,
    desc = "🧹 Очистить журнал ошибок Neovim текущего сеанса",
  })

  local mappings = {
    { "<leader>xe", "<cmd>ErrorLast10<cr>", "🔟 Последние 10 ошибок Neovim" },
    { "<leader>xj", "<cmd>ErrorLog<cr>", "📜 Журнал ошибок Neovim (все)" },
    { "<leader>xg", "<cmd>ErrorLog<cr>", "📜 Журнал ошибок Neovim (алиас)" },
    { "<leader>Hxe", "<cmd>ErrorLast10<cr>", "🔟 Последние 10 ошибок Neovim" },
    { "<leader>Hxj", "<cmd>ErrorLog<cr>", "📜 Журнал ошибок Neovim (все)" },
    { "<leader>Hxg", "<cmd>ErrorLog<cr>", "📜 Журнал ошибок Neovim (алиас)" },
  }
  for _, m in ipairs(mappings) do
    vim.keymap.set("n", m[1], m[2], { desc = m[3], silent = true })
  end
end

return M
