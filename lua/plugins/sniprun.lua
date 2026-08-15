return {
  {
    'michaelb/sniprun',
    build = 'sh ./install.sh',
    config = function()
      vim.keymap.set('v', '<leader>r', '<cmd>SnipRun<CR>', { desc = 'Запустить кусок кода' })
    end
  }
}