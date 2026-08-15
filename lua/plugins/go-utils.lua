return {
  {
    'olexsmir/gopher.nvim',
    ft = 'go',
    config = function()
      require('gopher').setup()
    end,
    keys = {
      { '<leader>gj', '<cmd>GoDoMock<cr>', desc = 'Генерация Мока' },
      { '<leader>gie', '<cmd>GoIfErr<cr>', desc = 'Генерация if err' },
    },
    build = function()
      vim.cmd [[silent! !go install ://github.com]]
    end,
  }
}