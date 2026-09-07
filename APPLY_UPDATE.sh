#!/usr/bin/env bash
# ============================================================================
#  APPLY_UPDATE.sh — накладывает русский-стек + умный Go на твой nvim-конфиг
#  Использование:  bash APPLY_UPDATE.sh [путь_к_конфигу]
#  По умолчанию:   ~/.config/nvim
# ============================================================================
set -e
DEST="${1:-$HOME/.config/nvim}"
cd "$DEST"
mkdir -p lua/config lua/plugins
echo "Обновляю конфиг в $DEST ..."
cat > lua/config/ru_util.lua <<'LUA_FILE_EOF'
-- ========================================================================== --
--              ОБЩИЙ АСИНХРОННЫЙ ПЕРЕВОД en→ru (Google gtx, curl)            --
-- ========================================================================== --
-- Пользователи: hover_ru (подсказки), diag_ru (ошибки LSP), notify_ru
-- (уведомления/вывод сборок), completions (окно документации cmp).
--
-- КЕШ: в памяти + файл stdpath("cache")/ru_cache.json — перевод переживает
-- перезапуск Neovim. Повторная ошибка/подсказка отдаётся СРАЗУ по-русски
-- (translate_cached), первый раз греет кеш асинхронно.
-- Любая ошибка (нет curl/сети, кривой JSON) → cb(nil); вызывающий показывает
-- оригинал — ничего не падает и не блокируется.

local M = { cache = {} }

local function cache_file()
  local ok, dir = pcall(vim.fn.stdpath, "cache")
  if not ok or type(dir) ~= "string" then
    dir = "/tmp"
  end
  return dir .. "/ru_cache.json"
end

-- подгружаем кеш прошлого сеанса
do
  local f = io.open(cache_file(), "r")
  if f then
    local raw = f:read("*a")
    f:close()
    local ok, data = pcall(vim.json.decode, raw)
    if ok and type(data) == "table" then
      for k, v in pairs(data) do
        if type(k) == "string" and type(v) == "string" then
          M.cache[k] = v
        end
      end
    end
  end
end

local save_scheduled = false
local function persist()
  if save_scheduled then
    return
  end
  save_scheduled = true
  vim.defer_fn(function()
    save_scheduled = false
    local ok, raw = pcall(vim.json.encode, M.cache)
    if ok then
      local f = io.open(cache_file(), "w")
      if f then
        f:write(raw)
        f:close()
      end
    end
  end, 2000)
end

function M.url_encode(s)
  return (s:gsub("([^%w%-%.%_%~ ])", function(c)
    return string.format("%%%02X", string.byte(c))
  end):gsub(" ", "+"))
end

--- Синхронно: перевод из кеша или nil (ещё не переводилось).
function M.translate_cached(text)
  return M.cache[text]
end

--- Асинхронный перевод en→ru, результат в кеш. cb(string|nil)
function M.translate(text, cb)
  local hit = M.cache[text]
  if hit then
    return cb(hit)
  end
  if vim.fn.executable("curl") == 0 then
    return cb(nil)
  end
  local function try(i)
    if i > #M.endpoints then
      return cb(nil)
    end
    local url = M.endpoints[i] .. M.url_encode(text)
    vim.system({ "curl", "-sS", "--max-time", "4", url }, { text = true }, function(res)
      vim.schedule(function()
        local tr = nil
        if res.code == 0 then
          local ok, data = pcall(vim.json.decode, res.stdout)
          if ok and type(data) == "table" and type(data[1]) == "table" then
            local out = {}
            for _, item in ipairs(data[1]) do
              if type(item) == "table" and type(item[1]) == "string" then
                out[#out + 1] = item[1]
              end
            end
            local joined = table.concat(out)
            if joined ~= "" then
              tr = joined
            end
          end
        end
        if tr then
          local n = 0
          for _ in pairs(M.cache) do
            n = n + 1
          end
          if n > 2000 then
            M.cache = {}
          end
          M.cache[text] = tr
          persist()
          return cb(tr)
        end
        try(i + 1) -- первый эндпоинт недоступен — пробуем запасной
      end)
    end)
  end
  try(1)
end

M.endpoints = {
  "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=ru&dt=t&q=",
  "https://translate.google.com/translate_a/single?client=gtx&sl=en&tl=ru&dt=t&q=",
}

-- ---------- markdown: код не переводим ----------

--- Разбить markdown на куски {code=bool, text=...}: fenced-блоки — code=true.
function M.split_md(md)
  local parts, buf, in_fence = {}, {}, false
  local function flush()
    if #buf > 0 then
      table.insert(parts, { code = in_fence, text = table.concat(buf, "\n") })
      buf = {}
    end
  end
  for line in (md .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^%s*```") then
      flush()
      table.insert(parts, { code = true, text = line })
      in_fence = not in_fence
    else
      table.insert(buf, line)
    end
  end
  flush()
  return parts
end


-- Спрятать inline `код` под маркеры @@N@@ и вернуть обратно.
function M.protect_inline(text)
  local stash = {}
  local masked = text:gsub("`[^`\n]+`", function(c)
    table.insert(stash, c)
    return "@@" .. #stash .. "@@"
  end)
  return masked, stash
end

function M.restore_inline(text, stash)
  return (text:gsub("@@(%d+)@@", function(n)
    return stash[tonumber(n)] or ""
  end))
end

return M
LUA_FILE_EOF
echo '  ✓ lua/config/ru_util.lua'
cat > lua/config/hover_ru.lua <<'LUA_FILE_EOF'
-- ========================================================================== --
--        РУССКИЙ В LSP-ПОДСКАЗКАХ (hover) — перевод БЕЗ трогания кода        --
-- ========================================================================== --
-- Перехватывает textDocument/hover — подсказку «что делает функция»
-- (клавиша K / авто-hover) — и переводит описательный текст en → ru.
--
-- НЕ переводится (код остаётся как есть):
--   * fenced-блоки ```...```  (сигнатура функции, примеры);
--   * inline `код` внутри прозы — на время перевода заменяется маркером
--     @@N@@ и восстанавливается после.
--
-- Перевод: свободный эндпоинт Google (client=gtx), асинхронно через curl.
-- Если сети/curl нет или ответ кривой — молча показывается оригинальная
-- подсказка: ничего не падает и не блокируется (таймаут-фолбэк 1.2 с).
--
-- Команды:  :HoverRu on | off | toggle
-- Работает с любым LSP: gopls (Go), lua_ls, ts_ls и т.д.
-- Окно документации автодополнения (nvim-cmp) НЕ переводится — это осознанное
-- ограничение (иначе запрос на каждый пункт списка).

local M = { enabled = true }

local RU = require("config.ru_util")

-- ---------- перехват hover ----------

function M.setup()
  local orig = vim.lsp.handlers["textDocument/hover"]
  if type(orig) ~= "function" then
    return
  end

  vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, cfg)
    if not M.enabled or err or not result or not result.contents then
      return orig(err, result, ctx, cfg)
    end

    local mc = result.contents
    local md
    if type(mc) == "string" then
      md = mc
    elseif type(mc) == "table" and type(mc.value) == "string" then
      md = mc.value
    elseif vim.islist(mc) then
      md = table.concat(mc, "\n")
    end
    if not md or md == "" then
      return orig(err, result, ctx, cfg)
    end

    local parts = RU.split_md(md)
    local pending, fired = 0, false

    local function finish()
      if fired then
        return
      end
      fired = true
      local out = {}
      for _, p in ipairs(parts) do
        out[#out + 1] = p.text
      end
      local r2 = vim.deepcopy(result)
      if type(r2.contents) == "string" then
        r2.contents = table.concat(out, "\n")
      elseif type(r2.contents) == "table" and r2.contents.value then
        r2.contents.value = table.concat(out, "\n")
      end
      orig(nil, r2, ctx, cfg)
    end

    for _, p in ipairs(parts) do
      if not p.code and p.text:match("%a%a%a") then
        local masked, stash = RU.protect_inline(p.text)
        pending = pending + 1
        RU.translate(masked, function(tr)
          if tr then
            local ok_ph = true
            for i = 1, #stash do
              if not tr:find("@@" .. i .. "@@", 1, true) then
                ok_ph = false
                break
              end
            end
            if ok_ph then
              p.text = RU.restore_inline(tr, stash)
            end
          end
          pending = pending - 1
          if pending == 0 then
            finish()
          end
        end)
      end
    end

    if pending == 0 and not fired then
      -- нечего переводить (или всё код) — сразу оригинал
      return orig(err, result, ctx, cfg)
    end
    -- страховка: сеть медленная → через 1.2 с показываем как есть
    vim.defer_fn(finish, 1200)
  end

  vim.api.nvim_create_user_command("HoverRu", function(o)
    local a = o.args
    if a == "on" then
      M.enabled = true
    elseif a == "off" then
      M.enabled = false
    elseif a == "toggle" then
      M.enabled = not M.enabled
    end
    vim.notify("HoverRu (перевод подсказок LSP): " .. (M.enabled and "вкл" or "выкл"), vim.log.levels.INFO)
  end, {
    nargs = "?",
    complete = function()
      return { "on", "off", "toggle" }
    end,
  })
end

return M
LUA_FILE_EOF
echo '  ✓ lua/config/hover_ru.lua'
cat > lua/config/diag_ru.lua <<'LUA_FILE_EOF'
-- ========================================================================== --
--          РУССКИЕ ОШИБКИ НА ЛЕТУ (LSP-диагностика при написании кода)       --
-- ========================================================================== --
-- Перехватывает textDocument/publishDiagnostics — сообщения об ошибках,
-- которые LSP шлёт прямо во время набора (gopls для Go, dockerls для
-- Dockerfile, protols для .proto, sqls для SQL, lua_ls и т.д.) — и
-- переводит текст ошибки на русский ДО того, как он попадёт в:
--   * виртуальный текст рядом со строкой,
--   * плавающее окно диагностики (<leader>d),
--   * Trouble / location list / quickfix.
--
-- Код в сообщениях не раздувается: переводится строка сообщения целиком
-- (это проза, не код). Повторные одинаковые сообщения берутся из кеша
-- (ru_util), сеть не спамится.
--
-- Нет сети/curl — молча показываются оригинальные английские ошибки.
-- Команда: :DiagRu on | off | toggle
--
-- Про Redis: для Redis НЕ существует живого LSP-сервера (проверено по
-- реестрам Mason/lspconfig), поэтому ошибки redis-cli в терминале сюда не
-- попадают — это честное ограничение экосистемы, а не конфига.

local RU = require("config.ru_util")

local M = { enabled = true }

function M.setup()
  local orig = vim.lsp.handlers["textDocument/publishDiagnostics"]
  if type(orig) ~= "function" then
    return
  end

  vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, cfg)
    if not M.enabled or err or not result or not result.diagnostics then
      return orig(err, result, ctx, cfg)
    end

    local pending, fired = 0, false
    local function finish()
      if fired then
        return
      end
      fired = true
      orig(nil, result, ctx, cfg)
    end

    for _, d in ipairs(result.diagnostics) do
      if type(d.message) == "string" and d.message:match("%a%a%a") then
        pending = pending + 1
        RU.translate(d.message, function(tr)
          if tr and tr ~= "" then
            d.message = tr
          end
          pending = pending - 1
          if pending == 0 then
            finish()
          end
        end)
      end
    end

    if pending == 0 and not fired then
      return orig(err, result, ctx, cfg)
    end
    -- страховка от медленной сети: через 2.5 с ошибки уходят как есть
    vim.defer_fn(finish, 2500)
  end

  vim.api.nvim_create_user_command("DiagRu", function(o)
    local a = o.args
    if a == "on" then
      M.enabled = true
    elseif a == "off" then
      M.enabled = false
    elseif a == "toggle" then
      M.enabled = not M.enabled
    end
    vim.notify("DiagRu (русские ошибки LSP): " .. (M.enabled and "вкл" or "выкл"), vim.log.levels.INFO)
  end, {
    nargs = "?",
    complete = function()
      return { "on", "off", "toggle" }
    end,
  })
end

return M
LUA_FILE_EOF
echo '  ✓ lua/config/diag_ru.lua'
cat > lua/config/notify_ru.lua <<'LUA_FILE_EOF'
-- ========================================================================== --
--     РУССКИЕ УВЕДОМЛЕНИЯ: вывод сборок/линтов (go.nvim и прочие плагины)    --
-- ========================================================================== --
-- Перехватывает vim.notify. Покрывает то, что НЕ является LSP-диагностикой:
--   * «build exited with code: 1 … package X is not in std …» после <leader>HGb,
--   * вывод GoLint, SnipRun, прочих плагинов, пишущих в notify.
--
-- Работает через кеш ru_util (файл stdpath("cache")/ru_cache.json):
--   * сообщение уже переводилось (в т.ч. в прошлый сеанс) — сразу по-русски;
--   * первый раз — показывается оригинал, перевод уходит в кеш фоном,
--     следующий показ этого же сообщения — русский.
-- LSP-диагностику (ошибки при наборе) переводит diag_ru, подсказки — hover_ru.
-- Команда: :NotifyRu on | off | toggle

local RU = require("config.ru_util")

local M = { enabled = true }

function M.setup()
  local orig = vim.notify
  if type(orig) ~= "function" then
    return
  end

  vim.notify = function(msg, level, opts)
    if not M.enabled or type(msg) ~= "string" or not msg:match("%a%a%a") then
      return orig(msg, level, opts)
    end
    local tr = RU.translate_cached(msg)
    if tr then
      return orig(tr, level, opts)
    end
    -- первый раз: до 0.7 с ждём перевод — успел (обычно да) — сразу
    -- русский; нет — оригинал, кеш греется для следующего раза
    local fired = false
    RU.translate(msg, function(t)
      if fired then
        return
      end
      fired = true
      orig(t or msg, level, opts)
    end)
    vim.defer_fn(function()
      if not fired then
        fired = true
        orig(msg, level, opts)
      end
    end, 700)
  end

  vim.api.nvim_create_user_command("NotifyRu", function(o)
    local a = o.args
    if a == "on" then
      M.enabled = true
    elseif a == "off" then
      M.enabled = false
    elseif a == "toggle" then
      M.enabled = not M.enabled
    end
    vim.notify("NotifyRu (русские уведомления): " .. (M.enabled and "вкл" or "выкл"), vim.log.levels.INFO)
  end, {
    nargs = "?",
    complete = function()
      return { "on", "off", "toggle" }
    end,
  })
end

return M
LUA_FILE_EOF
echo '  ✓ lua/config/notify_ru.lua'
cat > lua/config/go_extras.lua <<'LUA_FILE_EOF'
-- ========================================================================== --
--      УМНЫЙ GO: ФОРМОЧКА STRUCT (как в VSCode) + АВТОЗАПОЛНЕНИЕ ПОЛЕЙ       --
-- ========================================================================== --
-- fill_struct()  — «формочка»: выбираешь struct (красивый пикер через
--                  dressing), вставляется снаркет с ВСЕМИ полями, курсор
--                  прыгает по значениям (<Tab>/<S-Tab>), дефолты —
--                  нулевые значения Go по типу поля.
-- add_fields()   — автодополнение полей: берёт struct под/над курсором
--                  (или пикер) и вставляет поля со значениями.
-- Всё на treesitter-парсере `go` (уже ставится).
local M = {}

-- ---------- нулевые значения Go по типу ----------

function M.zero_for(typ)
  typ = (typ or ""):gsub("%s+", "")
  if typ == "" then
    return nil
  end
  if typ:match("^%*") or typ:match("^%[") or typ:match("^map%[") then
    return "nil"
  end
  if typ == "string" then
    return '""'
  end
  if typ == "bool" then
    return "false"
  end
  if typ:match("^int") or typ:match("^uint") or typ:match("^float")
    or typ:match("^byte$") or typ:match("^rune$") then
    return "0"
  end
  if typ == "error" or typ:match("^interface") or typ:match("^func%(") then
    return "nil"
  end
  return nil -- неизвестный тип → пустой плейсхолдер, заполнит человек
end

-- ---------- treesitter: struct'ы буфера ----------

local function parse_go()
  local parser = vim.treesitter.get_parser(0, "go")
  if not parser then
    return nil
  end
  local tree = parser:parse()[1]
  return tree and tree:root()
end

--- Имена всех struct в текущем буфере.
function M.struct_names()
  local root = parse_go()
  if not root then
    return {}
  end
  local ok, q = pcall(
    vim.treesitter.query.parse,
    "go",
    "(type_declaration (type_spec (type_identifier) @name (struct_type)))"
  )
  if not ok then
    return {}
  end
  local names, seen = {}, {}
  for _, node in q:iter_captures(root, 0) do
    local n = vim.treesitter.get_node_text(node, 0)
    if n ~= "" and not seen[n] then
      seen[n] = true
      names[#names + 1] = n
    end
  end
  return names
end

--- Поля struct'а: { {name=..., type=...}, ... }
function M.fields_of(name)
  local root = parse_go()
  if not root then
    return {}
  end
  local ok, q = pcall(
    vim.treesitter.query.parse,
    "go",
    "(type_declaration (type_spec (type_identifier) @name (struct_type) @body))"
  )
  if not ok then
    return {}
  end
  local fields = {}
  local bodies = {}
  for id, node in q:iter_captures(root, 0) do
    local cap = q.captures[id]
    if cap == "name" then
      bodies[vim.treesitter.get_node_text(node, 0)] = bodies[vim.treesitter.get_node_text(node, 0)] or node:parent()
    end
  end
  -- найдём тело нужного struct'а
  local ok2, q2 = pcall(vim.treesitter.query.parse, "go", "(type_spec (struct_type) @sb)")
  if not ok2 then
    return {}
  end
  local target = nil
  for _, spec in q2:iter_captures(root, 0) do
    local name_node = spec:child(0)
    if name_node and vim.treesitter.get_node_text(name_node, 0) == name then
      target = spec
      break
    end
  end
  if not target then
    return {}
  end
  local ok3, q3 = pcall(vim.treesitter.query.parse, "go", "(field_declaration) @fd")
  if not ok3 then
    return {}
  end
  for _, fd in q3:iter_captures(target, 0) do
    local fname, ftype = nil, {}
    for child in fd:iter_children() do
      if child:named() then
        if child:type() == "field_identifier" and not fname then
          fname = vim.treesitter.get_node_text(child, 0)
        elseif child:type() ~= "field_identifier" then
          ftype[#ftype + 1] = vim.treesitter.get_node_text(child, 0)
        end
      end
    end
    if fname then
      fields[#fields + 1] = { name = fname, type = table.concat(ftype, " ") }
    end
  end
  return fields
end

--- Имя struct'а, ближайшего над курсором (или первый в файле).
function M.nearest_struct()
  local names = M.struct_names()
  if #names == 0 then
    return nil
  end
  local root = parse_go()
  if not root then
    return names[1]
  end
  local cur = vim.api.nvim_win_get_cursor(0)
  local cur_row = cur[1] - 1
  local best, best_row = names[1], -1
  local ok, q = pcall(
    vim.treesitter.query.parse,
    "go",
    "(type_declaration (type_spec (type_identifier) @name (struct_type)))"
  )
  if ok then
    for _, node in q:iter_captures(root, 0) do
      local n = vim.treesitter.get_node_text(node, 0)
      local r = node:start()
      if r <= cur_row and r > best_row then
        best, best_row = n, r
      end
    end
  end
  return best
end

-- ---------- вставка сниппет-тела ----------

local function insert_lsp_snippet(body)
  local ok, ls = pcall(require, "luasnip")
  if ok and ls.lsp_expand then
    ls.lsp_expand(body)
  else
    vim.api.nvim_put(vim.split(body, "\n", { plain = true }), "c", true, true)
  end
end

--- Тело сниппета «формочки» для struct'а: Name{ \n\tField: ${i:zero}, ... }
function M.struct_snippet_body(name)
  local fields = M.fields_of(name)
  if #fields == 0 then
    return nil
  end
  local lines = { name .. " {" }
  for idx, f in ipairs(fields) do
    local zero = M.zero_for(f.type)
    if zero then
      lines[#lines + 1] = ("\t%s: ${%d:%s},"):format(f.name, idx, zero)
    else
      lines[#lines + 1] = ("\t%s: ${%d:},"):format(f.name, idx)
    end
  end
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n")
end

--- Формочка: выбрать struct → вставить сниппет с полями.
function M.fill_struct()
  local names = M.struct_names()
  if #names == 0 then
    vim.notify("В буфере нет struct (нужен treesitter-парсер go)", vim.log.levels.WARN)
    return
  end
  local choose = function(n)
    if not n then
      return
    end
    local body = M.struct_snippet_body(n)
    if body then
      insert_lsp_snippet(body)
    else
      vim.notify("У struct " .. n .. " нет полей", vim.log.levels.WARN)
    end
  end
  if #names == 1 then
    return choose(names[1])
  end
  -- dressing.nvim делает vim.ui.select красивым
  vim.ui.select(names, { prompt = "🧩 Заполнить struct: " }, choose)
end

--- Автодополнение полей struct'а под курсором.
function M.add_fields()
  local name = M.nearest_struct()
  if not name then
    return M.fill_struct()
  end
  local body = M.struct_snippet_body(name)
  if body then
    insert_lsp_snippet(body)
  end
end

return M
LUA_FILE_EOF
echo '  ✓ lua/config/go_extras.lua'
cat > lua/config/go_snips.lua <<'LUA_FILE_EOF'
-- ========================================================================== --
--   РУССКИЕ GO-СНИППЕТЫ + «ФОРМОЧКА» gstr (поля подставляются из struct'а)   --
-- ========================================================================== --
-- Описание сниппетов (dstring) — на русском: в меню автодополнения видно
-- по-русски, что делает сниппет.
-- gstr — динамический: при раскрытии берёт ближайший struct над курсором
-- и разворачивается в «формочку» со всеми полями и нулевыми значениями,
-- курсор прыгает по полям (<Tab>/<S-Tab>). Выбор любого struct'а —
-- <leader>HGS (пикер), автодополнение полей — <leader>HGf.
local M = {}

function M.register()
  local ok, ls = pcall(require, "luasnip")
  if not ok then
    return
  end
  local s, t, i, d = ls.snippet, ls.text_node, ls.insert_node, ls.dynamic_node
  local sn = ls.sn

  local function form_nodes()
    local ge = require("config.go_extras")
    local name = ge.nearest_struct()
    if not name then
      return sn(nil, { t("// struct не найден: <leader>HGS или проверь парсер go") })
    end
    local fields = ge.fields_of(name)
    if #fields == 0 then
      return sn(nil, { t(name .. "{}") })
    end
    local nodes = { t(name .. " {") }
    for idx, f in ipairs(fields) do
      local zero = ge.zero_for(f.type)
      nodes[#nodes + 1] = t({ "", "\t" .. f.name .. ": " })
      nodes[#nodes + 1] = i(idx + 1, zero or "")
      nodes[#nodes + 1] = t(",")
    end
    nodes[#nodes + 1] = t({ "", "}" })
    return sn(nil, nodes)
  end

  ls.add_snippets("go", {
    s("gmain", {
      t({ "func main() {", "\t" }),
      i(1, "// код"),
      t({ "", "}" }),
    }, { dstring = "Главная функция main()" }),
    s("gfunc", {
      t("func "), i(1, "name"), t("("), i(2, ""), t(") "), i(3, "error"),
      t({ " {", "\t" }), i(4), t({ "", "}" }),
    }, { dstring = "Функция с сигнатурой и error" }),
    s("giferr", {
      t({ "if err != nil {", "\treturn " }), i(1, "fmt.Errorf(\"контекст: %w\", err)"),
      t({ "", "}" }),
    }, { dstring = "Проверка if err != nil с возвратом" }),
    s("gtest", {
      t("func Test"), i(1, "Name"), t("(t *testing.T) {\n\t"), i(2), t({ "", "}" }),
    }, { dstring = "Тестовая функция TestX(t *testing.T)" }),
    s("gsrv", {
      t({ "srv := &http.Server{", "\tAddr:    " }), i(1, '":8080"'),
      t(",\n\tHandler: "), i(2, "mux"), t(",\n}"),
    }, { dstring = "Каркас http.Server (микросервис)" }),
    s("gstr", { d(1, form_nodes, {}) }, { dstring = "Формочка struct: поля с нулевыми значениями" }),
  })
end

return M
LUA_FILE_EOF
echo '  ✓ lua/config/go_snips.lua'
cat > lua/plugins/go-tools.lua <<'LUA_FILE_EOF'
-- ========================================================================== --
--                          GO: ЕДИНСТВЕННЫЙ СПЕК                             --
-- ========================================================================== --
-- ИСПРАВЛЕНО. Раньше ray-x/go.nvim был объявлен ДВАЖДЫ:
--   lua/plugins/go-tools.lua   и   lua/plugins/go-security.lua
-- lazy.nvim склеивает такие спеки в один плагин, а функция config у плагина
-- может быть только одна — выживал последний, поэтому все настройки и
-- клавиши из go-security.lua (GoLint / GoVulncheck) просто терялись.
-- Файл go-security.lua удалён, всё живёт здесь.
--
-- Также удалён lua/plugins/go-utils.lua (olexsmir/gopher.nvim):
--   * его build содержал мусор  `go install ://github.com`
--   * он объявлял те же команды, что и go.nvim (GoIfErr, GoImpl, GoNew),
--     и они перезаписывали друг друга
--   * клавиша <leader>gj вела на :GoDoMock — такой команды нет ни в одном
--     из плагинов. Генерация моков в go.nvim называется :GoMockGen.
return {
  {
    "ray-x/go.nvim",
    dependencies = {
      "ray-x/guihua.lua",
      "nvim-treesitter/nvim-treesitter",
    },
    event = { "CmdlineEnter" },
    ft = { "go", "gomod", "gowork", "gosum" },
    -- Стабы команд: which-key дёргает <cmd>Go* до загрузки плагина —
    -- без cmd = это E492. Все имена сверены с lua/go/commands.lua go.nvim.
    cmd = {
      "GoBuild", "GoTest", "GoTestFunc", "GoTestFile", "GoTestPkg",
      "GoLint", "GoVulnCheck", "GoMockGen", "GoIfErr", "GoImpl",
      "GoAddTag", "GoFillStruct", "GoJson", "GoJson2Struct",
    },
    build = ':lua require("go.install").update_all_sync()',
    config = function()
      require("go").setup({
        lsp_cfg = false, -- LSP настраивается в lua/plugins/lsp-config.lua
        lsp_keymaps = true,
        diagnostic = { hdlr = true, underline = true },
        gofmt = "goimports", -- форматирование с автоимпортом
        test_efm = false,
        trouble = true,
      })

      -- Автоформат Go-файлов при сохранении
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = vim.api.nvim_create_augroup("UserGoFormat", { clear = true }),
        pattern = "*.go",
        callback = function()
          pcall(require("go.format").goimports)
        end,
      })

      -- Быстрые команды (регистр важен: команда называется GoVulnCheck)
      vim.keymap.set("n", "<leader>gv", "<cmd>GoVulnCheck<cr>", { desc = "🛡 Проверить уязвимости" })
      vim.keymap.set("n", "<leader>gl", "<cmd>GoLint<cr>", { desc = "🧹 Линтер" })
      vim.keymap.set("n", "<leader>gt", "<cmd>GoTest<cr>", { desc = "🧪 Тесты пакета" })
      vim.keymap.set("n", "<leader>gb", "<cmd>GoBuild<cr>", { desc = "🔨 Собрать" })
      vim.keymap.set("n", "<leader>gm", "<cmd>GoMockGen<cr>", { desc = "🎭 Сгенерировать мок" })

      -- ============================================================== --
      --  УМНЫЙ GO: формочка struct как в VSCode + автозаполнение полей  --
      -- ============================================================== --
      vim.keymap.set("n", "<leader>HGS", function()
        require("config.go_extras").fill_struct()
      end, { desc = "🧩 Формочка struct (выбор из списка)" })
      vim.keymap.set("n", "<leader>HGf", function()
        require("config.go_extras").add_fields()
      end, { desc = "🧱 Поля struct'а под курсором" })

      -- Русские Go-сниппеты + динамическая формочка gstr
      pcall(function()
        require("config.go_snips").register()
      end)
    end,
  },
}
LUA_FILE_EOF
echo '  ✓ lua/plugins/go-tools.lua'
cat > lua/plugins/completions.lua <<'LUA_FILE_EOF'
-- ========================================================================== --
--                    АВТОДОПОЛНЕНИЕ (nvim-cmp + LuaSnip)                     --
-- ========================================================================== --
-- ИСПРАВЛЕНО / ДОБАВЛЕНО:
--  * <C-n>/<C-p> для навигации по списку — раньше выбор работал только
--    через <CR>, а по списку ходить было нечем.
--  * <Tab>/<S-Tab> для прыжков по плейсхолдерам сниппетов.
--  * rafamadriz/friendly-snippets — готовые сниппеты (НОВОЕ).
--  * Источник vim-dadbod-completion объявлен как зависимость, иначе cmp
--    ругался "source not found" в sql-файлах.
return {
  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
      "kristijanhusak/vim-dadbod-completion",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      -- Подгружаем готовые сниппеты (friendly-snippets)
      pcall(require("luasnip.loaders.from_vscode").lazy_load)

      -- ================================================================== --
      --  🧊 Сниппеты Protobuf/gRPC (ft=proto): hdr/svc/msg/rpc/enum/opt     --
      -- ================================================================== --
      local s, t, i = luasnip.snippet, luasnip.text_node, luasnip.insert_node
      luasnip.add_snippets("proto", {
        s("hdr", { -- каркас нового .proto
          t({ 'syntax = "proto3";', "", "package " }), i(1, "app.v1"),
          t({ "", "", 'option go_package = "' }), i(2, "github.com/org/repo/gen/go/app/v1;appv1"),
          t({ '";', "" }),
        }),
        s("svc", { -- сервис с одним rpc
          t("service "), i(1, "UserService"), t({ " {", "  rpc " }), i(2, "GetUser"),
          t("("), i(3, "GetUserRequest"), t(") returns ("), i(4, "GetUserResponse"),
          t({ ");", "}" }),
        }),
        s("msg", { t("message "), i(1, "User"), t({ " {", "  " }), i(2, "string id = 1;"), t({ "", "}" }) }),
        s("rpc", { t("rpc "), i(1, "Method"), t("("), i(2, "Req"), t(") returns ("), i(3, "Resp"), t(");") }),
        s("enum", { t("enum "), i(1, "Status"), t({ " {", "  " }), i(2, "STATUS_UNSPECIFIED = 0;"), t({ "", "}" }) }),
        s("opt", { t('option go_package = "'), i(1, "gen/go/app/v1"), t('";') }),
      })

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        completion = { completeopt = "menu,menuone,noinsert" },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
          ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
          -- Прыжки по плейсхолдерам сниппетов
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 1000 },
          { name = "luasnip", priority = 750 },
          { name = "path", priority = 500 },
        }, {
          { name = "buffer", priority = 250 },
        }),
      })

      -- Автодополнение команд Neovim в cmdline
      cmp.setup.cmdline({ ":", "/" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
      })

      -- ================================================================== --
      --  РУССКИЙ В ОКНЕ ДОКУМЕНТАЦИИ АВТОДОПОЛНЕНИЯ (скрин «Snippet for …») --
      -- ================================================================== --
      -- Через кеш ru_util: переводилось раньше (или в прошлый сеанс) —
      -- сразу русский; первый раз — английский + кеш греется фоном.
      local RU = require("config.ru_util")
      local ok_e, entry_mod = pcall(require, "cmp.entry")
      if ok_e and entry_mod and entry_mod.get_documentation then
        local orig_doc = entry_mod.get_documentation
        entry_mod.get_documentation = function(self)
          local docs = orig_doc(self)
          local text = type(docs) == "table" and table.concat(docs, "\n") or docs
          if type(text) ~= "string" or not text:match("%a%a%a") then
            return docs
          end
          -- весь текст целиком уже переводился
          local tr = RU.translate_cached(text)
          if tr then
            return vim.split(tr, "\n")
          end
          -- код (```-блок с сигнатурой) НЕ переводим: собираем из частей
          local parts = RU.split_md(text)
          local all_cached = true
          for _, p in ipairs(parts) do
            if not p.code and p.text:match("%a%a%a") and not RU.translate_cached(p.text) then
              all_cached = false
              break
            end
          end
          if all_cached and #parts > 1 then
            local out = {}
            for _, p in ipairs(parts) do
              out[#out + 1] = p.code and p.text or (RU.translate_cached(p.text) or p.text)
            end
            return vim.split(table.concat(out, "\n"), "\n")
          end
          -- первый раз: оригинал + греем кеш по частям
          for _, p in ipairs(parts) do
            if not p.code and p.text:match("%a%a%a") then
              RU.translate(p.text, function() end)
            end
          end
          return docs
        end
      end
    end,
  },
}
LUA_FILE_EOF
echo '  ✓ lua/plugins/completions.lua'

# init.lua: дописываем подключение модулей, если их ещё нет
for m in hover_ru diag_ru notify_ru; do
  grep -q "config.$m" init.lua || echo "require(\"config.$m\").setup()" >> init.lua
done
grep -q 'config.hover_ru' init.lua && echo '  ✓ init.lua'

echo
echo "Готово. Перезапусти Neovim."
echo "Клавиши: <leader>HGS — формочка struct, <leader>HGf — поля под курсором."
echo "Команды: :HoverRu / :DiagRu / :NotifyRu (on|off|toggle)."
