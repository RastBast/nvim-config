return {
  {
    'folke/persistence.nvim',
    event = 'BufReadPre',
    opts = {},
    config = function()
      -- Space + qs восстановить сессию проекта
      vim.keymap.set('n', '<leader>qs', function() require('persistence').load() end)
    end
  }
}