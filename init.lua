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

-- ========================================================================== --
--                     СВОРАЧИВАНИЕ (FOLDING) — ИСПРАВЛЕНО                    --
-- ========================================================================== --
-- Раньше здесь стояло foldenable=false + autocmd с `normal! zR` на каждый
-- FileType. Из-за этого nvim-ufo (lua/plugins/folding.lua) физически не мог
-- работать: без foldenable сворачивания просто не существует.
--
-- Теперь сворачивание ВКЛЮЧЕНО, но foldlevel=99, то есть при открытии файла
-- всё уже развёрнуто — визуально ничего не изменилось, зато zM/zR и ufo живут.
opt.foldenable = true
opt.foldlevel = 99          -- при открытии файла все блоки развёрнуты
opt.foldlevelstart = 99
opt.foldmethod = "manual"   -- nvim-ufo сам переключит на expr для нужных буферов
opt.foldcolumn = "0"        -- без колонки сворачивания (чтобы не мешала)

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
      "StatusLine", "StatusLineNC", "Pmenu", "NormalNC", "FloatBorder",
    }
    for _, group in ipairs(highlights) do
      vim.api.nvim_set_hl(0, group, { bg = "#000000" })
    end

    -- 2. ЗЕЛЕНЫЙ НОМЕР ТЕКУЩЕЙ СТРОКИ
    vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#00ff00", bold = true })

    -- 3. РАСКРАСКА GO
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

-- ИСПРАВЛЕНО: раньше сюда подставлялась строка "https://github.com",
-- из-за чего `git clone` падал и lazy.nvim вообще не устанавливался.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Не удалось установить lazy.nvim:\n", "ErrorMsg" },
      { "проверьте доступ к github.com и удалите " .. lazypath, "WarningMsg" },
      { "\nНажмите любую клавишу для выхода", "MoreMsg" },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Загружаем все плагины из папки ~/.config/nvim/lua/plugins/
require("lazy").setup("plugins", {
  checker = { enabled = true, notify = false },   -- не дёргать уведомлениями
  change_detection = { notify = false },
  install = { colorscheme = { "catppuccin-mocha", "habamax" } },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
    },
  },
})

-- ========================================================================== --
--                         ПРИМЕНЕНИЕ ТЕМЫ И ФИЛЬТРЫ                          --
-- ========================================================================== --

-- Тема ставится плагином lua/plugins/colorscheme.lua (catppuccin).
-- Здесь только страховка: если плагин ещё не скачан — падаем на habamax.
if not pcall(vim.cmd.colorscheme, "catppuccin-mocha") then
  pcall(vim.cmd.colorscheme, "habamax")
end

-- Фильтр всплывающих уведомлений (пропускаем только КРАСНЫЕ ОШИБКИ)
do
  local ok, notify = pcall(require, "notify")
  if ok then
    local base = vim.notify
    vim.notify = function(msg, level, opts)
      if level ~= nil and level < vim.log.levels.ERROR then return end
      if type(base) == "function" then
        return base(msg, level, opts)
      end
      return notify(msg, level, opts)
    end
  end
end

-- ========================================================================== --
--                           ГОРЯЧИЕ КЛАВИШИ (БАЗА)                           --
-- ========================================================================== --
-- Навигация по окнам, ресайз, сплиты и вкладки вынесены в lua/config/keymaps.lua
-- (раньше этот файл вообще никем не подключался — мёртвый код).

local keymap = vim.keymap.set

-- Быстрый выход из Insert Mode
keymap("i", "jk", "<Esc>", { desc = "Выход в Normal" })

-- Убрать подсветку поиска
keymap("n", "<leader>nh", ":nohlsearch<CR>", { desc = "Убрать подсветку поиска" })

-- Умное удаление (удаление через x не перезаписывает скопированный текст)
keymap("n", "x", '"_x')

-- Удалённые отсюда <A-j>/<A-k> делает move.nvim (lua/plugins/move.lua),
-- а <Tab>/<S-Tab> — bufferline.nvim. Дубли только ломали друг друга.

-- ========================================================================== --
--                            Кастомные функции                               --
-- ========================================================================== --
-- Открыть документацию в полноценном боковом окне (как в VS Code)
--
-- ИСПРАВЛЕНО: vim.lsp.util.make_position_params() без аргументов в
-- Neovim 0.11+ падает с ошибкой — второй параметр (кодировка позиций)
-- теперь обязательный. Берём её из подключённого клиента.
keymap("n", "<leader>tD", function()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  local client = clients[1]
  if not client then
    vim.notify("Нет подключённого LSP-сервера для этого буфера", vim.log.levels.WARN)
    return
  end

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding or "utf-16")
  vim.lsp.buf_request(0, "textDocument/hover", params, function(_, result)
    if not (result and result.contents) then return end

    local markdown_lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
    if #markdown_lines == 0 then return end

    -- ответ приходит асинхронно — переносим работу с окнами в основной цикл
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(0) then return end
      vim.cmd("vsplit")
      local win = vim.api.nvim_get_current_win()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(win, buf)

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, markdown_lines)
      vim.bo[buf].filetype = "markdown"
      vim.bo[buf].buftype = "nofile"
      vim.bo[buf].bufhidden = "wipe"
      vim.wo[win].number = false
      vim.wo[win].relativenumber = false
      vim.wo[win].signcolumn = "no"
      vim.api.nvim_win_set_width(win, math.max(40, math.floor(vim.o.columns * 0.4)))
      vim.api.nvim_win_set_cursor(win, { 1, 0 })
    end)
  end)
end, { desc = "📑 Открыть доку в новом окне" })

-- ========================================================================== --
--                       ПОДКЛЮЧЕНИЕ ФАЙЛА КЛАВИШ                             --
-- ========================================================================== --
require("config.keymaps")

-- Русский перевод LSP-подсказок (hover): переводится только проза,
-- код в ```-блоках и inline `code` не трогается. Выкл: :HoverRu off
require("config.hover_ru").setup()

-- Русские ошибки LSP на лету (Go/Docker/SQL/proto/...): выкл: :DiagRu off
require("config.diag_ru").setup()
