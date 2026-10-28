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
-- Если попали в терминал (toggleterm) — сразу включаем режим ввода (startinsert).
local function win_nav(dir)
  return function()
    vim.cmd("wincmd " .. dir)
    if vim.bo.buftype == "terminal" then
      vim.cmd("startinsert")
    end
  end
end
vim.keymap.set("n", "<C-h>", win_nav("h"), { desc = "Окно слева" })
vim.keymap.set("n", "<C-j>", win_nav("j"), { desc = "Окно снизу (терминал — сразу ввод)" })
vim.keymap.set("n", "<C-k>", win_nav("k"), { desc = "Окно сверху" })
vim.keymap.set("n", "<C-l>", win_nav("l"), { desc = "Окно справа" })
-- Из терминала: <C-\><C-n> → обычный режим, потом <C-h/j/k/l> или <leader>W*

-- БЫСТРОЕ ПЕРЕМЕЩЕНИЕ ПО ТЕКСТУ (поверх стандартных w/b/e, {/}, <C-o>/<C-i>)
-- H/L: в начало/конец строки. Экранные H (верх окна) и L (низ) сознательно
-- заменены; середину окна по-прежнему даёт M.
vim.keymap.set({ "n", "v" }, "H", "^", { desc = "⬅ В начало строки" })
vim.keymap.set({ "n", "v" }, "L", "$", { desc = "➡ В конец строки" })
-- n/N: переход к совпадению всегда по центру экрана (с открытием складки)
vim.keymap.set("n", "n", "nzzzv", { desc = "🔍 Следующее совпадение (по центру)" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "🔍 Предыдущее совпадение (по центру)" })
-- q забрал spider (умное назад-слово, lua/plugins/spider.lua) — запись
-- макросов переезжает на Q (родной Ex-режим Q всё равно не нужен: есть gQ).
vim.keymap.set("n", "Q", "q", { desc = "🎙 Запись макроса (раньше q)" })

-- ПАЛИТРА КОМАНД: пробел-пробел → список всех :команд с описаниями
-- (lua/config/cmd_palette.lua; новые команды попадают в список сами)
vim.keymap.set("n", "<leader><Space>", function()
  require("config.cmd_palette").open()
end, { desc = "⌨ Поиск команд (все :команды)" })

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
