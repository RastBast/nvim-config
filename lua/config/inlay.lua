-- LSP inlay hints: выключены глобально при запуске, переключаются по буферу.
local M = {}

function M.toggle()
  local ih = vim.lsp.inlay_hint
  if not ih or not ih.enable or not ih.is_enabled then
    vim.notify("Inlay hints требуют Neovim 0.10+", vim.log.levels.WARN)
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local enabled = ih.is_enabled({ bufnr = buf })
  ih.enable(not enabled, { bufnr = buf })
  vim.notify("Inlay hints для буфера: " .. (enabled and "выкл" or "вкл"), vim.log.levels.INFO)
end

function M.setup()
  local ih = vim.lsp.inlay_hint
  if ih and ih.enable then ih.enable(false) end
  vim.keymap.set("n", "<leader>uh", M.toggle, { desc = "💡 Inlay hints в текущем буфере вкл/выкл" })
end

return M
