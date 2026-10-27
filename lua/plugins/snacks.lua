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
      -- vim.ui.select → выбор в snacks picker (замена архивному dressing.nvim)
      picker = { enabled = true, ui_select = true },
      indent = { enabled = true, animate = { enabled = false } },
      quickfile = { enabled = true },
      statuscolumn = { enabled = false }, -- колонку рисуем сами (signcolumn = yes)
      words = { enabled = true },        -- подсветка слова под курсором (L<->n)
      -- картинки в nvim (Kitty graphics): Ghostty их понимает, Alacritty — нет.
      -- PNG работает без зависимостей; jpg/gif/webp — нужен ImageMagick (magick).
      image = { enabled = true },
    },
    keys = {
      { "<leader>ns", function() Snacks.scratch() end, desc = "📓 Черновик" },
      { "<leader>nS", function() Snacks.scratch.select() end, desc = "📓 История черновиков" },
      -- закрыть буфер без поломки окон (замена архивному bufdelete.nvim)
      { "<leader>bd", function() Snacks.bufdelete() end, desc = "Закрыть буфер" },
      -- УБРАНО: <leader>nh — оно уже занято под :nohlsearch в init.lua
      { "]]", function() Snacks.words.jump(1, true) end, desc = "Следующее слово", mode = { "n", "t" } },
      { "[[", function() Snacks.words.jump(-1, true) end, desc = "Предыдущее слово", mode = { "n", "t" } },
      { "<leader>un", function() Snacks.notifier.hide() end, desc = "🔕 Спрятать уведомления" },
      -- 🖼 Картинки: <leader>I* (группа в which-key)
      { "<leader>Ii", function() Snacks.image.hover() end, desc = "🖼 Показать картинку под курсором" },
      {
        "<leader>If",
        function()
          Snacks.picker.files({
            title = "🖼 Картинки в проекте",
            ft = { "png", "jpg", "jpeg", "gif", "webp" },
          })
        end,
        desc = "🖼 Найти картинку в проекте",
      },
      -- Git-клавиши здесь намеренно не объявляем: <leader>g* занят
      -- lazygit/gitsigns/go.nvim. Blame строки — <leader>Hgb (gitsigns).
    },
  },
}
