return {
  {
    'filipdutescu/renamer.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('renamer').setup()
      vim.keymap.set('i', '<F2>', '<cmd>lua require("renamer").rename()<cr>')
      vim.keymap.set('n', '<leader>rn', '<cmd>lua require("renamer").rename()<cr>')
    end
  }
}