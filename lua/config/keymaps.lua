-- ПЕРЕМЕЩЕНИЕ между окнами (Ctrl + hjkl)
-- Теперь вместо стрелок зажимаешь Ctrl и двигаешься как обычно
vim.keymap.set('n', '<C-h>', '<C-w>h') -- влево
vim.keymap.set('n', '<C-j>', '<C-w>j') -- вниз
vim.keymap.set('n', '<C-k>', '<C-w>k') -- вверх
vim.keymap.set('n', '<C-l>', '<C-w>l') -- вправо

-- ИЗМЕНЕНИЕ РАЗМЕРА окон (Alt + hjkl)
-- На Маке клавиша Alt — это Option (⌥)
vim.keymap.set('n', '<M-h>', ':vertical resize -2<CR>')
vim.keymap.set('n', '<M-j>', ':resize +2<CR>')
vim.keymap.set('n', '<M-k>', ':resize -2<CR>')
vim.keymap.set('n', '<M-l>', ':vertical resize +2<CR>')

-- БЫСТРЫЕ СПЛИТЫ (чтобы не писать :vsplit)
-- Leader (обычно пробел) + v или h
vim.keymap.set('n', '<leader>v', ':vsplit<CR>') -- вертикально
vim.keymap.set('n', '<leader>s', ':split<CR>')  -- горизонтально
