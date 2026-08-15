return {
  "uga-rosa/translate.nvim",
  config = function()
    require("translate").setup({
      default = {
        command = "google",
        output = "split", -- Меняем floating на split
      },
      output_option = {
        split = {
          position = "botright", -- Строго правый нижний угол
          size = 10,             -- Высота окна (10 строк)
        },
      },
    })

    -- Горячие клавиши
    vim.keymap.set("n", "<leader>t", ":Translate ru<CR>", { desc = "Translate Word" })
    vim.keymap.set("v", "<leader>t", ":Translate ru<CR>", { desc = "Translate Selection" })
  end,
}
