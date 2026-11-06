-- Эти команды принадлежат конфигу, а не lazy.nvim: доступны даже на старом
-- Neovim, при cond=false, отсутствии Avante или ошибке его загрузки.
local M = { handlers = {} }
local registered = false

local function show_unavailable(reason)
  local B = require("config.avante_build")
  local dir = B.plugin_dir()
  local version = vim.version()
  local lines = {
    "avante " .. B.TAG .. ": недоступен",
    "причина: " .. reason,
    ("Neovim: %d.%d.%d"):format(version.major, version.minor, version.patch),
    "конфиг: " .. vim.fn.stdpath("config"),
    "init: " .. (vim.env.MYVIMRC or "неизвестен"),
    "каталог плагина: " .. dir,
    "файл библиотеки: " .. B.lib_file(dir),
    "Подробнее: :Lazy, :messages, :EnvCheck",
  }
  vim.api.nvim_echo({ { table.concat(lines, "\n"), "WarningMsg" } }, true, {})
end

local function dispatch(action)
  if M.handlers[action] then return M.handlers[action]() end
  -- Сам upstream plugin/avante.lua закрывает редактор при версии < 0.12.
  if vim.fn.has("nvim-0.12") ~= 1 then
    return show_unavailable("для Avante v0.4.8 нужен Neovim 0.12+; обнови Neovim")
  end
  local config = package.loaded["lazy.core.config"]
  local plugin = type(config) == "table" and config.plugins and config.plugins["avante.nvim"]
  local disabled = type(config) == "table" and config.spec and config.spec.disabled
    and config.spec.disabled["avante.nvim"]
  if not plugin and disabled then
    return show_unavailable("плагин отключён в lazy.nvim; проверь условия и настройки плагина")
  end
  if not plugin then
    return show_unavailable("плагин не зарегистрирован в lazy.nvim; проверь загруженный конфиг и :Lazy sync")
  end
  if not plugin._ or not plugin._.installed then
    return show_unavailable("плагин не установлен; выполни :Lazy sync")
  end
  if plugin._.cond == false then
    return show_unavailable("плагин отключён условием lazy.nvim")
  end
  local ok, err = pcall(function() require("lazy").load({ plugins = { "avante.nvim" } }) end)
  if M.handlers[action] then return M.handlers[action]() end
  return show_unavailable("плагин не удалось настроить" .. (not ok and (": " .. tostring(err)) or "")
    .. "; смотри ошибку в :Lazy и :messages")
end

function M.setup()
  if registered then return end
  vim.api.nvim_create_user_command("AvanteStatus", function() dispatch("status") end, {
    force = true, desc = "Диагностика Avante, в том числе если плагин отключён",
  })
  vim.api.nvim_create_user_command("AvanteRebuild", function() dispatch("rebuild") end, {
    force = true, desc = "Пересобрать библиотеки Avante или показать причину недоступности",
  })
  registered = true
end

function M.bind(status, rebuild)
  M.handlers = { status = status, rebuild = rebuild }
  M.setup()
end

return M
