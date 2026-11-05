-- Сборка нативных библиотек avante.nvim для закреплённой версии.
-- Файл .so сам по себе не гарантирует, что require() сможет его загрузить:
-- он может быть повреждён, собран под другую архитектуру или версию Lua.
local M = {}

M.TAG = "v0.4.8"
-- Коммит тега: нельзя устанавливать бинарники релиза поверх другого checkout.
M.COMMIT = "079d964ea88bff4953996ee26d31314df5dc757f"
M.REPO = "avante-corp/avante.nvim"
M.MAIN_LIB = "avante_templates"

-- Экспортируемые функции проверены по исходникам закреплённого тега.
local LIBRARIES = {
  { name = "avante_templates", exports = { "initialize", "render" } },
  { name = "avante_tokenizers", exports = { "from_pretrained", "encode" } },
  { name = "avante_repo_map", exports = { "stringify_definitions" } },
  { name = "avante_html2md", exports = { "fetch_md", "html2md" } },
}
local OS_NAMES = { Darwin = "darwin", Linux = "linux" }
local ARCHES = { x86_64 = "x86_64", amd64 = "x86_64", arm64 = "aarch64", aarch64 = "aarch64" }
local running = {}

function M.artifact(os_name, machine)
  local osn, arch = OS_NAMES[os_name], ARCHES[machine]
  if not osn or not arch then return nil end
  return ("avante_lib-%s-%s-luajit.tar.gz"):format(osn, arch)
end

function M.url(artifact, tag)
  return ("https://github.com/%s/releases/download/%s/%s"):format(M.REPO, tag or M.TAG, artifact)
end

local function lib_name(name)
  local ext = vim.fn.has("win32") == 1 and "dll" or "so"
  return name .. "." .. ext
end

function M.lib_file(dir, name)
  return dir .. "/lua/" .. lib_name(name or M.MAIN_LIB)
end

-- Учитываем нестандартный root lazy.nvim, если он уже загружен.
function M.plugin_dir()
  local lazy = package.loaded["lazy.core.config"]
  local plugin = type(lazy) == "table" and lazy.plugins and lazy.plugins["avante.nvim"]
  return plugin and plugin.dir or (vim.fn.stdpath("data") .. "/lazy/avante.nvim")
end

local function check_libs(lua_dir)
  for _, lib in ipairs(LIBRARIES) do
    local file = lua_dir .. "/" .. lib_name(lib.name)
    local stat = vim.uv.fs_stat(file)
    if not stat or (stat.type and stat.type ~= "file") then
      return false, "нет файла " .. file
    end
    -- Именно этот файл, а не случайный одноимённый модуль из package.path.
    local called, loader, load_err = pcall(package.loadlib, file, "luaopen_" .. lib.name)
    if not called or type(loader) ~= "function" then
      return false, "не удалось загрузить " .. file .. ": " .. tostring(called and load_err or loader)
    end
    local loaded, module = pcall(loader)
    if not loaded or type(module) ~= "table" then
      return false, "ошибка инициализации " .. file .. ": " .. tostring(module)
    end
    for _, name in ipairs(lib.exports) do
      if type(module[name]) ~= "function" then
        return false, file .. ": нет функции " .. name .. " (несовместимая библиотека)"
      end
    end
  end
  return true, "все библиотеки загружаются"
end

--- Проверка файлов, динамического загрузчика и интерфейса библиотек.
---@return boolean, string
function M.check(dir)
  return check_libs(dir .. "/lua")
end

function M.is_built(dir)
  local ok = M.check(dir)
  return ok
end

--- Проверяем также обычный require, который использует сам avante.path.
--- Вызывать после добавления плагина в runtimepath lazy.nvim.
function M.runtime_check(dir)
  local ok, reason = M.check(dir)
  if not ok then return false, reason end
  -- При первом неуспешном require vim.loader / lazy.nvim могли запомнить,
  -- что модуля в этом runtimepath нет. После фоновой установки обновляем
  -- индекс только каталога плагина, не выгружая уже открытые библиотеки.
  local lazy_cache = package.loaded["lazy.core.cache"]
  if type(lazy_cache) == "table" and type(lazy_cache.reset) == "function" then
    pcall(lazy_cache.reset, dir)
  end
  if vim.loader and vim.loader ~= lazy_cache and type(vim.loader.reset) == "function" then
    pcall(vim.loader.reset, dir)
  end
  local loaded, module = pcall(require, M.MAIN_LIB)
  if not loaded then return false, "require('avante_templates'): " .. tostring(module) end
  if type(module) ~= "table" or type(module.initialize) ~= "function" or type(module.render) ~= "function" then
    return false, "require('avante_templates') вернул несовместимый модуль"
  end
  return true, "avante_templates доступен через require"
end

local function has(cmd)
  return vim.fn.executable(cmd) == 1
end

-- Никакой сети: проверка локального HEAD занимает обычно несколько миллисекунд.
function M.revision(dir)
  if not has("git") then return nil, "git не найден в PATH; проверь :EnvCheck" end
  local started, process = pcall(vim.system, { "git", "-C", dir, "rev-parse", "HEAD" }, { text = true })
  if not started then return nil, "не удалось запустить git: " .. tostring(process) end
  local waited, result = pcall(function() return process:wait(5000) end)
  if not waited or not result or result.code ~= 0 then
    local detail = waited and result and vim.trim(result.stderr or "") or tostring(result)
    return nil, "не удалось определить версию checkout avante: " .. detail .. "\nВыполни :Lazy update avante.nvim"
  end
  local revision = vim.trim(result.stdout or "")
  if revision == "" then return nil, "git не вернул HEAD; выполни :Lazy update avante.nvim" end
  return revision
end

function M.revision_error(revision)
  return "Установленный код avante (" .. revision:sub(1, 12) .. ") не совпадает с " .. M.TAG
    .. ".\nВыполни :Lazy update avante.nvim и перезапусти Neovim; затем при необходимости :AvanteRebuild."
end

-- vim.system вызывает колбэк в fast-контексте: все обращения к vim.fn и
-- уведомления переносим в главный цикл. Ошибка запуска тоже идёт в колбэк.
local function sys(cmd, opts, cb)
  local ok, result = pcall(vim.system, cmd, opts, function(r)
    vim.schedule(function() cb(r) end)
  end)
  if not ok then
    vim.schedule(function() cb({ code = -1, stderr = tostring(result), stdout = "" }) end)
  end
end

local function tail(text, n)
  local lines = vim.split(vim.trim(text or ""), "\n", { plain = true })
  local from = math.max(1, #lines - (n or 6) + 1)
  return table.concat(vim.list_slice(lines, from), "\n")
end

local function stage_dir(dir)
  -- Полный tempname уникален между процессами; хеш укладывается в имя файла.
  local suffix = vim.fn.sha256(vim.fn.tempname()):sub(1, 20)
  local path = dir .. "/lua/.avante-build-" .. suffix
  local ok, result = pcall(vim.fn.mkdir, path, "p", 448) -- 0700, та же ФС для атомарного rename
  if not ok or result == 0 then return nil, "не удалось создать " .. path .. ": " .. tostring(result) end
  return path
end

local function signature(path)
  local s = vim.uv.fs_stat(path)
  if not s then return nil end
  local m, c = s.mtime or {}, s.ctime or {}
  return table.concat({ tostring(s.ino), tostring(s.size), tostring(m.sec), tostring(m.nsec), tostring(c.sec), tostring(c.nsec) }, ":")
end

-- После make проверяем свежие копии под уникальным путём: package.loadlib и
-- ОС могут вернуть кэшированный старый .so для исходного имени файла.
local function check_fresh_source(dir)
  local stage, err = stage_dir(dir)
  if not stage then return false, err end
  for _, lib in ipairs(LIBRARIES) do
    local name = lib_name(lib.name)
    local copied, err = vim.uv.fs_copyfile(dir .. "/lua/" .. name, stage .. "/" .. name)
    if not copied then
      vim.fn.delete(stage, "rf")
      return false, "не удалось проверить " .. name .. ": " .. tostring(err)
    end
  end
  local ok, reason = check_libs(stage)
  vim.fn.delete(stage, "rf")
  return ok, reason
end

--- Асинхронная сборка. Повторные вызовы для того же каталога присоединяются
--- к текущей сборке, чтобы загрузка, make и ручной :AvanteRebuild не гонялись.
---@param dir string каталог avante.nvim
---@param on_done fun(ok: boolean, msg: string)
---@param opts? {force?: boolean}
function M.build(dir, on_done, opts)
  if running[dir] then
    table.insert(running[dir], on_done)
    return
  end
  running[dir] = { on_done }
  local finished = false
  local function finish(ok, msg)
    if finished then return end
    finished = true
    local callbacks = running[dir]
    running[dir] = nil
    for _, callback in ipairs(callbacks) do
      vim.schedule(function() callback(ok, msg) end)
    end
  end

  local revision, rev_err = M.revision(dir)
  if not revision then return finish(false, rev_err) end
  if revision ~= M.COMMIT then return finish(false, M.revision_error(revision)) end

  if not (opts and opts.force) then
    local ok = M.check(dir)
    if ok then return finish(true, "библиотеки уже исправны") end
  end

  local made, mkdir_result = pcall(vim.fn.mkdir, dir .. "/lua", "p")
  if not made or mkdir_result == 0 then
    return finish(false, "Не удалось создать каталог " .. dir .. "/lua: " .. tostring(mkdir_result))
  end

  local function try_make(prev_reason)
    if not has("make") or not has("cargo") then
      return finish(false, prev_reason
        .. "\nДля сборки из исходников нужны make и Rust/cargo (на macOS: brew install rust)."
        .. "\nПосле исправления выполни :AvanteRebuild.")
    end
    local before = {}
    for _, lib in ipairs(LIBRARIES) do
      local name = lib_name(lib.name)
      before[name] = signature(dir .. "/lua/" .. name)
    end
    sys({ "make" }, { cwd = dir, text = true, timeout = 900000 }, function(r)
      local ok, reason = false, "make завершился с ошибкой"
      if r.code == 0 then
        local changed = true
        for _, lib in ipairs(LIBRARIES) do
          local name = lib_name(lib.name)
          local after = signature(dir .. "/lua/" .. name)
          if not after or (before[name] and before[name] == after) then
            changed, reason = false, "make не обновил " .. name
            break
          end
        end
        if changed then ok, reason = check_fresh_source(dir) end
      end
      if ok then
        finish(true, "библиотеки собраны из исходников (make)")
      else
        local output = tail((r.stderr and r.stderr ~= "") and r.stderr or r.stdout, 8)
        finish(false, prev_reason .. "\nmake не собрал рабочие библиотеки (код " .. tostring(r.code)
          .. "): " .. output .. "\n" .. reason)
      end
    end)
  end

  local uname = vim.uv.os_uname()
  local artifact = M.artifact(uname.sysname, uname.machine)
  if not artifact then return try_make("Готовой сборки для этой платформы нет.") end
  if not has("curl") or not has("tar") then
    return try_make("Для готовой сборки нужны curl и tar.")
  end

  -- Временный каталог на том же ФС, что и библиотеки. Распаковываем и
  -- проверяем весь архив там, затем заменяем файлы через rename: нельзя
  -- распаковывать поверх уже загруженного .so (возможен SIGBUS/краш).
  local stage, stage_err = stage_dir(dir)
  if not stage then return finish(false, stage_err) end
  local tmp = stage .. "/libraries.tar.gz"
  local function cleanup() vim.fn.delete(stage, "rf") end
  local url = M.url(artifact, M.TAG)
  sys({ "curl", "-fsSL", "--connect-timeout", "20", "--max-time", "180", "-o", tmp, url }, { text = true }, function(dl)
    if dl.code ~= 0 then
      cleanup()
      return try_make("Готовая сборка " .. M.TAG .. " не скачалась (curl " .. tostring(dl.code) .. "): "
        .. tail(dl.stderr, 3) .. "\n" .. url)
    end
    sys({ "tar", "-xzf", tmp, "-C", stage }, { text = true }, function(ex)
      if ex.code ~= 0 then
        cleanup()
        return try_make("Архив не распаковался (tar " .. tostring(ex.code) .. "): " .. tail(ex.stderr, 3))
      end
      local ok, reason = check_libs(stage)
      if not ok then
        cleanup()
        return try_make("Архив " .. M.TAG .. " не содержит рабочих библиотек: " .. reason)
      end
      for _, lib in ipairs(LIBRARIES) do
        local name = lib_name(lib.name)
        local renamed, err = vim.uv.fs_rename(stage .. "/" .. name, dir .. "/lua/" .. name)
        if not renamed then
          cleanup()
          return finish(false, "Не удалось установить " .. name .. ": " .. tostring(err)
            .. "\nПроверь права на каталог " .. dir .. "/lua и повтори :AvanteRebuild.")
        end
      end
      cleanup()
      finish(true, "готовая сборка " .. M.TAG .. " установлена")
    end)
  end)
end

--- Синхронная обёртка только для build-хука lazy.nvim.
function M.build_blocking(dir, timeout_ms)
  local done, ok, msg = false, false, ""
  M.build(dir, function(o, m) ok, msg, done = o, m, true end, { force = true })
  -- curl может ждать 180 с, затем make — до 900 с.
  vim.wait(timeout_ms or 1100000, function() return done end, 200)
  if not done then return false, "сборка не уложилась во время ожидания" end
  return ok, msg
end

return M
