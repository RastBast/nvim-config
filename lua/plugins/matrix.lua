return {
  {
    'eandrju/cellular-automaton.nvim',
    config = function()
      -- Назначаем привычную команду :Matrix, чтобы она запускала эффект дождя
      vim.api.nvim_create_user_command('Matrix', 'CellularAutomaton make_it_rain', {})
      vim.keymap.set('n', '<leader>fL', '<cmd>CellularAutomaton make_it_rain<CR>', { desc = '🚀 Запустить Матрицу' })
    end
  }
}