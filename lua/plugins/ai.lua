-- CodeCompanion: встроенные и OpenAI-совместимые адаптеры из реестра ИИ.
-- В закреплённой версии нет встроенных HTTP-адаптеров Kimi и OpenRouter.
local AI = require("config.ai_api")

-- OpenAI-совместимые сервисы — через openai_compatible CodeCompanion.
local function openai_compat(name, label, url, key_env, model)
  return function()
    return require("codecompanion.adapters").extend("openai_compatible", {
      name = name,
      formatted_name = label,
      env = {
        url = url,
        api_key = key_env, -- ИМЯ переменной с ключом, не сам ключ
        chat_url = "/chat/completions",
        models_endpoint = "/models",
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
-- Таблица {name=...} без model в этой версии не разрешается как имя адаптера.
local chat_adapter = cc
local selected_model = cc_model()
if selected_model then
  chat_adapter = { name = cc, model = selected_model }
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
          groq = openai_compat("groq", "Groq", "https://api.groq.com/openai/v1", "GROQ_API_KEY", groq_model),
          kimi = openai_compat("kimi", "Kimi", "https://api.moonshot.ai/v1", "MOONSHOT_API_KEY", vim.env.MOONSHOT_MODEL or "moonshot-v1-8k"),
          openrouter = openai_compat("openrouter", "OpenRouter", "https://openrouter.ai/api/v1", "OPENROUTER_API_KEY", vim.env.OPENROUTER_MODEL or "openrouter/free"),
          -- Любой свой OpenAI-совместимый сервис: AI_BASE_URL, AI_API_KEY, AI_MODEL
          -- AI_BASE_URL — полный базовый путь API; /chat/completions добавится автоматически
          custom = openai_compat(
            "custom",
            "Свой сервис",
            ((vim.env.AI_BASE_URL or "http://localhost:8080/v1"):gsub("/+$", "")),
            "AI_API_KEY",
            vim.env.AI_MODEL or "model"
          ),
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
              content = function(context)
                return "Объясни подробно, что делает этот код:\n\n```" .. (context.filetype or "")
                  .. "\n" .. table.concat(context.lines or {}, "\n") .. "\n```"
              end,
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
