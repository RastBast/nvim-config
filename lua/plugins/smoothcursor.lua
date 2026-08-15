return {
  {
    'gen740/SmoothCursor.nvim',
    config = function()
      require('smoothcursor').setup({
        autostart = true,
        cursor = '▶',              -- символ курсора
        texthl = 'SmoothCursor',   -- цвет
        linehl = nil,              -- подсветка всей строки (выключена)
        type = 'default',          -- тип анимации
        fancy = {
          enable = true,           -- включаем красивый эффект
          head = { cursor = '▶', texthl = 'SmoothCursor', linehl = nil },
          body = {
            { cursor = '●', texthl = 'SmoothCursorVisual' },
            { cursor = '●', texthl = 'SmoothCursorVisual' },
            { cursor = '•', texthl = 'SmoothCursorVisual' },
            { cursor = '•', texthl = 'SmoothCursorVisual' },
            { cursor = '.', texthl = 'SmoothCursorVisual' },
          },
        },
        flyin_column = 1,          -- колонка появления
        speed = 25,                -- скорость (мс)
        intervals = 35,            -- интервал обновления
      })
    end
  }
}