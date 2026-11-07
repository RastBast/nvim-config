-- ========================================================================== --
--   ПОЧИНКА PATH: чтобы nvim видел git, mason, cargo и nix-бинари            --
-- ========================================================================== --
-- СИМПТОМ: в :Lazy на каждом плагине
--   «Failed to spawn process git { args = { "fetch", … } }»
--
-- ПРИЧИНА: lazy.nvim запускает git без shell — uv.spawn("git", …)
-- (lazy/lua/lazy/manage/process.lua:69), окружение берётся из nvim как есть
-- (там же :130, uv.os_environ()). Если uv.spawn вернул nil, lazy печатает
-- «Failed to spawn process» (там же :99). nil означает ровно одно:
-- исполняемый файл НЕ НАЙДЕН в PATH этого nvim.
--
-- На macOS так происходит, когда nvim запущен из GUI (Finder/Spotlight/
-- launchd даёт PATH=/usr/bin:/bin:/usr/sbin:/sbin), а git/cargo/nil стоят
-- в Homebrew, ~/.cargo/bin или ~/.nix-profile/bin.
--
-- ЛЕЧЕНИЕ: дописываем недостающие стандартные каталоги в конец PATH
-- (твой PATH остаётся приоритетнее). Подключается ПЕРВЫМ в init.lua —
-- до установки lazy.nvim, потому что bootstrap тоже зовёт git.

local M = {}

local home = (vim.env and vim.env.HOME)
  or (vim.uv and vim.uv.os_homedir and vim.uv.os_homedir())
  or ""

local function build_dirs()
  local list = {
    "/opt/homebrew/bin",  -- Homebrew, Apple Silicon (M1/M2/M3/M4)
    "/opt/homebrew/sbin",
    "/usr/local/bin",     -- Homebrew на Intel и ручной install
    "/usr/local/sbin",
    vim.fn.stdpath("data") .. "/mason/bin", -- LSP/DAP/format, поставленные mason
  }
  if type(home) == "string" and home ~= "" then
    list[#list + 1] = home .. "/.cargo/bin"       -- Rust / cargo (запасная сборка avante)
    list[#list + 1] = home .. "/.nix-profile/bin" -- Nix profile (nil LSP)
    list[#list + 1] = home .. "/go/bin"           -- Go утилиты
    list[#list + 1] = home .. "/.local/bin"       -- пользовательские CLI
  end
  list[#list + 1] = "/nix/var/nix/profiles/default/bin"
  list[#list + 1] = "/run/current-system/sw/bin"
  list[#list + 1] = "/usr/bin"
  list[#list + 1] = "/bin"
  list[#list + 1] = "/usr/sbin"
  list[#list + 1] = "/sbin"
  return list
end

-- Каталоги по порядку проверки. Несуществующие пропускаются (isdirectory).
M.dirs = build_dirs()

-- Что должно находиться, чтобы конфиг считался здоровым.
M.required = { "git", "curl", "tar" }
M.optional = { "cargo", "nil" }

--- Добавить недостающие каталоги в PATH.
--- Идемпотентно: повторный вызов ничего не меняет.
---@return string[] added список реально добавленных каталогов
function M.setup()
  local sep = vim.fn.has("win32") == 1 and ";" or ":"
  local path = vim.env.PATH or ""
  local have = {}
  for _, dir in ipairs(vim.split(path, sep, { plain = true })) do
    have[dir] = true
  end

  local added = {}
  for _, dir in ipairs(M.dirs) do
    if not have[dir] and vim.fn.isdirectory(dir) == 1 then
      have[dir] = true
      added[#added + 1] = dir
    end
  end

  if #added > 0 then
    -- В КОНЕЦ, не в начало: то, что ты настроил сам, важнее.
    vim.env.PATH = path == "" and table.concat(added, sep) or path .. sep .. table.concat(added, sep)
  end

  M.added = added

  -- git не найден даже после починки PATH: одно понятное сообщение вместо
  -- сотни «Failed to spawn process git» в :Lazy.
  M.git_missing = vim.fn.executable("git") ~= 1
  if M.git_missing then
    vim.schedule(function()
      vim.notify(
        "git не найден: lazy.nvim не сможет ставить и обновлять плагины.\n"
          .. "Установи: xcode-select --install   или   brew install git\n"
          .. "Потом перезапусти nvim и выполни :EnvCheck",
        vim.log.levels.ERROR,
        { title = "Нет git" }
      )
    end)
  end

  return added
end

--- Диагностика: :EnvCheck — покажет, что нашлось, а что нет.
function M.check()
  local lines = {}
  lines[#lines + 1] = "git: " .. (vim.fn.exepath("git") ~= "" and vim.fn.exepath("git") or "НЕ НАЙДЕН")
  for _, tool in ipairs(M.required) do
    if tool ~= "git" then
      local p = vim.fn.exepath(tool)
      lines[#lines + 1] = tool .. ": " .. (p ~= "" and p or "не найден")
    end
  end
  for _, tool in ipairs(M.optional) do
    local p = vim.fn.exepath(tool)
    lines[#lines + 1] = tool .. " (опц.): " .. (p ~= "" and p or "не установлен")
  end
  lines[#lines + 1] = " "
  lines[#lines + 1] = "PATH = " .. (vim.env.PATH or "(пусто)")
  if M.added and #M.added > 0 then
    lines[#lines + 1] = "добавлено конфигом: " .. table.concat(M.added, ", ")
  end

  -- avante: нативная библиотека для чата и подсказок (см. config/avante_build.lua)
  local okB, B = pcall(require, "config.avante_build")
  if okB then
    local dir = B.plugin_dir and B.plugin_dir() or (vim.fn.stdpath("data") .. "/lazy/avante.nvim")
    lines[#lines + 1] = " "
    if vim.fn.isdirectory(dir) == 0 then
      lines[#lines + 1] = "avante: плагин не установлен (:Lazy sync)"
    else
      lines[#lines + 1] = "avante " .. B.TAG .. ": " .. (B.is_built(dir) and "библиотека ЕСТЬ" or "библиотеки НЕТ, выполни :AvanteRebuild")
      lines[#lines + 1] = "  файл: " .. B.lib_file(dir)
      lines[#lines + 1] = "  подробная диагностика: :AvanteStatus"
    end
  end

  local text = table.concat(lines, "\n")
  vim.notify(text, vim.log.levels.INFO, { title = "Проверка окружения" })
  pcall(vim.api.nvim_echo, { { text, "None" } }, true, {})
end

return M
