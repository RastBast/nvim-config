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
}

