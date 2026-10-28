-- ========================================================================== --
--                       ЦВЕТОВАЯ СХЕМА (НОВОЕ)                               --
-- ========================================================================== --
-- Раньше темы в конфиге не было вообще: init.lua делал
-- `colorscheme <vim.g.colors_name or "habamax">`, а colors_name на старте
-- всегда nil — то есть всегда включался дефолтный habamax.
-- Тему выбирают через <leader>uT / :Theme (lua/config/themes.lua).
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
        -- Подсветка задаётся темами (lua/config/themes.lua), здесь не дублируется
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

  -- ----------------------------------------------------------------------
  -- Полные схемы для <leader>uT / :Theme. lazy = true: грузятся только при
  -- выборе темы (themes.lua → require("lazy").load). Имена plugin в themes.lua
  -- совпадают с name ниже.
  -- ----------------------------------------------------------------------
  { "folke/tokyonight.nvim", name = "tokyonight.nvim", lazy = true, priority = 1000 },
  { "ellisonleao/gruvbox.nvim", name = "gruvbox.nvim", lazy = true, priority = 1000 },
  { "rebelot/kanagawa.nvim", name = "kanagawa.nvim", lazy = true, priority = 1000 },
  { "rose-pine/neovim", name = "rose-pine", lazy = true, priority = 1000 },
  { "EdenEast/nightfox.nvim", name = "nightfox.nvim", lazy = true, priority = 1000 },
}
