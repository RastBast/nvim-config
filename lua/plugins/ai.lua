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
    opts = function()
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
      local gemini_model = (type(AI.env_model) == "function" and AI.env_model("GEMINI_MODEL", "gemini-3.6-flash")) or "gemini-3.6-flash"
      local kimi_model = (type(AI.env_model) == "function" and AI.env_model("MOONSHOT_MODEL", "moonshot-v1-8k")) or "moonshot-v1-8k"
      local openrouter_model = (type(AI.env_model) == "function" and AI.env_model("OPENROUTER_MODEL", "openrouter/free")) or "openrouter/free"
      local custom_model = (type(AI.env_model) == "function" and AI.env_model("AI_MODEL", "model")) or "model"
      return {
      adapters = {
        http = {
          -- Groq: OpenAI-совместимый API, ключ — переменная GROQ_API_KEY (fish: set -Ux GROQ_API_KEY "…")
          gemini = function()
            return require("codecompanion.adapters").extend("gemini", {
              env = { api_key = function()
                local scoped = vim.env.AVANTE_GEMINI_API_KEY
                if scoped and scoped ~= "" then return scoped end
                local reg = vim.env.GEMINI_API_KEY
                if reg and reg ~= "" then return reg end
                return vim.env.GOOGLE_API_KEY
              end },
              schema = { model = { default = gemini_model } },
            })
          end,
          groq = openai_compat("groq", "Groq", "https://api.groq.com/openai/v1", "GROQ_API_KEY", groq_model),
          kimi = openai_compat("kimi", "Kimi", "https://api.moonshot.ai/v1", "MOONSHOT_API_KEY", kimi_model),
          openrouter = openai_compat("openrouter", "OpenRouter", "https://openrouter.ai/api/v1", "OPENROUTER_API_KEY", openrouter_model),
          -- Любой свой OpenAI-совместимый сервис: AI_BASE_URL, AI_API_KEY, AI_MODEL
          -- AI_BASE_URL — полный базовый путь API; /chat/completions добавится автоматически
          custom = openai_compat(
            "custom",
            "Свой сервис",
            ((vim.env.AI_BASE_URL or "http://localhost:8080/v1"):gsub("/+$", "")),
            "AI_API_KEY",
            custom_model
          ),
        },
      },

      -- По умолчанию скрываем размышления модели (только чистый ответ; переключить: <leader>Ah)
      display = {
        chat = {
          show_reasoning = (function()
            local ok_th, th = pcall(require, "config.ai_thinking")
            return ok_th and type(th) == "table" and th.is_enabled() or false
          end)(),
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
      }
    end,
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
