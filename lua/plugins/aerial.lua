-- ========================================================================== --
--                    AERIAL: СТРУКТУРА ФАЙЛА / ДЕРЕВО JSON                    --
-- ========================================================================== --
-- ИСПРАВЛЕНО: stevearc/aerial.nvim был объявлен дважды — здесь и в
-- lua/plugins/json-pro.lua. lazy.nvim склеивает спеки, но config остаётся
-- только один, поэтому часть настроек/клавиш терялась. Теперь владелец —
-- только этот файл.
return {
  {
    "stevearc/aerial.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    cmd = { "AerialToggle", "AerialOpen", "AerialInfo" },
    keys = {
      { "<leader>a", "<cmd>AerialToggle! left<CR>", desc = "📑 Структура кода" },
      { "<leader>aj", "<cmd>AerialToggle!<CR>", desc = "🌳 Дерево JSON/структура" },
    },
    opts = {
      backends = { "treesitter", "lsp", "markdown" },
      layout = { min_width = 30 },
      show_guides = true,
      filter_kind = false, -- показывать все символы, а не только "важные"
      close_automatic_events = { "BufHidden" },
    },
  },
}
