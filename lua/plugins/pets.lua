return {
  {
    'giusgad/pets.nvim',
    dependencies = {
      'giusgad/hologram.nvim', -- нужен для рендеринга
      'MunifTanjim/nui.nvim',
    },
    config = function()
      require('pets').setup({
        row = 1, -- позиция над статус-баром
        col = 0,
        default_pet = 'dog', -- по умолчанию, но мы сейчас вызовем другого
        default_style = 'brown',
      })
      
      -- Команда для призыва: Space + up (User Pet)
      vim.keymap.set('n', '<leader>up', ':PetsNew custom holli brown<CR>', { desc = 'Призвать питомца' })
    end
  }
}