return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    ft = { "markdown", "obsidian" }, -- включаем для MD и Obsidian
    config = function()
      require("render-markdown").setup({
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

