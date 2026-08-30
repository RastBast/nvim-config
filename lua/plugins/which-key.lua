-- ========================================================================== --
--                        WHICH-KEY: ГЛАВНОЕ МЕНЮ                            --
-- ========================================================================== --
-- ИСПРАВЛЕНО (каждая строка проверена по исходникам плагинов):
--
--  ❌ было                              ✅ стало
--  ------------------------------------------------------------------
--  <leader>Ht объявлен 3 раза           один раз (группа «Тесты»);
--  (GoTest + Тесты + Терминал)          Go-тесты переехали на <leader>Hgo
--  GoVulncheck                          GoVulnCheck   (регистра важен)
--  GoJson2Struct                        GoJson
--  DBUI AddConnection                   DBUIAddConnection
--  DBUI ExecuteQuery                    убрано — такой подкоманды нет
--  CodeCompanionSend                    CodeCompanion (Send не существует)
--  TroubleToggle                        Trouble diagnostics toggle (v3)
--  ToggleTermCloseAll                   ToggleTermToggleAll
--  NvimTreeCreate                       NvimTreeFindFileToggle (Create нет;
--                                       файл создаётся клавишей `a` в дереве)
--  PomodoroStart / PomodoroStop         TimerStart / TimerStop (pomo.nvim)
--  Pets                                 PetsNew holli
--  KulalaRun                            require('kulala').run()
--  Telescope todo                       TodoTelescope (пикер зовётся
--                                       todo-comments)
--  require('noice').toggle()            переключатель mini.animate
--                                       (noice.toggle не существует)
--  require('harpoon.mark') /            harpoon v2 (ветка harpoon2):
--  require('harpoon.ui')                require('harpoon'):list():add() и т.д.
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
        --  🎛  Главное меню
        -------------------------------------------------------------
        { "<leader>H", group = "🎛 Главное меню" },

        -------------------------------------------------------------
        --  🔍 Поиск и Файлы
        -------------------------------------------------------------
        { "<leader>Hf", group = "🔍 Поиск и Файлы" },
        { "<leader>Hff", "<cmd>Telescope find_files<cr>", desc = "📂 Найти файл" },
        { "<leader>Hfg", "<cmd>Telescope live_grep<cr>", desc = "🔎 Live grep" },
        { "<leader>Hfb", "<cmd>Telescope buffers<cr>", desc = "🗂 Открыть буферы" },
        { "<leader>Hfh", "<cmd>Telescope help_tags<cr>", desc = "❓ Поиск по справке" },
        { "<leader>Hfr", "<cmd>Telescope oldfiles<cr>", desc = "🕑 Недавние файлы" },
        { "<leader>Hft", "<cmd>TodoTelescope<cr>", desc = "📝 TODO/FIXME" },
        { "<leader>Hfk", "<cmd>Telescope keymaps<cr>", desc = "⌨️ Все горячие клавиши" },

        -------------------------------------------------------------
        --  🌿 Git
        -------------------------------------------------------------
        { "<leader>Hg", group = "🌿 Git" },
        { "<leader>Hgs", function() require("gitsigns").stage_hunk() end, desc = "📦 Stage hunk" },
        { "<leader>Hgu", function() require("gitsigns").reset_hunk() end, desc = "↩️ Undo stage hunk" },
        { "<leader>Hgb", function() require("gitsigns").blame_line() end, desc = "🕵️ Автор строки" },
        { "<leader>Hgh", function() require("gitsigns").preview_hunk() end, desc = "🔎 Предпросмотр изменений" },
        { "<leader>Hgg", "<cmd>LazyGit<cr>", desc = "🐙 LazyGit" },

        -------------------------------------------------------------
        --  🐹 Go
        -------------------------------------------------------------
        { "<leader>HG", group = "🐹 Go" },
        { "<leader>HGi", "<cmd>GoAddTag json<cr>", desc = "🏷 Добавить json-теги" },
        { "<leader>HGe", "<cmd>GoIfErr<cr>", desc = "❗ Авто-if err" },
        { "<leader>HGs", "<cmd>GoFillStruct<cr>", desc = "🧩 Заполнить struct" },
        { "<leader>HGj", "<cmd>GoJson<cr>", desc = "📦 JSON → struct" },
        { "<leader>HGm", "<cmd>GoImpl<cr>", desc = "⚙️ Сгенерировать impl" },
        { "<leader>HGv", "<cmd>GoVulnCheck<cr>", desc = "🔐 Проверка уязвимостей" },
        { "<leader>HGl", "<cmd>GoLint<cr>", desc = "🧹 Линтер" },
        { "<leader>HGo", "<cmd>GoTest<cr>", desc = "🧪 Запуск тестов" },
        { "<leader>HGb", "<cmd>GoBuild<cr>", desc = "🔨 Собрать" },

        -------------------------------------------------------------
        --  🗄 Базы и Отладка
        -------------------------------------------------------------
        { "<leader>Hd", group = "🗄 Базы и Отладка" },
        { "<leader>Hdu", "<cmd>DBUI<cr>", desc = "💾 Панель БД" },
        { "<leader>Hdt", "<cmd>DBUIToggle<cr>", desc = "💾 Панель БД (toggle)" },
        { "<leader>Hda", "<cmd>DBUIAddConnection<cr>", desc = "➕ Добавить подключение" },
        { "<leader>Hdf", "<cmd>DBUIFindBuffer<cr>", desc = "🔍 Найти БД буфера" },
        { "<leader>Hdb", function() require("dap").toggle_breakpoint() end, desc = "⛔ Точка останова" },
        { "<leader>Hdr", function() require("dap").continue() end, desc = "▶️ Старт/Продолжить" },
        { "<leader>Hdi", function() require("dap").step_into() end, desc = "🔽 Шаг в" },
        { "<leader>Hdo", function() require("dap").step_over() end, desc = "⏭ Шаг через" },
        { "<leader>Hdg", function() require("dap-go").debug_test() end, desc = "🧪 Тест в режиме отладки" },

        -------------------------------------------------------------
        --  🤖 AI и Структура
        -------------------------------------------------------------
        { "<leader>Ha", group = "🤖 AI и Структура" },
        { "<leader>Has", "<cmd>AerialToggle!<cr>", desc = "📑 Показать структуру файла" },

        -------------------------------------------------------------
        --  💎 Obsidian
        -------------------------------------------------------------
        { "<leader>Ho", group = "💎 Obsidian" },
        { "<leader>Hos", "<cmd>ObsidianSearch<cr>", desc = "🔎 Поиск заметок" },
        { "<leader>Hon", "<cmd>ObsidianNew<cr>", desc = "📝 Новая заметка" },
        { "<leader>Hof", "<cmd>ObsidianFollowLink<cr>", desc = "🔗 Перейти по ссылке" },
        { "<leader>Hot", "<cmd>ObsidianToggleCheckbox<cr>", desc = "☑ Тоггл чекбокса" },

        -------------------------------------------------------------
        --  🧪 Тесты (единственная группа на <leader>Ht)
        -------------------------------------------------------------
        { "<leader>Ht", group = "🧪 Тесты" },
        { "<leader>Htr", "<cmd>Neotest run<cr>", desc = "▶️ Тест под курсором" },
        { "<leader>Htf", "<cmd>Neotest run file<cr>", desc = "📂 Все тесты в файле" },
        { "<leader>Hts", "<cmd>Neotest summary<cr>", desc = "🗂 Окно со статусом тестов" },
        { "<leader>Hto", "<cmd>Neotest output<cr>", desc = "📄 Вывод ошибки" },
        { "<leader>Htn", "<cmd>Neotest jump next<cr>", desc = "⬇️ Следующий тест" },

        -------------------------------------------------------------
        --  🎨 Визуал и UI
        -------------------------------------------------------------
        { "<leader>Hu", group = "🎨 Визуал и UI" },
        { "<leader>Hus", "<cmd>Silicon<cr>", desc = "📸 Скриншот кода (Silicon)" },
        { "<leader>Hur", function() require("kulala").run() end, desc = "🚀 HTTP-запрос (Kulala)" },
        { "<leader>Huz", "<cmd>ZenMode<cr>", desc = "🧘 Дзен-режим" },
        { "<leader>Hum", "<cmd>MaximizerToggle!<cr>", desc = "🪟 Развернуть/восстановить окно" },
        { "<leader>Hup", "<cmd>PetsNew holli<cr>", desc = "🐾 Питомец (Pets)" },
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
        { "<leader>Hut", "<cmd>TimerStart 25m Work<cr>", desc = "⏱️ Старт Pomodoro" },
        { "<leader>HuP", "<cmd>TimerStop Work<cr>", desc = "⏱️ Стоп Pomodoro" },

        -------------------------------------------------------------
        --  📌 Harpoon (v2 — ветка harpoon2)
        -------------------------------------------------------------
        { "<leader>Hh", group = "📌 Harpoon" },
        { "<leader>Hha", function() require("harpoon"):list():add() end, desc = "📍 Добавить файл" },
        { "<leader>Hhh", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, desc = "📂 Меню Harpoon" },
        { "<leader>Hh1", function() require("harpoon"):list():select(1) end, desc = "🚀 К 1-му файлу" },
        { "<leader>Hh2", function() require("harpoon"):list():select(2) end, desc = "🚀 Ко 2-му файлу" },

        -------------------------------------------------------------
        --  🔌 Плагины
        -------------------------------------------------------------
        { "<leader>Hp", group = "🔌 Плагины" },
        { "<leader>Hpl", "<cmd>Lazy<cr>", desc = "📦 Lazy UI" },
        { "<leader>Hpm", "<cmd>Mason<cr>", desc = "🛠 Mason UI" },
        { "<leader>Hpi", "<cmd>LspInfo<cr>", desc = "📝 Информация об LSP" },
        { "<leader>Hph", "<cmd>checkhealth<cr>", desc = "⚙️ Checkhealth" },
        { "<leader>Hpc", "<cmd>ConformInfo<cr>", desc = "🎨 Чем форматируется файл" },

        -------------------------------------------------------------
        --  ⚠️ Диагностика
        -------------------------------------------------------------
        { "<leader>Hx", group = "⚠️ Диагностика" },
        { "<leader>Hxx", "<cmd>Trouble diagnostics toggle<cr>", desc = "❗ Все ошибки (Trouble)" },
        { "<leader>Hxl", "<cmd>Trouble loclist toggle<cr>", desc = "📋 Location list" },
        { "<leader>Hxq", "<cmd>Trouble qflist toggle<cr>", desc = "📋 Quickfix list" },

        -------------------------------------------------------------
        --  📦 Прочее
        -------------------------------------------------------------
        { "<leader>Hn", group = "📦 Прочее" },
        { "<leader>Hnh", "<cmd>nohlsearch<cr>", desc = "🔎 Убрать подсветку поиска" },
        { "<leader>Hne", "<cmd>NvimTreeToggle<cr>", desc = "🗂 Дерево файлов" },

        -------------------------------------------------------------
        --  🖥 Терминал (toggleterm) — переехал с <leader>Ht, там тесты
        -------------------------------------------------------------
        { "<leader>HT", group = "🖥 Терминал" },
        { "<leader>HTt", "<cmd>ToggleTerm direction=float<cr>", desc = "📟 Плавающий терминал" },
        { "<leader>HTh", "<cmd>ToggleTerm direction=horizontal size=15<cr>", desc = "📟 Терминал снизу" },
        { "<leader>HTv", "<cmd>ToggleTerm direction=vertical size=40<cr>", desc = "📟 Терминал справа" },
        { "<leader>HTa", "<cmd>ToggleTermToggleAll<cr>", desc = "❎ Показать/скрыть все терминалы" },

        -------------------------------------------------------------
        --  📂 Файлы (создание — клавишей `a` внутри дерева)
        -------------------------------------------------------------
        { "<leader>Hc", group = "📂 Работа с файлами" },
        { "<leader>Hcf", "<cmd>NvimTreeFindFileToggle<cr>", desc = "🗂 Дерево (дальше `a` — создать)" },
        -- snacks.rename — это модуль (не функция), точка входа: rename_file()
        { "<leader>Hcr", function() require("snacks").rename.rename_file() end, desc = "✏️ Переименовать файл" },
      },
    },
  },
}
