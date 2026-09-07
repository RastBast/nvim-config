return {
  {
    'szw/vim-maximizer',
    cmd = { "MaximizerToggle" }, -- стаб для <cmd> из which-key до загрузки
    keys = {
      { '<leader>m', '<cmd>MaximizerToggle<CR>', desc = 'Развернуть окно' },
    },
  }
}