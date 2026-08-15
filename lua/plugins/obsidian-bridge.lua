return {
  {
    'oflisback/obsidian-bridge.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    event = { 'BufReadPre *.md', 'BufNewFile *.md' },
    opts = {
      scroll_sync = true,
      obsidian_server_address = 'http://localhost:27123',
    },
    config = function(_, opts)
      require('obsidian-bridge').setup(opts)
      -- Горячая клавиша для принудительной синхронизации
      vim.keymap.set('n', '<leader>ob', '<cmd>ObsidianBridgeToggle<CR>', { desc = '🔗 Связь с Obsidian' })
    end,
  }
}