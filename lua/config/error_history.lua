-- ========================================================================== --
--     РАЗДЕЛ ОШИБОК (<leader>x): ПОСЛЕДНИЕ 10 ОШИБОК И ПОЛНЫЙ ЖУРНАЛ         --
-- ========================================================================== --
-- Два отдельных макроса (клавиши) в группе <leader>x («Ошибки и журнал»):
--   1) <leader>xe  (и <leader>Hxe, :ErrorLast10) — последние 10 ошибок Neovim
--   2) <leader>xj  (и <leader>xg, <leader>Hxj, :ErrorLog) — полный журнал ошибок
--
-- ВНИМАНИЕ: <leader>xl НЕ трогаем — она занята Trouble Location List!
--
-- Откуда собираются ошибки (только в памяти текущего сеанса, на диск не пишем):
--   * перехват vim.notify с уровнем ERROR (Mason, Avante, плагины, LSP);
--   * отслеживание v:errmsg (нативные ошибки команд E492, E5108 и т.п.);
--   * история ошибок Noice (noice.message.manager с фильтром { error = true }),
--     которая ловит стектрейсы автокоманд ModeChanged / WinEnter / vim.schedule;
--   * разбор :messages (когда Noice ещё не загружен или отключён), со склейкой
--     многострочного stack traceback в одну запись ошибки.
local M = {
  entries = {},
  max_entries = 500,
  last_seen_errmsg = "",
}

local win_id = nil
local buf_id = nil
local current_mode = "last10" -- "last10" | "log"

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
    or line:match("^%[mason") and line:lower():find("fail", 1, true) ~= nil
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
      -- Если запись уже попала из нашего перехватчика, повтор из Noice/:messages не дублируем
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

local function format_view(mode)
  local all = M.collect()
  local total = #all
  local shown = {}

  if mode == "last10" then
    -- Показываем последние 10 ошибок (самая свежая — сверху #1, чтобы видеть сразу!)
    local from = math.max(1, total - 9)
    for i = total, from, -1 do
      shown[#shown + 1] = { idx = total - i + 1, real_num = i, item = all[i] }
    end
  else
    -- Полный журнал сеанса (от самой новой к старым, со сквозной нумерацией)
    for i = total, 1, -1 do
      shown[#shown + 1] = { idx = total - i + 1, real_num = i, item = all[i] }
    end
  end

  local title = mode == "last10"
    and ("🔟 Последние 10 ошибок Neovim (показано %d из %d)"):format(#shown, total)
    or ("📜 Полный журнал ошибок Neovim (всего: %d)"):format(total)

  local lines = {
    title,
    "Клавиши: q/Esc закрыть · Tab переключить (10 ↔ Все) · y скопировать всё · c очистить · r обновить",
    string.rep("─", 78),
  }

  local copy_blocks = {}

  if #shown == 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "✅ В текущем сеансе Neovim ошибок пока не зафиксировано."
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Подсказка:"
    lines[#lines + 1] = "  • Ошибки кода/LSP в файлах проекта: <leader>xx (Trouble)"
    lines[#lines + 1] = "  • Диагностика Avante: :AvanteStatus"
    lines[#lines + 1] = "  • Лог установки пакетов Mason: :MasonLog"
  else
    for _, row in ipairs(shown) do
      local e = row.item
      local repeat_tag = (e.count and e.count > 1) and (" ×" .. tostring(e.count)) or ""
      local head = ("[%d] %s · %s%s"):format(row.idx, e.time or "--:--:--", e.source or "nvim", repeat_tag)
      lines[#lines + 1] = ""
      lines[#lines + 1] = head
      for sub in (e.text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = "  " .. sub
      end
      copy_blocks[#copy_blocks + 1] = head .. "\n" .. e.text
    end
  end

  return lines, table.concat(copy_blocks, "\n\n"), title
end

local function render_into_window(mode)
  current_mode = mode or current_mode
  local lines, copy_text, short_title = format_view(current_mode)

  -- Безопасная очистка вложенных переводов строк для nvim_buf_set_lines
  local safe_lines = {}
  for _, line in ipairs(lines) do
    for part in (tostring(line) .. "\n"):gmatch("(.-)\n") do
      safe_lines[#safe_lines + 1] = part
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
    local width = math.min(math.max(68, math.floor(cols * 0.82)), math.max(20, cols - 4))
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
    -- Headless / запасной сплит
    if not (win_id and vim.api.nvim_win_is_valid(win_id)) then
      vim.cmd("botright new")
      win_id = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win_id, buf_id)
    end
  end

  local function close_win()
    if win_id and vim.api.nvim_win_is_valid(win_id) then
      pcall(vim.api.nvim_win_close, win_id, true)
    end
    win_id = nil
  end

  local map_opts = { buffer = buf_id, nowait = true, silent = true }
  vim.keymap.set("n", "q", close_win, vim.tbl_extend("force", map_opts, { desc = "Закрыть окно ошибок" }))
  vim.keymap.set("n", "<Esc>", close_win, vim.tbl_extend("force", map_opts, { desc = "Закрыть окно ошибок" }))
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

local setup_done = false

function M.setup()
  if setup_done then
    return
  end
  setup_done = true

  -- Перехватываем ранние ошибки vim.notify ещё до загрузки плагинов
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

  -- Два отдельных макроса в разделе <leader>x (без конфликта с <leader>xl Trouble!)
  -- плюс зеркала в главном меню <leader>Hx:
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
