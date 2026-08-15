return {
  "kdheepak/lazygit.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    -- Открыть интерфейс гита на Space + g + g
    vim.keymap.set("n", "<leader>gg", ":LazyGit<CR>", { desc = "LazyGit" })
  end,
}

