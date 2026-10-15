return {
  {
    'szw/vim-maximizer',
    cmd = { "MaximizerToggle" }, -- стаб для <cmd> из which-key до загрузки
    keys = {
      { '<leader>Hum', '<cmd>MaximizerToggle<CR>', desc = '🪟 Развернуть/восстановить окно' },
      -- «!» — это НЕ «toggle с подтверждением»: у vim-maximizer Bang-версия
      -- форсирует ВОССТАНОВЛЕНИЕ сохранённой раскладки (README, «The toggle
      -- command can be invoked with a bang»). До этой правки <leader>Hum из
      -- which-key звал именно её: окно никогда не разворачивалось, а только
      -- «чинилось» назад к сохранённой раскладке.
      { '<leader>HuM', '<cmd>MaximizerToggle!<CR>', desc = '🪟 Принудительно вернуть раскладку' },
    },
    -- ИСПРАВЛЕНО: <leader>m был занят maximizer'ом и одновременно являлся
    -- префиксом отдела TG (lua/config/telegram.lua) — нажатие <leader>m
    -- молча разворачивало окно вместо меню Telegram. Клавиша переехала на
    -- <leader>Hum, <leader>m отдаён группе.
  }
}
