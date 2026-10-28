-- ========================================================================== --
--                                MARKDOWN                                    --
-- ========================================================================== --
-- 1) render-markdown.nvim — вид в терминале: заголовки, списки, таблицы,
--    чекбоксы и блоки кода рисуются красиво прямо в nvim (без браузера).
-- 2) markdown-preview.nvim — живой предпросмотр в БРАУЗЕРЕ: открывается
--    localhost-страница, обновляется сразу при каждом изменении текста.
--    <leader>mv — вкл/выкл, <leader>mV — открыть принудительно.
--    Нужен Node.js/npm (установка app — при первом :Lazy build).
-- 3) vim-markdown (preservim) — фолдинг заголовков: za / zc / zo, zR / zM,
--    переход по разделам ]] и [[, автоотступы для списков.
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
          unchecked = { icon = "   " },
          checked = { icon = "   " },
        },
      })
    end,
  },

  {
    "iamcco/markdown-preview.nvim",
    ft = { "markdown" },
    cmd = { "MarkdownPreview", "MarkdownPreviewToggle", "MarkdownPreviewStop" },
    -- Сборка: как в README плагина. Строкой, а не функцией с vim.fn[...]:
    -- на момент сборки autoload-функции mkdp#util#install ещё не в runtimepath (E117).
    -- npx --yes ставит yarn сам, нужен только Node.js/npm.
    build = "cd app && npx --yes yarn install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
      vim.g.mkdp_auto_start = 0 -- не открывать браузер сразу при входе в .md
      vim.g.mkdp_auto_close = 1 -- закрыть вкладку при выходе из буфера
      vim.g.mkdp_refresh_slow = 0 -- обновлять на КАЖДОЕ изменение текста
      vim.g.mkdp_open_to_the_world = 0 -- только localhost, в сеть не выставляем
      vim.g.mkdp_echo_preview_url = 1 -- покажем адрес в строке сообщений
      vim.g.mkdp_theme = "dark"
    end,
    keys = {
      { "<leader>mv", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown", desc = "🌐 Предпросмотр markdown в браузере: вкл/выкл" },
      { "<leader>mV", "<cmd>MarkdownPreview<cr>", ft = "markdown", desc = "🌐 Открыть предпросмотр markdown в браузере" },
    },
  },

  {
    "preservim/vim-markdown",
    ft = { "markdown" },
    init = function()
      vim.g.vim_markdown_folding_style_pythonic = 1 -- сворачивание по заголовкам (#, ##, …)
      vim.g.vim_markdown_folding_level = 2 -- по умолчанию раскрыты разделы до уровня 2
      vim.g.vim_markdown_auto_insert_bullets = 1 -- продолжать список при Enter
      vim.g.vim_markdown_new_list_item_indent = 2
      vim.g.vim_markdown_conceal = 0 -- скрытием символов занимается render-markdown
      vim.g.vim_markdown_frontmatter = 1 -- YAML-шапка (---) подсвечивается
      vim.g.vim_markdown_strikethrough = 1
    end,
  },
}
