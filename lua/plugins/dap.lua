return {
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      'rcarriga/nvim-dap-ui',
      'leoluz/nvim-dap-go',
      'nvim-neotest/nvim-nio',
    },
    config = function()
      local dap = require('dap')
      local dapui = require('dapui')
      require('dap-go').setup()
      require('dapui').setup()

      -- Авто-открытие окон при старте отладки
      dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end
      dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end
      dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end

      -- Кнопки управления
      vim.keymap.set('n', '<F5>', function() dap.continue() end, { desc = '▶ Запуск / Продолжить' })
      vim.keymap.set('n', '<F10>', function() dap.step_over() end, { desc = '↷ Шаг через' })
      vim.keymap.set('n', '<F11>', function() dap.step_into() end, { desc = '↴ Шаг в' })
      vim.keymap.set('n', '<leader>db', function() dap.toggle_breakpoint() end, { desc = '🛑 Точка остановки' })
      vim.keymap.set('n', '<leader>dt', function() require('dap-go').debug_test() end, { desc = '🧪 Отладка теста' })
    end
  }
}