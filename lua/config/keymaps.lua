-- ========================================================================== --
--                       БАЗОВЫЕ ГОРЯЧИЕ КЛАВИШИ                              --
-- ========================================================================== --
-- ВАЖНО: этот файл теперь действительно подключается из init.lua
-- (require("config.keymaps")). Раньше он лежал мёртвым грузом.
--
-- Все маппинги здесь проверены на конфликты:
--   * <C-h/j/k/l> — только тут (из init.lua убраны дубли)
--   * <M-h>/<M-l> — ширина окна; <C-Up>/<C-Down> — высота окна
--     (<M-j>/<M-k> заняты move.nvim — перенос строк)
--   * <Tab>/<S-Tab> — bufferline.nvim, здесь их нет
--   * <leader>s — группа поиска (spectre/telescope), поэтому сплиты на - и |

-- ПЕРЕМЕЩЕНИЕ между окнами (Ctrl + hjkl)
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Окно слева" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Окно снизу" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Окно сверху" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Окно справа" })

-- ИЗМЕНЕНИЕ РАЗМЕРА окон
-- На Маке клавиша Alt — это Option (⌥)
vim.keymap.set("n", "<M-h>", ":vertical resize -2<CR>", { desc = "Уже" })
vim.keymap.set("n", "<M-l>", ":vertical resize +2<CR>", { desc = "Шире" })
vim.keymap.set("n", "<C-Up>", ":resize +2<CR>", { desc = "Выше" })
vim.keymap.set("n", "<C-Down>", ":resize -2<CR>", { desc = "Ниже" })

-- БЫСТРЫЕ СПЛИТЫ
vim.keymap.set("n", "<leader>|", ":vsplit<CR>", { desc = "Вертикальный сплит" })
vim.keymap.set("n", "<leader>-", ":split<CR>", { desc = "Горизонтальный сплит" })

-- УДОБНОЕ ВЫДЕЛЕНИЕ: после сдвига в визуальном режиме выделение не слетает
vim.keymap.set("v", "<", "<gv", { desc = "Отступ влево" })
vim.keymap.set("v", ">", ">gv", { desc = "Отступ вправо" })

-- Вставка из буфера обмена без потери текущего содержимого регистра
vim.keymap.set("v", "p", '"_dP', { desc = "Вставить, не затирая регистр" })

-- Сохранить / выйти
vim.keymap.set("n", "<leader>w", ":w<CR>", { desc = "Сохранить" })
vim.keymap.set("n", "<leader>q", ":q<CR>", { desc = "Закрыть окно" })

-- Переход в режим терминала по Esc (удобно с toggleterm)
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Выйти в Normal в терминале" })
