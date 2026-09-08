-- ========================================================================== --
--   ПРЕФЛАЙТ-ПРОВЕРКА КОНФИГА (запускать ДО nvim)                            --
-- ========================================================================== --
-- Зачем: три поломки подряд (E239 в avante, «Failed to spawn process git»,
-- маркеры конфликта <<<<<<< в completions.lua) всплывали только при запуске
-- nvim и в самый неподходящий момент. Этот скрипт проверяет конфиг за пару
-- секунд и без запуска редактора.
--
-- Запуск:  ./tools/check_config.sh     (или nvim --headless -u NONE
--                                        -c "luafile tools/check_config.lua" -c "qa!")
-- Выход:   0 — всё чисто;  1 — есть ошибки (список печатается).
--
-- Что проверяется:
--   1) каждый .lua компилируется (loadfile) — ловит синтаксис и маркеры
--      конфликта: на <<<<<<< Lua отвечает «unexpected symbol near '<<'»;
--   2) в файлах нет строк-маркеров git-конфликта (отдельно, чтобы показать
--      точное место, а не только «синтаксис сломан»);
--   3) git/curl/tar видны в PATH — без git lazy.nvim не обновит плагины.

local src = debug.getinfo(1, "S").source:sub(2)
-- :p — абсолютный путь, чтобы скрипт работал из любого каталога
local root = vim.fn.fnamemodify(src, ":p:h:h") -- tools/.. -> корень репозитория

--- Рекурсивно собрать все .lua, пропуская .git
---@param dir string
---@param out string[]
---@return string[]
local function walk(dir, out)
  for _, name in ipairs(vim.fn.globpath(dir, "*", 0, 1)) do
    if vim.fn.isdirectory(name) == 1 then
      if vim.fn.fnamemodify(name, ":t") ~= ".git" then walk(name, out) end
    elseif name:match("%.lua$") then
      out[#out + 1] = name
    end
  end
  return out
end

local files = walk(root, {})
table.sort(files)

local syntax_bad, marker_bad = {}, {}

for _, file in ipairs(files) do
  -- 1) компиляция
  local chunk, err = loadfile(file)
  if not chunk then
    syntax_bad[#syntax_bad + 1] = file .. "\n      " .. tostring(err)
  end

  -- 2) маркеры git-конфликта
  local fh = io.open(file, "r")
  if fh then
    local line, no = fh:read("*l"), 0
    while line do
      no = no + 1
      if line:match("^<<<<<<<") or line:match("^>>>>>>>") or line:match("^=======$") then
        marker_bad[#marker_bad + 1] = file .. ":" .. no .. "  " .. line:sub(1, 40)
      end
      line = fh:read("*l")
    end
    fh:close()
  end
end

local missing = {}
for _, tool in ipairs({ "git", "curl", "tar" }) do
  if vim.fn.exepath(tool) == "" then missing[#missing + 1] = tool end
end

local function short(path) return path:sub(#root + 2) end

print(("Проверено .lua-файлов: %d (корень: %s)"):format(#files, root))

if #syntax_bad > 0 then
  print(("\nСИНТАКСИС — ОШИБОК: %d"):format(#syntax_bad))
  for _, e in ipairs(syntax_bad) do
    print("  ✗ " .. e:gsub("^" .. vim.pesc(root .. "/"), ""))
  end
end

if #marker_bad > 0 then
  print(("\nМАРКЕРЫ КОНФЛИКТА: %d"):format(#marker_bad))
  for _, m in ipairs(marker_bad) do
    print("  ✗ " .. short(m))
  end
end

if #missing > 0 then
  print("\nВ PATH НЕ НАЙДЕНЫ: " .. table.concat(missing, ", "))
  print("  без git lazy.nvim печатает «Failed to spawn process git»;")
  print("  лечение: xcode-select --install  (см. INSTALL.md, §6)")
end

if #syntax_bad == 0 and #marker_bad == 0 and #missing == 0 then
  print("Всё чисто: синтаксис, маркеры конфликта и PATH в порядке.")
  vim.cmd("qa!")
else
  vim.cmd("cq") -- ненулевой код возврата
end
