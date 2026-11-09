-- ========================================================================== --
--     ВСЕГДА ДОСТУПНЫЕ КОМАНДЫ :AvanteStatus И :AvanteRebuild                --
-- ========================================================================== --
-- Регистрируются в самом начале init.lua ДО lazy.nvim, поэтому ошибка
-- «E492: Not an editor command: AvanteStatus» исключена в любом состоянии:
-- до события VeryLazy, при старом Neovim (<0.12), при неустановленном плагине
-- или при падении его сборки.
local M = {
  handlers = {},
}

local registered = false

local function show_report(title, lines, is_warn)
  local text = table.concat(lines, "\n")
  pcall(vim.api.nvim_echo, { { text, is_warn and "WarningMsg" or "None" } }, true, {})
  local ok_ai, AI = pcall(require, "config.ai_api")
  if ok_ai and type(AI.float) == "function" and #vim.api.nvim_list_uis() > 0 then
    pcall(AI.float, title, text)
  end
end

local function fallback_report(reason)
  local B = require("config.avante_build")
  local dir = B.plugin_dir()
  local v = vim.version and vim.version() or { major = 0, minor = 0, patch = 0 }
  local lines = {
    "# 🩺 Статус Avante (" .. B.TAG .. ")",
    "",
    "- **Состояние:** недоступен (" .. reason .. ")",
    ("- **Neovim:** %d.%d.%d (требуется 0.12+)"):format(v.major or 0, v.minor or 0, v.patch or 0),
    "- **Конфиг:** `" .. tostring(vim.fn.stdpath("config")) .. "`",
    "- **Каталог плагина:** `" .. dir .. "`",
    "- **Главная библиотека:** `" .. B.lib_file(dir) .. "`",
    "",
    "### Что сделать",
    "1. Проверь установку плагинов: `:Lazy sync`",
    "2. Пересобери нативные библиотеки: `:AvanteRebuild` (или `<leader>AU`)",
    "3. Проверь окружение и PATH: `:EnvCheck`",
  }
  show_report("🩺 AvanteStatus", lines, true)
end

local function dispatch(action)
  if type(M.handlers[action]) == "function" then
    return M.handlers[action]()
  end

  if vim.fn.has("nvim-0.12") ~= 1 then
    return fallback_report("нужен Neovim 0.12+; обнови Neovim")
  end

  local cfg = package.loaded["lazy.core.config"]
  local plugin = type(cfg) == "table" and cfg.plugins and cfg.plugins["avante.nvim"]
  local disabled = type(cfg) == "table" and cfg.spec and cfg.spec.disabled
    and cfg.spec.disabled["avante.nvim"]

  if not plugin and disabled then
    return fallback_report("плагин отключён в lazy.nvim")
  end
  if not plugin then
    return fallback_report("плагин не зарегистрирован в lazy.nvim (:Lazy sync)")
  end
  if plugin._ and plugin._.installed == false then
    return fallback_report("плагин ещё не установлен — выполни :Lazy sync")
  end
  if plugin._ and plugin._.cond == false then
    return fallback_report("плагин отключён условием cond в lazy.nvim")
  end

  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy and type(lazy.load) == "function" then
    local ok_load, load_err = pcall(lazy.load, { plugins = { "avante.nvim" } })
    if type(M.handlers[action]) == "function" then
      return M.handlers[action]()
    end
    if not ok_load then
      return fallback_report("ошибка загрузки плагина: " .. tostring(load_err))
    end
  end

  return fallback_report("обработчик avante ещё не инициализирован — проверь :Lazy и :ErrorLast10")
end

function M.setup()
  if registered then
    return
  end
  vim.api.nvim_create_user_command("AvanteStatus", function()
    dispatch("status")
  end, {
    force = true,
    desc = "🩺 Диагностика Avante, нативных библиотек и кеша репо-карты",
  })
  vim.api.nvim_create_user_command("AvanteRebuild", function()
    dispatch("rebuild")
  end, {
    force = true,
    desc = "🔧 Скачать или пересобрать нативные библиотеки Avante",
  })
  registered = true
end

function M.bind(status_fn, rebuild_fn)
  M.handlers.status = status_fn
  M.handlers.rebuild = rebuild_fn
  M.setup()
end

M.show_report = show_report

return M
