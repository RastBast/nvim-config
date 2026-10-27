-- ========================================================================== --
--                 ПОИСК КОМАНД: <leader><Space> (пробел-пробел)             --
-- ========================================================================== --
-- Показывает ВСЕ пользовательские команды (:Name) с описанием.
-- Список строится из nvim_get_commands() при каждом открытии, поэтому новые
-- команды (:Theme, :AiAsk, :GoIde, :Tui, …) попадают сюда сами — ничего
-- вручную дописывать не нужно.
--
-- Поведение при выборе:
--   * команда без аргументов (nargs = 0 или ?) — запускается сразу;
--   * команда с аргументами — в командную строку вписывается ":Имя ",
--     чтобы ты дописал аргумент и нажал Enter.
--
-- Парные поиски: <leader>fc (Telescope commands), <leader>fk (все клавиши).
local M = {}

--- Список пользовательских команд, отсортированный по имени.
function M.items()
  local list = {}
  for name, info in pairs(vim.api.nvim_get_commands({})) do
    list[#list + 1] = {
      name = name,
      nargs = info.nargs or "0",
      desc = info.definition or "",
    }
  end
  table.sort(list, function(a, b)
    return a.name < b.name
  end)
  return list
end

--- Открыть меню команд (vim.ui.select — у нас это snacks.picker).
function M.open()
  local items = M.items()
  vim.ui.select(items, {
    prompt = "⌨ Команда (" .. #items .. ")",
    format_item = function(it)
      local line = ":" .. it.name
      if it.desc ~= "" then
        line = line .. "  — " .. it.desc
      end
      return line
    end,
  }, function(it)
    if not it then
      return
    end
    if it.nargs == "0" or it.nargs == "?" then
      local ok, err = pcall(vim.cmd, it.name)
      if not ok then
        vim.notify(":" .. it.name .. " — ошибка: " .. tostring(err), vim.log.levels.ERROR)
      end
    else
      vim.api.nvim_feedkeys(":" .. it.name .. " ", "n", false)
    end
  end)
end

return M
