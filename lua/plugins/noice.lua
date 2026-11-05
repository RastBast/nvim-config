return {
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    keys = {
      { '<leader>xe', function() require('config.error_history').last() end, desc = 'Последние 10 ошибок Neovim' },
      { '<leader>xl', function() require('config.error_history').log() end, desc = 'Журнал ошибок Neovim' },
    },
    dependencies = {
      'MunifTanjim/nui.nvim',
      'rcarriga/nvim-notify',
    },
    config = function()
      require('noice').setup({
        -- Noice хранит типизированные ошибки этого сеанса: и vim.notify(ERROR),
        -- и ошибки самого Neovim. count выбирает последние по времени;
        -- reverse здесь не нужен, иначе Noice выберет самые старые десять.
        commands = {
          errors10 = {
            view = 'split', opts = { enter = true, format = 'details' },
            filter = { error = true }, filter_opts = { count = 10 },
          },
          errorlog = {
            view = 'split', opts = { enter = true, format = 'details' },
            filter = { error = true },
          },
        },
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