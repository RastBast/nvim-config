-- ========================================================================== --
--                     ФОРМАТИРОВАНИЕ (conform.nvim)                          --
-- ========================================================================== --
-- ИСПРАВЛЕНО: `lsp_fallback = true` — устаревший ключ. В текущем
-- conform.nvim список разрешённых опций форматирования:
--   allowed_default_opts = { "timeout_ms", "lsp_format", "quiet", "stop_after_first" }
-- `lsp_fallback` поддерживается только внутри conform.format() ради
-- обратной совместимости, в config'е его быть не должно — нужен
-- lsp_format = "fallback".
return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo", "Format" },
    keys = {
      { "<leader>cf", function() require("conform").format({ async = true }) end, desc = "🎨 Форматировать файл" },
    },
    opts = {
      formatters_by_ft = {
        go = { "goimports", "gofmt" },
        lua = { "stylua" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        css = { "prettier" },
        html = { "prettier" },
        markdown = { "prettier" },
        sql = { "sqlformat" },
        xml = { "xmlformat" },
        sh = { "shfmt" },
        ["_"] = { "trim_whitespace", "trim_newlines" },
      },
      format_on_save = {
        timeout_ms = 1000,
        lsp_format = "fallback", -- если нет внешнего форматтера — через LSP
      },
    },
  },
}
