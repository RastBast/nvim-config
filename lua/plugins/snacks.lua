-- ========================================================================== --
--                        SNACKS.NVIM (НОВОЕ + ЧЕРНОВИКИ)                     --
-- ========================================================================== --
-- ИСПРАВЛЕНО: lua/plugins/bigfile.lua указывал на folke/bigfile.nvim —
-- этого репозитория БОЛЬШЕ НЕ СУЩЕСТВУЕТ (GitHub отдаёт 404, плагин
-- переехал внутрь snacks.nvim). Спека была с enabled = false, так что
-- больших файлов не защищало ничего.
--
-- Здесь snacks.nvim собран в одном месте: черновики (были в scratch.lua)
-- + bigfile + подсветка отступов + улучшенный picker.
return {
  {
    "folke/snacks.nvim",
    priority = 900,
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      bigfile = { enabled = true, size = 1024 * 1024 }, -- 1 МБ
      scratch = { enabled = true },
      indent = { enabled = true, animate = { enabled = false } },
      quickfile = { enabled = true },
      statuscolumn = { enabled = false }, -- колонку рисуем сами (signcolumn = yes)
      words = { enabled = true },        -- подсветка слова под курсором (L<->n)
    },
    keys = {
      { "<leader>ns", function() Snacks.scratch() end, desc = "📓 Черновик" },
      { "<leader>nS", function() Snacks.scratch.select() end, desc = "📓 История черновиков" },
      -- УБРАНО: <leader>nh — оно уже занято под :nohlsearch в init.lua
      { "]]", function() Snacks.words.jump(1, true) end, desc = "Следующее слово", mode = { "n", "t" } },
      { "[[", function() Snacks.words.jump(-1, true) end, desc = "Предыдущее слово", mode = { "n", "t" } },
      { "<leader>un", function() Snacks.notifier.hide() end, desc = "🔕 Спрятать уведомления" },
      -- Git-клавиши здесь намеренно не объявляем: <leader>g* занят
      -- lazygit/gitsigns/go.nvim. Blame строки — <leader>Hgb (gitsigns).
    },
  },
}
