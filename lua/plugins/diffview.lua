-- Diffview: сравнение веток/коммитов, история файла, разрешение конфликтов.
return {
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
  },
}
