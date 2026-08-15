return {
  {
    'epwalsh/obsidian.nvim',
    version = '*',
    lazy = true,
    ft = 'markdown',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('obsidian').setup({
        workspaces = {
          {
            name = 'main',
            path = '~/obsidian_base/',
          },
        },
        -- Настройки заметок
        notes_subdir = 'notes', -- папка для новых заметок (если нужно)
        new_notes_location = 'notes_subdir',
        
        -- Интеграция с автодополнением
        completion = {
          nvim_cmp = true,
          min_chars = 2,
        },

        -- Настройка того, как выглядят ссылки
        ui = {
          enable = true,
          update_debounce = 200,
          checkboxes = {
            [' '] = { char = '  ', hl_group = 'ObsidianTodo' },
            ['x'] = { char = '', hl_group = 'ObsidianDone' },
          },
        },

        -- Горячие клавиши внутри Obsidian файлов
        mappings = {
          -- Перейти по ссылке под курсором (вместо gf)
          ['<leader>of'] = { action = function() return require('obsidian').util.gf_passthrough() end, opts = { buffer = true }, desc = 'Перейти по ссылке' },
          -- Переключить чекбокс
          ['<leader>ot'] = { action = function() return require('obsidian').util.toggle_checkbox() end, opts = { buffer = true }, desc = 'Чекбокс' },
        },
      })
    end,
  }
}