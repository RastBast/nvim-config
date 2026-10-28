-- ========================================================================== --
--         ХЛЕБНЫЕ КРОШКИ (nvim-navic) — замена заброшенному barbecue         --
-- ========================================================================== --
-- ИСПРАВЛЕНО: utilyre/barbecue.nvim АРХИВЕН (GitHub: archived = true,
-- последний коммит 2024-08-20) и на свежих Neovim падает.
-- barbecue был лишь обёрткой над SmiteshP/nvim-navic, поэтому ставим
-- сам navic и рисуем его в winbar — то же самое, но живой плагин.
return {
  {
    "SmiteshP/nvim-navic",
    lazy = false,
    dependencies = { "neovim/nvim-lspconfig" },
    init = function()
      vim.g.navic_silence = true -- не ругаться, если сервер не даёт символы
    end,
    opts = {
      separator = " › ",
      depth_limit = 4,
      highlight = true,
      icons = {
        File = "󰈙 ", Module = "󰏗 ", Namespace = " ", Package = " ",
        Class = " ", Method = " ", Property = " ", Field = " ",
        Constructor = " ", Enum = " ", Interface = " ", Function = " ",
        Variable = " ", Constant = " ", String = " ", Number = " ",
        Boolean = " ", Array = " ", Object = " ", Key = " ",
        Null = " ", EnumMember = " ", Struct = " ", Event = " ",
        Operator = " ", TypeParameter = " ",
      },
    },
    config = function(_, opts)
      local navic = require("nvim-navic")
      navic.setup(opts)

      -- Подключаем к каждому буферу, где LSP умеет documentSymbol
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserNavic", { clear = true }),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.server_capabilities.documentSymbolProvider then
            pcall(navic.attach, client, args.buf)
          end
        end,
      })

      -- Хлебные крошки в верхнюю строку окна
      vim.opt.winbar = "%{%v:lua.require'nvim-navic'.get_location()%}"
    end,
  },
}
