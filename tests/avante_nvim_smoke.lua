-- Запускается только через tests/avante_nvim_smoke.py: настоящий Neovim и код
-- avante v0.4.8, но искусственные C-библиотеки и локальный fake-curl без сети.
local root, plugin, deps = vim.env.AVANTE_TEST_CONFIG, vim.env.AVANTE_TEST_PLUGIN, vim.env.AVANTE_TEST_DEPS
vim.opt.rtp:prepend(root)
if vim.env.AVANTE_TEST_USE_LAZY ~= "1" then
  vim.opt.rtp:append(plugin)
  for _, name in ipairs({ "plenary.nvim", "nui.nvim", "mega.logging", "mega.cmdparse" }) do
    vim.opt.rtp:append(deps .. "/" .. name)
  end
end
vim.env.GEMINI_API_KEY = "test-only-not-a-real-key"
vim.g.mapleader = " "
local messages = {}
-- Как в init.lua: INFO/WARN от notify не видны пользователю.
vim.notify = function(msg, level)
  if level == nil or level >= vim.log.levels.ERROR then messages[#messages + 1] = tostring(msg) end
end
local echo = vim.api.nvim_echo
vim.api.nvim_echo = function(chunks, history, opts)
  for _, chunk in ipairs(chunks) do messages[#messages + 1] = tostring(chunk[1]) end
  return echo(chunks, history, opts)
end
local function message_contains(text)
  for _, message in ipairs(messages) do
    if message:find(text, 1, true) then return true end
  end
  return false
end
-- В тесте ошибки загрузки нельзя случайно начать настоящую сборку cargo.
if vim.env.AVANTE_TEST_FAIL == "1" and vim.env.AVANTE_TEST_SOURCE_BUILD ~= "1" then
  local executable = vim.fn.executable
  vim.fn.executable = function(name) return name == "cargo" and 0 or executable(name) end
end
if vim.env.AVANTE_TEST_UNSUPPORTED == "1" then
  local has = vim.fn.has
  vim.fn.has = function(feature) return feature == "nvim-0.12" and 0 or has(feature) end
end
local spec = dofile(root .. "/lua/plugins/avante.lua")[1]
spec.opts.behaviour.auto_suggestions = false -- тест не отправляет сетевых запросов к AI
if vim.env.AVANTE_TEST_USE_LAZY == "1" then
  vim.go.loadplugins = true -- -u NONE отключает плагины по умолчанию
  vim.opt.rtp:prepend(vim.env.AVANTE_TEST_LAZY)
  spec.dir, spec.name = plugin, "avante.nvim"
  spec.dependencies = {}
  for _, name in ipairs({ "plenary.nvim", "nui.nvim", "mega.logging", "mega.cmdparse" }) do
    spec.dependencies[#spec.dependencies + 1] = { dir = deps .. "/" .. name, name = name }
  end
  require("lazy").setup({ spec }, {
    root = vim.env.AVANTE_TEST_TMP .. "/lazy-root",
    lockfile = vim.env.AVANTE_TEST_TMP .. "/lazy-lock.json",
    install = { missing = false }, checker = { enabled = false }, change_detection = { enabled = false },
    performance = { rtp = { reset = false } },
  })
else
  vim.cmd.source(plugin .. "/plugin/avante.lua")
  spec.config({ dir = plugin }, spec.opts)
end
if vim.env.AVANTE_TEST_UNSUPPORTED == "1" then
  -- При cond=false настоящий lazy не вызывает init плагина: предупреждение
  -- должно прийти из init.lua / отдельного помощника, а не от плагина.
  require("config.avante_runtime").warn_unsupported()
  assert(vim.wait(1000, function() return message_contains("требует Neovim 0.12+") end, 10), "нет предупреждения о версии")
  assert(not package.loaded.avante and vim.fn.exists(":AvanteAsk") == 0, "Avante загрузился на неподдерживаемой версии")
  print("OK   реальный Neovim: старую версию предупреждаем, Avante отключён без выхода")
  return vim.cmd("qa!")
end
assert(vim.fn.exists(":AvanteStatus") == 2, "нет :AvanteStatus")
local original_windows = #vim.api.nvim_list_wins()
vim.cmd.AvanteAsk()
assert(#vim.api.nvim_list_wins() == original_windows, "чат открылся до завершения сборки")
assert(message_contains("сборка библиотек"), "нет статуса во время сборки")

if vim.env.AVANTE_TEST_FAIL == "1" and vim.env.AVANTE_TEST_SOURCE_BUILD ~= "1" then
  assert(vim.wait(15000, function() return message_contains("не скачалась") end, 20), "нет ошибки скачивания")
  assert(not require("avante").did_setup, "setup выполнен при ошибке")
  vim.cmd.AvanteAsk()
  assert(#vim.api.nvim_list_wins() == original_windows, "чат открылся после неудачной сборки")
  assert(message_contains(":AvanteStatus"), "нет подсказки по диагностике")
  print("OK   реальный Neovim: ошибка сборки не открывает чат")
else
  local initialized = vim.wait(30000, function() return require("avante").did_setup end, 20)
  if not initialized then vim.cmd.AvanteStatus() end
  assert(initialized, "setup не дождался библиотеки: " .. table.concat(messages, " | ") .. " / " .. vim.v.errmsg)
  vim.wait(300) -- инициализация avante по расписанию
  local chat_map = vim.fn.maparg("<leader>Aa", "n", false, true)
  assert(type(chat_map) == "table" and next(chat_map) and chat_map.desc ~= "avante: ожидание библиотек", "клавиша чата не установилась")
  vim.cmd.AvanteAsk()
  vim.wait(500)
  local input = nil
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].filetype == "AvanteInput" then input = buf end
  end
  assert(input, "AvanteInput не создан")
  -- Те же автособытия, которые фигурировали в traceback пользователя.
  vim.api.nvim_exec_autocmds("WinEnter", { buffer = input })
  vim.api.nvim_exec_autocmds("ModeChanged", { buffer = input })
  vim.wait(200)
  assert(not vim.v.errmsg:find("missing avante_templates", 1, true), vim.v.errmsg)
  vim.cmd.AvanteRebuild()
  assert(vim.wait(15000, function() return message_contains("Перезапусти Neovim для загрузки") end, 20), "нет результата принудительной сборки")
  vim.cmd.AvanteStatus()
  assert(message_contains("все библиотеки загружаются"), "нет статуса готовых библиотек")
  if vim.env.AVANTE_TEST_USE_LAZY == "1" then
    -- Ошибка build-хука должна попасть в статус задачи lazy.nvim, а не только
    -- в уведомление: иначе :Lazy build неверно сообщает об успехе.
    vim.env.AVANTE_TEST_FAIL = "1"
    local executable = vim.fn.executable
    vim.fn.executable = function(name) return name == "cargo" and 0 or executable(name) end
    require("lazy.manage").build({ plugins = { "avante.nvim" }, show = false, wait = true })
    local task_error = false
    for _, task in ipairs(require("lazy.core.config").plugins["avante.nvim"]._.tasks or {}) do
      if task.name == "build" and task:has_errors() and task:output():find("не скачалась", 1, true) then task_error = true end
    end
    assert(task_error, "lazy.nvim не отметил сбой build-хука")
    print("OK   настоящий lazy.nvim: ошибка build-хука отображается в задаче")
  end
  if vim.env.AVANTE_TEST_SOURCE_BUILD == "1" then
    -- Несмотря на уже загруженный старый .so, новая сломанная сборка не должна
    -- пройти проверку за счёт кэша package.loadlib / системного загрузчика.
    vim.env.AVANTE_TEST_CORRUPT = "1"
    vim.cmd.AvanteRebuild()
    assert(vim.wait(15000, function() return message_contains("не удалось загрузить") end, 20), "сломанный make принят из кэша")
    print("OK   реальный Neovim: make fallback и отклонение новой повреждённой библиотеки")
  end
  print("OK   реальный Neovim: ожидание, AvanteAsk, автособытия и безопасная пересборка")
end
vim.cmd("qa!")
