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
if vim.env.AVANTE_TEST_REQUIRE_FAIL == "1" then
  -- Файлы загрузятся через dlopen, но обычный require repo_map сломан.
  package.preload.avante_repo_map = function() error("synthetic repo_map require failure") end
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
vim.cmd.AvanteShowRepoMap() -- эта upstream-команда обходит avante.api
assert(#vim.api.nvim_list_wins() == original_windows, "карта открылась до завершения сборки")

if vim.env.AVANTE_TEST_FAIL == "1" and vim.env.AVANTE_TEST_SOURCE_BUILD ~= "1" then
  assert(vim.wait(15000, function() return message_contains("не скачалась") end, 20), "нет ошибки скачивания")
  assert(not require("avante").did_setup, "setup выполнен при ошибке")
  vim.cmd.AvanteAsk()
  assert(#vim.api.nvim_list_wins() == original_windows, "чат открылся после неудачной сборки")
  assert(message_contains(":AvanteStatus"), "нет подсказки по диагностике")
  vim.cmd.AvanteShowRepoMap()
  assert(#vim.api.nvim_list_wins() == original_windows, "карта открылась после неудачной сборки")
  print("OK   реальный Neovim: ошибка сборки не открывает чат")
else
  if vim.env.AVANTE_TEST_REQUIRE_FAIL == "1" then
    assert(vim.wait(15000, function() return message_contains("synthetic repo_map require failure") end, 20),
      "обычный require repo_map не был проверен")
    assert(not require("avante").did_setup, "setup прошёл при недоступном repo_map")
    vim.cmd.AvanteAsk()
    vim.cmd.AvanteShowRepoMap()
    assert(#vim.api.nvim_list_wins() == original_windows, "чат/карта открылись при ошибке require")
    package.preload.avante_repo_map = nil
    vim.cmd.AvanteRebuild()
    print("OK   реальный Neovim: неисправный require repo_map блокирует чат и может восстановиться")
  end
  local initialized = vim.wait(30000, function() return require("avante").did_setup end, 20)
  if not initialized then vim.cmd.AvanteStatus() end
  assert(initialized, "setup не дождался библиотеки: " .. table.concat(messages, " | ") .. " / " .. vim.v.errmsg)
  vim.wait(300) -- инициализация avante по расписанию
  local chat_map = vim.fn.maparg("<leader>Aa", "n", false, true)
  assert(type(chat_map) == "table" and next(chat_map) and chat_map.desc ~= "avante: ожидание библиотек", "клавиша чата не установилась")

  -- Воспроизводим настоящий сломанный кеш из старого Avante: json null
  -- превращается в userdata vim.NIL и без защиты падает на next().
  local Path, Repo = require("avante.path"), require("avante.repo_map")
  local root_dir = require("avante.utils").root.get()
  local old_build = Repo._build_repo_map
  Repo._build_repo_map = function() return { { path = "a.lua", lang = "lua", defs = "function a" } } end
  for ext, content in pairs({ brokennull = "null", brokenjson = "{invalid", brokenobject = '{"wrong":true}' }) do
    local file = tostring(Path.repo_map.get(root_dir, ext))
    assert(vim.fn.writefile({ content }, file) == 0)
    local map = Repo._get_repo_map(ext)
    assert(type(map) == "table" and map[1] and map[1].path == "a.lua", "кеш не восстановлен: " .. ext)
    local decoded = vim.json.decode(table.concat(vim.fn.readfile(file), "\n"))
    assert(type(decoded) == "table" and decoded[1].path == "a.lua", "исправленная карта не сохранена")
  end
  Repo._build_repo_map = old_build
  vim.cmd.AvanteStatus()
  assert(message_contains("Повреждённых карт репозитория проигнорировано: 3"), "нет статуса восстановленных кешей")
  print("OK   настоящий Avante: null, сломанный JSON и объект безопасно перестраиваются")

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
  if vim.env.AVANTE_TEST_SOURCE_BUILD ~= "1" and vim.env.AVANTE_TEST_USE_LAZY ~= "1"
    and vim.env.AVANTE_TEST_REQUIRE_FAIL ~= "1" then
    vim.cmd("AvanteBuild source=true")
    assert(vim.wait(15000, function() return message_contains("библиотеки собраны из исходников (make)") end, 20),
      ":AvanteBuild source=true обошёл управляемый make")
    print("OK   настоящий Avante: :AvanteBuild source=true использует закреплённый checkout")
  end
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
