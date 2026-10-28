-- ========================================================================== --
--                 WHICH-KEY: ГЛАВНОЕ МЕНЮ <leader>H (как в main)             --
-- ========================================================================== --
-- Структура, эмодзи и названия групп — из main (Главное меню, Поиск, Git и Go,
-- Базы, AI, Obsidian, Тесты, Визуал, Harpoon, Плагины, Диагностика, Прочее,
-- Файлы). Отличия от main — только там, где в main клавиша была сломана:
--   • GoTest        <leader>Ht  → <leader>Hgt   (Ht — группа «Тесты», два значения
--                                                на одном префиксе не работают)
--   • Терминал      <leader>Ht* → <leader>T*    (живёт в toggleterm.lua)
--   • команды       GoVulncheck→GoVulnCheck, GoTest/Telescope todo/DBUI AddConnection,
--                   TroubleToggle→Trouble diagnostics toggle, PomodoroStart→TimerStart,
--                   harpoon.mark → harpoon v2, KulalaRun → kulala.run(), CodeCompanionSend → :CodeCompanion
--   • ушли из main, потому что такой команды/подкоманды нет: DBUI ExecuteQuery,
--     NvimTreeCreate (создание файла — клавишей `a` в дереве)
-- Новые команды помечены  ✚  в подписи.
-- Клавиши, которые ставятся в другом месте (ai.lua, maximizer.lua, hud.lua,
-- go-tools.lua, toggleterm.lua), здесь только подписаны, без действия — иначе дубль.
return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      plugins = {
        spelling = { enabled = true },
        presets = {
          operators = false,
          motions = false,
          text_objects = false,
          windows = false,
          nav = false,
          z = false,
          g = false,
        },
      },

      spec = {
        -------------------------------------------------------------
        --  🎛  Главное меню (через <leader>H)
        -------------------------------------------------------------
        { "<leader>H", group = "🎛 Главное меню" },

        -------------------------------------------------------------
        --  ✈️  TG — ОТДЕЛ TELEGRAM (консольный tele внутри nvim)
        -------------------------------------------------------------
        -- Сами клавиши ставит lua/config/telegram.lua; здесь только подписи.
        { "<leader>m", group = "TG ✈ Telegram (tele)", icon = "✈" },
        { "<leader>mm", desc = "🗕 tele: маленькое окно (float)" },
        { "<leader>mf", desc = "🖥 tele: на весь экран" },
        { "<leader>mp", desc = "▐ tele: боковой панелью" },
        { "<leader>mh", desc = "🙈 спрятать окно (tele останется живым)" },
        { "<leader>mo", desc = "↩︎ открыть чат последнего уведомления" },
        { "<leader>mc", desc = "🎯 выбрать чат и сесть на него" },
        { "<leader>mi", desc = "📥 история входящих" },
        { "<leader>mt", desc = "📖 прочитать чат, не открывая tele" },
        { "<leader>mr", desc = "✍️ ответить через tele" },
        { "<leader>mq", desc = "↩︎ ответить в чат последнего уведомления" },
        { "<leader>ms", desc = "📤 отправить выделение в tele (visual)" },
        { "<leader>mS", desc = "📤 отправить текущую строку в tele" },
        { "<leader>mn", desc = "🔇 режим тишины (dnd)" },
        { "<leader>mb", desc = "🔔 гудок вкл/выкл" },
        { "<leader>md", desc = "🩺 диагностика (:TeleCheck)" },
        { "<leader>mk", desc = "💀 убить процесс tele" },
        { "<leader>m?", desc = "📋 шпаргалка по telegram-мосту" },

        -------------------------------------------------------------
        --  🔍 Поиск и Файлы (H + f)
        -------------------------------------------------------------
        { "<leader>Hf", group = "🔍 Поиск и Файлы" },
        { "<leader>Hff", "<cmd>Telescope find_files<cr>", desc = "📂 Найти файл" },
        { "<leader>Hfg", "<cmd>Telescope live_grep<cr>", desc = "🔎 Live grep" },
        { "<leader>Hfb", "<cmd>Telescope buffers<cr>", desc = "🗂 Открыть буферы" },
        { "<leader>Hfh", "<cmd>Telescope help_tags<cr>", desc = "❓ Поиск по справке" },
        { "<leader>Hfr", "<cmd>Telescope oldfiles<cr>", desc = "🕑 Недавние файлы" },
        { "<leader>Hft", "<cmd>TodoTelescope<cr>", desc = "📝 TODO/FIXME" },
        { "<leader>Hfk", "<cmd>Telescope keymaps<cr>", desc = "⌨️ Все горячие клавиши" },
        { "<leader>Hfc", "<cmd>Telescope commands<cr>", desc = "✚ ⌨️ Все команды Neovim" },
        { "<leader>Hfw", "<cmd>Telescope grep_string<cr>", desc = "✚ 🔍 Найти слово под курсором" },
        { "<leader>Hfm", "<cmd>Telescope marks<cr>", desc = "✚ 🔖 Метки (marks)" },

        -------------------------------------------------------------
        --  🌿 Git и Go (H + g; Go-команды — как в main)
        -------------------------------------------------------------
        { "<leader>Hg", group = "🌿 Git и Go" },
        { "<leader>Hgs", function() require("gitsigns").stage_hunk() end, desc = "📦 Stage hunk" },
        { "<leader>Hgu", function() require("gitsigns").reset_hunk() end, desc = "↩️ Undo stage hunk" },
        { "<leader>Hgb", function() require("gitsigns").blame_line() end, desc = "🕵️‍♂️ Показать автора строки" },
        { "<leader>Hgh", function() require("gitsigns").preview_hunk() end, desc = "🔎 Предпросмотр изменений" },
        { "<leader>Hgd", function() require("gitsigns").diffthis() end, desc = "✚ 🔀 Diff текущего файла" },
        { "<leader>Hgl", function() require("gitsigns").toggle_current_line_blame() end, desc = "✚ 👤 Blame строки вкл/выкл" },
        { "<leader>Hgg", "<cmd>LazyGit<cr>", desc = "✚ 🐙 LazyGit" },
        { "<leader>Hti", "<cmd>GoAddTag json<cr>", desc = "🏷 Добавить json‑теги" },
        { "<leader>Hie", "<cmd>GoIfErr<cr>", desc = "❗ Авто‑if err" },
        { "<leader>Hfs", "<cmd>GoFillStruct<cr>", desc = "🧩 Заполнить struct" },
        { "<leader>Hj2s", "<cmd>GoJson2Struct<cr>", desc = "📦 JSON → struct" },
        { "<leader>Him", "<cmd>GoImpl<cr>", desc = "⚙️ Сгенерировать impl" },
        { "<leader>Hvc", "<cmd>GoVulnCheck<cr>", desc = "🔐 Проверка уязвимостей" },
        { "<leader>Hgt", "<cmd>GoTest<cr>", desc = "🧪 Запуск Go-тестов" },

        -------------------------------------------------------------
        --  🗄 Базы и Отладка (H + d)
        -------------------------------------------------------------
        { "<leader>Hd", group = "🗄 Базы и Отладка" },
        { "<leader>Hdu", "<cmd>DBUI<cr>", desc = "💾 Открыть панель БД" },
        { "<leader>Hda", "<cmd>DBUIAddConnection<cr>", desc = "➕ Добавить подключение" },
        { "<leader>Hdf", "<cmd>DBUIFindBuffer<cr>", desc = "✚ 🔍 Найти БД буфера" },
        { "<leader>Hdb", function() require("dap").toggle_breakpoint() end, desc = "⛔ Точка останова" },
        { "<leader>Hdr", function() require("dap").continue() end, desc = "▶️ Старт/Продолжить" },
        { "<leader>Hdi", function() require("dap").step_into() end, desc = "🔽 Шаг в" },
        { "<leader>Hdo", function() require("dap").step_over() end, desc = "⏭ Шаг через" },
        { "<leader>Hdt", function() require("dap-go").debug_test() end, desc = "🧪 Тест в режиме отладки" },
        -- Выполнение запроса — только в SQL-буфере (filetype sql), иначе :%DB упадёт непонятно.
        { "<leader>Hde", function()
          if vim.bo.filetype ~= "sql" then
            vim.notify("Выполнение запроса — из SQL-буфера (filetype sql).", vim.log.levels.WARN)
            return
          end
          vim.cmd("%DB")
        end, desc = "🚀 Выполнить запрос" },

        -------------------------------------------------------------
        --  🤖 AI и Структура (H + a) — клавиши ставит ai.lua, тут подписи
        -------------------------------------------------------------
        { "<leader>Ha", group = "🤖 AI и Структура" },
        { "<leader>Hat", desc = "💬 Открыть чат с ИИ" },
        { "<leader>Hai", desc = "🛠 AI‑меню действий" },
        { "<leader>Hae", desc = "📤 Отправить выделение ИИ" },
        { "<leader>Hac", desc = "✚ ✨ Команда в CodeCompanion" },
        { "<leader>Has", "<cmd>AerialToggle!<cr>", desc = "📑 Показать структуру файла" },

        -------------------------------------------------------------
        --  💎 Obsidian (H + o)
        -------------------------------------------------------------
        { "<leader>Ho", group = "💎 Obsidian" },
        { "<leader>Hos", "<cmd>ObsidianSearch<cr>", desc = "🔎 Поиск заметок" },
        { "<leader>Hon", "<cmd>ObsidianNew<cr>", desc = "📝 Новая заметка" },
        { "<leader>Hof", "<cmd>ObsidianFollowLink<cr>", desc = "🔗 Перейти по ссылке" },
        { "<leader>Hot", "<cmd>ObsidianToggleCheckbox<cr>", desc = "☑ Тоггл чекбокса" },

        -------------------------------------------------------------
        --  🧪 Тесты (H + t) — единственная группа на <leader>Ht
        -------------------------------------------------------------
        { "<leader>Ht", group = "🧪 Тесты" },
        { "<leader>Htr", "<cmd>Neotest run<cr>", desc = "▶️ Запуск теста под курсором" },
        { "<leader>Htf", "<cmd>Neotest run file<cr>", desc = "📂 Запуск всех тестов в файле" },
        { "<leader>Hts", "<cmd>Neotest summary<cr>", desc = "🗂 Окно со статусом тестов" },
        { "<leader>Hto", "<cmd>Neotest output<cr>", desc = "📄 Показать вывод ошибки" },
        { "<leader>Htn", "<cmd>Neotest jump next<cr>", desc = "⬇️ Следующий тест" },

        -------------------------------------------------------------
        --  🎨 Визуал и UI (клавиши — как в main)
        -------------------------------------------------------------
        { "<leader>Hu", group = "🎨 Визуал и UI" },
        { "<leader>Hsc", "<cmd>Silicon<cr>", desc = "📸 Скриншот кода (Silicon)" },
        { "<leader>Hrr", function() require("kulala").run() end, desc = "🚀 HTTP‑запрос (Kulala)" },
        { "<leader>Hz", "<cmd>ZenMode<cr>", desc = "🧘 Дзен‑режим" },
        -- клавишу <leader>Hum ставит lua/plugins/maximizer.lua (там и ленивый триггер)
        { "<leader>Hum", desc = "🪟 Развернуть/восстановить окно" },
        { "<leader>Hm", "<cmd>MaximizerToggle!<cr>", desc = "🪟 Развернуть/восстановить окно" },
        { "<leader>Hup", function() require("config.pets_custom").menu() end, desc = "🐾 Питомец: выбрать и призвать" },
        { "<leader>Hug", "<cmd>PetsNewCustom gopher blue Харек<cr>", desc = "🐹 Гофер Харек (синий, Go)" },
        { "<leader>Huy", "<cmd>PetsNewCustom nyan classic Нян<cr>", desc = "🐱 Нян-кот (мем)" },
        { "<leader>Hut", "<cmd>PetsNewCustom toaster silver Тостер<cr>", desc = "🍞 Тостер (мем)" },
        { "<leader>HuG", "<cmd>PetsNewCustom ghost white Бу<cr>", desc = "👻 Призрак «бу» (мем)" },
        {
          "<leader>Hua",
          function()
            -- noice.toggle() не существует — переключаем анимации (mini.animate)
            if vim.g.minianimate_disable then
              vim.g.minianimate_disable = false
              vim.notify("Анимации включены")
            else
              vim.g.minianimate_disable = true
              vim.notify("Анимации выключены")
            end
          end,
          desc = "✨ Переключить анимации",
        },

        -- ⏱ Pomodoro (pomo.nvim) — клавиши из main, команды исправлены
        { "<leader>Hpt", "<cmd>TimerStart 25m Work<cr>", desc = "⏱️ Старт Pomodoro" },
        { "<leader>Hps", "<cmd>TimerStop Work<cr>", desc = "⏱️ Стоп Pomodoro" },

        -- 🕐 HUD в правом верхнем углу (lua/config/hud.lua) и 🔥 огонёк за
        -- коммиты (lua/config/streak.lua). Клавиши ставятся там, тут подписи.
        { "<leader>Huh", desc = "🕐 HUD: плашка в углу (вкл/выкл)" },
        { "<leader>Hud", desc = "🐞 HUD: что он видит (диагностика)" },
        { "<leader>Hui", desc = "🌐 HUD: какой IP — lan → public → both → off" },
        { "<leader>Huo", desc = "🙈 HUD: IP в углу — скрыть/показать" },
        { "<leader>Huc", desc = "🕐 HUD: 12/24-часовой формат" },
        { "<leader>Huk", desc = "🔥 Огонёк за коммиты (:Streak)" },

        -------------------------------------------------------------
        --  📌 Harpoon (v2 — ветка harpoon2)
        -------------------------------------------------------------
        { "<leader>Hh", group = "📌 Harpoon" },
        { "<leader>Hha", function() require("harpoon"):list():add() end, desc = "📍 Добавить файл в Harpoon" },
        { "<leader>Hhh", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, desc = "📂 Открыть меню Harpoon" },
        { "<leader>Hh1", function() require("harpoon"):list():select(1) end, desc = "🚀 Перейти к 1‑му файлу" },
        { "<leader>Hh2", function() require("harpoon"):list():select(2) end, desc = "🚀 Перейти к 2‑му файлу" },

        -------------------------------------------------------------
        --  🔌 Плагины (H + p)
        -------------------------------------------------------------
        { "<leader>Hp", group = "🔌 Плагины" },
        { "<leader>Hpl", "<cmd>Lazy<cr>", desc = "📦 Открыть Lazy UI" },
        { "<leader>Hpm", "<cmd>Mason<cr>", desc = "🛠 Открыть Mason UI" },
        { "<leader>Hpy", "<cmd>Lazy sync<cr>", desc = "✚ 🔄 Lazy sync (поставить новые плагины)" },
        { "<leader>Hli", "<cmd>LspInfo<cr>", desc = "📝 LspInfo" },
        { "<leader>Hch", "<cmd>checkhealth<cr>", desc = "⚙️ Checkhealth" },
        { "<leader>Hpc", "<cmd>ConformInfo<cr>", desc = "✚ 🎨 Чем форматируется файл" },

        -------------------------------------------------------------
        --  ⚠️ Диагностика (H + x)
        -------------------------------------------------------------
        { "<leader>Hx", group = "⚠️ Диагностика" },
        { "<leader>Hxx", "<cmd>Trouble diagnostics toggle<cr>", desc = "❗ Показать все ошибки (Trouble)" },
        { "<leader>Hxl", "<cmd>Trouble loclist toggle<cr>", desc = "📋 Location list" },
        { "<leader>Hxq", "<cmd>Trouble qflist toggle<cr>", desc = "📋 Quickfix list" },
        { "<leader>Hxs", "<cmd>Trouble symbols toggle<cr>", desc = "✚ 🧭 Символы файла (Trouble)" },
        { "<leader>Hxt", "<cmd>Trouble todo toggle<cr>", desc = "✚ 📝 TODO‑комментарии (Trouble)" },

        -------------------------------------------------------------
        --  📦 Прочее (H + n)
        -------------------------------------------------------------
        { "<leader>Hn", group = "📦 Прочее" },
        { "<leader>Hnh", "<cmd>nohlsearch<cr>", desc = "🔎 Убрать подсветку поиска" },
        { "<leader>He", "<cmd>NvimTreeToggle<cr>", desc = "🗂 Дерево файлов (nvim‑tree)" },

        -------------------------------------------------------------
        --  🖥 Терминал — клавиши в lua/plugins/toggleterm.lua (<leader>T*)
        -------------------------------------------------------------
        -- 🧰 Утилиты: команды, которые раньше были без клавиш. Строчные буквы под
        -- <leader>H заняты, поэтому префикс — заглавная <leader>HW.
        { "<leader>HW", group = "🧰 Утилиты и диагностика" },
        -- 🎮 Игры: клавиши основные — <leader>X*; здесь зеркала для главного меню
        { "<leader>HX", group = "🎮 Игры: шахматы · змейка · тетрис · 2048" },
        { "<leader>HXc", function() require("games.chess.ui").open() end, desc = "♟ Шахматы (2 игрока / против ПК)" },
        { "<leader>HXs", function() require("games.snake").open() end, desc = "🐍 Змейка" },
        { "<leader>HXt", function() require("games.tetris").open() end, desc = "🧱 Тетрис" },
        { "<leader>HXf", function() require("games.game2048").open() end, desc = "🔢 2048" },
        { "<leader>HXm", function() require("config.games").menu() end, desc = "🎮 Меню игр" },
        -- 🖼 Картинки (нужна Ghostty/Kitty): <leader>I* и зеркала
        { "<leader>HI", group = "🖼 Картинки (Ghostty / Kitty)" },
        { "<leader>HIi", function() Snacks.image.hover() end, desc = "🖼 Показать картинку под курсором" },
        { "<leader>HIf", function() Snacks.picker.files({ title = "🖼 Картинки в проекте", ft = { "png", "jpg", "jpeg", "gif", "webp" } }) end, desc = "🖼 Найти картинку в проекте" },
        -- ⏪ История правок (undotree) и выравнивание: зеркала
        { "<leader>HV", "<cmd>UndotreeToggle<cr>", desc = "⏪ История правок (undotree)" },
        { "<leader>HU", group = "🧰 TUI-утилиты (k9s, iredis, pgcli…)" },
        { "<leader>HK", group = "📖 Английский: перевод слов" },
        { "<leader>HWr", "<cmd>RuCheck<cr>", desc = "🌐 Проверить переводчики" },
        { "<leader>HWh", "<cmd>HoverRu toggle<cr>", desc = "🌐 Перевод подсказок K: вкл/выкл" },
        { "<leader>HWd", "<cmd>DiagRu toggle<cr>", desc = "🩺 Русские ошибки LSP: вкл/выкл" },
        { "<leader>HWn", "<cmd>NotifyRu toggle<cr>", desc = "🔔 Русские уведомления: вкл/выкл" },
        { "<leader>HWe", "<cmd>EnvCheck<cr>", desc = "🧪 Проверка PATH и утилит" },
        { "<leader>HWm", "<cmd>Matrix<cr>", desc = "🟢 Дождь из символов" },
        { "<leader>HWt", "<cmd>HudNow<cr>", desc = "🕐 Обновить часы и HUD" },
        { "<leader>HWc", "<cmd>HudClock 24<cr>", desc = "🕐 Часы: 24 часа" },
        { "<leader>HWC", "<cmd>HudClock 12<cr>", desc = "🕐 Часы: 12 часов" },
        { "<leader>HWz", "<cmd>HudTz 3<cr>", desc = "🕐 Пояс UTC+3 (МСК)" },
        { "<leader>HWa", "<cmd>StreakNotify off<cr>", desc = "🔕 Огонёк: без уведомлений" },
        { "<leader>HWA", "<cmd>StreakNotify on<cr>", desc = "🔔 Огонёк: уведомления вкл" },
        { "<leader>HWg", "<cmd>StreakGoal 1<cr>", desc = "🔥 Огонёк: цель 1 коммит в день" },
        { "<leader>HWb", "<cmd>StreakHour 3<cr>", desc = "🔥 Огонёк: день до 03:00 МСК" },
        { "<leader>T", group = "🖥 Терминал (toggleterm)" },
        { "<leader>U", group = "🧰 TUI-утилиты (k9s, iredis, pgcli…)" },
        { "<leader>A", group = "🤖 AI (avante) · 🦊 Firefox" },
        { "<leader>G", group = "🐙 GitHub · 🦊 GitLab · 📰 Хабр" },
        { "<leader>K", group = "📖 Английский: перевод слов" },
        { "<leader>P", group = "🧊 Protobuf (buf)" },
        { "<leader>a", group = "🌳 Структура (aerial)" },
        { "<leader>b", group = "📑 Буферы" },
        { "<leader>g", group = "🐹 Go и LazyGit" },
        { "<leader>h", group = "📌 Harpoon (закладки)" },
        { "<leader>j", group = "🧾 JSON" },
        { "<leader>n", group = "📓 Черновики и подсветка" },
        { "<leader>o", group = "💎 Obsidian" },
        { "<leader>p", group = "⏱ Pomodoro (таймер)" },
        { "<leader>q", group = "🚪 Закрыть окно · сессии · sudo" },
        { "<leader>X", group = "🎮 Игры: шахматы · змейка · тетрис · 2048" },
        { "<leader>I", group = "🖼 Картинки (Ghostty / Kitty)" },
        { "<leader>r", group = "🚀 HTTP и переименование" },
        { "<leader>s", group = "🎵 Spotify · 📸 скриншот" },
        { "<leader>t", group = "🌐 Перевод · 🧪 Тесты · 📖 Док" },
        { "<leader>u", group = "🎨 Визуал и тема · 🐾 Питомцы" },
        { "<leader>x", group = "⚠️ Ошибки (Trouble)" },
        { "<leader>W", group = "🪟 Окна: дерево · код · терминал" },
        { "<leader>k", group = "⌨️ Показ нажатий" },
        { "<leader>Tt", desc = "📟 Плавающий терминал" },
        { "<leader>Th", desc = "📟 Терминал снизу" },
        { "<leader>Tv", desc = "📟 Терминал справа" },
        { "<leader>Ta", desc = "❎ Показать/скрыть все терминалы" },
        { "<leader>Tc", desc = "❎ Закрыть все терминалы" },
        { "<leader>Tl", desc = "➡ Строку в терминал" },

        -------------------------------------------------------------
        --  🗄 Базы данных — КАТАЛОГ <leader>D (клавиши: lua/config/db_menu.lua)
        --  <leader>D → СУБД → c подключиться · r выполнить (SQL) · t таблицы ·
        --  d описание таблицы · n новый SQL-буфер · u панель DBUI
        -------------------------------------------------------------
        { "<leader>D", group = "🗄 Базы данных (каталог)" },
        { "<leader>Ds", group = "🪶 SQLite" },
        { "<leader>Dm", group = "🐬 MySQL / MariaDB" },
        { "<leader>Dp", group = "🐘 PostgreSQL" },
        { "<leader>Do", group = "🏛 Oracle" },
        { "<leader>Dx", group = "🟦 SQL Server" },
        { "<leader>Dc", group = "🏠 ClickHouse" },

        -------------------------------------------------------------
        --  🐹 Go: Kubernetes · Docker · Kafka — в плавающем терминале
        --  (если утилиты нет в PATH — подсказка со ссылкой, без обходных путей)
        -------------------------------------------------------------
        { "<leader>HG", group = "🐹 Go: K8s · Docker · Kafka" },
        { "<leader>HGi", desc = "🧠 Go IDE-меню (как в GoLand)" },
        { "<leader>HGk", group = "☸ Kubernetes" },
        { "<leader>HGkk", require("config.termcmd").make("k9s", 120, "k9s"), desc = "☸ k9s — TUI кластера" },
        { "<leader>HGkp", require("config.termcmd").make("kubectl get pods", 121, "kubectl pods"), desc = "📦 kubectl: поды текущего namespace" },
        { "<leader>HGkc", require("config.termcmd").make("kubectl config get-contexts", 122, "kubectl contexts"), desc = "🔀 kubectl: контексты" },
        { "<leader>HGd", group = "🐳 Docker" },
        { "<leader>HGdd", require("config.termcmd").make("lazydocker", 130, "lazydocker"), desc = "🐳 lazydocker — TUI Docker" },
        { "<leader>HGdp", require("config.termcmd").make("docker ps -a", 131, "docker ps"), desc = "📦 docker ps -a" },
        { "<leader>HGdi", require("config.termcmd").make("docker images", 132, "docker images"), desc = "🖼 docker images" },
        { "<leader>HGa", group = "📨 Kafka" },
        { "<leader>HGak", require("config.termcmd").make("ktea", 140, "ktea"), desc = "📨 ktea — Kafka TUI (топики, группы, сообщения)" },
        { "<leader>HGat", require("config.termcmd").make("kafkactl get topics", 141, "kafkactl topics"), desc = "📋 kafkactl: топики" },
        { "<leader>HGag", require("config.termcmd").make("kafkactl get consumer-groups", 142, "kafkactl groups"), desc = "👥 kafkactl: consumer-группы" },
        { "<leader>HGab", require("config.termcmd").make("kafkactl get brokers", 143, "kafkactl brokers"), desc = "🖧 kafkactl: брокеры" },

        -------------------------------------------------------------
        --  💬 Чаты в терминале (H + y)
        --  Discordo — неофициальный клиент Discord: в правилах Discord
        --  автоматизированные «self-bot» аккаунты запрещены. Токен не
        --  хранится в конфиге: логин в самом приложении или DISCORDO_TOKEN.
        -------------------------------------------------------------
        { "<leader>Hy", group = "💬 Чаты (терминал)" },
        -- Справка по клавишам и буфер обмена / macOS (вторая итерация, части 4–6)
        { "<leader>Hq", group = "❓ Справка по клавишам" },
        { "<leader>Hq?", function() require("config.keydoc").lookup() end, desc = "❓ Справка по клавише (не выполняет)" },
        { "<leader>Hqm", function() require("config.keydoc").toggle_help_mode() end, desc = "❓ Режим справки вкл/выкл" },
        { "<leader>Hb", group = "📋 Буфер обмена и macOS" },
        { "<leader>Hbr", function() require("config.yank_ring").pick() end, desc = "📋 Кольцо буфера обмена (1–9)" },
        { "<leader>Hbm", function() vim.cmd("vsplit " .. vim.fn.stdpath("config") .. "/macos/README.md") end, desc = "🍎 macOS: клавиатура и Maccy (инструкция)" },
        { "<leader>Hbk", function() vim.notify("⌃⌥⌘K — экранная клавиатура (Hammerspoon). Инструкция: <leader>Hbm", vim.log.levels.INFO) end, desc = "⌨ Экранная клавиатура macOS (⌃⌥⌘K)" },
        { "<leader>y", group = "📋 Буфер обмена" },
        { "<leader>yr", function() require("config.yank_ring").pick() end, desc = "📋 Кольцо буфера обмена (1–9)" },
        { "<leader>Hyd", require("config.termcmd").make("discordo", 150, "discordo"), desc = "💬 Discordo — Discord в терминале (⚠ риск для аккаунта, см. доку)" },

        -------------------------------------------------------------
        --  🛠 Код: разбить/собрать (treesj) — <leader>c…
        --  (<leader>cl линтеры — в plugins/lint.lua, <leader>cf/ca — выше)
        -------------------------------------------------------------
        { "<leader>c", group = "🛠 Код" },
        { "<leader>cj", "<cmd>TSJToggle<cr>", desc = "🔀 Разбить/собрать конструкцию (переключить)" },
        { "<leader>cs", "<cmd>TSJSplit<cr>", desc = "✂ Разбить конструкцию на строки" },
        { "<leader>cJ", "<cmd>TSJJoin<cr>", desc = "🔗 Собрать конструкцию в одну строку" },

        -------------------------------------------------------------
        --  🧷 Окружения (mini.surround) — переехали с s* на gz* (2026-10-28),
        --  чтобы s целиком отдавался flash-прыжку без ожидания 2-го символа
        -------------------------------------------------------------
        { "gz", group = "🧷 Окружения (surround)" },
        { "gza", desc = "🧷 Добавить окружение (было sa)" },
        { "gzd", desc = "🧷 Удалить окружение (было sd)" },
        { "gzf", desc = "🧷 Найти окружение справа (было sf)" },
        { "gzF", desc = "🧷 Найти окружение слева (было sF)" },
        { "gzh", desc = "🧷 Подсветить окружение (было sh)" },
        { "gzr", desc = "🧷 Заменить окружение (было sr)" },
        { "gzn", desc = "🧷 Окружения: окно поиска n_lines" },
        { "q", desc = "⬅ Назад-слово умное (было b)" },
        { "Q", desc = "🎙 Запись макроса (было q)" },

        -------------------------------------------------------------
        --  🎃 Хэллоуин и 📖 markdown (2026-10-28)
        -------------------------------------------------------------
        { "<leader>uH", desc = "🎃 Хэллоуин-вайб вкл/выкл (тема + мыши + тыква)" },
        { "<leader>uP", desc = "🎃 Питомец: тыква" },
        { "<leader>Im", desc = "📖 Markdown: live-превью в браузере (вкл/выкл)" },
        { "<leader>It", desc = "📑 Markdown: оглавление (:Toc)" },
        { "<leader>IT", desc = "📐 Markdown: выровнять таблицу" },

        -------------------------------------------------------------
        --  🆚 Git: Diffview и мерж-конфликты (H g v / f / q / m…)
        --  Дефолтные co/ct/cb у git-conflict отключены (конфликт с оператором c)
        -------------------------------------------------------------
        { "<leader>Hgv", "<cmd>DiffviewOpen<cr>", desc = "🆚 Diffview: сравнить изменения" },
        { "<leader>Hgf", "<cmd>DiffviewFileHistory %<cr>", desc = "🕰 История файла (Diffview)" },
        { "<leader>Hgq", "<cmd>DiffviewClose<cr>", desc = "❌ Закрыть Diffview" },
        { "<leader>Hgm", group = "⚔ Мерж-конфликты" },
        { "<leader>Hgmo", "<cmd>GitConflictChooseOurs<cr>", desc = "⬅ Оставить СВОЁ (ours)" },
        { "<leader>Hgmt", "<cmd>GitConflictChooseTheirs<cr>", desc = "➡ Оставить ЧУЖОЁ (theirs)" },
        { "<leader>Hgmb", "<cmd>GitConflictChooseBoth<cr>", desc = "⬌ Оставить оба куска" },
        { "<leader>Hgm0", "<cmd>GitConflictChooseNone<cr>", desc = "🚫 Убрать оба куска" },
        { "<leader>Hgmn", "<cmd>GitConflictNextConflict<cr>", desc = "⏭ Следующий конфликт" },
        { "<leader>Hgmp", "<cmd>GitConflictPrevConflict<cr>", desc = "⏮ Предыдущий конфликт" },
        { "<leader>Hgml", "<cmd>GitConflictListQf<cr>", desc = "📋 Все конфликты в quickfix" },

        -------------------------------------------------------------
        --  📚 Шпаргалки cheat.sh (H k)
        -------------------------------------------------------------
        { "<leader>Hk", group = "📚 Шпаргалки (cheat.sh)" },
        { "<leader>Hkc", function()
            vim.ui.input({ prompt = "cheat.sh: " }, function(q)
              if q and q ~= "" then vim.cmd("Cheat " .. q) end
            end)
          end, desc = "📚 Шпаргалка по запросу (cheat.sh)" },
        { "<leader>Hkl", "<cmd>CheatList<cr>", desc = "📋 Поиск по всем шпаргалкам" },

        -------------------------------------------------------------
        --  📂 Создать файл/директорию (H + c)
        -------------------------------------------------------------
        { "<leader>Hc", group = "📂 Создать файл/директорию" },
        -- NvimTreeCreate не существует: файл создаётся клавишей `a` в дереве
        { "<leader>Hcf", "<cmd>NvimTreeFindFileToggle<cr>", desc = "🆕 Дерево: создать файл (клавиша a)" },
        -- snacks.rename — это модуль (не функция), точка входа: rename_file()
        { "<leader>Hcr", function() require("snacks").rename.rename_file() end, desc = "✏️ Переименовать файл" },
      },
    },

    config = function(_, opts)
      require("which-key").setup(opts)
    end,
  },
}
