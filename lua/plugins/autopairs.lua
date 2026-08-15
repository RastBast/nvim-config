return {
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    config = function()
      local autopairs = require('nvim-autopairs')
      autopairs.setup({
        check_ts = true, -- использовать Treesitter для проверки контекста
        ts_config = {
          lua = { 'string' }, -- не добавлять пары в строках lua
          javascript = { 'template_string' },
          go = { 'string' },
        },
      })

      -- Интеграция с автодополнением (cmp)
      -- Чтобы при выборе функции из списка скобки добавлялись сами
      local cmp_autopairs = require('nvim-autopairs.completion.cmp')
      local cmp = require('cmp')
      cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done())
    end,
  }
}