return {
  {
    'numToStr/Comment.nvim',
    opts = {}, -- пустые опции включают стандартные настройки
    config = function()
      require('Comment').setup()
      -- Теперь жми:
      -- 'gcc' чтобы закомментировать строку
      -- 'gc' в визуальном режиме, чтобы закомментировать выделение
    end
  }
}

