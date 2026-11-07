-- ========================================================================== --
--   СБОРКА НАТИВНЫХ БИБЛИОТЕК avante.nvim (avante_templates, repo_map и др.) --
-- ========================================================================== --
-- СИМПТОМ:
--   * «Make sure to build avante (missing avante_templates)» в чате / ModeChanged / WinEnter
--   * «Failed to load avante_repo_map»
--
-- ПРИЧИНЫ:
--   1. build.sh из репозитория avante при отсутствии тегов тихо выходит с кодом 0;
--   2. запасной `make` требует cargo (Rust), которого без установки нет;
--   3. lazy.core.cache кэширует список файлов в `avante.nvim/lua/` на старте:
--      после фоновой распаковки `.so` без сброса кэша и `package.cpath`
--      вызов `require("avante_templates")` не видел только что скачанные файлы;
--   4. нужно проверять ВСЕ 4 нативные библиотеки релиза (`avante_templates`,
--      `avante_tokenizers`, `avante_repo_map`, `avante_html2md`), а не только одну.
--
-- Тег должен совпадать с `tag = ...` в lua/plugins/avante.lua (проверяет
-- tests/avante_build_test.py).
local M = {}

M.TAG = "v0.4.8"
M.COMMIT = "079d964ea88bff4953996ee26d31314df5dc757f"
M.REPO = "avante-corp/avante.nvim"

-- Главная библиотека: без неё нет шаблонов промптов (то, что ищет avante).
M.MAIN_LIB = "avante_templates"

-- Полный набор нативных библиотек avante v0.4.8 и их обязательные экспорты.
M.LIBRARIES = {
  { name = "avante_templates", exports = { "initialize", "render" } },
  { name = "avante_tokenizers", exports = { "from_pretrained", "encode" } },
  { name = "avante_repo_map", exports = { "stringify_definitions" } },
  { name = "avante_html2md", exports = { "fetch_md", "html2md" } },
}

local OS_NAMES = { Darwin = "darwin", Linux = "linux" }
local ARCHES = { x86_64 = "x86_64", amd64 = "x86_64", arm64 = "aarch64", aarch64 = "aarch64" }

local function lib_ext()
  return vim.fn.has("win32") == 1 and "dll" or "so"
end

--- Имя архива релиза для платформы или nil, если платформы нет в списке.
---@param os_name string  например "Darwin" (vim.uv.os_uname().sysname)
---@param machine string  например "arm64" (vim.uv.os_uname().machine)
---@return string|nil
function M.artifact(os_name, machine)
  local osn, arch = OS_NAMES[os_name], ARCHES[machine]
  if not osn or not arch then
    return nil
  end
  return ("avante_lib-%s-%s-luajit.tar.gz"):format(osn, arch)
end

--- Ссылка на архив в релизе закреплённого тега.
function M.url(artifact, tag)
  return ("https://github.com/%s/releases/download/%s/%s"):format(M.REPO, tag or M.TAG, artifact)
end

--- Каталог установленного плагина avante.nvim (учитывает кастомный root lazy.nvim).
function M.plugin_dir()
  local lazy = package.loaded["lazy.core.config"]
  local plugin = type(lazy) == "table" and (
    (lazy.plugins and lazy.plugins["avante.nvim"])
    or (lazy.spec and lazy.spec.disabled and lazy.spec.disabled["avante.nvim"])
  )
  if plugin and plugin.dir then
    return plugin.dir
  end
  local root = type(lazy) == "table" and lazy.options and lazy.options.root
  return (root or (vim.fn.stdpath("data") .. "/lazy")) .. "/avante.nvim"
end

--- Путь к библиотеке внутри каталога плагина (по умолчанию — главной).
function M.lib_file(dir, name)
  return dir .. "/lua/" .. (name or M.MAIN_LIB) .. "." .. lib_ext()
end

--- Собрана ли главная библиотека (быстрая проверка по файлу).
function M.is_built(dir)
  return vim.uv.fs_stat(M.lib_file(dir)) ~= nil
end

--- Обновить cpath и сбросить кэш модулей lazy.nvim / vim.loader для каталога плагина,
--- чтобы только что скачанные `.so` сразу находились через `require()` без перезапуска.
function M.refresh_loader(dir)
  local pattern = dir .. "/lua/?." .. lib_ext()
  local cpath = package.cpath or ""
  if not cpath:find(pattern, 1, true) then
    package.cpath = cpath == "" and pattern or (cpath .. ";" .. pattern)
  end

  local lazy_cache = package.loaded["lazy.core.cache"]
  if type(lazy_cache) == "table" and type(lazy_cache.reset) == "function" then
    pcall(lazy_cache.reset, dir)
  end
  if vim.loader and vim.loader ~= lazy_cache and type(vim.loader.reset) == "function" then
    pcall(vim.loader.reset, dir)
  end

  for _, lib in ipairs(M.LIBRARIES) do
    if package.loaded[lib.name] ~= nil and type(package.loaded[lib.name]) ~= "table" then
      package.loaded[lib.name] = nil
    end
  end
end

--- Проверить наличие, загрузку через dlopen (`package.loadlib`) и экспорты всех 4 библиотек.
---@param dir string
---@return boolean, string
function M.check_all_libs(dir)
  for _, lib in ipairs(M.LIBRARIES) do
    local file = M.lib_file(dir, lib.name)
    if vim.uv.fs_stat(file) == nil then
      return false, "отсутствует файл " .. file
    end
    local ok_call, loader, load_err = pcall(package.loadlib, file, "luaopen_" .. lib.name)
    if not ok_call or type(loader) ~= "function" then
      return false, "не удалось загрузить " .. lib.name .. ": " .. tostring(ok_call and load_err or loader)
    end
    local ok_init, mod = pcall(loader)
    if not ok_init or type(mod) ~= "table" then
      return false, "ошибка инициализации " .. lib.name .. ": " .. tostring(mod)
    end
    for _, fn_name in ipairs(lib.exports) do
      if type(mod[fn_name]) ~= "function" then
        return false, lib.name .. ": нет функции " .. fn_name .. " (несовместимая версия библиотеки)"
      end
    end
  end
  return true, "все 4 нативные библиотеки исправны"
end

--- Полная runtime-готовность: обновляет cpath/loader и проверяет `require()` всех 4 библиотек.
---@param dir string
---@return boolean, string
function M.ensure_runtime(dir)
  M.refresh_loader(dir)
  local ok_files, reason = M.check_all_libs(dir)
  if not ok_files then
    return false, reason
  end
  for _, lib in ipairs(M.LIBRARIES) do
    local ok_req, mod = pcall(require, lib.name)
    if not ok_req or type(mod) ~= "table" then
      package.loaded[lib.name] = nil
      return false, "require('" .. lib.name .. "'): " .. tostring(mod)
    end
    for _, fn_name in ipairs(lib.exports) do
      if type(mod[fn_name]) ~= "function" then
        return false, "require('" .. lib.name .. "'): нет функции " .. fn_name
      end
    end
  end
  return true, "все 4 библиотеки загружены через require()"
end

-- vim.system вызывает колбэк в fast-контексте, где нельзя звать vim.fn.*
-- (E5560). Поэтому любой колбэк переносим в главный цикл.
local function sys(cmd, opts, cb)
  local ok, result = pcall(vim.system, cmd, opts, function(r)
    vim.schedule(function() cb(r) end)
  end)
  if not ok then
    vim.schedule(function() cb({ code = -1, stderr = tostring(result), stdout = "" }) end)
  end
  return ok and result or nil
end

local function has(cmd)
  return vim.fn.executable(cmd) == 1
end

local function tail(text, n)
  local lines = vim.split(vim.trim(text or ""), "\n", { plain = true })
  local from = math.max(1, #lines - (n or 6) + 1)
  return table.concat(vim.list_slice(lines, from), "\n")
end

--- Получить локальный git HEAD плагина (асинхронно, без сети).
function M.revision_async(dir, cb)
  if not has("git") then
    return vim.schedule(function() cb(nil, "git не найден в PATH") end)
  end
  sys({ "git", "-C", dir, "rev-parse", "HEAD" }, { text = true }, function(r)
    if r.code ~= 0 then
      return cb(nil, vim.trim(r.stderr or "не удалось прочитать git HEAD"))
    end
    local rev = vim.trim(r.stdout or "")
    cb(rev ~= "" and rev or nil, rev == "" and "пустой git HEAD" or nil)
  end)
end

--- Асинхронная сборка. on_done(ok:boolean, msg:string) вызывается один раз.
---@param dir string каталог плагина avante.nvim
---@param on_done fun(ok: boolean, msg: string)
---@param force? boolean|{force?: boolean, source?: boolean}
function M.build(dir, on_done, force)
  local force_rebuild = force == true or (type(force) == "table" and force.force == true)
  local source_only = type(force) == "table" and force.source == true

  local function finish(ok, msg)
    if ok then
      M.refresh_loader(dir)
    end
    vim.schedule(function()
      on_done(ok, msg)
    end)
  end

  if not force_rebuild and M.is_built(dir) then
    return finish(true, "библиотеки уже на месте")
  end

  vim.fn.mkdir(dir .. "/lua", "p")

  local function after_extract(label)
    if not M.is_built(dir) then
      return false
    end
    local uname = vim.uv.os_uname()
    if uname and uname.sysname == "Darwin" and has("xattr") then
      sys({ "xattr", "-dr", "com.apple.quarantine", dir .. "/lua" }, { text = true }, function()
        finish(true, label)
      end)
      return true
    end
    finish(true, label)
    return true
  end

  local function try_make(prev_reason)
    if not has("make") or not has("cargo") then
      return finish(
        false,
        prev_reason
          .. "\nЗапасной вариант — сборка из исходников — нужен Rust: brew install rust"
          .. "\nПотом в nvim: :AvanteRebuild"
      )
    end
    sys({ "make" }, { cwd = dir, text = true }, function(r)
      if r.code == 0 and M.is_built(dir) then
        after_extract("собрано из исходников (make)")
      else
        finish(false, "make не собрал библиотеку (код " .. tostring(r.code) .. "):\n" .. tail(r.stderr, 8))
      end
    end)
  end

  if source_only then
    return try_make("Запрошена сборка из исходников.")
  end

  local uname = vim.uv.os_uname()
  local artifact = uname and M.artifact(uname.sysname, uname.machine) or nil
  if not artifact then
    return try_make("Готовой сборки для этой платформы нет.")
  end
  if not has("curl") or not has("tar") then
    return try_make("Для готовой сборки нужны curl и tar (есть в macOS/Linux).")
  end

  local url = M.url(artifact, M.TAG)
  local tmp = vim.fn.tempname() .. ".tar.gz"
  sys({ "curl", "-fsSL", "-o", tmp, url }, { text = true }, function(dl)
    if dl.code ~= 0 then
      vim.fn.delete(tmp)
      return try_make("Готовая сборка " .. M.TAG .. " не скачалась (curl " .. tostring(dl.code) .. "): " .. url)
    end
    sys({ "tar", "-xzf", tmp, "-C", dir .. "/lua" }, { text = true }, function(ex)
      vim.fn.delete(tmp)
      if ex.code ~= 0 then
        return try_make("Архив не распаковался (tar " .. tostring(ex.code) .. "): " .. tail(ex.stderr, 3))
      end
      if after_extract("готовая сборка " .. M.TAG .. " установлена") then
        return
      end
      -- архив распаковался, но главной библиотеки в нём нет — пробуем make
      try_make("В архиве " .. M.TAG .. " нет " .. M.MAIN_LIB .. " (" .. artifact .. ").")
    end)
  end)
end

--- Синхронная обёртка для хука build в lazy.nvim. Возвращает ok, msg.
function M.build_blocking(dir, timeout_ms)
  local done, ok, msg = false, false, ""
  M.build(dir, function(o, m)
    ok, msg, done = o, m, true
  end, true)
  vim.wait(timeout_ms or 900000, function()
    return done
  end, 200)
  if not done then
    return false, "сборка не уложилась во время ожидания"
  end
  return ok, msg
end

return M
