-- Тест команд конструктора в реальном Neovim. Запускается только через
-- architecture_nvim_smoke.py, файлы создаются во временном каталоге.
local root, output = vim.env.ARCH_TEST_CONFIG, vim.env.ARCH_TEST_FILE
vim.opt.rtp:prepend(root)
require("config.architecture").setup()
local messages = {}
local echo = vim.api.nvim_echo
vim.api.nvim_echo = function(chunks, history, opts)
  for _, chunk in ipairs(chunks) do messages[#messages + 1] = chunk[1] end
  return echo(chunks, history, opts)
end
local preview_count = 0
vim.api.nvim_create_user_command("MarkdownPreview", function() preview_count = preview_count + 1 end, {})

vim.cmd.ArchNew({ args = { output } })
assert(vim.api.nvim_buf_get_name(0) == output, "путь с пробелами потерян")
assert(vim.uv.fs_stat(output) == nil, "новый файл записан без разрешения")
assert(vim.bo.modified, "шаблон не считается несохранённым")
local before = vim.api.nvim_buf_get_lines(0, 0, -1, false)
vim.cmd.ArchNew({ args = { output } })
assert(vim.deep_equal(before, vim.api.nvim_buf_get_lines(0, 0, -1, false)), "существующий буфер перезаписан")

local inputs = { 'Auth "OAuth" | #<team>&', "HTTPS | JSON" }
local selections = { "N1", "N4" }
vim.ui.input = function(_, cb) cb(table.remove(inputs, 1)) end
vim.ui.select = function(items, _, cb)
  local wanted = table.remove(selections, 1)
  for _, item in ipairs(items) do if item.id == wanted then return cb(item) end end
  error("узел не найден: " .. tostring(wanted))
end
vim.cmd.ArchNode()
vim.cmd.ArchLink()
local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert(text:find('N4["Auth #quot;OAuth#quot; #124; #35;#60;team#62;#38;"]', 1, true), text)
assert(text:find('N1 -->|"HTTPS #124; JSON"| N4', 1, true), text)
vim.cmd.ArchPreview()
assert(preview_count == 1, "ArchPreview не вызвал MarkdownPreview")
vim.cmd.write()
assert(vim.uv.fs_stat(output) ~= nil, ":write не сохранил результат")
print("OK   реальный Neovim: команды, безопасный буфер, компоненты и связи")
vim.cmd("qa!")
