-- Не открывать чат и не включать автоподсказки до готовности avante_templates.
-- Сборка асинхронная: Neovim остаётся отзывчивым, а команды показывают причину
-- вместо открытия полуработающего sidebar с повторяющимися ошибками автокоманд.
local M = {}

-- Вызывается из init.lua, а не из spec.init: lazy.nvim не запускает init
-- плагина, если его cond=false, поэтому иначе на старом nvim не будет подсказки.
function M.warn_unsupported()
  if vim.fn.has("nvim-0.12") == 1 then return end
  vim.schedule(function()
    vim.api.nvim_echo({ { "Avante v0.4.8 требует Neovim 0.12+. Обнови Neovim; остальные ИИ-инструменты не отключены.", "WarningMsg" } }, true, {})
  end)
end

function M.setup(plugin, opts)
  local B = require("config.avante_build")
  local dir = plugin.dir or B.plugin_dir()
  local avante = require("avante")
  local api = require("avante.api")
  local ready, building, restart_required = false, false, false
  local state, last_error = "проверка", nil
  local startup_revision, revision_err = B.revision(dir)
  local temporary = {}
  local temporary_desc = "avante: ожидание библиотек"

  -- В init.lua уведомления INFO/WARN отфильтрованы. Интерактивные команды
  -- и клавиши должны быть видны независимо от этого фильтра.
  local function show(message, highlight)
    vim.api.nvim_echo({ { message, highlight or "None" } }, true, {})
  end
  local function notify_status()
    local message = "avante: " .. state
    if last_error then message = message .. "\n" .. last_error end
    if restart_required then message = message .. "\nПерезапусти Neovim, чтобы загрузить новые библиотеки." end
    show(message .. "\nДиагностика: :AvanteStatus", ready and "None" or "WarningMsg")
  end

  -- Команды плагина зарегистрированы lazy.nvim до вызова config(). Они уже
  -- ссылаются на avante.api, поэтому защищаем его точки входа, включая :AvanteAsk,
  -- :AvanteChat, :AvanteEdit и :AvanteHistory. :AvanteBuild не перехватываем.
  for name, fn in pairs(api) do
    if type(fn) == "function" and name ~= "build" then
      local original = fn
      api[name] = function(...)
        if not ready then return notify_status() end
        return original(...)
      end
    end
  end
  -- :AvanteToggle вызывает avante.toggle(), а не avante.api.ask().
  for _, name in ipairs({ "toggle_sidebar", "open_sidebar" }) do
    local original = avante[name]
    if type(original) == "function" then
      avante[name] = function(...)
        if not ready then return notify_status() end
        return original(...)
      end
    end
  end

  -- RepoMap вызывается также напрямую из :AvanteShowRepoMap, в обход api.
  -- Заодно обрабатываем старые повреждённые *.repo_map.json до первого чата.
  local cache_guard = require("config.avante_repo_map")
  local guard_ok, guard_err = pcall(cache_guard.install, function() return ready end, notify_status)

  -- На время сборки привычные клавиши сообщают статус. Чужие существующие
  -- маппинги не перезаписываются и при удалении проверяем их desc ещё раз.
  local function hold_map(mode, lhs)
    if not lhs or lhs == "" then return end
    local existing = vim.fn.maparg(lhs, mode, false, true)
    if type(existing) == "table" and next(existing) ~= nil then return end
    vim.keymap.set(mode, lhs, notify_status, { desc = temporary_desc, silent = true })
    temporary[#temporary + 1] = { mode = mode, lhs = lhs }
  end
  local function hold_maps()
    local maps = opts.mappings or {}
    for _, mode in ipairs({ "n", "v" }) do
      hold_map(mode, maps.ask)
      hold_map(mode, maps.new_ask)
      hold_map(mode, maps.zen_mode)
      hold_map(mode, "<leader>Ax")
    end
    hold_map("v", maps.edit)
    hold_map("n", maps.toggle and maps.toggle.default)
  end
  local function release_maps()
    for _, map in ipairs(temporary) do
      local info = vim.fn.maparg(map.lhs, map.mode, false, true)
      if type(info) == "table" and info.desc == temporary_desc then
        pcall(vim.keymap.del, map.mode, map.lhs)
      end
    end
    temporary = {}
  end

  local function fail(message)
    state, last_error = "не готов", message
    vim.notify("❌ avante: " .. message .. "\nДиагностика: :AvanteStatus", vim.log.levels.ERROR, { title = "avante" })
  end

  local function activate()
    -- После :Lazy update в уже запущенном nvim Lua-модули могут быть от старого
    -- checkout, даже если файлы на диске уже обновились. Нужен новый процесс.
    local revision, err = B.revision(dir)
    if startup_revision and startup_revision ~= B.COMMIT then
      restart_required = true
      return fail("Код avante был обновлён в этом сеансе. Перезапусти Neovim.")
    end
    if revision and revision ~= B.COMMIT then return fail(B.revision_error(revision)) end
    if not revision and startup_revision then return fail(err) end

    local ok, reason = B.runtime_check(dir)
    if ok then
      local called, available, detail = pcall(cache_guard.native_ready)
      ok, reason = called and available, called and detail or tostring(available)
    end
    if not ok then
      return fail("Библиотеки не удалось загрузить: " .. tostring(reason)
        .. "\nПерезапусти Neovim и проверь :AvanteStatus; при необходимости выполни :AvanteRebuild.")
    end
    release_maps()
    ready = true
    local setup_ok, setup_err = pcall(avante.setup, opts)
    if not setup_ok then
      ready = false
      hold_maps()
      return fail("ошибка настройки: " .. tostring(setup_err) .. "\nПосле исправления перезапусти Neovim.")
    end
    state, last_error = "готов", nil
    vim.keymap.set({ "n", "v" }, "<leader>Ax", function()
      vim.cmd("AvanteAsk Объясни по-русски этот код или ошибку под курсором: что происходит, почему и как исправить")
    end, { desc = "🤖 Объяснить код/ошибку (Gemini)" })
  end

  local function rebuild(force, source)
    if building then
      return show("avante: сборка уже выполняется; дождись результата.", "WarningMsg")
    end
    building, state, last_error = true, "сборка библиотек", nil
    if force then
      show("avante: собираю библиотеки " .. B.TAG .. " в фоне…")
    end
    B.build(dir, function(ok, message)
      building = false
      if not ok then
        -- Если ручная пересборка не удалась, текущий уже загруженный avante
        -- может продолжать работать; не объявляем его сломанным.
        if ready then
          state, last_error = "готов; пересборка не удалась", message
          return vim.notify("❌ avante: " .. message, vim.log.levels.ERROR, { title = "avante" })
        end
        return fail(message)
      end
      if ready then
        state, last_error, restart_required = "готов; библиотеки обновлены", nil, true
        return show("✅ avante: " .. message .. ". Перезапусти Neovim для загрузки новых библиотек.")
      end
      activate()
      if ready then show("✅ avante: " .. message .. ". Чат готов к работе.") end
    end, { force = force, source = source })
  end

  -- Upstream :AvanteBuild без source=true скачивает ПОСЛЕДНИЙ тег через
  -- build.sh, даже если Lua-код закреплён на v0.4.8. Используем общий путь
  -- с проверкой версии, не допуская несовместимых бинарников и гонки сборок.
  api.build = function(options) rebuild(true, options and options.source == true) end

  local function status()
    local version = vim.version()
    local lines = {
      "avante " .. B.TAG .. ": " .. state,
      ("Neovim: %d.%d.%d"):format(version.major, version.minor, version.patch),
      "конфиг: " .. vim.fn.stdpath("config"), "init: " .. (vim.env.MYVIMRC or "неизвестен"),
      "каталог: " .. dir, "файл: " .. B.lib_file(dir),
    }
    local revision, err = B.revision(dir)
    lines[#lines + 1] = revision and ("commit: " .. revision) or (err or "версия неизвестна")
    local ok, reason = B.check(dir)
    lines[#lines + 1] = (ok and "библиотеки: " or "библиотеки не готовы: ") .. reason
    if ready then lines[#lines + 1] = "Проверка в текущем процессе; после замены библиотек нужен перезапуск." end
    if cache_guard.invalid_cache_count > 0 then
      lines[#lines + 1] = "Повреждённых карт репозитория проигнорировано: " .. cache_guard.invalid_cache_count
    end
    if last_error then lines[#lines + 1] = last_error end
    if restart_required then lines[#lines + 1] = "Перезапусти Neovim." end
    show(table.concat(lines, "\n"))
  end
  -- Команды существуют независимо от наличия плагина. Когда runtime готов,
  -- подключаем расширенную диагностику и реальную пересборку к этим командам.
  require("config.avante_commands").bind(status, function() rebuild(true) end)

  if not guard_ok then
    hold_maps()
    return fail("Не удалось включить защиту карты репозитория: " .. tostring(guard_err)
      .. "\nПроверь версию :Lazy update avante.nvim и перезапусти Neovim.")
  end
  if startup_revision and startup_revision ~= B.COMMIT then
    hold_maps()
    return fail(B.revision_error(startup_revision))
  end
  local ok, reason = B.runtime_check(dir)
  if ok then
    if not startup_revision then
      show("avante: не удалось проверить версию git: " .. tostring(revision_err), "WarningMsg")
    end
    return activate()
  end
  hold_maps()
  last_error = reason
  rebuild(false)
end

return M
