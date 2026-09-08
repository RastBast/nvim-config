-- ========================================================================== --
--   ПОЧИНКА PATH: чтобы nvim видел git и mason-бинари                        --
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
-- launchd даёт PATH=/usr/bin:/bin:/usr/sbin:/sbin), а git стоит в Homebrew
-- (/opt/homebrew/bin) и Xcode Command Line Tools не установлены — тогда
-- /usr/bin/git просто нет. В терминале при этом git работает: fish добавляет
-- /opt/homebrew/bin в свой PATH, но GUI-процессу его не передаёт.
--
-- ЛЕЧЕНИЕ: дописываем недостающие стандартные каталоги в конец PATH
-- (твой PATH остаётся приоритетнее). Подключается ПЕРВЫМ в init.lua —
-- до установки lazy.nvim, потому что bootstrap тоже зовёт git.

local M = {}

-- Каталоги по порядку проверки. Несуществующие пропускаются (isdirectory).
M.dirs = {
  "/opt/homebrew/bin",  -- Homebrew, Apple Silicon (M1/M2/M3/M4)
  "/opt/homebrew/sbin",
  "/usr/local/bin",     -- Homebrew на Intel и ручной install
  "/usr/local/sbin",
  vim.fn.stdpath("data") .. "/mason/bin", -- LSP/DAP/format, поставленные mason
  "/usr/bin",
  "/bin",
  "/usr/sbin",
  "/sbin",
}

-- Что должно находиться, чтобы конфиг считался здоровым.
M.required = { "git", "curl", "tar" }

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
  lines[#lines + 1] = " "
  lines[#lines + 1] = "PATH = " .. (vim.env.PATH or "(пусто)")
  if M.added and #M.added > 0 then
    lines[#lines + 1] = "добавлено конфигом: " .. table.concat(M.added, ", ")
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Проверка окружения" })
end

return M
