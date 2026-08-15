-- ========================================================================== --
--                           ОСНОВНЫЕ НАСТРОЙКИ (CORE)                        --
-- ========================================================================== --

vim.g.mapleader = " " 
vim.g.maplocalleader = " "

local opt = vim.opt

-- Интерфейс
opt.number = true           -- Номера строк
opt.relativenumber = true   -- Относительные номера (удобно для прыжков типа 5j)
opt.mouse = "a"             -- Мышь работает везде
opt.termguicolors = true    -- Поддержка 24-битного цвета
opt.cursorline = true       -- Подсветка строки, на которой стоит курсор
opt.signcolumn = "yes"      -- Всегда держать колонку слева (чтобы текст не прыгал)
opt.laststatus = 3          -- Глобальный статус-бар (одна линия на все окна)
opt.showmode = false        -- Скрыть стандартную надпись -- INSERT -- (есть Lualine)

-- Поведение и Память
opt.clipboard = "unnamedplus" -- Системный буфер обмена (Cmd+C / Cmd+V)
opt.undofile = true           -- Сохранять историю изменений после закрытия файла
opt.swapfile = false          -- ОТКЛЮЧЕНО: Больше никакой ошибки W325 (Swapfile)
opt.backup = false            -- Не плодить лишние копии файлов
opt.writebackup = false
opt.updatetime = 250          -- Быстрота реакции (мс)
opt.timeoutlen = 300          -- Задержка появления Which-Key
opt.ignorecase = true         -- Игнорировать регистр при поиске
opt.smartcase = true          -- ...если нет заглавных букв

-- Окна и Сплиты
opt.splitright = true       -- Новое окно открывается справа
opt.splitbelow = true       -- Новое окно открывается снизу
opt.breakindent = true      -- Умный перенос длинных строк

-- Настройки Табов (Идеально для Go)
opt.tabstop = 4             -- Ширина таба
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = false       -- Используем ЧЕСТНЫЕ ТАБЫ (Go стандарт)

-- ПОЛНОЕ ОТКЛЮЧЕНИЕ СВОРАЧИВАНИЯ (FOLDING) — Чтобы ничего не бесило
opt.foldenable = false      
opt.foldmethod = "manual"   
opt.foldlevel = 99          
opt.foldcolumn = "0"        

-- ========================================================================== --
--                  ФИЛЬТРАЦИЯ ДИАГНОСТИКИ (БЕЗ ШУМА)                         --
-- ========================================================================== --

-- Показываем ТОЛЬКО КРАСНЫЕ ОШИБКИ. Желтые предупреждения и подсказки скрыты.
vim.diagnostic.config({
  underline = { severity = vim.diagnostic.severity.ERROR },
  virtual_text = { severity = vim.diagnostic.severity.ERROR },
  signs = { severity = vim.diagnostic.severity.ERROR },
  update_in_insert = false,
  severity_sort = true,
})

-- ========================================================================== --
--                         КАСТОМНАЯ РАСКРАСКА И ФОН                          --
-- ========================================================================== --

vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
        -- 1. ГЛУБОКИЙ ЧЕРНЫЙ ФОН (Везде: окна, меню, плавающие панели)
        local highlights = {
            "Normal", "NormalFloat", "SignColumn", "MsgArea", 
            "StatusLine", "StatusLineNC", "Pmenu", "NormalNC", "FloatBorder"
        }
        for _, group in ipairs(highlights) do
            vim.api.nvim_set_hl(0, group, { bg = "#000000" })
        end

        -- 2. ЗЕЛЕНЫЙ НОМЕР ТЕКУЩЕЙ СТРОКИ
        vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#00ff00", bold = true })

        -- 3. РАСКРАСКА GO (Твои настройки)
        -- Ключевые слова (ГОЛУБОЙ)
        vim.api.nvim_set_hl(0, "@keyword", { fg = "#82aaff", bold = true })
        vim.api.nvim_set_hl(0, "@keyword.function", { fg = "#82aaff", bold = true })
        vim.api.nvim_set_hl(0, "@repeat", { fg = "#82aaff" })
        vim.api.nvim_set_hl(0, "@conditional", { fg = "#82aaff" })

        -- Функции (ФИОЛЕТОВЫЙ + ПОДЧЕРКИВАНИЕ)
        vim.api.nvim_set_hl(0, "@function", { fg = "#c792ea", underline = true })
        vim.api.nvim_set_hl(0, "@function.call", { fg = "#c792ea", underline = true })
        vim.api.nvim_set_hl(0, "@function.builtin", { fg = "#c792ea", underline = true })
        vim.api.nvim_set_hl(0, "@method", { fg = "#c792ea", underline = true })
        
        -- Переменные (ЛАЙМОВЫЙ)
        vim.api.nvim_set_hl(0, "@variable", { fg = "#c3e88d" })
        vim.api.nvim_set_hl(0, "@variable.member", { fg = "#c3e88d" })
        vim.api.nvim_set_hl(0, "@parameter", { fg = "#c3e88d", italic = true })
    end,
})

-- ========================================================================== --
--                           УСТАНОВКА ПЛАГИНОВ (LAZY)                        --
-- ========================================================================== --

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com", "--branch=stable", lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- Загружаем все плагины из папки ~/.config/nvim/lua/plugins/
require("lazy").setup("plugins")

-- ========================================================================== --
--                         ПРИМЕНЕНИЕ ТЕМЫ И ФИЛЬТРЫ                          --
-- ========================================================================== --

-- Безопасный запуск темы (чтобы не было ошибки colors_name nil)
local status_theme, _ = pcall(vim.cmd, "colorscheme " .. (vim.g.colors_name or "habamax"))
if not status_theme then
    vim.cmd("colorscheme habamax")
end

-- Фильтр всплывающих уведомлений (пропускаем только КРАСНЫЕ ОШИБКИ)
local status_notify, notify = pcall(require, "notify")
if status_notify then
    vim.notify = function(msg, level, opts)
        if level ~= nil and level < vim.log.levels.ERROR then return end
        notify(msg, level, opts)
    end
end

-- Принудительное разворачивание всех строк при открытии файлов
vim.api.nvim_create_autocmd({ "BufReadPost", "FileType" }, {
    pattern = "*",
    callback = function()
        vim.opt_local.foldenable = false
        vim.cmd("normal! zR") 
    end,
})

-- ========================================================================== --
--                           ГОРЯЧИЕ КЛАВИШИ (БАЗА)                           --
-- ========================================================================== --

local keymap = vim.keymap.set

-- Быстрый выход из Insert Mode
keymap("i", "jk", "<Esc>", { desc = "Выход в Normal" })

-- Убрать подсветку поиска после нажатия Enter
keymap("n", "<leader>nh", ":nohlsearch<CR>", { desc = "Убрать подсветку поиска" })

-- Навигация между окнами (Ctrl + h,j,k,l)
keymap("n", "<C-h>", "<C-w>h")
keymap("n", "<C-j>", "<C-w>j")
keymap("n", "<C-k>", "<C-w>k")
keymap("n", "<C-l>", "<C-w>l")

-- Переключение вкладок (через Tab и Shift+Tab)
keymap("n", "<Tab>", ":bnext<CR>", { desc = "След. вкладка" })
keymap("n", "<S-Tab>", ":bprevious<CR>", { desc = "Пред. вкладка" })

-- Умное удаление (удаление через x не перезаписывает скопированный текст)
keymap("n", "x", '"_x')

-- Перемещение строк (Alt + j/k)
keymap("n", "<A-j>", ":m .+1<CR>== ", { desc = "Двигать строку вниз" })
keymap("n", "<A-k>", ":m .-2<CR>== ", { desc = "Двигать строку вверх" })
keymap("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Двигать блок вниз" })
keymap("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Двигать блок вверх" })
-- ========================================================================== --
--                            Кастомные функции                               --
-- ========================================================================== --
-- Открыть документацию в полноценном боковом окне (как в VS Code)
vim.keymap.set('n', '<leader>tD', function()
    local params = vim.lsp.util.make_position_params()
    vim.lsp.buf_request(0, "textDocument/hover", params, function(_, result)
        if not (result and result.contents) then return end
        
        local markdown_lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
        
        -- Создаем новое вертикальное окно справа
        vim.cmd("vsplit")
        local win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_create_buf(false, true) -- Создаем пустой буфер
        vim.api.nvim_win_set_buf(win, buf)
        
        -- Настраиваем буфер: Markdown, без номеров строк, временный
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, markdown_lines)
        vim.opt_local.filetype = "markdown"
        vim.opt_local.buftype = "nofile"
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
    end)
end, { desc = "📑 Открыть доку в новом окне" })

