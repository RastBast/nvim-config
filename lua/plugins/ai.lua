-- ========================================================================== --
--                       AI: CODECOMPANION + KIMI                             --
-- ========================================================================== --
-- ИСПРАВЛЕНО:
--  1) Адаптер kimi в codecompanion.nvim уже встроен
--     (lua/codecompanion/adapters/http/kimi.lua, url api.moonshot.ai,
--     ключ из MOONSHOT_API_KEY). Самодельный адаптер через
--     `extend("openai", ...)` был лишним и писался по устаревшей схеме —
--     в текущей версии адаптеры лежат в `adapters.http`, а не в `adapters`.
--  2) `strategies` — устаревшее имя (config.lua подменяет его на
--     `interactions`), переписано на актуальное.
--  3) `display.diff.provider = "mini_diff"` — такой опции нет
--     (у display.diff есть enabled/threshold_for_chat/window/word_highlights),
--     поэтому mini.diff подключён как отдельный плагин.
--  4) Команды :CodeCompanionSend НЕ СУЩЕСТВУЕТ. Реальные команды:
--     CodeCompanion, CodeCompanionChat, CodeCompanionActions, CodeCompanionCmd,
--     CodeCompanionCLI, CodeCompanionCodeReview.
--     Отправка выделения в инлайн-чат — это :CodeCompanion в visual-режиме.
--  5) Свой промпт «Explain Code» переехал из `interactions` в `prompt_library`
--     (с `interaction = "chat"` и `opts.alias`). В `interactions` он никогда
--     не регистрировался, а `opts.mapping` в CodeCompanion не поддерживается.
--  6) api_key для kimi — имя переменной окружения, а не её значение
--     (см. комментарий у `env` ниже).
return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-telescope/telescope.nvim",
    },
    cmd = {
      "CodeCompanion",
      "CodeCompanionChat",
      "CodeCompanionActions",
      "CodeCompanionCmd",
      "CodeCompanionCLI",
      "CodeCompanionCodeReview",
    },
    keys = {
      { "<leader>Hat", "<cmd>CodeCompanionChat<cr>", desc = "💬 Чат с Kimi", mode = { "n", "v" } },
      { "<leader>Hai", "<cmd>CodeCompanionActions<cr>", desc = "🛠 Действия AI", mode = { "n", "v" } },
      -- Строковый rhs, а не <cmd>: в visual Vim дописывает '<,'> и команда
      -- получает именно выделение. С <cmd> range пустой → уходила одна строка.
      { "<leader>Hae", ":CodeCompanion<cr>", desc = "📤 Отправить выделение ИИ", mode = { "n", "v" } },
      { "<leader>Hac", "<cmd>CodeCompanionCmd<cr>", desc = "✨ Команда в CodeCompanion", mode = { "n", "v" } },
    },
    opts = {
      adapters = {
        http = {
          -- Встроенный адаптер kimi + ключ из окружения.
          -- Нужен только `export MOONSHOT_API_KEY=...` в shell.
          extend = {
            kimi = {
              -- ИМЯ переменной, а не её значение: CodeCompanion сам читает
              -- переменную в момент запроса. Раньше здесь стояло
              -- os.getenv(...) or "MOONSHOT_API_KEY": при заданном ключе
              -- его значение принималось за имя переменной, а при незаданном
              -- в запрос уходила строка "MOONSHOT_API_KEY" → 401.
              env = {
                api_key = "MOONSHOT_API_KEY",
              },
              schema = {
                model = { default = "moonshot-v1-8k" }, -- есть 32k и 128k
                temperature = { default = 0.7 },
              },
            },
          },
        },
      },

      -- Актуальное имя секции (раньше называлось `strategies`)
      interactions = {
        chat = {
          adapter = { name = "kimi", model = "moonshot-v1-8k" },
          keymaps = {
            close = { modes = { n = "q", i = "<C-c>" } },
            stop = { modes = { n = "<C-c>" } },
          },
        },
        inline = { adapter = "kimi" },
        agent = { adapter = "kimi" },
      },

      -- Пользовательские промпты — в prompt_library (НЕ в interactions).
      -- Вызов: require("codecompanion").prompt("explain") или :CodeCompanion /explain
      prompt_library = {
        ["Explain Code"] = {
          interaction = "chat",
          description = "Объясни выделенный код",
          opts = { alias = "explain" },
          prompts = {
            {
              role = "user",
              content = "Объясни подробно, что делает этот код:\n\n```\n${selected}\n```",
            },
          },
        },
      },
    },
  },

  -- Красивый diff для изменений, которые предлагает ИИ
  {
    "nvim-mini/mini.diff",
    version = false,
    event = "VeryLazy",
    config = function()
      require("mini.diff").setup()
    end,
  },
}
