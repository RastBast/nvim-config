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
--  3) `prompt_library` больше не хранит промпты (там только markdown.dirs),
--     кастомные промпты переехали в `interactions`.
--  4) `display.diff.provider = "mini_diff"` — такой опции нет
--     (у display.diff есть enabled/threshold_for_chat/window/word_highlights),
--     поэтому mini.diff подключён как отдельный плагин.
--  5) Команды :CodeCompanionSend НЕ СУЩЕСТВУЕТ. Реальные команды:
--     CodeCompanion, CodeCompanionChat, CodeCompanionActions, CodeCompanionCmd,
--     CodeCompanionCLI, CodeCompanionCodeReview.
--     Отправка выделения в инлайн-чат — это :CodeCompanion в visual-режиме.
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
      { "<leader>Hae", "<cmd>CodeCompanion<cr>", desc = "📤 Отправить выделение ИИ", mode = { "n", "v" } },
      { "<leader>Hac", "<cmd>CodeCompanionCmd<cr>", desc = "✨ Команда в CodeCompanion", mode = { "n", "v" } },
    },
    opts = {
      adapters = {
        http = {
          -- Встроенный адаптер kimi + наш ключ из окружения.
          -- Можно просто `export MOONSHOT_API_KEY=...` — тогда блок не нужен.
          extend = {
            kimi = {
              env = {
                api_key = os.getenv("MOONSHOT_API_KEY") or "MOONSHOT_API_KEY",
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

        -- Кастомный промпт (раньше жил в prompt_library)
        ["Explain Code"] = {
          strategy = "chat",
          description = "Объясни выделенный код",
          opts = { mapping = "<leader>Hae" },
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
    "echasnovski/mini.diff",
    version = false,
    event = "VeryLazy",
    config = function()
      require("mini.diff").setup()
    end,
  },
}
