-- ========================================================================== --
--   СБОРКА НАТИВНЫХ БИБЛИОТЕК avante.nvim (avante_templates, repo_map и др.) --
-- ========================================================================== --
-- СИМПТОМ:
--   * «Make sure to build avante (missing avante_templates)» в чате / ModeChanged / WinEnter
--   * «Failed to load avante_repo_map»
--   * на macOS (Darwin): «dlopen(.../avante_templates.so): Library not loaded:
--     /nix/store/...-libiconv-.../lib/libiconv.2.dylib (no such file)»
--
-- ПРИЧИНЫ:
--   1. build.sh из репозитория avante при отсутствии тегов тихо выходит с кодом 0;
--   2. запасной `make` требует cargo (Rust), которого без установки нет;
--   3. lazy.core.cache кэширует список файлов в `avante.nvim/lua/` на старте:
--      после фоновой распаковки `.so` без сброса кэша и `package.cpath`
--      вызов `require("avante_templates")` не видел только что скачанные файлы;
--   4. нужно проверять ВСЕ 4 нативные библиотеки релиза (`avante_templates`,
--      `avante_tokenizers`, `avante_repo_map`, `avante_html2md`), а не только одну;
--   5. апстрим avante-corp/avante.nvim собирает релизные `.so` для macOS внутри
--      `nix develop .#ci`, из-за чего в Mach-O зашивается путь вида
--      `/nix/store/<hash>-libiconv-115.100.1/lib/libiconv.2.dylib`. На обычном
--      Mac без этого Nix-пути `dlopen` падает, хотя системная
--      `/usr/lib/libiconv.2.dylib` всегда есть в macOS dyld shared cache.
--      Поэтому на Darwin мы автоматически переписываем отсутствующие пути
--      `/nix/store/...` на системные (`/usr/lib/...` / Homebrew) через
--      `install_name_tool` во временную копию (новый inode для Apple Silicon
--      UBC-кэша), переподписываем `codesign --force --sign -` и атомарно
--      заменяем `.so`.
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

-- Префиксы стандартных библиотек macOS, живущих в `/usr/lib/` (dyld shared cache;
-- начиная с macOS 11 Big Sur файлов на диске нет, но `dlopen("/usr/lib/...")` работает штатно).
M.MACOS_SYSTEM_DYLIB_PREFIXES = {
  "libiconv.",
  "libcharset.",
  "libSystem.",
  "libc++.",
  "libc++abi.",
  "libobjc.",
  "libz.",
  "libbz2.",
  "libcompression.",
  "libresolv.",
  "libcurl.",
  "libsqlite3.",
  "libxml2.",
  "liblzma.",
  "libedit.",
  "libncurses.",
  "libexpat.",
  "libffi.",
}

M.darwin_patched_count = 0

local OS_NAMES = { Darwin = "darwin", Linux = "linux" }
local ARCHES = { x86_64 = "x86_64", amd64 = "x86_64", arm64 = "aarch64", aarch64 = "aarch64" }

local function lib_ext()
  return vim.fn.has("win32") == 1 and "dll" or "so"
end

local function has(cmd)
  return vim.fn.executable(cmd) == 1
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

--- Подобрать системный / Homebrew путь на macOS взамен отсутствующего `/nix/store/...`.
---@param dep string путь из `otool -L`
---@param file_exists? fun(path: string): boolean
---@return string
function M.resolve_macos_dylib(dep, file_exists)
  local exists = file_exists or function(p)
    return vim.uv.fs_stat(p) ~= nil
  end
  local fw = dep:match("/Library/Frameworks/(.+)$")
  if fw then
    if exists("/Library/Frameworks/" .. fw) then
      return "/Library/Frameworks/" .. fw
    end
    return "/System/Library/Frameworks/" .. fw
  end

  local base = dep:match("([^/]+)$") or dep
  for _, prefix in ipairs(M.MACOS_SYSTEM_DYLIB_PREFIXES) do
    if base:sub(1, #prefix) == prefix then
      return "/usr/lib/" .. base
    end
  end

  local home = (vim.env and vim.env.HOME) or ""
  local candidates = {
    "/opt/homebrew/lib/" .. base,
    "/opt/homebrew/opt/openssl@3/lib/" .. base,
    "/opt/homebrew/opt/libiconv/lib/" .. base,
    "/usr/local/lib/" .. base,
    "/usr/local/opt/openssl@3/lib/" .. base,
    "/usr/local/opt/libiconv/lib/" .. base,
  }
  if home ~= "" then
    candidates[#candidates + 1] = home .. "/.nix-profile/lib/" .. base
  end
  candidates[#candidates + 1] = "/nix/var/nix/profiles/default/lib/" .. base

  for _, cand in ipairs(candidates) do
    if exists(cand) then
      return cand
    end
  end
  return "/usr/lib/" .. base
end

--- Разобрать вывод `otool -L <file.so>` и сформировать план патча для `install_name_tool`.
---@param otool_output string
---@param lib_name? string
---@param file_exists? fun(path: string): boolean
---@return { needs_patch: boolean, new_id: string|nil, changes: { old: string, new: string }[] }
function M.parse_otool_fixes(otool_output, lib_name, file_exists)
  local exists = file_exists or function(p)
    return vim.uv.fs_stat(p) ~= nil
  end
  local plan = {
    needs_patch = false,
    new_id = nil,
    changes = {},
  }
  local seen = {}
  for _, line in ipairs(vim.split(otool_output or "", "\n", { plain = true })) do
    if line:match("^%s+") then
      local dep = line:match("^%s+(.+)%s+%(compatibility version")
        or line:match("^%s+(%S+)")
      if dep and dep:sub(1, 11) == "/nix/store/" and not seen[dep] then
        seen[dep] = true
        local base = dep:match("([^/]+)$") or ""
        local is_self_id = base:match("^libavante_") ~= nil
          or (lib_name and base:find(lib_name, 1, true) ~= nil)
        if is_self_id then
          local short = lib_name or base:gsub("^lib", ""):gsub("%.dylib$", ""):gsub("%.so$", "")
          plan.new_id = "@rpath/" .. short .. ".so"
          plan.needs_patch = true
        elseif not exists(dep) then
          plan.changes[#plan.changes + 1] = {
            old = dep,
            new = M.resolve_macos_dylib(dep, exists),
          }
          plan.needs_patch = true
        end
      end
    end
  end
  return plan
end

--- Собрать команду `install_name_tool` по плану `parse_otool_fixes`.
function M.build_install_name_cmd(plan, target_file)
  local cmd = { "install_name_tool" }
  if plan.new_id then
    cmd[#cmd + 1] = "-id"
    cmd[#cmd + 1] = plan.new_id
  end
  for _, ch in ipairs(plan.changes or {}) do
    cmd[#cmd + 1] = "-change"
    cmd[#cmd + 1] = ch.old
    cmd[#cmd + 1] = ch.new
  end
  cmd[#cmd + 1] = target_file
  return cmd
end

local function copy_for_patch(src, dst)
  local uv = vim.uv or vim.loop
  if uv and type(uv.fs_copyfile) == "function" then
    local ok = pcall(uv.fs_copyfile, src, dst)
    if ok then
      if type(uv.fs_chmod) == "function" then
        pcall(uv.fs_chmod, dst, 493) -- 0755 (снимает read-only 0555 из Nix-архива)
      end
      return true
    end
  end
  local r = io.open(src, "rb")
  if not r then
    return false
  end
  local data = r:read("*a")
  r:close()
  local w = io.open(dst, "wb")
  if not w then
    return false
  end
  w:write(data)
  w:close()
  if uv and type(uv.fs_chmod) == "function" then
    pcall(uv.fs_chmod, dst, 493)
  end
  return true
end

local function atomic_replace(src, dst)
  local uv = vim.uv or vim.loop
  if uv and type(uv.fs_rename) == "function" then
    local ok, res = pcall(uv.fs_rename, src, dst)
    if ok and res ~= nil then
      return true
    end
  end
  local ok_os = os.rename(src, dst)
  return ok_os == true
end

local function unlink_quiet(path)
  local uv = vim.uv or vim.loop
  if uv and type(uv.fs_unlink) == "function" then
    pcall(uv.fs_unlink, path)
    return
  end
  os.remove(path)
end

--- Синхронно пропатчить Mach-O `.so` библиотеки на macOS (Nix `/nix/store/...` → `/usr/lib/...`
--- + `codesign --force --sign -` на новом inode). Безопасно вызывать в обычном контексте Neovim.
---@param dir string
---@return boolean patched_any, string detail
function M.repair_darwin_libs_sync(dir)
  local uname = vim.uv.os_uname()
  if not uname or uname.sysname ~= "Darwin" then
    return false, "не macOS"
  end
  if not has("otool") or not has("install_name_tool") then
    return false, "нет otool / install_name_tool (установите: xcode-select --install)"
  end
  if has("xattr") then
    pcall(vim.fn.system, { "xattr", "-dr", "com.apple.quarantine", dir .. "/lua" })
  end

  local patched = 0
  for _, lib in ipairs(M.LIBRARIES) do
    local file = M.lib_file(dir, lib.name)
    if vim.uv.fs_stat(file) ~= nil then
      local out = vim.fn.system({ "otool", "-L", file })
      local shell_err = (vim.v and vim.v.shell_error) or 0
      if shell_err == 0 and type(out) == "string" and out ~= "" then
        local plan = M.parse_otool_fixes(out, lib.name)
        if plan.needs_patch then
          local tmp = file .. ".patched"
          unlink_quiet(tmp)
          if not copy_for_patch(file, tmp) then
            return false, "не удалось создать копию для патча: " .. tmp
          end
          local patch_out = vim.fn.system(M.build_install_name_cmd(plan, tmp))
          if ((vim.v and vim.v.shell_error) or 0) ~= 0 then
            unlink_quiet(tmp)
            return false, "install_name_tool (" .. lib.name .. "): " .. vim.trim(tostring(patch_out or ""))
          end
          if has("codesign") then
            local cs_out = vim.fn.system({ "codesign", "--force", "--sign", "-", tmp })
            if ((vim.v and vim.v.shell_error) or 0) ~= 0 then
              unlink_quiet(tmp)
              return false, "codesign (" .. lib.name .. "): " .. vim.trim(tostring(cs_out or ""))
            end
          end
          if not atomic_replace(tmp, file) then
            unlink_quiet(tmp)
            return false, "не удалось атомарно обновить " .. file
          end
          patched = patched + 1
        end
      end
    end
  end

  if patched > 0 then
    M.darwin_patched_count = (M.darwin_patched_count or 0) + patched
    return true, ("пропатчено библиотек macOS Mach-O: %d"):format(patched)
  end
  return false, "патч Mach-O не требовался"
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

--- Полная runtime-готовность: обновляет cpath/loader, при необходимости чинит
--- Nix-пути в Mach-O на macOS и проверяет `require()` всех 4 библиотек.
---@param dir string
---@return boolean, string
function M.ensure_runtime(dir)
  M.refresh_loader(dir)
  local ok_files, reason = M.check_all_libs(dir)
  if not ok_files then
    local uname = vim.uv.os_uname()
    local why = tostring(reason or "")
    if uname and uname.sysname == "Darwin" and (
      why:find("/nix/store/", 1, true)
      or why:find("Library not loaded", 1, true)
      or why:find("code signature", 1, true)
    ) then
      local repaired = M.repair_darwin_libs_sync(dir)
      if repaired then
        M.refresh_loader(dir)
        ok_files, reason = M.check_all_libs(dir)
      end
    end
  end
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

local function tail(text, n)
  local lines = vim.split(vim.trim(text or ""), "\n", { plain = true })
  local from = math.max(1, #lines - (n or 6) + 1)
  return table.concat(vim.list_slice(lines, from), "\n")
end

--- Асинхронный патч Mach-O после распаковки архива на macOS.
local function repair_darwin_libs_async(dir, cb)
  local uname = vim.uv.os_uname()
  if not uname or uname.sysname ~= "Darwin" or not has("otool") or not has("install_name_tool") then
    return cb(0)
  end
  local patched = 0
  local function step(idx)
    local lib = M.LIBRARIES[idx]
    if not lib then
      if patched > 0 then
        M.darwin_patched_count = (M.darwin_patched_count or 0) + patched
      end
      return cb(patched)
    end
    local file = M.lib_file(dir, lib.name)
    if vim.uv.fs_stat(file) == nil then
      return step(idx + 1)
    end
    sys({ "otool", "-L", file }, { text = true }, function(ot)
      if ot.code ~= 0 then
        return step(idx + 1)
      end
      local plan = M.parse_otool_fixes(ot.stdout or "", lib.name)
      if not plan.needs_patch then
        return step(idx + 1)
      end
      local tmp = file .. ".patched"
      unlink_quiet(tmp)
      if not copy_for_patch(file, tmp) then
        return step(idx + 1)
      end
      sys(M.build_install_name_cmd(plan, tmp), { text = true }, function(ir)
        if ir.code ~= 0 then
          unlink_quiet(tmp)
          return step(idx + 1)
        end
        local function finalize_tmp()
          if atomic_replace(tmp, file) then
            patched = patched + 1
          else
            unlink_quiet(tmp)
          end
          step(idx + 1)
        end
        if has("codesign") then
          sys({ "codesign", "--force", "--sign", "-", tmp }, { text = true }, function(cs)
            if cs.code ~= 0 then
              unlink_quiet(tmp)
              return step(idx + 1)
            end
            finalize_tmp()
          end)
        else
          finalize_tmp()
        end
      end)
    end)
  end
  step(1)
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
    local function run_macho_patch()
      repair_darwin_libs_async(dir, function(patched)
        if patched > 0 then
          finish(true, label .. (" (адаптировано под macOS: %d .so)"):format(patched))
        else
          finish(true, label)
        end
      end)
    end
    if uname and uname.sysname == "Darwin" and has("xattr") then
      sys({ "xattr", "-dr", "com.apple.quarantine", dir .. "/lua" }, { text = true }, function()
        run_macho_patch()
      end)
      return true
    end
    if uname and uname.sysname == "Darwin" and has("otool") and has("install_name_tool") then
      run_macho_patch()
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
