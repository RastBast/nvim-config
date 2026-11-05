-- Только через tests/lsp_nil_nvim_smoke.py. Настоящий LSP-клиент Neovim,
-- реальный закреплённый nvim-lspconfig и маленький локальный fake nil сервер.
vim.opt.rtp:prepend(vim.env.NIL_TEST_ROOT)
vim.opt.rtp:prepend(vim.env.NIL_TEST_LSPCONFIG)
vim.g.mapleader = " "
local notices = {}
local echo = vim.api.nvim_echo
vim.api.nvim_echo = function(chunks, history, opts)
  for _, chunk in ipairs(chunks) do notices[#notices + 1] = chunk[1] end
  return echo(chunks, history, opts)
end
local spec = dofile(vim.env.NIL_TEST_ROOT .. "/lua/plugins/lsp-config.lua")
local opts = spec[2].opts()
assert(not vim.tbl_contains(opts.ensure_installed, "nil_ls"), "Mason всё ещё пытается установить nil_ls")
assert(vim.tbl_contains(opts.automatic_enable.exclude, "nil_ls"), "nil_ls не исключён из automatic_enable Mason")
spec[3].config()
vim.cmd.edit(vim.fn.fnameescape(vim.env.NIL_TEST_PROJECT .. "/flake.nix"))
vim.bo.filetype = "nix"
if vim.env.NIL_TEST_PRESENT == "1" then
  assert(vim.fn.executable("nil") == 1, "тестовый nil не найден")
  local bufnr = vim.api.nvim_get_current_buf()
  local attached = vim.wait(5000, function()
    for _, client in ipairs(vim.lsp.get_clients({ name = "nil_ls", bufnr = bufnr })) do
      if client.initialized and client.attached_buffers[bufnr] then return true end
    end
    return false
  end, 20)
  assert(attached, "nil_ls не подключился к Nix-буферу")
  vim.wait(100)
  assert(not table.concat(notices, "\n"):find("бинарник nil не найден", 1, true), "лишнее предупреждение")
  print("OK   реальный Neovim: nil_ls подключается к Nix при наличии бинарника")
else
  assert(vim.fn.executable("nil") == 0, "в окружении теста неожиданно найден nil")
  assert(vim.wait(1000, function() return table.concat(notices, "\n"):find("nix profile install", 1, true) ~= nil end, 10),
    "нет подсказки об установке Nix LSP")
  assert(#vim.lsp.get_clients({ name = "nil_ls", bufnr = 0 }) == 0, "LSP не должен подключаться без бинарника")
  print("OK   реальный Neovim: без nil видна подсказка, Mason его автоматически не ставит")
end
vim.cmd("qa!")
