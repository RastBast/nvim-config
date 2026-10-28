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
-- Провайдеры: единый реестр в lua/config/ai_api.lua (Groq и др.).
-- Выбранный провайдер (<leader>Ap или AI_PROVIDER) становится адаптером чата.
local AI = require("config.ai_api")

-- Адаптер Groq и «свой сервис» — через штатный openai_compatible codecompanion.
local function openai_compat(name, label, url, key_env, model)
  return function()
    return require("codecompanion.adapters").extend("openai_compatible", {
      name = name,
      formatted_name = label,
      env = {
        url = url,
        api_key = key_env, -- ИМЯ переменной с ключом, не сам ключ
        chat_url = "/v1/chat/completions",
        models_endpoint = "/v1/models",
      },
      schema = { model = { default = model } },
    })
  end
end

local cc = AI.cc_adapter()
local function cc_model()
  local r = AI.resolve()
  if r and AI.cc_map[r.id] == cc then
    return r.model
  end
  return nil
end
local chat_adapter = { name = cc }
if cc_model() then
  chat_adapter.model = cc_model()
elseif cc == "kimi" then
  chat_adapter.model = "moonshot-v1-8k" -- запасной вариант, как было раньше
end
local groq_model = (AI.resolve("groq")) and AI.resolve("groq").model or "openai/gpt-oss-120b"

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
      { "<leader>Hat", "<cmd>CodeCompanionChat<cr>", desc = "💬 Чат с ИИ (выбранный провайдер)", mode = { "n", "v" } },
      { "<leader>Hai", "<cmd>CodeCompanionActions<cr>", desc = "🛠 Действия AI", mode = { "n", "v" } },
      -- Строковый rhs, а не <cmd>: в visual Vim дописывает '<,'> и команда
      -- получает именно выделение. С <cmd> range пустой → уходила одна строка.
      { "<leader>Hae", ":CodeCompanion<cr>", desc = "📤 Отправить выделение ИИ", mode = { "n", "v" } },
      { "<leader>Hac", "<cmd>CodeCompanionCmd<cr>", desc = "✨ Команда в CodeCompanion", mode = { "n", "v" } },
    },
    opts = {
      adapters = {
        http = {
          -- Groq: OpenAI-совместимый API, ключ — переменная GROQ_API_KEY (fish: set -Ux GROQ_API_KEY "…")
          groq = openai_compat("groq", "Groq", "https://api.groq.com/openai", "GROQ_API_KEY", groq_model),
          -- Любой свой OpenAI-совместимый сервис: AI_BASE_URL, AI_API_KEY, AI_MODEL
          -- AI_BASE_URL в ai_api.lua включает /v1 (…/v1); здесь chat_url уже содержит /v1 — срезаем хвост
          custom = openai_compat(
            "custom",
            "Свой сервис",
            ((vim.env.AI_BASE_URL or "http://localhost:8080"):gsub("/v1/?$", "")),
            "AI_API_KEY",
            vim.env.AI_MODEL or "model"
          ),
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
          adapter = chat_adapter,
          keymaps = {
            close = { modes = { n = "q", i = "<C-c>" } },
            stop = { modes = { n = "<C-c>" } },
          },
        },
        inline = { adapter = cc },
        agent = { adapter = cc },
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
