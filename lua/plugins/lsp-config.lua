return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "gopls", "ts_ls", "bashls", "dotls", "lemminx", "html", "cssls" },
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Функция для настройки серверов через новый интерфейс Neovim 0.11+
      local function setup_server(name, config)
        config = config or {}
        config.capabilities = capabilities
        
        if vim.lsp.config then
          -- Новый метод для Neovim 0.11
          vim.lsp.config(name, config)
          vim.lsp.enable(name)
        else
          -- Старый метод (fallback), если Neovim ниже 0.11
          require("lspconfig")[name].setup(config)
        end
      end

      -- 1. Настройка обычных серверов
      setup_server("ts_ls")
      setup_server("bashls")
      setup_server("dotls")

      -- 2. Настройка GOPLS (фишки GoLand: автоимпорт, плейсхолдеры)
      setup_server("gopls", {
        settings = {
          gopls = {
            completeUnimported = true,
            usePlaceholders = true,
            analyses = { unusedparams = true },
            staticcheck = true,
          },
        },
      })

      -- ГОРЯЧИЕ КЛАВИШИ
      vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Документация" })
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Действия кода (Alt+Enter)" })
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Перейти к определению" })
    end,
  },
}

