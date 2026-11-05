-- ========================================================================== --
--   СБОРКА НАТИВНЫХ БИБЛИОТЕК avante.nvim (avante_templates и др.)           --
-- ========================================================================== --
-- СИМПТОМ: «Make sure to build avante (missing avante_templates)» в чате,
-- inline-подсказках и :AvanteAsk. Значит, .so-библиотеки в lua/ нет.
--
-- ПОЧЕМУ БЫЛО ПЛОХО:
--   * build.sh из репозитория avante при отсутствии git тихо печатает
--     «No latest tag» и выходит с кодом 0 — сборка «успешна», а файла нет;
--   * запасной `make` требует cargo (Rust), которого на Mac обычно нет,
--     и ошибка терялась в выводе;
--   * Lua-код плагина брался с main, а готовые бинарники — от тега v0.4.8.
--
-- ЧТО ДЕЛАЕТ ЭТОТ МОДУЛЬ:
--   1. Скачивает готовую библиотеку ИМЕННО для закреплённого тега (curl+tar,
--      без git и без cargo).
--   2. Если не вышло и есть cargo — собирает `make`.
--   3. Не верит коду возврата: успех только когда файл lua/avante_templates.so
--      появился на диске. Иначе — одно понятное сообщение с причиной.
--
-- Тег должен совпадать с `tag = ...` в lua/plugins/avante.lua (проверяет
-- tests/avante_build_test.py).
local M = {}

M.TAG = "v0.4.8"
M.REPO = "avante-corp/avante.nvim"

-- Главная библиотека: без неё нет шаблонов промптов (то, что ищет avante).
M.MAIN_LIB = "avante_templates"

local OS_NAMES = { Darwin = "darwin", Linux = "linux" }
local ARCHES = { x86_64 = "x86_64", amd64 = "x86_64", arm64 = "aarch64", aarch64 = "aarch64" }

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

--- Путь к главной библиотеке внутри каталога плагина.
function M.lib_file(dir)
  local ext = vim.fn.has("win32") == 1 and "dll" or "so"
  return dir .. "/lua/" .. M.MAIN_LIB .. "." .. ext
end

--- Собрана ли библиотека (проверка по файлу, а не по коду возврата).
function M.is_built(dir)
  return vim.uv.fs_stat(M.lib_file(dir)) ~= nil
end

-- vim.system вызывает колбэк в fast-контексте, где нельзя звать vim.fn.*
-- (E5560). Поэтому любой колбэк переносим в главный цикл.
local function sys(cmd, opts, cb)
  local ok, result = pcall(vim.system, cmd, opts, function(r)
    vim.schedule(function() cb(r) end)
  end)
  if not ok then
    vim.schedule(function() cb({ code = -1, stderr = tostring(result) }) end)
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

--- Асинхронная сборка. on_done(ok:boolean, msg:string) вызывается один раз.
---@param dir string каталог плагина avante.nvim
---@param on_done fun(ok: boolean, msg: string)
function M.build(dir, on_done, force)
  local function finish(ok, msg)
    vim.schedule(function()
      on_done(ok, msg)
    end)
  end

  if not force and M.is_built(dir) then
    return finish(true, "библиотеки уже на месте")
  end

  vim.fn.mkdir(dir .. "/lua", "p")

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
        finish(true, "собрано из исходников (make)")
      else
        finish(false, "make не собрал библиотеку (код " .. tostring(r.code) .. "):\n" .. tail(r.stderr, 8))
      end
    end)
  end

  local uname = vim.uv.os_uname()
  local artifact = M.artifact(uname.sysname, uname.machine)
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
      if M.is_built(dir) then
        return finish(true, "готовая сборка " .. M.TAG .. " установлена")
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
  end)
  vim.wait(timeout_ms or 900000, function()
    return done
  end, 200)
  if not done then
    return false, "сборка не уложилась во время ожидания"
  end
  return ok, msg
end

return M
