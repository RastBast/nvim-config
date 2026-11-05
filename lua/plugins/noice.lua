return {
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = {
      'MunifTanjim/nui.nvim',
      'rcarriga/nvim-notify',
    },
    config = function()
      require('noice').setup({
        lsp = {
          -- ВАЖНО: hover выключен. По умолчанию noice подменяет vim.lsp.buf.hover
          -- на свою функцию и показывает подсказку в своём окне, мимо
          -- vim.lsp.util.open_floating_preview. Из-за этого перехват перевода
          -- (lua/config/hover_ru.lua) на K не срабатывал. С hover = false K
          -- идёт штатным путём и перевод показывается сразу.
          hover = { enabled = false },
          override = {
            ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
            ['vim.lsp.util.stylize_markdown'] = true,
            -- НЕ true: эту функцию уже подменяет lua/plugins/completions.lua
            -- (перевод окна документации cmp на русский через config.ru_util).
            -- В закреплённом Noice это boolean: таблица даже с enabled=false
            -- истинна в Lua и включает override, вызывая конфликт.
            ['cmp.entry.get_documentation'] = false,
          },
        },
        presets = {
          bottom_search = true,
          command_palette = true,
          long_message_to_split = true,
          inc_rename = false,
          lsp_doc_border = true,
        },
      })
    end,
  }
}