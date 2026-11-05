-- Опциональная проверка реального markdown-preview.nvim (см. .py-обёртку).
-- Сервер живёт только в течение теста на localhost, браузер не открывается.
local root, plugin, path = vim.env.ARCH_TEST_CONFIG, vim.env.MARKDOWN_PREVIEW_DIR, vim.env.ARCH_PREVIEW_FILE
vim.opt.rtp:prepend(root)
vim.opt.rtp:append(plugin)
vim.g.mkdp_browserfunc = "ArchTestBrowser"
vim.cmd([[
function! ArchTestBrowser(url) abort
  let g:arch_test_url = a:url
endfunction
]])
vim.cmd.source(plugin .. "/plugin/mkdp.vim")
require("config.architecture").setup()
vim.cmd.ArchNew({ args = { path } })
assert(vim.fn.exists(":MarkdownPreview") == 2, "нет команды MarkdownPreview")
vim.cmd.ArchPreview()
assert(vim.wait(12000, function() return vim.g.arch_test_url ~= nil end, 20), "preview не запустился: " .. vim.v.errmsg)
local url = vim.g.arch_test_url
assert(url:match("^http://localhost:"), "preview должен слушать только localhost")
local function get(address)
  local result
  vim.system({ "curl", "-fsS", "--max-time", "5", address }, { text = true }, function(r)
    vim.schedule(function() result = r end)
  end)
  assert(vim.wait(7000, function() return result ~= nil end, 20), "таймаут HTTP")
  assert(result.code == 0, tostring(result.stderr))
  return result.stdout
end
local html = get(url)
assert(html:find("mermaid.min.js", 1, true), "в HTML нет Mermaid")
local base = assert(url:match("^(http://[^/]+)"))
assert(#get(base .. "/_static/mermaid.min.js") > 100000, "Mermaid asset отсутствует")
vim.cmd.MarkdownPreviewStop()
print("OK   markdown-preview.nvim: localhost HTTP и встроенный Mermaid доступны")
vim.cmd("qa!")
