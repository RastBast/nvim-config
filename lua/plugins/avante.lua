-- ========================================================================== --
--   ИИ-АГЕНТ КАК В VSCODE/CURSOR: avante.nvim + БЕСПЛАТНЫЙ Google Gemini    --
-- ========================================================================== --
-- 1) Чат в боковой панели: видит проект (репomap), умеет рефакторить
--    (применяет diff'ы), отвечает на вопросы по коду.
-- 2) Inline-автодополнение целыми блоками при наборе (как Copilot):
--    поведение.auto_suggestions = true; призрак-подсказка принимается
--    по <Tab> (встроено в цепочку Tab в completions.lua: сначала меню cmp,
--    потом сниппеты, потом ИИ-подсказка), <M-l> — принять напрямую,
--    <C-]> — закрыть подсказку.
-- 3) Окно объяснения выделенного кода/ошибок: выдели код и <leader>Aa
--    (спросить) или <leader>Ax (объяснить по-русски).
--
-- КЛЮЧ: получи бесплатный ключ на https://aistudio.google.com/apikey
-- и пропиши (fish):  set -Ux GEMINI_API_KEY "твой_ключ"
-- (avante также понимает AVANTE_GEMINI_API_KEY — он приоритетнее;
--  ключ можно вообще не хранить в переменных: в providers.gemini задай
--  api_key_name = "cmd:команда", и avante возьмёт ключ из её stdout.)
--
-- СЕТЬ: по умолчанию трафик идёт напрямую в
-- generativelanguage.googleapis.com. Google блокирует IP неподдерживаемых
-- стран («400 User location is not supported for the API use») — тогда
-- нужен выход не из РФ: VPN/туннель, либо ретранслятор на сервере не в РФ
-- (GEMINI_ENDPOINT / GEMINI_PROXY), либо план B на OpenRouter
-- (AVANTE_PROVIDER="openrouter-free"). Всё пошагово: PROXY.md.
--
-- ВАЖНО ПРО ЭМОДЗИ: windows.input.prefix уходит в vim.fn.sign_define,
-- поэтому там нельзя ставить эмодзи — будет «E239: Invalid sign text»
-- и весь setup() упадёт (avante init.lua:288).
--
-- Сборка (ИСПРАВЛЕНО: «missing avante_templates» = native-библиотеки не собраны):
--   Логика в lua/config/avante_build.lua: готовые библиотеки ЗАКРЕПЛЁННОГО тега
--   скачиваются из релиза GitHub (curl + tar, cargo не нужен). Если не вышло —
--   запасной вариант make (нужен cargo: brew install rust).
--   Успех = файл lua/avante_templates.so появился на диске.
--   Вручную: :AvanteRebuild (рекомендуется). Не :AvanteBuild: это встроенная
--   команда avante, она использует свой build.sh, который тихо падает без git.
--   Переустановка с нуля: :Lazy build avante.nvim, затем перезапуск nvim.
--
-- Все схемы опций сверены с исходниками avante-corp/avante.nvim (бывш. yetone) (2026-09):
--   providers.gemini            lua/avante/config.lua:499
--   api_key_name = GEMINI_API_KEY  lua/avante/providers/gemini.lua:10
--   mappings.suggestion.*       lua/avante/config.lua:735
--   accept == "<Tab>" фолбэк    lua/avante/suggestion.lua:463
return {
  {
    "avante-corp/avante.nvim",
    event = "VeryLazy",
    cond = vim.fn.has("nvim-0.12") == 1, -- v0.4.8 вызывает :quit на более старом Neovim
    version = false, -- НИКОГДА не "*" — плагин ломается на тегах
    -- ЗАКРЕПЛЕНО на теге v0.4.8: готовые бинарники релиза собраны под этот код.
    -- Lua с main (новее на 34 коммита) с бинарниками v0.4.8 не совместим.
    -- Обновление: поменять tag здесь И M.TAG в lua/config/avante_build.lua,
    -- затем :Lazy sync и :AvanteRebuild.
    tag = "v0.4.8",
    -- Сборка: готовые библиотеки для тега (curl+tar, без git и cargo), запасной
    -- вариант — make (нужен cargo). Логика и сообщения — в config/avante_build.lua
    build = function(plugin)
      local ok, msg = require("config.avante_build").build_blocking(plugin.dir)
      if ok then
        vim.notify("avante: " .. msg, vim.log.levels.INFO)
      else
        error("avante не собрался: " .. msg)
      end
    end,
    cmd = {
      "Avante", "AvanteAsk", "AvanteChat", "AvanteChatNew", "AvanteEdit",
      "AvanteFocus", "AvanteRefresh", "AvanteStop", "AvanteHistory",
      "AvanteToggle", "AvanteShowRepoMap", "AvanteModels", "AvanteClear",
      "AvanteBuild", "AvanteRebuild", "AvanteStatus", "AvanteSwitchProvider",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      -- Обязательная зависимость avante (README avante, «Mandatory dependencies»):
      -- avante/commands.lua делает require("mega.cmdparse") при VeryLazy.
      -- Без неё: «module 'mega.cmdparse' not found».
      { "ColinKennedy/mega.cmdparse", dependencies = { "ColinKennedy/mega.logging" } },
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
      "nvim-telescope/telescope.nvim", -- выбор файлов для @упоминаний
      "folke/snacks.nvim",             -- input-виджеты
      "MeanderingProgrammer/render-markdown.nvim", -- рендер ответов (ft Avante добавлен в markdown.lua)
    },
    opts = function()
      local AI = require("config.ai_api")
      local function safe_model(env_name, fallback)
        if type(AI.env_model) == "function" then
          return AI.env_model(env_name, fallback)
        end
        local v = vim.env[env_name]
        if type(v) == "string" and v ~= "" and not v:find("[\128-\255]") and not v:find("%s") then
          return v
        end
        return fallback
      end
      local chosen_provider = (vim.g.ai_provider and vim.g.ai_provider ~= "" and vim.g.ai_provider)
        or (vim.env.AVANTE_PROVIDER and vim.env.AVANTE_PROVIDER ~= "" and vim.env.AVANTE_PROVIDER)
        or AI.avante_default()
      local gemini_model = safe_model("GEMINI_MODEL", "gemini-3.6-flash")
      local openrouter_model = safe_model("OPENROUTER_MODEL", "openrouter/free")

      return {
      -- ========================= ПРОВАЙДЕР ================================ --
      -- Переключение прямо в чате без перезапуска:
      --   <leader>Ag (:AvanteGemini)     — прямой Google Gemini (с отдельным ключом AVANTE_GEMINI_API_KEY / GEMINI_API_KEY)
      --   <leader>Ao (:AvanteOpenRouter) — OpenRouter
      --   <leader>Ap (:AiProvider)       — меню всех провайдеров
      --   <leader>Am (:AvanteModels)     — выбор конкретной модели
      provider = chosen_provider,
      -- inline-подсказки — тем же провайдером (дешёвая flash-модель)
      auto_suggestions_provider = vim.env.AVANTE_SUGGEST_PROVIDER
        or (chosen_provider == "gemini" and "gemini-flash" or chosen_provider),
      -- Универсальные провайдеры (Groq, OpenRouter, Mistral, DeepSeek, Kimi, свой сервис)
      -- берутся из lua/config/ai_api.lua. Переключение в чате: <leader>Ap / <leader>Ag / :AvanteSwitchProvider
      providers = vim.tbl_extend("force", AI.avante_providers(), {
        gemini = {
          endpoint = vim.env.GEMINI_ENDPOINT
            or "https://generativelanguage.googleapis.com/v1beta/models",
          proxy = vim.env.GEMINI_PROXY or nil,
          allow_insecure = vim.env.GEMINI_INSECURE == "1",
          model = gemini_model,
          model_names = {
            "gemini-3.6-flash",
            "gemini-3.6-pro",
            "gemini-2.5-flash",
            "gemini-2.5-pro",
            "gemini-2.0-flash",
          },
          timeout = 30000,
          context_window = 1048576, -- миллион токенов контекста проекта
          extra_request_body = {
            generationConfig = { temperature = 0.75 },
          },
        },
        -- Прямой Google Gemini в обход любых GEMINI_ENDPOINT / GEMINI_PROXY (для отдельного прямого ключа):
        ["gemini-direct"] = {
          __inherited_from = "gemini",
          endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
          proxy = nil,
          allow_insecure = false,
          model = gemini_model,
          model_names = {
            "gemini-3.6-flash",
            "gemini-3.6-pro",
            "gemini-2.5-flash",
            "gemini-2.5-pro",
            "gemini-2.0-flash",
          },
          timeout = 30000,
          context_window = 1048576,
        },
        -- отдельный лёгкий провайдер для автоподсказок
        ["gemini-flash"] = {
          __inherited_from = "gemini", -- наследует endpoint/proxy/allow_insecure
          hide_in_model_selector = true,
          model = gemini_model,
        },

        -- ============ ПЛАН B: OPENROUTER (если Google не пускает) ========= --
        ["openrouter-free"] = {
          __inherited_from = "openai",
          endpoint = "https://openrouter.ai/api/v1",
          api_key_name = "OPENROUTER_API_KEY",
          model = openrouter_model,
          model_names = {
            "openrouter/free",
            "qwen/qwen3-coder:free",
            "deepseek/deepseek-chat-v3-0324:free",
            "google/gemini-2.5-flash",
            "anthropic/claude-sonnet-4",
          },
          timeout = 30000,
          context_window = 128000,
        },
      }),

      -- ========================= ПОВЕДЕНИЕ ================================ --
      -- Отключаем встроенный инструмент "think", чтобы в чате оставался только чистый ответ ИИ
      -- (переключатель размышлений: <leader>Ah / :AiThinkingToggle).
      disabled_tools = { "think" },
      behaviour = {
        -- Встроенные серые автоподсказки (Ghost Text) вынесены в плагин
        -- Codeium / NeoCodeium (lua/plugins/neocodeium.lua, включён по умолчанию;
        -- переключатель: <leader>AG или <leader>ui; авторизация: <leader>AK).
        -- Штатный авто-режим avante по умолчанию выключен (включить при желании:
        -- set -Ux AVANTE_SUGGESTIONS 1).
        auto_suggestions = vim.env.AVANTE_SUGGESTIONS == "1",
        -- дифы не применяются сами: сначала показываем, ты подтверждаешь.
        -- Правильное имя опции — auto_apply_diff_after_generation
        -- (avante config.lua, таблица behaviour); auto_apply_diffs не
        -- существует и молча игнорировался.
        auto_apply_diff_after_generation = false,
      },

      -- ========================= ОКНА ===================================== --
      windows = {
        position = "right",  -- сайдбар справа, как в Cursor
        wrap = true,
        width = 40,
        sidebar_header = { align = "center", rounded = true },
        -- ВАЖНО: этот префикс уходит в vim.fn.sign_define (avante init.lua:288
        -- H.signs), а текст знака не может быть шире 2 ячеек — эмодзи даёт
        -- «E239: Invalid sign text» и setup() падает. Только ASCII/узкие
        -- символы: "> ", "AI", "❯ ".
        input = { prefix = "> " },
        edit = { border = "rounded" },
        ask = { border = "rounded" },
      },

      -- ========================= КЛАВИШИ ================================== --
      -- Префикс <leader>A (верхний регистр!): <leader>a занят aerial.
      -- Принятие inline-подсказки — <Tab> через completions.lua (см. там),
      -- напрямую — <M-l>; следующие/предыдущие варианты — <M-]>/<M-[>;
      -- скрыть подсказку — <C-]>.
      mappings = {
        ask = "<leader>Aa",       -- чат о выделенном/текущем коде (агент)
        new_ask = "<leader>An",  -- новый чат
        edit = "<leader>Ae",     -- рефакторинг выделения по инструкции
        refresh = "<leader>Ar",  -- обновить окна
        focus = "<leader>Af",    -- фокус на сайдбар
        stop = "<leader>AS",     -- остановить генерацию
        zen_mode = "<leader>Az",
        toggle = {
          default = "<leader>At",   -- показать/скрыть сайдбар
          debug = "<leader>Ad",
          selection = "<leader>AC", -- окно выбора (selection window)
          suggestion = "<leader>As", -- позвать inline-подсказку вручную
          repomap = "<leader>AR",   -- карта репозитория
        },
        suggestion = {
          accept = "<M-l>",  -- принять подсказку напрямую (дубль <Tab>)
          next = "<M-]>",    -- следующий вариант подсказки
          prev = "<M-[>",    -- предыдущий вариант
          dismiss = "<C-]>", -- закрыть подсказку
        },
        submit = {
          normal = "<CR>",
          insert = "<C-s>",  -- отправить сообщение из поля ввода
        },
      },
      }
    end,
    config = function(plugin, opts)
      local B = require("config.avante_build")
      local ok_guard, repo_guard = pcall(require, "config.avante_repo_map")
      local ok_cmds, avante_cmds = pcall(require, "config.avante_commands")
      local function plugin_dir() return plugin.dir end
      local running, configured = false, false
      local last_reason = nil

      local function echo_msg(text, hl)
        pcall(vim.api.nvim_echo, { { text, hl or "None" } }, true, {})
      end

      local function notify_not_ready()
        local msg = running
          and ("avante: скачиваю/собираю нативные библиотеки " .. B.TAG .. "… Дождись завершения или проверь :AvanteStatus")
          or ("avante ещё не готов" .. (last_reason and (": " .. last_reason) or "") .. ". Восстановление: :AvanteRebuild (<leader>AU), статус: :AvanteStatus")
        vim.notify(msg, vim.log.levels.WARN)
        echo_msg(msg, "WarningMsg")
      end

      -- Существование файла не гарантирует, что он подходит архитектуре и Lua,
      -- а lazy.core.cache без сброса не видит новые .so до перезапуска.
      -- До успешной загрузки ВСЕХ библиотек нельзя вызывать setup: иначе чат
      -- установит ModeChanged/WinEnter autocmd и упадёт при вводе текста.
      local function available()
        if not B.is_built(plugin_dir()) then return false, "файл avante_templates отсутствует" end
        if type(B.ensure_runtime) == "function" then
          local ok_rt, err_rt = B.ensure_runtime(plugin_dir())
          if not ok_rt then return false, tostring(err_rt) end
          return true
        end
        local loader, err = package.loadlib(B.lib_file(plugin_dir()), "luaopen_avante_templates")
        if not loader then return false, tostring(err) end
        local ok, result = pcall(require, "avante_templates")
        if not ok then
          package.loaded.avante_templates = nil
          return false, tostring(result)
        end
        return true
      end

      if ok_guard and type(repo_guard.install) == "function" then
        pcall(repo_guard.install, function() return configured end, notify_not_ready)
      end

      local hold_keys = {
        { "<leader>Aa", { "n", "v" }, "🤖 Чат Avante (ожидание сборки)" },
        { "<leader>An", { "n", "v" }, "🤖 Новый чат Avante (ожидание сборки)" },
        { "<leader>Ae", { "n", "v" }, "🤖 Рефакторинг Avante (ожидание сборки)" },
        { "<leader>At", "n", "🤖 Панель Avante (ожидание сборки)" },
        { "<leader>Af", "n", "🤖 Фокус Avante (ожидание сборки)" },
        { "<leader>Ar", "n", "🤖 Обновить Avante (ожидание сборки)" },
        { "<leader>AR", "n", "🤖 Карта репозитория Avante (ожидание сборки)" },
        { "<leader>Ax", { "n", "v" }, "🤖 Объяснить код/ошибку (ожидание сборки)" },
      }
      local function install_hold_maps()
        for _, item in ipairs(hold_keys) do
          vim.keymap.set(item[2], item[1], notify_not_ready, { desc = item[3], silent = true })
        end
      end

      local function leave_tree_if_code_open()
        if type(vim.api.nvim_get_current_buf) ~= "function" or type(vim.api.nvim_list_wins) ~= "function" then
          return
        end
        local cur_buf = vim.api.nvim_get_current_buf()
        local ft = vim.bo[cur_buf] and vim.bo[cur_buf].filetype or ""
        if ft ~= "NvimTree" and ft ~= "neo-tree" then
          return
        end
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          local b = vim.api.nvim_win_get_buf(w)
          local bft = vim.bo[b] and vim.bo[b].filetype or ""
          local bt = vim.bo[b] and vim.bo[b].buftype or ""
          if bt == "" and bft ~= "NvimTree" and bft ~= "neo-tree" and not bft:match("^Avante") then
            pcall(vim.api.nvim_set_current_win, w)
            return
          end
        end
      end

      local function setup_if_ready()
        if configured then return true end
        local ready, reason = available()
        if not ready then
          last_reason = reason
          return false, reason
        end
        if ok_guard and package.loaded["avante.path"] and package.loaded["avante.repo_map"] then
          local ok_native, why_native = repo_guard.native_ready()
          if not ok_native then
            last_reason = why_native
            return false, why_native
          end
        end
        local ok_ai_pre, AI_pre = pcall(require, "config.ai_api")
        if ok_ai_pre and type(AI_pre) == "table" then
          if type(AI_pre.sync_gemini_env) == "function" then
            pcall(AI_pre.sync_gemini_env)
          end
          if type(AI_pre.sanitize_avante_state_file) == "function" then
            pcall(AI_pre.sanitize_avante_state_file)
          end
        end
        local ok, err = pcall(function() require("avante").setup(opts) end)
        if not ok then
          last_reason = tostring(err)
          return false, tostring(err)
        end
        configured = true
        last_reason = nil
        pcall(function() require("config.ai_thinking").install_avante_hooks() end)
        if ok_guard and type(repo_guard.install) == "function" then
          pcall(repo_guard.install, function() return configured end, notify_not_ready)
        end
        vim.keymap.set({ "n", "v" }, "<leader>Ax", function()
          leave_tree_if_code_open()
          vim.cmd("AvanteAsk Объясни по-русски этот код или ошибку под курсором: что происходит, почему и как исправить")
        end, { desc = "🤖 Объяснить код/ошибку" })
        return true
      end

      local function status_report()
        local v = vim.version and vim.version() or { major = 0, minor = 0, patch = 0 }
        local state = configured and "✅ готов к работе" or (running and "⏳ идёт сборка библиотек" or "⚠️ ожидает восстановления")
        local lines = {
          "# 🩺 Статус Avante (" .. B.TAG .. ")",
          "",
          "- **Состояние:** " .. state,
          ("- **Neovim:** %d.%d.%d"):format(v.major or 0, v.minor or 0, v.patch or 0),
          "- **Каталог плагина:** `" .. tostring(plugin_dir()) .. "`",
        }
        if type(B.LIBRARIES) == "table" then
          lines[#lines + 1] = ""
          lines[#lines + 1] = "### Нативные библиотеки (`.so`)"
          for _, lib in ipairs(B.LIBRARIES) do
            local path = B.lib_file(plugin_dir(), lib.name)
            local exists = vim.uv.fs_stat(path) ~= nil
            local loaded = type(package.loaded[lib.name]) == "table"
            lines[#lines + 1] = ("- `%s`: файл %s · модуль %s"):format(
              lib.name,
              exists and "✓ есть" or "✗ НЕТ",
              loaded and "✓ загружен" or "· ещё не загружен"
            )
          end
        else
          lines[#lines + 1] = "- **Библиотека:** `" .. tostring(B.lib_file(plugin_dir())) .. "`"
        end
        if ok_guard then
          lines[#lines + 1] = ""
          lines[#lines + 1] = ("- **Защита repo_map:** активна (очищено битых файлов: %d, перехвачено в сеансе: %d)"):format(
            repo_guard.cleaned_disk_count or 0,
            repo_guard.invalid_cache_count or 0
          )
        end
        if type(B.darwin_patched_count) == "number" and B.darwin_patched_count > 0 then
          lines[#lines + 1] = ("- **macOS Mach-O (Nix → dyld):** адаптировано библиотек: %d"):format(B.darwin_patched_count)
        end
        local ok_ai, AI = pcall(require, "config.ai_api")
        local ok_av_cfg, av_cfg = pcall(require, "avante.config")
        if ok_av_cfg and type(av_cfg) == "table" and av_cfg.provider then
          local p_tbl = type(av_cfg.providers) == "table" and av_cfg.providers[av_cfg.provider] or nil
          local cur_m = type(p_tbl) == "table" and p_tbl.model or "?"
          lines[#lines + 1] = ("- **Активный провайдер чата Avante:** `%s` (модель: `%s`)"):format(tostring(av_cfg.provider), tostring(cur_m))
        elseif ok_ai and type(AI.active_id) == "function" then
          lines[#lines + 1] = "- **ИИ-провайдер по умолчанию:** `" .. tostring(AI.active_id() or "gemini") .. "` (`:AiStatus`)"
        end
        if last_reason then
          lines[#lines + 1] = ""
          lines[#lines + 1] = "### Последняя причина отказа"
          lines[#lines + 1] = "```text\n" .. tostring(last_reason) .. "\n```"
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Переключение в чате: `<leader>Ag` Gemini · `<leader>Ao` OpenRouter · `<leader>Ap` все провайдеры · `<leader>Am` модель · `<leader>Ak` вставить ключ"
        lines[#lines + 1] = "Диагностика: `:AvanteRebuild` (`<leader>AU`) · `:AiStatus` · `:EnvCheck`"
        if ok_cmds and type(avante_cmds.show_report) == "function" then
          avante_cmds.show_report("🩺 AvanteStatus", lines, not configured)
        else
          echo_msg(table.concat(lines, "\n"), configured and "None" or "WarningMsg")
        end
      end

      local function rebuild(rebuild_opts)
        if running then
          vim.notify("avante: сборка уже выполняется", vim.log.levels.INFO)
          echo_msg("avante: сборка уже выполняется…", "WarningMsg")
          return
        end
        if vim.fn.isdirectory(plugin_dir()) == 0 then
          local msg = "avante не установлен: откройте <leader>AL (:Lazy sync) и повторите установку"
          vim.notify(msg, vim.log.levels.WARN)
          echo_msg(msg, "WarningMsg")
          return
        end
        running = true
        if not (rebuild_opts and rebuild_opts.silent) then
          vim.notify("avante: сборка " .. B.TAG .. "…", vim.log.levels.INFO)
          echo_msg("avante: скачиваю/собираю библиотеки " .. B.TAG .. "…", "None")
        end
        -- Удаляем непригодные библиотеки перед пересборкой (создаст новые inode без старого кэша).
        local loadable = available()
        if not loadable then
          if type(B.LIBRARIES) == "table" then
            for _, lib in ipairs(B.LIBRARIES) do
              local f = B.lib_file(plugin_dir(), lib.name)
              if vim.uv.fs_stat(f) then vim.fn.delete(f) end
            end
          elseif B.is_built(plugin_dir()) then
            vim.fn.delete(B.lib_file(plugin_dir()))
          end
        end
        local want_source = type(rebuild_opts) == "table" and rebuild_opts.source == true
        local build_arg = want_source and { force = true, source = true } or (not loadable or (rebuild_opts and rebuild_opts.force) or false)
        B.build(plugin_dir(), function(ok, msg)
          running = false
          if ok then
            local ready, reason = setup_if_ready()
            if ready then
              vim.notify("avante готов: " .. msg, vim.log.levels.INFO)
              echo_msg("✅ avante готов: " .. msg, "MoreMsg")
            elseif not want_source and vim.fn.executable("cargo") == 1 and vim.fn.executable("make") == 1 then
              vim.notify("avante: готовый бинарник не загрузился (" .. tostring(reason) .. "), собираю локально через cargo/make…", vim.log.levels.WARN)
              vim.schedule(function()
                rebuild({ force = true, source = true })
              end)
            else
              vim.notify("avante: библиотека не загрузилась/ошибка setup: " .. reason .. "\nПроверьте :AvanteStatus и перезапустите Neovim.", vim.log.levels.ERROR)
            end
          else
            last_reason = msg
            vim.notify("avante не собрался:\n" .. msg .. "\nПовторить: <leader>AU (:AvanteRebuild)", vim.log.levels.ERROR)
          end
        end, build_arg)
      end

      vim.api.nvim_create_user_command("AvanteRebuild", function() rebuild({ force = true }) end,
        { force = true, desc = "Скачать или собрать библиотеки avante" })
      vim.api.nvim_create_user_command("AvanteStatus", status_report,
        { force = true, desc = "Диагностика Avante и нативных библиотек" })
      if ok_cmds and type(avante_cmds.bind) == "function" then
        avante_cmds.bind(status_report, function() rebuild({ force = true }) end)
      end

      -- Команды avante регистрируются его plugin/ до config. Пока setup не
      -- завершён, не позволяем им (включая :AvanteToggle и сайдбар) открыть
      -- сломанный буфер AvanteInput; после сборки те же обёртки пропускают вызовы.
      local api_ok, api = pcall(require, "avante.api")
      if api_ok and type(api) == "table" then
        for _, name in ipairs({ "ask", "full_view_ask", "zen_mode", "edit", "focus", "refresh", "select_model", "select_history" }) do
          local original = api[name]
          if type(original) == "function" then
            api[name] = function(...)
              if not configured then
                notify_not_ready()
                return
              end
              if name == "ask" or name == "full_view_ask" then
                leave_tree_if_code_open()
              end
              return original(...)
            end
          end
        end
        if type(api.build) == "function" then
          api.build = function(bopts)
            rebuild({ force = true, source = type(bopts) == "table" and bopts.source == true })
          end
        end
      end

      local av_ok, av_mod = pcall(require, "avante")
      if av_ok and type(av_mod) == "table" then
        for _, name in ipairs({ "toggle_sidebar", "open_sidebar" }) do
          local original = av_mod[name]
          if type(original) == "function" then
            av_mod[name] = function(...)
              if not configured then
                notify_not_ready()
                return false
              end
              leave_tree_if_code_open()
              return original(...)
            end
          end
        end
        if type(av_mod.toggle) == "function" then
          local orig_toggle = av_mod.toggle
          av_mod.toggle = function(...)
            if not configured then
              notify_not_ready()
              return false
            end
            leave_tree_if_code_open()
            return orig_toggle(...)
          end
        end
      end

      local ready, reason = setup_if_ready()
      if not ready then
        install_hold_maps()
        if not available() then
          vim.notify("avante пока отключён: " .. reason .. "\nПробуем восстановить; повторить: <leader>AU", vim.log.levels.WARN)
          vim.schedule(function() rebuild({ silent = true }) end)
        else
          vim.notify("Ошибка настройки avante: " .. reason .. "\nПроверьте :AvanteStatus и <leader>AL.", vim.log.levels.ERROR)
        end
      end
    end,
  },
}
