-- История ошибок интерфейса Noice за текущий сеанс, не диагностика LSP.
-- Не перехватываем vim.notify второй раз и не сохраняем сообщения на диск:
-- в них могут находиться имена файлов, фрагменты кода и секреты.
local M = {}

local function echo(message)
  vim.api.nvim_echo({ { message, "WarningMsg" } }, true, {})
end

local function open(command)
  local ok = pcall(require, "noice") -- lazy.nvim может загрузить плагин по клавише
  if not ok then
    return echo("Noice недоступен. Историю сообщений Neovim можно открыть через :messages.")
  end
  -- Noice завершает настройку в следующем тике после lazy-загрузки.
  vim.schedule(function()
    local config = package.loaded["noice.config"]
    if vim.fn.exists(":Noice") ~= 2 or not config or type(config.is_running) ~= "function"
      or not config.is_running() then
      return echo("Noice ещё не запущен или отключён. Доступна общая история :messages.")
    end
    local manager_ok, manager = pcall(require, "noice.message.manager")
    if not manager_ok or type(manager) ~= "table" or type(manager.get) ~= "function" then
      return echo("История Noice недоступна. Используй :messages.")
    end
    local got, errors = pcall(manager.get, { error = true }, { history = true, sort = true, count = 1 })
    if not got or type(errors) ~= "table" then
      return echo("Не удалось прочитать историю Noice. Используй :messages.")
    end
    if #errors == 0 then
      return echo("В истории Noice за этот сеанс ошибок нет. Сообщения до запуска Noice: :messages.")
    end
    vim.cmd("Noice " .. command)
  end)
end

function M.last() open("errors10") end
function M.log() open("errorlog") end

return M
