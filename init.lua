-- ========================================================================== --
--                           ОСНОВНЫЕ НАСТРОЙКИ (CORE)                        --
-- ========================================================================== --

-- ПЕРВЫМ ДЕЛОМ — чиним PATH, иначе lazy.nvim не сможет запустить git:
-- «Failed to spawn process git» на всех плагинах (подробности и причина —
-- в lua/config/env_path.lua). Диагностика: :EnvCheck
require("config.env_path").setup()
vim.api.nvim_create_user_command("EnvCheck", function() require("config.env_path").check() end, {
  desc = "Показать git/curl/tar и PATH этого nvim",
})
-- Какой переводчик en→ru реально отвечает (Google из РФ без VPN не работает,
-- тогда должен отвечать MyMemory). Без этого «нет перевода» не диагностировать.
vim.api.nvim_create_user_command("RuCheck", function() require("config.ru_util").check() end, {
  desc = "Проверить доступность переводчиков (перевод ошибок/подсказок)",
})

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

-- Темы: выбор в nvim — <leader>uT или :Theme (см. lua/config/themes.lua).
-- ВАЖНО: переключение ровно ОДНО. Раньше здесь стояла страховка colorscheme
-- catppuccin, а themes.setup() потом переключал на сохранённую тему — на старте
-- мелькала дефолтная тема. Теперь themes.setup() сам ставит сохранённую тему
-- (плагины тем зарегистрированы lazy.setup, priority = 1000), а страховка
-- catppuccin/habamax срабатывает только если схема не загрузилась.
require("config.themes").setup()

-- Markdown: live-превью в браузере (<leader>mL, :MdPreview)
require("config.md_preview").setup()

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
require("config.yank_ring").setup() -- кольцо буфера обмена: "1…"9, <leader>yr
require("config.winnav").setup() -- <leader>W*: фокус дерево / код / терминал
require("config.keyshow").setup() -- показ нажатий: <leader>kk
require("config.browser_ask").setup() -- <leader>Ab / :Ask: запрос в Firefox
require("config.webtools").setup() -- <leader>Gh/Gl/Gb: GitHub, GitLab, Хабр; :Habr
require("config.keydoc").setup() -- справка по клавишам: <leader>? и режим <leader>?m
require("config.sudo_write").setup() -- :SudoWrite и <leader>qW: запись файла через sudo
require("config.games").setup() -- игры: <leader>Xc шахматы, Xs змейка, Xt тетрис, Xf 2048, Xm меню

-- Русский перевод LSP-подсказок (hover): переводится только проза,
-- код в ```-блоках и inline `code` не трогается. Выкл: :HoverRu off
require("config.hover_ru").setup()
require("config.gloss").setup() -- K (визуал) и <leader>Kw: английский по словам с частью речи; :Gloss
require("config.ai_api").setup() -- ИИ любой: <leader>Ap (выбор: Groq, Gemini, OpenAI…), <leader>Aq; :AiProvider, :AiStatus, :AiAsk
require("config.go_ide").setup() -- Go как в GoLand: <leader>gi (меню), gT/gC/gD/ga/go/gr/gx; :GoIde
require("config.go_pro").setup() -- Go как в VS Code/GoLand: gh gL gR gB gc gM gn gS gE gG gp gA gV gH gO gJ
require("config.tui_tools").setup() -- <leader>U: TUI-утилиты (k9s, iredis, pgcli, lazysql, dive…); :Tui

-- Русские ошибки LSP на лету (Go/Docker/SQL/proto/...): выкл: :DiagRu off
require("config.diag_ru").setup()

-- Русские уведомления (вывод сборок Go/lint и т.п.): выкл: :NotifyRu off
require("config.notify_ru").setup()

-- ========================================================================== --
--                          TELEGRAM: КОНСОЛЬНЫЙ tele ВНУТРИ NVIM
-- ========================================================================== --
-- Три способа открыть tele (весь экран / панель / маленький float на один чат),
-- уведомления о новых сообщениях прямо в редакторе и ответы через PTY.
-- Читает кэш tele (~/.local/state/tele/state.db), поэтому уведомления идут,
-- даже когда tele запущен в другой вкладке терминала. Диагностика: :TeleCheck
-- Шпаргалка: :TeleDocs   Клавиши: <leader>m…   (подробности — в шапке модуля)
require("config.telegram").setup()

-- ========================================================================== --
--              🔥 ОГОНЁК ЗА КОММИТЫ  +  🕐 HUD (МСК / ЗАРЯД / IP)
-- ========================================================================== --
-- В правом верхнем углу редактора одна строка: время в Москве (12-часовой
-- формат с AM/PM), заряд батареи мака (M4) и IP. Рядом — 🔥N: сколько дней подряд
-- в этом (и добавленных :StreakRepo) репозиториях был хотя бы один коммит.
--
-- День «закрывается» в 03:00 МСК, а не в 00:00: ночной коммит в 01:40
-- засчитывается за вчерашний день, и сгорать серия идёт тоже в три, когда
-- «сутки» реально закончились. Ночные часы — обычное дело, и из-за полуночи
-- такой коммит терялся бы каждые сутки.
--
-- require'ы в конце: streak дёргает git (первый scan ~5-10 мс), hud — pmset и
-- curl; в startup-time это почти нулевые, но пусть будут ПОСЛЕ lazy.nvim, а не
-- до него. vim.notify тут фильтруется до ERROR (см. начало файла), поэтому про
-- отсутствующий git говорим напрямую через nvim_echo.
if vim.fn.executable("git") == 1 then
  require("config.streak").setup({
    -- repos = { "~/code/work/api", "~/code/nvim-config" }, -- nil = репозиторий конфига
    burn_hour = 3,   -- во сколько МСК день считается законченным
    goal = 1,        -- коммитов в день, чтобы огонёк зажёгся
    check_every = 300,
  })
else
  vim.schedule(function()
    vim.api.nvim_echo({ { "🔥 git не найден в PATH — огонёк за коммиты выключен", "WarningMsg" } }, false, {})
  end)
end

require("config.hud").setup({
  -- время и заряд обновляются сами; публичный IP — раз в 10 минут (см. PROXY.md)
  ip_mode = "both",  -- lan | public | both | off  (переключатель <leader>Hui)
  clock = 12,        -- 12-часовой с AM/PM; 24 — <leader>Huc или :HudClock 24
  tz_offset = 3 * 3600, -- МСК = UTC+3 (переводов времени в РФ нет с 2014)
})
