return {
  {
    'folke/snacks.nvim',
    opts = {
      scratch = { enabled = true },
    },
    keys = {
      { '<leader>ns', function() Snacks.scratch() end, desc = '📓 Заметка (Черновик)' },
      { '<leader>nh', function() Snacks.scratch.select() end, desc = '📓 История заметок' },
    },
  }
}