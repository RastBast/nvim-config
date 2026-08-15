return {
  {
    'stevearc/conform.nvim',
    opts = {
      formatters_by_ft = {
        xml = { 'xmlformat' },
        go = { 'goimports', 'gofmt' },
        javascript = { 'prettier' },
      },
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = true,
      },
    },
  }
}