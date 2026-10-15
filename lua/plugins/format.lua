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
    -- Команды conform: только ConformInfo. Раньше здесь был «Format» — такой
    -- команды у conform НЕТ (E492 при вызове), форматирование — <leader>cf.
    cmd = { "ConformInfo" },
    keys = {
      { "<leader>cf", function() require("conform").format({ async = true }) end, desc = "🎨 Форматировать файл" },
    },
    opts = {
      -- Базовые форматтеры ≈40 языков — из lua/config/languages.lua;
      -- записи ниже (уже были в конфиге) имеют приоритет над ними.
      formatters_by_ft = vim.tbl_extend("force", require("config.languages").formatters(), {
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
        sql = { "sqlfluff" }, -- ИСПРАВЛЕНО: "sqlformat" в conform не существует
        xml = { "xmlformat" },
        sh = { "shfmt" },
        proto = { "buf" }, -- buf format; если buf нет — фолбэк через LSP (protols)
        ["_"] = { "trim_whitespace", "trim_newlines" },
      }),
      format_on_save = {
        timeout_ms = 1000,
        lsp_format = "fallback", -- если нет внешнего форматтера — через LSP
      },
    },
  },
}
