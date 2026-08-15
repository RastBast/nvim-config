return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      -- опционально, для улучшенного отображения
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("codecompanion").setup({
        -- Настройка адаптера для Kimi (Moonshot AI)
        adapters = {
          kimi = function()
            return require("codecompanion.adapters").extend("openai", {
              name = "kimi",
              env = {
                -- Получаем ключ из переменной окружения
                api_key = os.getenv("MOONSHOT_API_KEY"),
              },
              url = "https://api.moonshot.cn/v1/chat/completions",
              schema = {
                model = {
                  default = "moonshot-v1-8k", -- можно заменить на 32k или 128k
                },
                temperature = {
                  default = 0.7,
                },
              },
              headers = {
                ["Content-Type"] = "application/json",
                ["Authorization"] = "Bearer ${api_key}",
              },
            })
          end,
        },
        
        -- Стратегии использования
        strategies = {
          chat = {
            adapter = "kimi",
            keymaps = {
              close = { modes = { n = "q", i = "<C-c>" } },
              stop = { modes = { n = "<C-c>" } },
            },
          },
          inline = {
            adapter = "kimi",
            keymaps = {
              accept_change = { modes = { n = "ga" } },
              reject_change = { modes = { n = "gr" } },
            },
          },
          agent = {
            adapter = "kimi",
          },
        },
        
        -- Отображение
        display = {
          chat = {
            window = {
              position = "right",
              width = 0.35,
            },
          },
          diff = {
            provider = "mini_diff", -- или "default"
          },
        },
        
        -- Промпты (опционально, можно оставить дефолтные)
        prompt_library = {
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
      })
    end,
    keys = {
      -- Твои бинды из which-key будут работать, но можно добавить и здесь для наглядности
      { "<leader>Hat", "<cmd>CodeCompanionChat<cr>", desc = "💬 Чат с Kimi" },
      { "<leader>Hai", "<cmd>CodeCompanionActions<cr>", desc = "🛠 Действия AI" },
      { "<leader>Hae", "<cmd>CodeCompanionSend<cr>", mode = { "n", "v" }, desc = "📤 Отправить в Kimi" },
      -- Быстрый доступ к inline-редактированию
      { "<leader>Hac", "<cmd>CodeCompanion<cr>", mode = { "n", "v" }, desc = "✨ Inline код" },
    },
  },
  
  -- Опционально: плагин для отображения diff (если хочешь красивое сравнение изменений)
  {
    "echasnovski/mini.diff",
    version = false,
    config = function()
      require("mini.diff").setup()
    end,
  },
}
