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
local home = vim.env.HOME or vim.fn.expand("~")
local state_home = vim.env.XDG_STATE_HOME
if not state_home or state_home == "" then state_home = home .. "/.local/state" end
M.dirs = {
  "/opt/homebrew/bin",  -- Homebrew, Apple Silicon (M1/M2/M3/M4)
  "/opt/homebrew/sbin",
  "/usr/local/bin",     -- Homebrew на Intel и ручной install
  "/usr/local/sbin",
  state_home .. "/nix/profile/bin", -- современный nix profile
  home .. "/.nix-profile/bin",     -- прежний пользовательский профиль Nix
  "/nix/var/nix/profiles/default/bin",
  home .. "/.cargo/bin",           -- Rust/cargo при запуске nvim из GUI
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
  for _, tool in ipairs({ "nil", "nix", "cargo" }) do
    local p = vim.fn.exepath(tool)
    lines[#lines + 1] = tool .. ": " .. (p ~= "" and p or "не найден")
  end
  lines[#lines + 1] = "Nix LSP (nil_ls): устанавливается отдельно; подробности — DOCS.md §18."
  lines[#lines + 1] = " "
  lines[#lines + 1] = "PATH = " .. (vim.env.PATH or "(пусто)")
  if M.added and #M.added > 0 then
    lines[#lines + 1] = "добавлено конфигом: " .. table.concat(M.added, ", ")
  end

  -- avante: нативная библиотека для чата и подсказок (см. config/avante_build.lua)
  local okB, B = pcall(require, "config.avante_build")
  if okB then
    local dir = B.plugin_dir()
    lines[#lines + 1] = " "
    if vim.fn.has("nvim-0.12") ~= 1 then
      lines[#lines + 1] = "avante: нужен Neovim 0.12+; плагин отключён до обновления"
    end
    if vim.fn.isdirectory(dir) == 0 then
      lines[#lines + 1] = "avante: плагин не установлен (:Lazy sync)"
    else
      local revision, rev_err = B.revision(dir)
      local ok, reason = B.check(dir)
      lines[#lines + 1] = "avante " .. B.TAG .. ": " .. (ok and "библиотеки загружаются" or "библиотеки не готовы — :AvanteRebuild")
      lines[#lines + 1] = "  файл: " .. B.lib_file(dir)
      if not ok then lines[#lines + 1] = "  причина: " .. reason end
      if revision and revision ~= B.COMMIT then
        lines[#lines + 1] = "  " .. B.revision_error(revision)
      elseif not revision then
        lines[#lines + 1] = "  " .. tostring(rev_err)
      end
    end
  end

  -- INFO/WARN от vim.notify в этом конфиге фильтруются: диагностику команды
  -- показываем через echo, иначе пользователь ничего не увидит.
  vim.api.nvim_echo({ { "Проверка окружения\n" .. table.concat(lines, "\n"), "None" } }, true, {})
end

return M
