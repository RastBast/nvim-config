-- ========================================================================== --
--   MARKDOWN: КРАСИВО В ТЕРМИНАЛЕ + СКЛАДКИ + LIVE-ПРЕВЬЮ (см. md_preview)   --
-- ========================================================================== --
-- 1. render-markdown.nvim — WYSIWYG прямо в nvim: скрывает символы разметки,
--    заголовки с иконками, списки с маркерами, таблицы и код через Treesitter.
-- 2. Preservim/vim-markdown — классика: сворачивание разделов (folding),
--    переходы по заголовкам (]] / [[ / :Toc), авто-отступы списков,
--    :TableFormat для таблиц. Добавлен 2026-10-28 по просьбе пользователя.
-- 3. Live-превью в браузере — lua/config/md_preview.lua (:MdPreview, <leader>Im).
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    ft = { "markdown", "obsidian", "Avante" }, -- Avante — для рендера ответов ИИ
    config = function()
      require("render-markdown").setup({
        file_types = { "markdown", "obsidian", "Avante" },
        heading = {
          icons = { "❶ ", "❷ ", "❸ ", "❹ ", "❺ ", "❻ " }, -- красивые цифры для заголовков
        },
        code = {
          style = "normal",
          highlight = "RenderMarkdownCode",
        },
        checkbox = {
          unchecked = { icon = "☐ " },
          checked = { icon = "☑ " },
        },
        bullet = {
          icons = { "•", "◦", "" },
        },
      })
    end,
  },
  {
    "Preservim/vim-markdown",
    ft = "markdown",
    dependencies = { "godlygeek/tabular" }, -- нужен для :TableFormat
    init = function()
      -- globals читаются vim-markdown при загрузке ftplugin — ставим ДО неё
      vim.g.vim_markdown_folding_level = 1   -- складки с уровня 1 (zM сворачивает)
      vim.g.vim_markdown_frontmatter = 1     -- yaml-frontmatter не ломает складки
      vim.g.vim_markdown_json_frontmatter = 1
      vim.g.vim_markdown_toml_frontmatter = 1
      vim.g.vim_markdown_toc_autofit = 1
      vim.g.vim_markdown_math = 1            -- $…$$ как math
      -- conceal код-блоков оставим render-markdown: двойной conceal мигает
      vim.g.vim_markdown_conceal_code_blocks = 0
    end,
    config = function()
      vim.keymap.set("n", "<leader>It", "<cmd>Toc<cr>", { desc = "📑 Markdown: оглавление (:Toc)" })
      vim.keymap.set("n", "<leader>IT", "<cmd>TableFormat<cr>", { desc = "📐 Markdown: выровнять таблицу" })
    end,
  },
}
