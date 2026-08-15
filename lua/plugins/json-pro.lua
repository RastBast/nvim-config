return {
  -- Визуальное дерево для JSON (как в VSCode)
  {
    'stevearc/aerial.nvim', -- Мы его используем для Go, но он идеален и для JSON
    config = function()
      require('aerial').setup({
        backends = { 'treesitter', 'lsp' },
        layout = { min_width = 30 },
        show_guides = true,
      })
      vim.keymap.set('n', '<leader>aj', '<cmd>AerialToggle!<cr>', { desc = '🌳 Дерево JSON/Структура' })
    end
  },

  -- Инструменты для работы с JSON (JQ)
  {
    'gennaro-tedesco/nvim-jqx',
    ft = { 'json', 'yaml' },
    config = function()
      -- Показывает типы данных в JSON
      vim.keymap.set('n', '<leader>jx', '<cmd>JqxList<cr>', { desc = '🔍 Список ключей JSON' })
    end
  }
}