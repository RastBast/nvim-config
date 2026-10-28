-- ========================================================================== --
--        GO КАК В GOLAND: генерация, рефакторинг, навигация, запуск          --
-- ========================================================================== --
-- Что умеет (меню <leader>gi или <leader>HGi, :GoIde):
--   * сгенерировать тест для функции под курсором  <leader>gT
--     (gotests, если установлен; иначе шаблон table-driven теста);
--   * конструктор New<Тип> для struct под курсором  <leader>gC;
--   * комментарий-документация к функции            <leader>gD;
--   * файл ↔ тест (_test.go)                         <leader>ga;
--   * извлечь выделение в переменную/функцию (gopls) <leader>gx (в визуальном);
--   * оптимизировать импорты (gopls)                 <leader>go;
--   * запустить пакет (go run .) во float-терминале  <leader>gr;
--   * if err != nil, реализация интерфейса, теги struct — через go.nvim;
--   * переименование, все использования, реализации — через LSP (gopls).
-- Структура кода берётся из treesitter (парсер go уже ставится).
local M = {}

local ts = vim.treesitter

local GO_KEYWORDS = {
  ["break"] = true, case = true, chan = true, const = true, continue = true,
  default = true, defer = true, ["else"] = true, fallthrough = true, ["for"] = true,
  func = true, go = true, ["goto"] = true, ["if"] = true, import = true,
  interface = true, map = true, package = true, range = true, ["return"] = true,
  select = true, struct = true, switch = true, type = true, var = true,
}

local function notify(msg, level)
  vim.notify("Go: " .. msg, level or vim.log.levels.INFO)
end

local function is_go()
  if vim.bo.filetype == "go" then
    return true
  end
  notify("это не Go-файл", vim.log.levels.WARN)
  return false
end

local function text(node)
  return vim.treesitter.get_node_text(node, 0)
end

--- Узел под курсором, поднимаемся до одного из типов из набора.
local function enclosing(types)
  local ok, node = pcall(ts.get_node)
  if not ok or not node then
    return nil
  end
  while node do
    if types[node:type()] then
      return node
    end
    node = node:parent()
  end
  return nil
end

local FUNC_TYPES = { function_declaration = true, method_declaration = true }
local constructor_lines -- объявлено ниже

local function package_name()
  for _, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, 80, false)) do
    local p = l:match("^package%s+([%w_]+)")
    if p then
      return p
    end
  end
  return "main"
end

--- Параметры списка: массив {names = {...}, type = "...", variadic = bool}.
local function param_items(list)
  local items = {}
  if not list then
    return items
  end
  for i = 0, list:named_child_count() - 1 do
    local c = list:named_child(i)
    local t = c:type()
    if t == "parameter_declaration" or t == "variadic_parameter_declaration" then
      local names = {}
      for _, n in ipairs(c:field("name")) do
        names[#names + 1] = text(n)
      end
      local ty = c:field("type")[1]
      items[#items + 1] = {
        names = names,
        type = ty and text(ty) or "",
        variadic = t == "variadic_parameter_declaration",
      }
    end
  end
  return items
end

--- Плоский список параметров: {name, type}. Безымянные получают argN.
local function flat_params(fn)
  local out = {}
  for _, it in ipairs(param_items(fn:field("parameters")[1])) do
    local ty = (it.variadic and "..." or "") .. it.type
    if #it.names == 0 then
      out[#out + 1] = { name = "arg" .. (#out + 1), type = ty, variadic = it.variadic }
    else
      for _, n in ipairs(it.names) do
        out[#out + 1] = { name = n, type = ty, variadic = it.variadic }
      end
    end
  end
  return out
end

--- Результаты: массив типов.
local function results(fn)
  local res = fn:field("result")[1]
  if not res then
    return {}
  end
  if res:type() ~= "parameter_list" then
    return { text(res) }
  end
  local types = {}
  for _, it in ipairs(param_items(res)) do
    local n = math.max(1, #it.names)
    for _ = 1, n do
      types[#types + 1] = it.type
    end
  end
  return types
end

--- Тип получателя без указателя: "(s *Server)" → "Server".
local function receiver_type(fn)
  local r = fn:field("receiver")[1]
  if not r then
    return nil
  end
  local items = param_items(r)
  local ty = items[1] and items[1].type or nil
  return ty and ty:match("([%w_]+)%s*$") or nil
end

--- Файл теста для файла исходника.
local function test_file_for(src)
  return vim.fn.fnamemodify(src, ":r") .. "_test.go"
end

-- ---------------------------------------------------------------------------
-- Тест для функции
-- ---------------------------------------------------------------------------

local function skeleton(fn)
  local name = text(fn:field("name")[1])
  local params = flat_params(fn)
  local res = results(fn)
  local recv = receiver_type(fn)
  local out = {}
  local function add(s)
    out[#out + 1] = s
  end

  add("func Test" .. name .. "(t *testing.T) {")
  add("\ttests := []struct {")
  add("\t\tname string")
  for _, p in ipairs(params) do
    add("\t\t" .. p.name .. " " .. p.type)
  end
  if #res == 1 then
    add("\t\twant " .. res[1])
  end
  add("\t}{")
  add("\t\t{")
  add('\t\t\tname: "TODO: описание случая",')
  if #params > 0 then
    add("\t\t\t// TODO: значения аргументов")
  end
  add("\t\t},")
  add("\t}")
  add("\tfor _, tt := range tests {")
  add("\t\tt.Run(tt.name, func(t *testing.T) {")
  local args = {}
  for _, p in ipairs(params) do
    args[#args + 1] = "tt." .. p.name .. (p.variadic and "..." or "")
  end
  if recv then
    add("\t\t\trecv := &" .. recv .. "{} // TODO: создай получателя")
  end
  local callee = (recv and "recv." or "") .. name .. "(" .. table.concat(args, ", ") .. ")"
  if #res == 0 then
    add("\t\t\t" .. callee)
  else
    local vars = {}
    for i = 1, #res do
      vars[i] = #res == 1 and "got" or ("got" .. i)
    end
    add("\t\t\t" .. table.concat(vars, ", ") .. " := " .. callee)
    for _, v in ipairs(vars) do
      add("\t\t\t_ = " .. v)
    end
    if #res == 1 then
      add("\t\t\t// TODO: сравни got с tt.want")
    end
  end
  add("\t\t})")
  add("\t}")
  add("}")
  return out
end

--- Добавляет код теста в _test.go (создаёт файл при необходимости).
local function write_test(src, fname, code)
  local test = test_file_for(src)
  if vim.fn.filereadable(test) == 0 then
    local body = { "package " .. package_name(), "", 'import "testing"', "" }
    vim.list_extend(body, code)
    vim.fn.writefile(body, test)
  else
    local lines = vim.fn.readfile(test)
    for _, l in ipairs(lines) do
      if l:find("^func Test" .. fname .. "%(") then
        notify("тест Test" .. fname .. " уже есть в " .. vim.fn.fnamemodify(test, ":t"), vim.log.levels.WARN)
        vim.cmd("edit " .. vim.fn.fnameescape(test))
        return
      end
    end
    local has_testing = false
    for _, l in ipairs(lines) do
      if l:find('"testing"', 1, true) then
        has_testing = true
        break
      end
    end
    if not has_testing then
      local inserted = false
      for i, l in ipairs(lines) do
        if l:match("^import%s*%(") then
          table.insert(lines, i + 1, '\t"testing"')
          inserted = true
          break
        end
      end
      if not inserted then
        for i, l in ipairs(lines) do
          if l:match("^package%s") then
            table.insert(lines, i + 1, "")
            table.insert(lines, i + 2, 'import "testing"')
            break
          end
        end
      end
    end
    lines[#lines + 1] = ""
    vim.list_extend(lines, code)
    vim.fn.writefile(lines, test)
  end
  vim.cmd("edit " .. vim.fn.fnameescape(test))
  notify("тест Test" .. fname .. " → " .. vim.fn.fnamemodify(test, ":t"))
end

function M.gen_test()
  if not is_go() then
    return
  end
  local fn = enclosing(FUNC_TYPES)
  if not fn then
    return notify("поставь курсор внутри функции или метода", vim.log.levels.WARN)
  end
  local name = text(fn:field("name")[1])
  local src = vim.api.nvim_buf_get_name(0)
  if vim.fn.executable("gotests") == 1 then
    -- gotests сам пишет полноценный table-driven тест в _test.go
    vim.cmd("silent write")
    local res = vim.system({ "gotests", "-only", "^" .. name .. "$", "-w", src }, { text = true }):wait()
    if res.code ~= 0 then
      return notify("gotests: " .. vim.trim(res.stderr or ("код " .. res.code)), vim.log.levels.ERROR)
    end
    vim.cmd("edit " .. vim.fn.fnameescape(test_file_for(src)))
    return notify("тест для " .. name .. " сгенерирован (gotests)")
  end
  write_test(src, name, skeleton(fn))
end

-- ---------------------------------------------------------------------------
-- Конструктор New<Тип> для struct
-- ---------------------------------------------------------------------------

local function lower_first(s)
  local first = s:sub(1, 1):lower()
  local out = first .. s:sub(2)
  if GO_KEYWORDS[out] then
    out = out .. "_"
  end
  return out
end

--- Строки конструктора New<Тип> по списку полей {name, type}. Чистая функция (без nvim).
constructor_lines = function(tname, fields)
  local ctor = "New" .. tname
  local params, body = {}, {}
  for _, f in ipairs(fields) do
    local p = lower_first(f.name)
    params[#params + 1] = p .. " " .. f.type
    body[#body + 1] = "\t\t" .. f.name .. ": " .. p .. ","
  end
  local block = {
    "",
    "// " .. ctor .. " создаёт *" .. tname .. ". TODO: описание.",
    "func " .. ctor .. "(" .. table.concat(params, ", ") .. ") *" .. tname .. " {",
    "\treturn &" .. tname .. "{",
  }
  vim.list_extend(block, body)
  block[#block + 1] = "\t}"
  block[#block + 1] = "}"
  return block
end

function M.gen_constructor()
  if not is_go() then
    return
  end
  local spec = enclosing({ type_spec = true })
  local st = spec and spec:field("type")[1]
  if not spec or not st or st:type() ~= "struct_type" then
    return notify("поставь курсор внутри struct", vim.log.levels.WARN)
  end
  local tname = text(spec:field("name")[1])
  local ctor = "New" .. tname
  for _, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if l:find("^func " .. ctor .. "%(") then
      return notify(ctor .. " уже есть в файле", vim.log.levels.WARN)
    end
  end

  -- поля: имя и тип; встроенные поля (без имени) пропускаем
  local fields = {}
  for i = 0, st:named_child_count() - 1 do
    local list = st:named_child(i)
    if list:type() == "field_declaration_list" then
      for j = 0, list:named_child_count() - 1 do
        local f = list:named_child(j)
        if f:type() == "field_declaration" then
          local ty = f:field("type")[1]
          for _, n in ipairs(f:field("name")) do
            fields[#fields + 1] = { name = text(n), type = ty and text(ty) or "" }
          end
        end
      end
    end
  end

  local block = constructor_lines(tname, fields)

  -- вставляем сразу после объявления type
  local decl = spec:parent() or spec
  local _, _, erow = decl:range()
  vim.api.nvim_buf_set_lines(0, erow + 1, erow + 1, false, block)
  notify("конструктор " .. ctor .. " добавлен после type " .. tname)
end

-- ---------------------------------------------------------------------------
-- Комментарий-документация и прочее
-- ---------------------------------------------------------------------------

function M.gen_doc()
  if not is_go() then
    return
  end
  local fn = enclosing(FUNC_TYPES)
  if not fn then
    return notify("поставь курсор внутри функции или метода", vim.log.levels.WARN)
  end
  local row = fn:range()
  local above = row > 0 and vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
  if above:match("^%s*//") then
    return notify("перед функцией уже есть комментарий", vim.log.levels.WARN)
  end
  local name = text(fn:field("name")[1])
  vim.api.nvim_buf_set_lines(0, row, row, false, { "// " .. name .. " — TODO: опишите, что делает функция." })
end

function M.alt_file()
  if not is_go() then
    return
  end
  local f = vim.api.nvim_buf_get_name(0)
  local target
  if f:match("_test%.go$") then
    target = f:gsub("_test%.go$", ".go")
  elseif f:match("%.go$") then
    target = test_file_for(f)
  end
  if not target then
    return notify("файл без имени .go", vim.log.levels.WARN)
  end
  if vim.fn.filereadable(target) == 1 then
    return vim.cmd("edit " .. vim.fn.fnameescape(target))
  end
  -- файла нет: для теста — заголовок с import "testing", для исходника — только package
  local body = { "package " .. package_name(), "" }
  if not f:match("_test%.go$") then
    body = { "package " .. package_name(), "", 'import "testing"', "" }
  end
  vim.fn.writefile(body, target)
  vim.cmd("edit " .. vim.fn.fnameescape(target))
  notify("создан " .. vim.fn.fnamemodify(target, ":t"))
end

function M.organize_imports()
  if not is_go() then
    return
  end
  vim.lsp.buf.code_action({
    context = { only = { "source.organizeImports" }, diagnostics = {} },
    apply = true,
  })
end

--- Извлечение: вызывается из визуального режима (выделение сохраняется).
function M.extract()
  if not is_go() then
    return
  end
  vim.lsp.buf.code_action({
    context = { only = { "refactor.extract" }, diagnostics = {} },
  })
end

function M.run_pkg()
  if not is_go() then
    return
  end
  require("config.termcmd").make("go run .", 0, "go run .")()
end

-- ---------------------------------------------------------------------------
-- Меню (как Alt+Enter в GoLand)
-- ---------------------------------------------------------------------------

local function call_cmd(c)
  return function()
    local ok, err = pcall(vim.cmd, c)
    if not ok then
      notify("команда " .. c .. " недоступна: " .. tostring(err), vim.log.levels.WARN)
    end
  end
end

function M.menu()
  if not is_go() then
    return
  end
  local items = {
    { label = "🧪 Тест для функции под курсором (<leader>gT)", run = M.gen_test },
    { label = "🏗 Конструктор New… для struct (<leader>gC)", run = M.gen_constructor },
    { label = "📝 Комментарий-документация к функции (<leader>gD)", run = M.gen_doc },
    { label = "↔ Файл ↔ тест (<leader>ga)", run = M.alt_file },
    { label = "✂ Извлечь выделение (выдели код, <leader>gx)", run = function()
        notify("выдели код в визуальном режиме и нажми <leader>gx")
      end },
    { label = "🧹 Оптимизировать импорты (<leader>go)", run = M.organize_imports },
    { label = "⚠ if err != nil (go.nvim :GoIfErr)", run = call_cmd("GoIfErr") },
    { label = "🔌 Реализовать интерфейс (go.nvim :GoImpl)", run = call_cmd("GoImpl") },
    { label = "🏷 Теги json/yaml у struct (go.nvim :GoAddTag)", run = call_cmd("GoAddTag") },
    { label = "🧩 Формочка struct (<leader>HGS)", run = function()
        require("config.go_extras").fill_struct()
      end },
    { label = "▶ Запустить пакет: go run . (<leader>gr)", run = M.run_pkg },
    { label = "🧪 Запустить тест под курсором (<leader>tr)", run = function()
        local ok, neotest = pcall(require, "neotest")
        if ok then
          neotest.run.run()
        else
          call_cmd("GoTestFunc")()
        end
      end },
    { label = "🔍 Все использования (gr)", run = function()
        vim.lsp.buf.references()
      end },
    { label = "🧭 Реализации интерфейса / метода", run = function()
        vim.lsp.buf.implementation()
      end },
    { label = "✏ Переименовать (LSP)", run = function()
        vim.lsp.buf.rename()
      end },
    { label = "💡 Все действия gopls (как Alt+Enter)", run = function()
        vim.lsp.buf.code_action()
      end },
  }
  -- пункты «как в VS Code / GoLand» из go_pro.lua (тесты -race, bench, покрытие…)
  vim.list_extend(items, require("config.go_pro").menu_items)
  vim.ui.select(items, {
    prompt = "Go IDE",
    format_item = function(it)
      return it.label
    end,
  }, function(it)
    if it then
      it.run()
    end
  end)
end

function M.setup()
  local map = vim.keymap.set
  map("n", "<leader>gi", M.menu, { desc = "🧠 Go IDE-меню: тесты, конструкторы, рефакторинг (как Alt+Enter)" })
  map("n", "<leader>HGi", M.menu, { desc = "🧠 Go IDE-меню (как в GoLand)" })
  map("n", "<leader>gT", M.gen_test, { desc = "🧪 Go: тест для функции под курсором" })
  map("n", "<leader>gC", M.gen_constructor, { desc = "🏗 Go: конструктор New… для struct" })
  map("n", "<leader>gD", M.gen_doc, { desc = "📝 Go: комментарий-документация к функции" })
  map("n", "<leader>ga", M.alt_file, { desc = "↔ Go: файл ↔ тест (_test.go)" })
  map("n", "<leader>go", M.organize_imports, { desc = "🧹 Go: оптимизировать импорты" })
  map("n", "<leader>gr", M.run_pkg, { desc = "▶ Go: запустить пакет (go run .)" })
  map("x", "<leader>gx", M.extract, { desc = "✂ Go: извлечь выделение в переменную/функцию" })
  vim.api.nvim_create_user_command("GoIde", M.menu, { desc = "🧠 Go IDE-меню" })
end

-- Для тестов (lupa): внутренние чистые функции
M._test = {
  skeleton = skeleton,
  flat_params = flat_params,
  results = results,
  receiver_type = receiver_type,
  lower_first = lower_first,
  constructor_lines = constructor_lines,
}

return M
