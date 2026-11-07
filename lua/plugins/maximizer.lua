return {
  {
    'szw/vim-maximizer',
    cmd = { "MaximizerToggle" }, -- стаб для <cmd> из which-key до загрузки
    keys = {
      { '<leader>um', '<cmd>MaximizerToggle<CR>', desc = '🪟 Развернуть/восстановить окно' },
      -- «!» — это НЕ «toggle с подтверждением»: у vim-maximizer Bang-версия
      -- форсирует ВОССТАНОВЛЕНИЕ сохранённой раскладки (README, «The toggle
      -- command can be invoked with a bang»).
      { '<leader>uM', '<cmd>MaximizerToggle!<CR>', desc = '🪟 Принудительно вернуть раскладку' },
    },
    -- <leader>m отдан отделу Telegram (lua/config/telegram.lua), а разворот
    -- окна живёт напрямую в отделе Визуал (<leader>um / <leader>uM).
  }
}
