return {
  {
    'echasnovski/mini.animate',
    version = '*',
    config = function()
      local animate = require('mini.animate')
      animate.setup()
      
      -- Горячая клавиша для ВКЛ/ВЫКЛ анимаций
      vim.keymap.set('n', '<leader>ua', function()
        if vim.g.minianimate_disable then
          vim.g.minianimate_disable = false
          print('Анимации включены')
        else
          vim.g.minianimate_disable = true
          print('Анимации выключены')
        end
      end, { desc = 'Переключить анимации' })
    end
  }
}