-- ========================================================================== --
--                    НОВОЕ: улучшенный QuickFix (nvim-bqf)                   --
-- ========================================================================== --
-- Quickfix/loclist с предпросмотром результата и нормальной навигацией —
-- то, чего не хватало при работе с :TodoQuickFix, LSP-ссылками и grep.
return {
  {
    "kevinhwang91/nvim-bqf",
    ft = "qf",
    opts = {
      auto_enable = true,
      preview = {
        auto_preview = true,
        should_preview_cb = function(bufnr)
          -- не открывать предпросмотр для гигантских файлов
          local ok, api = pcall(vim.api.nvim_buf_get_name, bufnr)
          if not ok then return true end
          local fsize = vim.fn.getfsize(api)
          return fsize < 5 * 1024 * 1024
        end,
      },
      func_map = {
        vsplit = "v",
        split = "s",
        tab = "t",
        prevfile = "K",
        nextfile = "J",
      },
    },
  },
}
