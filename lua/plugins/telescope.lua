return {
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local builtin = require('telescope.builtin')
      -- Поиск файлов по названию (Cmd + P)
      vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = "Поиск файлов" })
      -- Поиск текста внутри всех файлов (как в VSCode поиск слева)
      vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = "Поиск текста" })
      -- Поиск по твоим заметкам в Obsidian
      vim.keymap.set('n', '<leader>fn', function()
        builtin.find_files({ cwd = "~/Documents/ObsidianVault" }) -- УКАЖИ СВОЙ ПУТЬ
      end, { desc = "Поиск в Obsidian" })
    end
  }
}

