-- ========================================================================== --
--   ПОЧИНКА PATH + СНЯТИЕ ЗАВИСШИХ GIT-БЛОКИРОВОК ПЛАГИНОВ LAZY.NVIM         --
-- ========================================================================== --
-- СИМПТОМЫ:
--   1. в :Lazy на каждом плагине:
--      «Failed to spawn process git { args = { "fetch", … } }»
--   2. в :Lazy при обновлении отдельных плагинов (nvim-lspconfig, nvim-treesitter):
--      «fatal: Unable to create '.../.local/share/nvim/lazy/<plug>/.git/index.lock': File exists»
--
-- ПРИЧИНЫ:
--   1. lazy.nvim запускает git без shell — uv.spawn("git", …), окружение берётся
--      из nvim как есть. На macOS из GUI PATH урезан до /usr/bin:/bin.
--   2. При прерванном `:Lazy sync` / закрытии терминала на середине git-операции
--      в каталоге плагина остаётся осиротевший `.git/index.lock` (или `HEAD.lock` /
--      `shallow.lock`), после чего git навсегда отказывается обновлять этот плагин.
--
-- ЛЕЧЕНИЕ:
--   1. `M.setup()` дописывает недостающие стандартные каталоги в конец PATH.
--   2. `M.clean_lazy_git_locks()` перед `require("lazy").setup(...)` за < 1 мс
--      проверяет наличие `.git/*.lock` у плагинов lazy.nvim и безопасно удаляет
--      осиротевшие блокировки (не трогая каталоги, где прямо сейчас работает
--      живой процесс `git`). Вручную доступно через `:LazyUnlock` (`<leader>AX`).

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

-- Стандартные lock-файлы Git внутри `<plugin>/.git/`.
M.GIT_LOCK_RELPATHS = {
  ".git/index.lock",
  ".git/HEAD.lock",
  ".git/shallow.lock",
  ".git/config.lock",
  ".git/packed-refs.lock",
  ".git/FETCH_HEAD.lock",
}

M.cleaned_git_locks = {}
M.skipped_git_locks = {}

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

--- Найти все существующие `.git/*.lock` внутри каталога плагинов lazy.nvim.
---@param lazy_root? string
---@return { plugin: string, dir: string, path: string, rel: string, mtime: integer }[]
function M.find_lazy_git_locks(lazy_root)
  local root = lazy_root or (vim.fn.stdpath("data") .. "/lazy")
  local uv = vim.uv or vim.loop
  if vim.fn.isdirectory(root) ~= 1 or not uv or type(uv.fs_scandir) ~= "function" or type(uv.fs_scandir_next) ~= "function" then
    return {}
  end

  local handle = uv.fs_scandir(root)
  if not handle then
    return {}
  end

  local found = {}
  while true do
    local name, ftype = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    local plug_dir = root .. "/" .. name
    if ftype == "directory" or (ftype == nil and vim.fn.isdirectory(plug_dir) == 1) then
      for _, rel in ipairs(M.GIT_LOCK_RELPATHS) do
        local lock_path = plug_dir .. "/" .. rel
        local st = type(uv.fs_stat) == "function" and uv.fs_stat(lock_path) or nil
        if st ~= nil then
          local mtime = type(st.mtime) == "table" and tonumber(st.mtime.sec) or tonumber(st.mtime) or 0
          found[#found + 1] = {
            plugin = name,
            dir = plug_dir,
            path = lock_path,
            rel = rel,
            mtime = mtime or 0,
          }
        end
      end
    end
  end
  return found
end

--- Определить, запущен ли сейчас живой процесс `git` и в каких каталогах `lazy_root` он работает.
---@param lazy_root string
---@return boolean any_git_running, boolean has_lsof, table<string, boolean> busy_dirs
local function inspect_live_git(lazy_root)
  local has_lsof = vim.fn.executable("lsof") == 1
  if vim.fn.executable("ps") ~= 1 then
    return false, has_lsof, {}
  end
  local ps_out = vim.fn.system({ "ps", "-axo", "comm=,args=" })
  if type(ps_out) ~= "string" or ps_out == "" then
    return false, has_lsof, {}
  end
  local any_git = false
  local busy = {}
  local esc_root = lazy_root ~= "" and lazy_root:gsub("([^%w])", "%%%1") or nil
  for _, line in ipairs(vim.split(ps_out, "\n", { plain = true })) do
    local trimmed = vim.trim(line)
    if trimmed ~= "" then
      local comm, args = trimmed:match("^(%S+)%s*(.*)$")
      local bin = comm and comm:match("([^/]+)$") or ""
      if bin == "git" or bin:match("^git%-") ~= nil then
        any_git = true
        if esc_root and args and args ~= "" then
          for plug in args:gmatch(esc_root .. "/([^/%s\"']+)") do
            busy[lazy_root .. "/" .. plug] = true
          end
        end
      end
    end
  end

  -- lazy.nvim запускает `git` с `cwd = <plugin_dir>` без пути в argv:
  -- проверяем открытые рабочие каталоги процессов `git` через `lsof`.
  if any_git and has_lsof then
    local lsof_out = vim.fn.system({ "lsof", "-a", "-c", "git", "-d", "cwd", "-Fn" })
    if type(lsof_out) == "string" and lsof_out ~= "" then
      for _, line in ipairs(vim.split(lsof_out, "\n", { plain = true })) do
        local cwd = line:match("^n(.+)$")
        if cwd and cwd:find(lazy_root, 1, true) == 1 then
          local rest = cwd:sub(#lazy_root + 2)
          local plug = rest:match("^([^/]+)")
          if plug then
            busy[lazy_root .. "/" .. plug] = true
          end
        end
      end
    end
  end

  return any_git, has_lsof, busy
end

local function remove_lock_file(path)
  local uv = vim.uv or vim.loop
  if uv and type(uv.fs_unlink) == "function" then
    local ok, res = pcall(uv.fs_unlink, path)
    if ok and res ~= nil then
      return true
    end
  end
  local ok_del, rc = pcall(vim.fn.delete, path)
  if ok_del and rc == 0 then
    return true
  end
  local ok_os = os.remove(path)
  return ok_os == true
end

--- Безопасно очистить осиротевшие `.git/*.lock` у плагинов lazy.nvim.
--- Быстрый путь (99.9% запусков, когда lock-файлов нет): < 0.5 мс и 0 подпроцессов.
---@param opts? { lazy_root?: string, force?: boolean, max_age_sec?: integer, now?: integer, quiet?: boolean }
---@return string[] cleaned_paths, string[] skipped_paths
function M.clean_lazy_git_locks(opts)
  opts = opts or {}
  local root = opts.lazy_root or (vim.fn.stdpath("data") .. "/lazy")
  local found = M.find_lazy_git_locks(root)
  if #found == 0 then
    return {}, {}
  end

  local force = opts.force == true
  local max_age = tonumber(opts.max_age_sec) or 300 -- соответствует git.timeout = 300 в lazy.nvim
  local now = tonumber(opts.now) or os.time()

  local any_git, has_lsof, busy = false, false, {}
  if not force then
    any_git, has_lsof, busy = inspect_live_git(root)
  end

  local cleaned, skipped, plugins_seen = {}, {}, {}
  local plugin_names = {}
  for _, item in ipairs(found) do
    local is_old = item.mtime > 0 and (now - item.mtime) >= max_age
    local is_busy = busy[item.dir] == true
    -- Если lsof недоступен, а где-то в системе бежит git, без флага force удаляем только старые (>= max_age) блокировки.
    local uncertain_young = (not force) and any_git and (not has_lsof) and (not is_old)
    local can_clean = force or is_old or ((not is_busy) and (not uncertain_young))

    if can_clean and remove_lock_file(item.path) then
      cleaned[#cleaned + 1] = item.path
      M.cleaned_git_locks[#M.cleaned_git_locks + 1] = item.path
      if not plugins_seen[item.plugin] then
        plugins_seen[item.plugin] = true
        plugin_names[#plugin_names + 1] = item.plugin
      end
    else
      skipped[#skipped + 1] = item.path
    end
  end
  M.skipped_git_locks = skipped

  if #cleaned > 0 and not opts.quiet then
    local msg = ("🔧 Lazy: удалены зависшие git-блокировки (%d): %s"):format(
      #cleaned,
      table.concat(plugin_names, ", ")
    )
    vim.schedule(function()
      pcall(vim.api.nvim_echo, { { msg, "MoreMsg" } }, true, {})
    end)
  end

  return cleaned, skipped
end

--- Команда `:LazyUnlock[!]`: очистить зависшие `.git/*.lock` в плагинах Lazy и показать отчёт.
function M.unlock_command(force)
  local cleaned, skipped = M.clean_lazy_git_locks({ force = force == true, quiet = true })
  local lines = {}
  if #cleaned > 0 then
    lines[#lines + 1] = ("✅ Удалено git-блокировок Lazy: %d"):format(#cleaned)
    for _, p in ipairs(cleaned) do
      lines[#lines + 1] = "  - " .. p
    end
    lines[#lines + 1] = "Теперь можно выполнить :Lazy sync (<leader>AL)."
  elseif #skipped > 0 then
    lines[#lines + 1] = ("⏳ Найдены активные git-блокировки (%d), пропуск (для принудительного снятия: :LazyUnlock!):"):format(#skipped)
    for _, p in ipairs(skipped) do
      lines[#lines + 1] = "  - " .. p
    end
  else
    lines[#lines + 1] = "✅ Зависших .git/*.lock в плагинах Lazy не обнаружено."
  end
  local text = table.concat(lines, "\n")
  vim.notify(text, vim.log.levels.INFO, { title = "LazyUnlock" })
  pcall(vim.api.nvim_echo, { { text, #cleaned > 0 and "MoreMsg" or "None" } }, true, {})
  return cleaned, skipped
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

  local active_locks = M.find_lazy_git_locks()
  if #active_locks > 0 then
    lines[#lines + 1] = ("lazy git-locks: ОБНАРУЖЕНО %d (выполни :LazyUnlock)"):format(#active_locks)
  elseif M.cleaned_git_locks and #M.cleaned_git_locks > 0 then
    lines[#lines + 1] = ("lazy git-locks: чисто (автоочищено на старте: %d)"):format(#M.cleaned_git_locks)
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
