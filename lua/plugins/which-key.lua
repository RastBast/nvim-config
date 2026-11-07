-- ========================================================================== --
--              WHICH-KEY: ПАНЕЛЬ <leader> В 3 СТОЛБИКА (БЕЗ <leader>H)       --
-- ========================================================================== --
-- Все разделы и кнопки перенесены напрямую в основной <leader> (Пробел):
--   • Панель <leader> и все внутренние отделы отображаются в 3 столбика
--     (layout.width = { min = 0.27, max = 0.30 }, spacing = 2, win.width = 0.96).
--   • Дублирующий отдел <leader>H («Главное меню») убран целиком; все его
--     кнопки и подразделы живут напрямую под <leader>:
--       - <leader>f  🔍 Поиск и файлы (+ fw слово, fm метки, fF дерево)
--       - <leader>V  🌿 Git · Diffview · Конфликты (stage, blame, diff, merge)
--       - <leader>g  🐹 Go и LazyGit (+ gs/gf struct, gj json-теги, ge if err, gu/gI)
--       - <leader>i  ☸ Инфра: K8s · Docker · Kafka (k9s, kubectl, lazydocker, ktea)
--       - <leader>d  🗄 Отладка · БД · Docker (DAP, DBUI, SQL :%DB, Docker)
--       - <leader>L  🔌 Плагины и LSP (Lazy, Lazy sync, Mason, LspInfo, checkhealth)
--       - <leader>l  🧰 Утилиты · HUD · Огонёк · RU (часы, IP, streak, перевод)
--       - <leader>A  🤖 AI · Codeium · .txt · Diff (Avante, CodeCompanion, NeoCodeium)
--       - <leader>C  🏗️ Архитектура C4 и связи (:ArchBoard, :ArchWeb, :ArchScan…)
--       - <leader>o / <leader>t / <leader>u / <leader>x / <leader>n / <leader>k / <leader>y / <leader>U
return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      win = {
        width = 0.96,
        height = { min = 4, max = 28 },
        padding = { 1, 2 },
        title = true,
        title_pos = "center",
      },
      -- Строго 3 столбика и в корневом <leader>, и во всех внутренних отделах:
      -- при ширине колонки 27%..30% от контейнера math.floor(W / (bw + 2)) == 3,
      -- после чего which-key автоматически растягивает каждый из 3 столбиков на 1/3 окна.
      layout = {
        width = { min = 0.27, max = 0.30 },
        spacing = 2,
      },
      sort = { "group", "alphanum", "mod" },
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
        --  ✈️  TG — ОТДЕЛ TELEGRAM (консольный tele внутри nvim)
        -------------------------------------------------------------
        { "<leader>m", group = "✈ Telegram · Markdown", icon = "✈" },
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
        --  🏗️  АРХИТЕКТУРА C4 И СВЯЗИ — ОТДЕЛЬНЫЙ РАЗДЕЛ <leader>C
        -------------------------------------------------------------
        { "<leader>C", group = "🏗️ Архитектура C4 и связи", icon = "🏗" },
        { "<leader>Cb", desc = "🏗️ C4-доска архитектуры в Neovim (:ArchBoard)" },
        { "<leader>Cf", desc = "🎯 Найти текущий файл на C4-доске (:ArchFocusFile)" },
        { "<leader>Cp", desc = "🧭 Меню всех действий архитектуры (:ArchMenu)" },
        { "<leader>Cw", desc = "🌐 Браузерный C4-холст drag-and-drop (:ArchWeb)" },
        { "<leader>Cs", desc = "🔍 Умный скан: код + .proto + SQL + OpenAPI (:ArchScan)" },
        { "<leader>Cl", desc = "🔎 Подтянуть символы и контракты из LSP (:ArchLspScan)" },
        { "<leader>Cd", desc = "✨ ИИ-черновик или правка схемы (:ArchAiDraft)" },
        { "<leader>Cr", desc = "🧠 Аудит циклов и ИИ-ревью (:ArchAiReview)" },
        { "<leader>Cn", desc = "➕ Добавить компонент (:ArchAddNode)" },
        { "<leader>Cc", desc = "🔗 Соединить компоненты (:ArchConnect)" },
        { "<leader>Cm", desc = "📐 Экспорт в Mermaid + Markdown (:ArchMermaid)" },
        { "<leader>Cj", desc = "📄 Открыть architecture.json (:ArchJson)" },
        { "<leader>Cx", desc = "⏹️ Остановить веб-холст (:ArchWebStop)" },

        -- Совместимые алиасы в <leader>mA
        { "<leader>mA", group = "🏗️ Архитектура C4 (алиас <leader>C)" },
        { "<leader>mAb", desc = "🏗️ C4-доска архитектуры в Neovim (:ArchBoard)" },
        { "<leader>mAf", desc = "🎯 Найти текущий файл на C4-доске (:ArchFocusFile)" },
        { "<leader>mAp", desc = "🧭 Меню всех действий архитектуры (:ArchMenu)" },
        { "<leader>mAw", desc = "🌐 Браузерный C4-холст drag-and-drop (:ArchWeb)" },
        { "<leader>mAs", desc = "🔍 Умный скан: код + .proto + SQL + OpenAPI (:ArchScan)" },
        { "<leader>mAl", desc = "🔎 Подтянуть символы и контракты из LSP (:ArchLspScan)" },
        { "<leader>mAd", desc = "✨ ИИ-черновик или правка схемы (:ArchAiDraft)" },
        { "<leader>mAr", desc = "🧠 Аудит циклов и ИИ-ревью (:ArchAiReview)" },
        { "<leader>mAn", desc = "➕ Добавить компонент (:ArchAddNode)" },
        { "<leader>mAc", desc = "🔗 Соединить компоненты (:ArchConnect)" },
        { "<leader>mAm", desc = "📐 Экспорт в Mermaid + Markdown (:ArchMermaid)" },
        { "<leader>mAj", desc = "📄 Открыть architecture.json (:ArchJson)" },
        { "<leader>mAx", desc = "⏹️ Остановить веб-холст (:ArchWebStop)" },

        -------------------------------------------------------------
        --  🔍 ПОИСК И ФАЙЛЫ — <leader>f
        -------------------------------------------------------------
        { "<leader>f", group = "🔍 Поиск и файлы" },
        { "<leader>fw", "<cmd>Telescope grep_string<cr>", desc = "🔍 Найти слово под курсором" },
        { "<leader>fm", "<cmd>Telescope marks<cr>", desc = "🔖 Метки (marks)" },
        { "<leader>fF", "<cmd>NvimTreeFindFileToggle<cr>", desc = "🆕 Дерево: текущий файл / создать (a)" },

        -------------------------------------------------------------
        --  🌿 GIT · DIFFVIEW · МЕРЖ-КОНФЛИКТЫ — <leader>V
        -------------------------------------------------------------
        { "<leader>V", group = "🌿 Git · Diffview · Конфликты" },
        { "<leader>Vs", function() require("gitsigns").stage_hunk() end, desc = "📦 Stage hunk" },
        { "<leader>Vu", function() require("gitsigns").reset_hunk() end, desc = "↩️ Undo stage hunk" },
        { "<leader>Vb", function() require("gitsigns").blame_line() end, desc = "🕵️‍♂️ Показать автора строки" },
        { "<leader>Vh", function() require("gitsigns").preview_hunk() end, desc = "🔎 Предпросмотр изменений" },
        { "<leader>Vd", function() require("gitsigns").diffthis() end, desc = "🔀 Diff текущего файла" },
        { "<leader>Vl", function() require("gitsigns").toggle_current_line_blame() end, desc = "👤 Blame строки вкл/выкл" },
        { "<leader>Vg", "<cmd>LazyGit<cr>", desc = "🐙 LazyGit" },
        { "<leader>Vv", "<cmd>DiffviewOpen<cr>", desc = "🆚 Diffview: сравнить изменения" },
        { "<leader>Vf", "<cmd>DiffviewFileHistory %<cr>", desc = "🕰 История файла (Diffview)" },
        { "<leader>Vq", "<cmd>DiffviewClose<cr>", desc = "❌ Закрыть Diffview" },
        { "<leader>Vm", group = "⚔ Мерж-конфликты" },
        { "<leader>Vmo", "<cmd>GitConflictChooseOurs<cr>", desc = "⬅ Оставить СВОЁ (ours)" },
        { "<leader>Vmt", "<cmd>GitConflictChooseTheirs<cr>", desc = "➡ Оставить ЧУЖОЕ (theirs)" },
        { "<leader>Vmb", "<cmd>GitConflictChooseBoth<cr>", desc = "⬌ Оставить оба куска" },
        { "<leader>Vm0", "<cmd>GitConflictChooseNone<cr>", desc = "🚫 Убрать оба куска" },
        { "<leader>Vmn", "<cmd>GitConflictNextConflict<cr>", desc = "⏭ Следующий конфликт" },
        { "<leader>Vmp", "<cmd>GitConflictPrevConflict<cr>", desc = "⏮ Предыдущий конфликт" },
        { "<leader>Vml", "<cmd>GitConflictListQf<cr>", desc = "📋 Все конфликты в quickfix" },

        -------------------------------------------------------------
        --  🐹 GO И LAZYGIT — <leader>g
        -------------------------------------------------------------
        { "<leader>g", group = "🐹 Go и LazyGit" },
        { "<leader>gs", desc = "🧩 Go: формочка struct (выбор из списка)" },
        { "<leader>gf", desc = "🧱 Go: поля struct'а под курсором" },
        { "<leader>gj", "<cmd>GoAddTag json<cr>", desc = "🏷 Go: добавить json-теги" },
        { "<leader>ge", "<cmd>GoIfErr<cr>", desc = "❗ Go: авто-if err" },
        { "<leader>gF", "<cmd>GoFillStruct<cr>", desc = "🧩 Go: заполнить struct" },
        { "<leader>gu", "<cmd>GoJson2Struct<cr>", desc = "📦 Go: JSON → struct" },
        { "<leader>gI", "<cmd>GoImpl<cr>", desc = "⚙️ Go: сгенерировать impl" },

        -------------------------------------------------------------
        --  ☸ ИНФРА: KUBERNETES · DOCKER · KAFKA — <leader>i
        -------------------------------------------------------------
        { "<leader>i", group = "☸ Инфра: K8s · Docker · Kafka" },
        { "<leader>ik", group = "☸ Kubernetes" },
        { "<leader>ikk", require("config.termcmd").make("k9s", 120, "k9s"), desc = "☸ k9s — TUI кластера" },
        { "<leader>ikp", require("config.termcmd").make("kubectl get pods", 121, "kubectl pods"), desc = "📦 kubectl: поды namespace" },
        { "<leader>ikc", require("config.termcmd").make("kubectl config get-contexts", 122, "kubectl contexts"), desc = "🔀 kubectl: контексты" },
        { "<leader>id", group = "🐳 Docker" },
        { "<leader>idd", require("config.termcmd").make("lazydocker", 130, "lazydocker"), desc = "🐳 lazydocker — TUI Docker" },
        { "<leader>idp", require("config.termcmd").make("docker ps -a", 131, "docker ps"), desc = "📦 docker ps -a" },
        { "<leader>idi", require("config.termcmd").make("docker images", 132, "docker images"), desc = "🖼 docker images" },
        { "<leader>ia", group = "📨 Kafka" },
        { "<leader>iak", require("config.termcmd").make("ktea", 140, "ktea"), desc = "📨 ktea — Kafka TUI" },
        { "<leader>iat", require("config.termcmd").make("kafkactl get topics", 141, "kafkactl topics"), desc = "📋 kafkactl: топики" },
        { "<leader>iag", require("config.termcmd").make("kafkactl get consumer-groups", 142, "kafkactl groups"), desc = "👥 kafkactl: consumer-группы" },
        { "<leader>iab", require("config.termcmd").make("kafkactl get brokers", 143, "kafkactl brokers"), desc = "🖧 kafkactl: брокеры" },

        -------------------------------------------------------------
        --  🗄 ОТЛАДКА · БД · DOCKER — <leader>d
        -------------------------------------------------------------
        { "<leader>d", group = "🗄 Отладка · БД · Docker" },
        { "<leader>da", "<cmd>DBUIAddConnection<cr>", desc = "➕ Добавить подключение БД" },
        { "<leader>df", "<cmd>DBUIFindBuffer<cr>", desc = "🔍 Найти БД буфера" },
        { "<leader>dg", function() require("dap").continue() end, desc = "▶️ Отладка: старт/продолжить" },
        { "<leader>ds", function() require("dap").step_into() end, desc = "🔽 Отладка: шаг в (step into)" },
        { "<leader>do", function() require("dap").step_over() end, desc = "⏭ Отладка: шаг через (step over)" },
        {
          "<leader>de",
          function()
            if vim.bo.filetype ~= "sql" then
              vim.notify("Выполнение запроса — из SQL-буфера (filetype sql).", vim.log.levels.WARN)
              return
            end
            vim.cmd("%DB")
          end,
          desc = "🚀 Выполнить SQL-запрос (:%DB)",
        },

        -------------------------------------------------------------
        --  🔌 ПЛАГИНЫ И LSP — <leader>L
        -------------------------------------------------------------
        { "<leader>L", group = "🔌 Плагины и LSP (Lazy · Mason)" },
        { "<leader>Ll", "<cmd>Lazy<cr>", desc = "📦 Открыть Lazy UI" },
        { "<leader>Ls", "<cmd>Lazy sync<cr>", desc = "🔄 Lazy sync (поставить/обновить плагины)" },
        { "<leader>Lu", "<cmd>LazyUnlock<cr>", desc = "🔓 Снять git-блокировки Lazy (:LazyUnlock)" },
        { "<leader>Lm", "<cmd>Mason<cr>", desc = "🛠 Открыть Mason UI" },
        { "<leader>Li", "<cmd>LspInfo<cr>", desc = "📝 Статус LSP (:LspInfo)" },
        { "<leader>Lc", "<cmd>ConformInfo<cr>", desc = "🎨 Чем форматируется файл (:ConformInfo)" },
        { "<leader>Lh", "<cmd>checkhealth<cr>", desc = "⚙️ Проверка здоровья (:checkhealth)" },

        -------------------------------------------------------------
        --  🧰 УТИЛИТЫ · HUD · ОГОНЁК · RU — <leader>l
        -------------------------------------------------------------
        -- Клавиши lh/ld/li/lo/lc/lk регистрирует lua/config/hud.lua; здесь подписи и команды.
        { "<leader>l", group = "🧰 Утилиты · HUD · Огонёк · RU" },
        { "<leader>lh", desc = "🕐 HUD: плашка в углу (вкл/выкл)" },
        { "<leader>ld", desc = "🐞 HUD: диагностика" },
        { "<leader>li", desc = "🌐 HUD: режим IP (lan → public → both → off)" },
        { "<leader>lo", desc = "🙈 HUD: IP в углу — скрыть/показать" },
        { "<leader>lc", desc = "🕐 HUD: 12/24-часовой формат" },
        { "<leader>lk", desc = "🔥 Огонёк за коммиты (:Streak)" },
        { "<leader>lt", "<cmd>HudNow<cr>", desc = "🕐 Обновить часы и HUD (:HudNow)" },
        { "<leader>l2", "<cmd>HudClock 24<cr>", desc = "🕐 Часы: 24 часа" },
        { "<leader>l1", "<cmd>HudClock 12<cr>", desc = "🕐 Часы: 12 часов" },
        { "<leader>lz", "<cmd>HudTz 3<cr>", desc = "🕐 Пояс UTC+3 (МСК)" },
        { "<leader>la", "<cmd>StreakNotify off<cr>", desc = "🔕 Огонёк: без уведомлений" },
        { "<leader>lA", "<cmd>StreakNotify on<cr>", desc = "🔔 Огонёк: уведомления вкл" },
        { "<leader>lg", "<cmd>StreakGoal 1<cr>", desc = "🔥 Огонёк: цель 1 коммит в день" },
        { "<leader>lb", "<cmd>StreakHour 3<cr>", desc = "🔥 Огонёк: день до 03:00 МСК" },
        { "<leader>lr", "<cmd>RuCheck<cr>", desc = "🌐 Проверить переводчики (:RuCheck)" },
        { "<leader>lK", "<cmd>HoverRu toggle<cr>", desc = "🌐 Перевод подсказок K: вкл/выкл" },
        { "<leader>lD", "<cmd>DiagRu toggle<cr>", desc = "🩺 Русские ошибки LSP: вкл/выкл" },
        { "<leader>ln", "<cmd>NotifyRu toggle<cr>", desc = "🔔 Русские уведомления: вкл/выкл" },
        { "<leader>le", "<cmd>EnvCheck<cr>", desc = "🧪 Проверка PATH и утилит (:EnvCheck)" },
        { "<leader>lm", "<cmd>Matrix<cr>", desc = "🟢 Дождь из символов (:Matrix)" },

        -------------------------------------------------------------
        --  🤖 AI · CODEIUM · .TXT · GIT-DIFF — <leader>A
        -------------------------------------------------------------
        { "<leader>A", group = "🤖 AI · Codeium · .txt · Git-Diff" },
        { "<leader>AG", desc = "⚡ Codeium / NeoCodeium (Ghost Text): вкл/выкл (:CodeiumToggle)" },
        { "<leader>AK", desc = "🔑 Авторизация Codeium / NeoCodeium (:CodeiumAuth)" },
        { "<leader>Ai", desc = "⚡ Запросить подсказку Codeium вручную" },
        { "<leader>Ah", desc = "🧠 Размышления ИИ: скрыть/показать (:AiThinkingToggle)" },
        { "<leader>AF", desc = "📄 Файл → .txt → ИИ → правки как в git (:AiFileTxt)" },
        { "<leader>AT", desc = "📄 Прикрепить файл как .txt в чат Avante (:AvanteFileTxt)" },
        { "<leader>AD", desc = "🔀 Показать изменения файла от ИИ как в git (:AiDiffLast)" },
        { "<leader>Ag", desc = "✨ Чат Avante → прямой Google Gemini (:AvanteGemini)" },
        { "<leader>Ao", desc = "🌐 Чат Avante → OpenRouter (:AvanteOpenRouter)" },
        { "<leader>Am", desc = "🎛 Выбрать модель в чате Avante (:AvanteModels)" },
        { "<leader>Ak", desc = "🔑 Задать API-ключ ИИ на сеанс (:AvanteKey)" },
        { "<leader>Ac", desc = "💬 CodeCompanion: чат с ИИ" },
        { "<leader>AA", desc = "🛠 CodeCompanion: меню действий AI" },
        { "<leader>Av", desc = "📤 CodeCompanion: отправить выделение" },
        { "<leader>AM", desc = "✨ CodeCompanion: inline-команда" },
        { "<leader>AI", desc = "🩺 Статус Avante и библиотек (:AvanteStatus)" },
        { "<leader>AU", desc = "🔧 Восстановить Avante (:AvanteRebuild)" },
        { "<leader>AL", "<cmd>Lazy sync<cr>", desc = "🔄 Lazy sync (обновить плагины)" },
        { "<leader>AX", desc = "🔓 Снять git-блокировки Lazy (:LazyUnlock)" },

        -------------------------------------------------------------
        --  💎 OBSIDIAN — <leader>o
        -------------------------------------------------------------
        { "<leader>o", group = "💎 Obsidian" },
        { "<leader>os", "<cmd>ObsidianSearch<cr>", desc = "🔎 Поиск заметок" },
        { "<leader>on", "<cmd>ObsidianNew<cr>", desc = "📝 Новая заметка" },

        -------------------------------------------------------------
        --  🌐 ПЕРЕВОД · 🧪 ТЕСТЫ · 📖 ДОК — <leader>t
        -------------------------------------------------------------
        { "<leader>t", group = "🌐 Перевод · 🧪 Тесты · 📖 Док" },
        { "<leader>tn", "<cmd>Neotest jump next<cr>", desc = "⬇️ Следующий тест" },

        -------------------------------------------------------------
        --  🎨 ВИЗУАЛ · ⚡ CODEIUM · 🐾 ПИТОМЦЫ — <leader>u
        -------------------------------------------------------------
        { "<leader>u", group = "🎨 Визуал · ⚡ Codeium · 🐾 Питомцы" },
        { "<leader>ui", desc = "⚡ Призрачные подсказки Codeium (Ghost Text): вкл/выкл" },
        { "<leader>um", desc = "🪟 Развернуть/восстановить окно" },
        { "<leader>uM", desc = "🪟 Принудительно вернуть раскладку" },

        -------------------------------------------------------------
        --  ⚠️ ОШИБКИ И ЖУРНАЛ — <leader>x
        -------------------------------------------------------------
        { "<leader>x", group = "⚠️ Ошибки и журнал (Trouble / Nvim)" },
        { "<leader>xe", desc = "🔟 Последние 10 ошибок Neovim (:ErrorLast10)" },
        { "<leader>xj", desc = "📜 Журнал ошибок Neovim (:ErrorLog)" },
        { "<leader>xg", desc = "📜 Журнал ошибок Neovim (алиас)" },
        { "<leader>xs", "<cmd>Trouble symbols toggle<cr>", desc = "🧭 Символы файла (Trouble)" },
        { "<leader>xt", "<cmd>Trouble todo toggle<cr>", desc = "📝 TODO-комментарии (Trouble)" },

        -------------------------------------------------------------
        --  📓 ЧЕРНОВИКИ И ПОДСВЕТКА — <leader>n
        -------------------------------------------------------------
        { "<leader>n", group = "📓 Черновики и подсветка" },
        { "<leader>nh", "<cmd>nohlsearch<cr>", desc = "🔎 Убрать подсветку поиска" },

        -------------------------------------------------------------
        --  ⌨️ НАЖАТИЯ И ШПАРГАЛКИ (cheat.sh) — <leader>k
        -------------------------------------------------------------
        { "<leader>k", group = "⌨️ Нажатия · 📚 Шпаргалки" },
        {
          "<leader>kc",
          function()
            vim.ui.input({ prompt = "cheat.sh: " }, function(q)
              if q and q ~= "" then vim.cmd("Cheat " .. q) end
            end)
          end,
          desc = "📚 Шпаргалка по запросу (cheat.sh)",
        },
        { "<leader>kl", "<cmd>CheatList<cr>", desc = "📋 Поиск по всем шпаргалкам" },

        -------------------------------------------------------------
        --  📋 БУФЕР ОБМЕНА И MACOS — <leader>y
        -------------------------------------------------------------
        { "<leader>y", group = "📋 Буфер обмена и macOS" },
        { "<leader>yr", function() require("config.yank_ring").pick() end, desc = "📋 Кольцо буфера обмена (1–9)" },
        { "<leader>ym", function() vim.cmd("vsplit " .. vim.fn.stdpath("config") .. "/macos/README.md") end, desc = "🍎 macOS: клавиатура и Maccy (инструкция)" },
        { "<leader>yk", function() vim.notify("⌃⌥⌘K — экранная клавиатура (Hammerspoon). Инструкция: <leader>ym", vim.log.levels.INFO) end, desc = "⌨ Экранная клавиатура macOS (⌃⌥⌘K)" },

        -------------------------------------------------------------
        --  🚀 HTTP И ПЕРЕИМЕНОВАНИЕ — <leader>r
        -------------------------------------------------------------
        { "<leader>r", group = "🚀 HTTP и переименование" },
        { "<leader>rf", function() require("snacks").rename.rename_file() end, desc = "✏️ Переименовать файл" },

        -------------------------------------------------------------
        --  🧰 TUI-УТИЛИТЫ — <leader>U
        -------------------------------------------------------------
        { "<leader>U", group = "🧰 TUI-утилиты (k9s, iredis, pgcli…)" },
        { "<leader>UD", require("config.termcmd").make("discordo", 150, "discordo"), desc = "💬 Discordo — Discord в терминале (⚠ риск для аккаунта)" },

        -------------------------------------------------------------
        --  🖥 ТЕРМИНАЛ — <leader>T (клавиши в toggleterm.lua)
        -------------------------------------------------------------
        { "<leader>T", group = "🖥 Терминал (toggleterm)" },
        { "<leader>Tt", desc = "📟 Плавающий терминал" },
        { "<leader>Th", desc = "📟 Терминал снизу" },
        { "<leader>Tv", desc = "📟 Терминал справа" },
        { "<leader>Ta", desc = "❎ Показать/скрыть все терминалы" },
        { "<leader>Tc", desc = "❎ Закрыть все терминалы" },
        { "<leader>Tl", desc = "➡ Строку в терминал" },

        -------------------------------------------------------------
        --  🗄 БАЗЫ ДАННЫХ — КАТАЛОГ <leader>D (lua/config/db_menu.lua)
        -------------------------------------------------------------
        { "<leader>D", group = "🗄 Базы данных (каталог)" },
        { "<leader>Ds", group = "🪶 SQLite" },
        { "<leader>Dm", group = "🐬 MySQL / MariaDB" },
        { "<leader>Dp", group = "🐘 PostgreSQL" },
        { "<leader>Do", group = "🏛 Oracle" },
        { "<leader>Dx", group = "🟦 SQL Server" },
        { "<leader>Dc", group = "🏠 ClickHouse" },

        -------------------------------------------------------------
        --  🛠 КОД: РАЗБИТЬ/СОБРАТЬ (treesj) — <leader>c
        -------------------------------------------------------------
        { "<leader>c", group = "🛠 Код" },
        { "<leader>cj", "<cmd>TSJToggle<cr>", desc = "🔀 Разбить/собрать конструкцию (переключить)" },
        { "<leader>cs", "<cmd>TSJSplit<cr>", desc = "✂ Разбить конструкцию на строки" },
        { "<leader>cJ", "<cmd>TSJJoin<cr>", desc = "🔗 Собрать конструкцию в одну строку" },

        -------------------------------------------------------------
        --  ОСТАЛЬНЫЕ ГРУППЫ <leader>
        -------------------------------------------------------------
        { "<leader>G", group = "🐙 GitHub · 🦊 GitLab · 📰 Хабр" },
        { "<leader>K", group = "📖 Английский: перевод слов" },
        { "<leader>P", group = "🧊 Protobuf (buf)" },
        { "<leader>a", group = "🌳 Структура (aerial)" },
        { "<leader>b", group = "📑 Буферы" },
        { "<leader>h", group = "📌 Harpoon (закладки)" },
        { "<leader>j", group = "🧾 JSON" },
        { "<leader>p", group = "⏱ Pomodoro (таймер)" },
        { "<leader>q", group = "🚪 Закрыть окно · сессии · sudo" },
        { "<leader>X", group = "🎮 Игры: шахматы · змейка · тетрис · 2048" },
        { "<leader>I", group = "🖼 Картинки (Ghostty / Kitty)" },
        { "<leader>s", group = "🎵 Spotify · 📸 скриншот" },
        { "<leader>W", group = "🪟 Окна: дерево · код · терминал" },
      },
    },

    config = function(_, opts)
      require("which-key").setup(opts)
    end,
  },
}
