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
-- Трафик идёт напрямую в generativelanguage.googleapis.com — прокси в Lua
-- НЕ нужны (системный обход DPI/WARP подхватывается из окружения).
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
      -- ========================= ПРОВАЙДЕР: GEMINI ======================== --
      provider = "gemini",
      -- inline-подсказки — тем же gemini (дешёвая flash-модель)
      auto_suggestions_provider = "gemini-flash",
      providers = {
        gemini = {
          endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
          -- бесплатный тариф AI Studio: gemini-2.5-flash.
          -- Актуальная дефолтная модель avante — gemini-3.6-flash:
          -- просто замени строку, когда захочешь новее.
          model = "gemini-2.5-flash",
          timeout = 30000,
          context_window = 1048576, -- миллион токенов контекста проекта
          extra_request_body = {
            generationConfig = { temperature = 0.75 },
          },
        },
        -- отдельный лёгкий провайдер для автоподсказок
        ["gemini-flash"] = {
          __inherited_from = "gemini",
          model = "gemini-2.5-flash",
        },
      },

      -- ========================= ПОВЕДЕНИЕ ================================ --
      behaviour = {
        auto_suggestions = true,  -- inline-подсказки при наборе (Copilot-стиль)
        auto_apply_diffs = false, -- дифы применяем вручную (безопаснее)
        enable_cursor_planning_mode = true, -- агент планирует перед правкой
      },

      -- ========================= ОКНА ===================================== --
      windows = {
        position = "right",  -- сайдбар справа, как в Cursor
        wrap = true,
        width = 40,
        sidebar_header = { align = "center", rounded = true },
        input = { prefix = "🤖 " },
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
