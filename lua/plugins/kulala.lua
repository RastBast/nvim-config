return {
  {
    'mistweaverco/kulala.nvim',
    ft = { 'http' },
    config = function()
      require('kulala').setup({
        additional_curl_args = { '-L', '-k' },
      })
      vim.keymap.set('n', '<leader>rr', "<cmd>lua require('kulala').run()<cr>", { desc = '🚀 Запустить запрос' })
    end,
  }
}