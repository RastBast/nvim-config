return {
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/neotest-go',
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    config = function()
      require('neotest').setup({
        adapters = {
          require('neotest-go')({
            recursive_run = true,
          })
        }
      })
      -- ГОРЯЧИЕ КЛАВИШИ:
      vim.keymap.set('n', '<leader>tr', function() require('neotest').run.run() end, { desc = 'Запустить тест под курсором' })
      vim.keymap.set('n', '<leader>tf', function() require('neotest').run.run(vim.fn.expand("%")) end, { desc = 'Запустить тесты в файле' })
      vim.keymap.set('n', '<leader>ts', function() require('neotest').summary.toggle() end, { desc = 'Панель тестов (IDE style)' })
      vim.keymap.set('n', '<leader>to', function() require('neotest').output.open({ enter = true }) end, { desc = 'Показать лог ошибки' })
    end
  }
}