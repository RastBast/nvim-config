-- ========================================================================== --
--                       ЦВЕТОВАЯ СХЕМА (НОВОЕ)                               --
-- ========================================================================== --
-- Раньше темы в конфиге не было вообще: init.lua делал
-- `colorscheme <vim.g.colors_name or "habamax">`, а colors_name на старте
-- всегда nil — то есть всегда включался дефолтный habamax.
-- Теперь тема есть и применяется в init.lua через pcall.
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000, -- грузим самым первым, до остальных плагинов
    lazy = false,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha", -- самый тёмный вариант
        transparent_background = false,
        term_colors = true,
        styles = {
          comments = { "italic" },
          functions = { "bold" },
          keywords = { "bold" },
        },
        custom_highlights = function()
          -- init.lua всё равно перекрашивает фон в #061115,
          -- здесь только добираем то, что ему не покрыто
          return {
            CursorLineNr = { fg = "#d4ff3a", bold = true },
            CursorLine = { bg = "#080a26" },
            LineNr = { fg = "#2e3a55" },
          }
        end,
        integrations = {
          treesitter = true,
          native_lsp = { enabled = true },
          cmp = true,
          gitsigns = true,
          nvimtree = true,
          telescope = { enabled = true },
          notify = true,
          which_key = true,
          mason = true,
          dap = true,
          dap_ui = true,
          neotest = true,
          aerial = true,
          markdown = true,
          noice = true,
          illuminate = { enabled = true },
          indent_blankline = { enabled = true },
          mini = { enabled = true },
        },
      })
      vim.cmd.colorscheme("catppuccin-mocha")
    end,
  },
}
