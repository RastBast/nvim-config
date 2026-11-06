-- Действия доступны с самого запуска, даже когда Noice не установлен.
-- История хранится только в текущем процессе: сообщения могут содержать секреты.
local M = {}

-- Общая история Noice может содержать агрегат сообщений, появившихся до его
-- запуска. Не вызываем :messages при работающем Noice: на Neovim 0.11 он
-- перехватывает эту команду и открывает своё окно поверх нашего.
local function noice_history(last)
  local manager = package.loaded["noice.message.manager"]
  if type(manager) ~= "table" or type(manager.get) ~= "function" then return nil end
  local options = { history = true, sort = true, count = last and 10 or nil }
  local ok, entries = pcall(manager.get, nil, options)
  if not ok or type(entries) ~= "table" then return nil end
  local lines = {}
  for _, entry in ipairs(entries) do
    if type(entry) == "table" and type(entry.content) == "function" then
      local read, text = pcall(entry.content, entry)
      if read and type(text) == "string" and text ~= "" then lines[#lines + 1] = text end
    end
  end
  return table.concat(lines, "\n\n")
end

-- Без Noice Neovim не предоставляет надёжный фильтр по типу всех старых
-- сообщений. Вместо пустого окна показываем общую историю и честно отмечаем,
-- что записи не обязательно являются ошибками.
local function fallback(command, reason)
  local last = command == "errors10"
  local previous_error = vim.v.errmsg
  local config, ui = package.loaded["noice.config"], package.loaded["noice.ui"]
  local checked, running = false, false
  if type(config) == "table" and type(config.is_running) == "function" then
    checked, running = pcall(config.is_running)
  end
  local active = (checked and running) or (type(ui) == "table" and ui._attached)
  local source, text
  if active then
    source = "общая история Noice; ранние сообщения могут быть объединены"
    text = noice_history(last) or "История Noice недоступна. Открой :messages вручную."
  else
    source = ":messages"
    local ok, result = pcall(vim.api.nvim_exec2, last and "10messages" or "messages", { output = true })
    text = ok and result.output or ("Не удалось прочитать :messages: " .. tostring(result))
  end
  local lines = {
    last and "Последние сообщения Neovim (запасной режим)" or "История сообщений Neovim (запасной режим)",
    reason,
    "Источник: " .. source,
    "Фильтрация по типу ошибки недоступна: здесь могут быть и другие сообщения.",
    "Это история текущего сеанса, а не постоянный системный журнал.",
  }
  if previous_error and previous_error ~= "" then
    lines[#lines + 1] = "Последняя ошибка (v:errmsg): " .. previous_error
  end
  lines[#lines + 1] = "Закрыть это окно: q"
  lines[#lines + 1] = ""
  lines[#lines + 1] = text ~= "" and text or "История сообщений пуста."
  -- v:errmsg и ошибка Noice могут содержать traceback с переводами строк;
  -- nvim_buf_set_lines не принимает вложенные переводы строк в одном элементе.
  local contents = vim.split(table.concat(lines, "\n"), "\n", { plain = true })

  vim.cmd("botright new")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, contents)
  vim.bo[buf].modifiable = false
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true, desc = "Закрыть историю" })
end

local function open(command)
  local ok = pcall(require, "noice") -- lazy.nvim может загрузить плагин до VeryLazy
  if not ok then
    return fallback(command, "Noice недоступен.")
  end
  -- Noice завершает настройку в следующем тике после lazy-загрузки.
  vim.schedule(function()
    local config = package.loaded["noice.config"]
    local checked, running = false, false
    if type(config) == "table" and type(config.is_running) == "function" then
      checked, running = pcall(config.is_running)
    end
    if vim.fn.exists(":Noice") ~= 2 or not checked or not running then
      return fallback(command, "Noice не запущен или его состояние недоступно.")
    end
    local manager_ok, manager = pcall(require, "noice.message.manager")
    if not manager_ok or type(manager) ~= "table" or type(manager.get) ~= "function" then
      return fallback(command, "История Noice недоступна.")
    end
    local got, errors = pcall(manager.get, { error = true }, { history = true, sort = true, count = 1 })
    if not got or type(errors) ~= "table" then
      return fallback(command, "Не удалось прочитать историю Noice.")
    end
    if #errors == 0 then
      return fallback(command, "В истории Noice нет ошибок.")
    end
    local displayed, err = pcall(vim.cmd, "Noice " .. command)
    if not displayed then
      fallback(command, "Не удалось открыть Noice: " .. tostring(err))
    end
  end)
end

function M.last() open("errors10") end
function M.log() open("errorlog") end

function M.setup()
  vim.api.nvim_create_user_command("ErrorLast10", M.last, { desc = "Последние ошибки Neovim" })
  vim.api.nvim_create_user_command("ErrorLog", M.log, { desc = "Журнал ошибок Neovim" })
  -- Маппинги определены не в lazy.keys: их видно ещё до загрузки плагинов.
  for _, map in ipairs({
    { "<leader>xe", "<cmd>ErrorLast10<cr>", "Последние 10 ошибок Neovim" },
    { "<leader>xl", "<cmd>ErrorLog<cr>", "Журнал ошибок Neovim" },
    { "<leader>Hxe", "<cmd>ErrorLast10<cr>", "Последние 10 ошибок Neovim" },
    -- Hxl занят списком location list; g = журнал (log).
    { "<leader>Hxg", "<cmd>ErrorLog<cr>", "Журнал ошибок Neovim" },
  }) do
    vim.keymap.set("n", map[1], map[2], { desc = map[3], silent = true })
  end
end

return M
