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
-- Сборка: build = "make" тянет ПРЕДСОБРАННЫЕ бинари через curl+tar
-- (cargo не нужен; нужен только curl и tar — есть в macOS/Linux).
--
-- Все схемы опций сверены с исходниками yetone/avante.nvim (2026-09):
--   providers.gemini            lua/avante/config.lua:499
--   api_key_name = GEMINI_API_KEY  lua/avante/providers/gemini.lua:10
--   mappings.suggestion.*       lua/avante/config.lua:735
--   accept == "<Tab>" фолбэк    lua/avante/suggestion.lua:463
return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false, -- НИКОГДА не "*" — плагин ломается на тегах
    -- пребуилт-бинари через curl+tar; cargo не требуется
    build = vim.fn.has("win32") ~= 0 and "make BUILD_FROM_SOURCE=true" or "make",
    cmd = {
      "AvanteAsk", "AvanteChat", "AvanteChatNew", "AvanteEdit",
      "AvanteFocus", "AvanteRefresh", "AvanteStop", "AvanteHistory",
      "AvanteBuild", "AvanteSwitchProvider",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
      "stevearc/dressing.nvim",
      "nvim-telescope/telescope.nvim", -- выбор файлов для @упоминаний
      "folke/snacks.nvim",             -- input-виджеты
      "MeanderingProgrammer/render-markdown.nvim", -- рендер ответов (ft Avante добавлен в markdown.lua)
    },
    opts = {
      -- ========================= ПРОВАЙДЕР ================================ --
      -- По умолчанию Gemini. Google блокирует запросы с IP неподдерживаемых
      -- стран: «400 User location is not supported for the API use».
      -- Тогда либо включаешь VPN/туннель с выходом не из РФ, либо поднимаешь
      -- ретранслятор на сервере НЕ в РФ (PROXY.md), либо переключаешься на
      -- OpenRouter одной переменной (план B в PROXY.md):
      --   set -Ux AVANTE_PROVIDER "openrouter-free"
      --   set -Ux OPENROUTER_API_KEY "sk-or-..."
      --   set -Ux AVANTE_SUGGEST_PROVIDER "openrouter-free"
      provider = vim.env.AVANTE_PROVIDER or "gemini",
      -- inline-подсказки — тем же провайдером (дешёвая flash-модель)
      auto_suggestions_provider = vim.env.AVANTE_SUGGEST_PROVIDER or "gemini-flash",
      providers = {
        gemini = {
          -- ТОЧКА ВХОДА. По умолчанию — напрямую в Google.
          -- Если Google из твоей сети недоступен/палится, сюда можно
          -- подставить адрес ретранслятора на СВОЁМ сервере — тогда Google
          -- увидит IP сервера, а не твой:
          --   1) поднял nginx-ретранслятор на VPS (см. PROXY.md, способ A);
          --   2) пробросил порт туннелем (PROXY.md, способ B);
          --   3) раскомментируй строку ниже:
          -- endpoint = "http://127.0.0.1:8443/v1beta/models",
          -- Переопределяется без правки конфига переменной окружения:
          --   set -Ux GEMINI_ENDPOINT "http://127.0.0.1:8443/v1beta/models"
          endpoint = vim.env.GEMINI_ENDPOINT
            or "https://generativelanguage.googleapis.com/v1beta/models",
          -- HTTP(S)-ПРОКСИ для запросов к Gemini (curl -x под капотом:
          -- lua/avante/providers/gemini.lua:331 → plenary.curl → curl).
          -- Пример: proxy = "http://127.0.0.1:1080" — локальный порт,
          -- проброшенный на твой сервер (ssh -D / gost / 3proxy).
          -- Ничего не прописано = прямой доступ, как раньше.
          proxy = vim.env.GEMINI_PROXY or nil,
          -- Не проверять TLS-сертификат. Нужно ТОЛЬКО если у ретранслятора
          -- самоподписанный сертификат (см. PROXY.md, §4).
          -- Включается без правки файла:  set -Ux GEMINI_INSECURE 1
          allow_insecure = vim.env.GEMINI_INSECURE ~= nil,
          -- МОДЕЛЬ. gemini-2.5-flash для НОВЫХ аккаунтов закрыт, Google
          -- отвечает 404 "no longer available to new users" — поэтому
          -- ставим gemini-3.6-flash (это и дефолт самого avante).
          -- Меняется без правки файла:  set -Ux GEMINI_MODEL "имя-модели"
          -- Список доступных тебе моделей:
          --   curl -sS "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY"
          model = vim.env.GEMINI_MODEL or "gemini-3.6-flash",
          timeout = 30000,
          context_window = 1048576, -- миллион токенов контекста проекта
          extra_request_body = {
            generationConfig = { temperature = 0.75 },
          },
        },
        -- отдельный лёгкий провайдер для автоподсказок
        ["gemini-flash"] = {
          __inherited_from = "gemini", -- наследует endpoint/proxy/allow_insecure
          -- отдельная переменная, чтобы подсказки можно было сделать дешевле
          model = vim.env.GEMINI_MODEL or "gemini-3.6-flash",
        },

        -- ============ ПЛАН B: OPENROUTER (если Google не пускает) ========= --
        -- Агрегатор моделей, ключ на https://openrouter.ai/keys.
        -- Наследует штатный провайдер avante «openrouter» (endpoint
        -- https://openrouter.ai/api/v1, ключ OPENROUTER_API_KEY —
        -- lua/avante/config.lua:547-553), здесь переопределена только модель.
        -- Есть и бесплатные модели (суффикс ":free").
        -- Включается:  set -Ux AVANTE_PROVIDER "openrouter-free"
        ["openrouter-free"] = {
          __inherited_from = "openrouter",
          model = vim.env.OPENROUTER_MODEL or "openrouter/auto",
        },
      },

      -- ========================= ПОВЕДЕНИЕ ================================ --
      behaviour = {
        auto_suggestions = true, -- inline-подсказки при наборе (Copilot-стиль)
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
    },
    config = function(_, opts)
      require("avante").setup(opts)

      -- «Объясни выделенный код / ошибку» по-русски в сайдбаре.
      -- Выдели код (или встань на строку с ошибкой) и нажми <leader>Ax.
      vim.keymap.set({ "n", "v" }, "<leader>Ax", function()
        vim.cmd("AvanteAsk Объясни по-русски этот код или ошибку под курсором: что происходит, почему и как исправить")
      end, { desc = "🤖 Объяснить код/ошибку (Gemini)" })
    end,
  },
}
