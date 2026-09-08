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
          override = {
            ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
            ['vim.lsp.util.stylize_markdown'] = true,
            -- НЕ true: эту функцию уже подменяет lua/plugins/completions.lua
            -- (перевод окна документации cmp на русский через config.ru_util).
            -- При = true noice ругается «cmp.entry.get_documentation has been
            -- overwritten by another plugin?» и просит именно enabled = false.
            ['cmp.entry.get_documentation'] = { enabled = false },
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