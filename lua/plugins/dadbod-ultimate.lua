return {
  {
    'kristijanhusak/vim-dadbod-ui',
    dependencies = {
      { 'tpope/vim-dadbod', lazy = true },
      { 'kristijanhusak/vim-dadbod-completion', ft = { 'sql', 'mysql', 'plsql' }, lazy = true },
    },
    cmd = {
      'DBUI',
      'DBUIToggle',
      'DBUIAddConnection',
      'DBUIFindBuffer',
    },
    init = function()
      -- Настройки внешнего вида (чтобы было красиво как в VSCode)
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_show_database_navigation = 1
      vim.g.db_ui_win_size = 40
      vim.g.db_ui_save_location = '~/.config/nvim/db_ui'
      
      -- Чтобы сразу видеть результат в новом окне
      vim.g.db_ui_execute_on_save = 0 
    end,
    config = function()
      -- Горячие клавиши
      vim.keymap.set('n', '<leader>du', '<cmd>DBUIToggle<cr>', { desc = '🗄 Панель БД (IDE Style)' })
      vim.keymap.set('n', '<leader>dr', '<cmd>DBUIFindBuffer<cr>', { desc = '🔍 Найти текущую БД' })
      
      -- Автодополнение в SQL файлах
      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'sql', 'mysql', 'plsql' },
        callback = function()
          require('cmp').setup.buffer({
            sources = { { name = 'vim-dadbod-completion' } }
          })
        end,
      })
    end,
  },
}