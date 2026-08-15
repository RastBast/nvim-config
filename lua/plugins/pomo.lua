return {
  {
    'epwalsh/pomo.nvim',
    version = '*',
    lazy = true,
    cmd = { 'PomoStart', 'PomoStop', 'PomoPause' },
    config = function()
      require('pomo').setup({
        -- Уведомления будут всплывать через твой nvim-notify
        notifiers = {
          { name = 'notify', opts = { title = 'Pomo.nvim' } },
        },
        -- Настройка времени (в секундах)
        work_time = 1500,  -- 25 минут
        break_time = 300,  -- 5 минут
      })
      
      -- Горячие клавиши для управления
      vim.keymap.set('n', '<leader>pt', '<cmd>PomoStart<CR>', { desc = '⏱️ Запустить таймер' })
      vim.keymap.set('n', '<leader>ps', '<cmd>PomoStop<CR>', { desc = '⏱️ Остановить таймер' })
    end,
  }
}