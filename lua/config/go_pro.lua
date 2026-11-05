-- ========================================================================== --
--        GO PRO: как в VS Code и GoLand — подсказки, codelens, тесты,       --
--        покрытие, race, benchmark, рефакторинг, JSON → struct             --
-- ========================================================================== --
-- Всё, что уже есть, здесь НЕ дублируется: меню и базовые действия живут в
--   lua/config/go_ide.lua      (<leader>gi, gT gC gD ga go gr gx)
--   lua/plugins/go-tools.lua   (ray-x/go.nvim: gv gl gt gb gm, формочка HGS/HGf)
--   lua/config/go_extras.lua   (формочка struct)
--   lua/config/go_snips.lua    (русские сниппеты; новые — ниже, в go_snips.lua)
-- Команды go.nvim вызываются через :Go… — их имена проверены по закреплённой
-- версии плагина (lazy-lock.json). Они перечислены в cmd = {…} в go-tools.lua,
-- иначе lazy.nvim не загрузит плагин и клавиша ответит E492.
local M = {}

local function notify(msg, level)
  vim.notify("🐹 " .. msg, level or vim.log.levels.INFO)
end

local function is_go()
  return vim.bo.filetype == "go"
end

local function need_go()
  if is_go() then
    return true
  end
  notify("Открой Go-файл (*.go)", vim.log.levels.WARN)
  return false
end

-- Экранирование для shell (одинарные кавычки). Чистая функция — тестируется.
local function sq(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end
M._sq = sq

-- Имя функции или метода, в которой стоит строка `row` (1-based).
-- Возвращает nil, если курсор вне функции (между `}` и следующим `func`).
-- Чистая функция: принимает таблицу строк, поэтому тестируется без nvim.
function M.func_name_at(lines, row)
  for i = row, 1, -1 do
    local l = lines[i] or ""
    if i < row and l:match("^}") then
      return nil
    end
    if l:match("^func ") then
      local name = l:match("^func%s+%b()%s*([%w_]+)") or l:match("^func%s+([%w_]+)")
      return name, i
    end
  end
  return nil
end

-- Добавить элементы в конец массива (без vim.* — чистая логика, тестируется).
local function push(list, items)
  for _, v in ipairs(items) do
    list[#list + 1] = v
  end
end

-- Строка shell: `cd <папка> && go test …` для пакета файла.
-- opts: race (bool), run (имя теста), bench (имя бенчмарка).
function M.go_test_cmd(dir, opts)
  opts = opts or {}
  local args = { "go", "test", "-count=1" }
  if opts.race then
    args[#args + 1] = "-race"
  end
  if opts.bench then
    -- -run ^$ отключает обычные тесты, остаётся только бенчмарк
    push(args, { "-run", sq("^$"), "-bench", sq("^" .. opts.bench .. "$"), "-benchmem" })
  elseif opts.run then
    push(args, { "-run", sq("^" .. opts.run .. "$"), "-v" })
  end
  args[#args + 1] = "."
  return "cd " .. sq(dir) .. " && " .. table.concat(args, " ")
end

local function cur_dir()
  return vim.fn.expand("%:p:h")
end

local function run_term(cmd, title)
  require("config.termcmd").make(cmd, 0, title)()
end

local function func_here()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  return M.func_name_at(lines, row)
end

-- ---------------------------------------------------------------- тесты ---

-- Тесты всего пакета с детектором гонок (как «Run with race detector» в GoLand)
function M.race_pkg()
  if not need_go() then
    return
  end
  run_term(M.go_test_cmd(cur_dir(), { race = true }), "go test -race")
end

-- <leader>gR: внутри TestXxx — только этот тест с -race, иначе весь пакет
function M.race()
  if not need_go() then
    return
  end
  local name = func_here()
  if name and name:match("^Test") then
    run_term(M.go_test_cmd(cur_dir(), { race = true, run = name }), "go test -race " .. name)
  else
    M.race_pkg()
  end
end

-- Бенчмарк функции под курсором (BenchmarkXxx) с -benchmem
function M.bench_func()
  if not need_go() then
    return
  end
  local name = func_here()
  if not name or not name:match("^Benchmark") then
    notify("Курсор внутри функции BenchmarkXxx (сейчас: " .. tostring(name or "нет") .. ")", vim.log.levels.WARN)
    return
  end
  run_term(M.go_test_cmd(cur_dir(), { bench = name }), "go test -bench " .. name)
end

function M.vet()
  if not need_go() then
    return
  end
  run_term("cd " .. sq(cur_dir()) .. " && go vet ./...", "go vet")
end

-- ---------------------------------------------------- подсказки и codelens ---

-- Inlay hints: типы переменных, имена параметров, поля struct-литералов.
-- По умолчанию выключены (чтобы не шуметь в коде); включаются <leader>gh.
function M.toggle_inlay()
  if not need_go() then
    return
  end
  require("config.inlay").toggle()
end

-- Codelens над функциями: «run test | debug test | generate | tidy»
function M.codelens_run()
  if not need_go() then
    return
  end
  if not vim.lsp.codelens then
    notify("Codelens требует Neovim 0.10+", vim.log.levels.WARN)
    return
  end
  vim.lsp.codelens.run()
end

-- ------------------------------------------------------- рефакторинг ---

-- JSON → struct: выдели JSON в визуальном режиме, введи имя типа
function M.json_to_struct()
  if not need_go() then
    return
  end
  vim.ui.input({ prompt = "Имя struct (например Order): " }, function(name)
    if not name or name == "" then
      return
    end
    if not name:match("^[%a_][%w_]*$") then
      notify("Имя должно быть идентификатором Go (латиница, цифры, _)", vim.log.levels.WARN)
      return
    end
    vim.cmd("'<,'>GoJson2Struct " .. name)
  end)
end

-- Inline переменной (gopls refactor.inline) — из меню, без клавиши
function M.inline_var()
  if not need_go() then
    return
  end
  vim.lsp.buf.code_action({ context = { only = { "refactor.inline" } } })
end

local function call(cmd)
  return function()
    if not need_go() then
      return
    end
    local ok, err = pcall(vim.cmd, cmd)
    if not ok then
      notify("команда " .. cmd .. " недоступна: " .. tostring(err), vim.log.levels.WARN)
    end
  end
end

-- Список пунктов для меню go_ide (<leader>gi): подписи и функции
M.menu_items = {
  { label = "💡 Подсказки типов и параметров вкл/выкл (<leader>gh)", run = M.toggle_inlay },
  { label = "▶ Codelens над функцией: тест / генерация / tidy (<leader>gL)", run = M.codelens_run },
  { label = "🏃 Тест под курсором или пакет с детектором гонок -race (<leader>gR)", run = M.race },
  { label = "⏱ Бенчмарк функции под курсором (<leader>gB)", run = M.bench_func },
  { label = "📊 Покрытие тестов в буфере (<leader>gc)", run = call("GoCoverage") },
  { label = "🧬 Escape analysis: что уходит в кучу (<leader>gG)", run = call("GoGCDetails") },
  { label = "📦 Структура пакета: outline (<leader>gp)", run = call("GoPkgOutline") },
  { label = "🔀 Заполнить case'ы switch (<leader>gS)", run = call("GoFillSwitch") },
  { label = "↩ Заполнить return под сигнатуру функции (<leader>gE)", run = call("GoGenReturn") },
  { label = "🧽 go mod tidy (<leader>gM)", run = call("GoModTidy") },
  { label = "⚙ go generate (<leader>gn)", run = call("GoGenerate") },
  { label = "📥 JSON → struct: выдели JSON (<leader>gJ)", run = M.json_to_struct },
  { label = "🧪 Тесты для всех функций файла (<leader>gA)", run = call("GoAddAllTest") },
  { label = "🔎 Кто вызывает функцию (<leader>gH)", run = function() vim.lsp.buf.incoming_calls() end },
  { label = "📤 Что вызывает функция (<leader>gO)", run = function() vim.lsp.buf.outgoing_calls() end },
  { label = "🧩 Inline переменной (gopls refactor.inline)", run = M.inline_var },
  { label = "🔧 go vet ./... (<leader>gV)", run = M.vet },
}

-- ----------------------------------------------------- автоматика gopls ---

-- Codelens включаем для буфера, когда подключился gopls, и обновляем при правке.
local function attach_codelens(bufnr)
  if not vim.lsp.codelens then
    return
  end
  local group = vim.api.nvim_create_augroup("UserGoCodelens" .. bufnr, { clear = true })
  pcall(vim.lsp.codelens.refresh, { bufnr = bufnr })
  vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "BufWritePost" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      pcall(vim.lsp.codelens.refresh, { bufnr = bufnr })
    end,
  })
end

function M.setup()
  local map = vim.keymap.set
  map("n", "<leader>gh", M.toggle_inlay, { desc = "💡 Go: подсказки типов и параметров вкл/выкл" })
  map("n", "<leader>gL", M.codelens_run, { desc = "▶ Go: codelens — тест/генерация/tidy" })
  map("n", "<leader>gR", M.race, { desc = "🏃 Go: тест под курсором или пакет с -race" })
  map("n", "<leader>gB", M.bench_func, { desc = "⏱ Go: бенчмарк функции под курсором" })
  map("n", "<leader>gc", call("GoCoverage"), { desc = "📊 Go: покрытие тестов в буфере" })
  map("n", "<leader>gM", call("GoModTidy"), { desc = "🧽 Go: go mod tidy" })
  map("n", "<leader>gn", call("GoGenerate"), { desc = "⚙ Go: go generate" })
  map("n", "<leader>gS", call("GoFillSwitch"), { desc = "🔀 Go: заполнить case'ы switch" })
  map("n", "<leader>gE", call("GoGenReturn"), { desc = "↩ Go: заполнить return" })
  map("n", "<leader>gG", call("GoGCDetails"), { desc = "🧬 Go: escape analysis (что в кучу)" })
  map("n", "<leader>gp", call("GoPkgOutline"), { desc = "📦 Go: структура пакета (outline)" })
  map("n", "<leader>gA", call("GoAddAllTest"), { desc = "🧪 Go: тесты для всех функций файла" })
  map("n", "<leader>gV", M.vet, { desc = "🔧 Go: go vet ./..." })
  map("n", "<leader>gH", function()
    if need_go() then vim.lsp.buf.incoming_calls() end
  end, { desc = "🔎 Go: кто вызывает функцию (call hierarchy)" })
  map("n", "<leader>gO", function()
    if need_go() then vim.lsp.buf.outgoing_calls() end
  end, { desc = "📤 Go: что вызывает функция (call hierarchy)" })
  map("x", "<leader>gJ", M.json_to_struct, { desc = "📥 Go: JSON из выделения → struct" })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("UserGoPro", { clear = true }),
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client and client.name == "gopls" then
        attach_codelens(ev.buf)
      end
    end,
  })
end

return M
