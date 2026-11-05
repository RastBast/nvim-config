return {
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { win = { position = "bottom", size = 10 } },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Проблемы: все файлы" },
      { "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Проблемы: текущий буфер" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Проблемы: quickfix" },
      { "<leader>xl", "<cmd>Trouble loclist toggle<cr>", desc = "Проблемы: location list" },
    },
  },
}
