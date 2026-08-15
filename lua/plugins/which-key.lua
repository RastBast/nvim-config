
return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      plugins = {
        spelling = { enabled = true },
        presets = {
          operators   = false,
          motions     = false,
          text_objects = false,
          windows     = false,
          nav         = false,
          z           = false,
          g           = false,
        },
      },

      -----------------------------------------------------------------
      --  СПЕЦИФИКАЦИЯ (spec) – добавляем новые группы,
      --  оставляя всё, что уже было у тебя
      -----------------------------------------------------------------
      spec = {
        -------------------------------------------------------------
        --  🎛  Главное меню (через <leader>H) – оставляем как было
        -------------------------------------------------------------
        { "<leader>H", group = "🎛 Главное меню" },

        -------------------------------------------------------------
        --  🔍 Поиск и Файлы (H + f) – без изменений
        -------------------------------------------------------------
        { "<leader>Hf", group = "🔍 Поиск и Файлы" },
        { "<leader>Hff",  "<cmd>Telescope find_files<cr>",          desc = "📂 Найти файл" },
        { "<leader>Hfg",  "<cmd>Telescope live_grep<cr>",          desc = "🔎 Live grep" },
        { "<leader>Hfb",  "<cmd>Telescope buffers<cr>",            desc = "🗂 Открыть буферы" },
        { "<leader>Hfh",  "<cmd>Telescope help_tags<cr>",          desc = "❓ Поиск по справке" },
        { "<leader>Hfr",  "<cmd>Telescope oldfiles<cr>",           desc = "🕑 Недавние файлы" },
        { "<leader>Hft",  "<cmd>Telescope todo<cr>",               desc = "📝 TODO/FIXME" },

        -------------------------------------------------------------
        --  🌿 Git и Go (H + g) – без изменений
        -------------------------------------------------------------
        { "<leader>Hg",  group = "🌿 Git и Go" },
        { "<leader>Hgs", "<cmd>lua require('gitsigns').stage_hunk()<cr>",    desc = "📦 Stage hunk" },
        { "<leader>Hgu", "<cmd>lua require('gitsigns').reset_hunk()<cr>",    desc = "↩️ Undo stage hunk" },
        { "<leader>Hgb", "<cmd>lua require('gitsigns').blame_line()<cr>",    desc = "🕵️‍♂️ Показать автора строки" },
        { "<leader>Hgh", "<cmd>lua require('gitsigns').preview_hunk()<cr>",  desc = "🔎 Предпросмотр изменений" },
        { "<leader>Hti", "<cmd>GoTagAdd json<cr>",       desc = "🏷 Добавить json‑теги" },
        { "<leader>Hie", "<cmd>GoIfErr<cr>",             desc = "❗ Авто‑if err" },
        { "<leader>Hfs", "<cmd>GoFillStruct<cr>",        desc = "🧩 Заполнить struct" },
        { "<leader>Hj2s","<cmd>GoJson2Struct<cr>",       desc = "📦 JSON → struct" },
        { "<leader>Him", "<cmd>GoImpl<cr>",              desc = "⚙️ Сгенерировать impl" },
        { "<leader>Hvc", "<cmd>GoVulncheck<cr>",         desc = "🔐 Проверка уязвимостей" },
        { "<leader>Ht",  "<cmd>GoTest<cr>",              desc = "🧪 Запуск тестов" },

        -------------------------------------------------------------
        --  🗄 Базы и Отладка (H + d) – без изменений
        -------------------------------------------------------------
        { "<leader>Hd",  group = "🗄 Базы и Отладка" },
        { "<leader>Hdu", "<cmd>DBUI<cr>",                           desc = "💾 Открыть панель БД" },
        { "<leader>Hda", "<cmd>DBUI AddConnection<cr>",            desc = "➕ Добавить подключение" },
        { "<leader>Hde", "<cmd>DBUI ExecuteQuery<cr>",            desc = "🚀 Выполнить запрос" },
        { "<leader>Hdb", "<cmd>lua require('dap').toggle_breakpoint()<cr>", desc = "⛔ Точка останова" },
        { "<leader>Hdr", "<cmd>lua require('dap').continue()<cr>",          desc = "▶️ Старт/Продолжить" },
        { "<leader>Hdi", "<cmd>lua require('dap').step_into()<cr>",        desc = "🔽 Шаг в" },
        { "<leader>Hdo", "<cmd>lua require('dap').step_over()<cr>",        desc = "⏭ Шаг через" },
        { "<leader>Hdt", "<cmd>lua require('dap-go').debug_test()<cr>",    desc = "🧪 Тест в режиме отладки" },

        -------------------------------------------------------------
        --  🤖 AI и Структура (H + a) – без изменений
        -------------------------------------------------------------
        { "<leader>Ha",  group = "🤖 AI и Структура" },
        { "<leader>Hat", "<cmd>CodeCompanionChat<cr>",    desc = "💬 Открыть чат с ИИ" },
        { "<leader>Hai", "<cmd>CodeCompanionActions<cr>",  desc = "🛠 AI‑меню действий" },
        { "<leader>Hae", "<cmd>CodeCompanionSend<cr>",     desc = "📤 Отправить выделение ИИ" },
        { "<leader>Has", "<cmd>AerialToggle!<cr>",         desc = "📑 Показать структуру файла" },

        -------------------------------------------------------------
        --  💎 Obsidian (H + o) – без изменений
        -------------------------------------------------------------
        { "<leader>Ho",  group = "💎 Obsidian" },
        { "<leader>Hos", "<cmd>ObsidianSearch<cr>",       desc = "🔎 Поиск заметок" },
        { "<leader>Hon", "<cmd>ObsidianNew<cr>",          desc = "📝 Новая заметка" },
        { "<leader>Hof", "<cmd>ObsidianFollowLink<cr>",   desc = "🔗 Перейти по ссылке" },
        { "<leader>Hot", "<cmd>ObsidianToggleCheckbox<cr>", desc = "☑ Тоггл чекбокса" },

        -------------------------------------------------------------
        --  🧪 Тесты (H + t) – без изменений
        -------------------------------------------------------------
        { "<leader>Ht",  group = "🧪 Тесты" },
        { "<leader>Htr", "<cmd>Neotest run<cr>",            desc = "▶️ Запуск теста под курсором" },
        { "<leader>Htf", "<cmd>Neotest run file<cr>",       desc = "📂 Запуск всех тестов в файле" },
        { "<leader>Hts", "<cmd>Neotest summary<cr>",        desc = "🗂 Окно со статусом тестов" },
        { "<leader>Hto", "<cmd>Neotest output<cr>",         desc = "📄 Показать вывод ошибки" },
        { "<leader>Htn", "<cmd>Neotest jump next<cr>",      desc = "⬇️ Следующий тест" },

        -------------------------------------------------------------
        --  🎨 Визуал и UI (H + u) – без изменений
        -------------------------------------------------------------
        { "<leader>Hu",  group = "🎨 Визуал и UI" },
        { "<leader>Hsc", "<cmd>Silicon<cr>",                desc = "📸 Скриншот кода (Silicon)" },
        { "<leader>Hrr", "<cmd>KulalaRun<cr>",              desc = "🚀 HTTP‑запрос (Kulala)" },
        { "<leader>Hz",  "<cmd>ZenMode<cr>",                desc = "🧘 Дзен‑режим" },
        { "<leader>Hm",  "<cmd>MaximizerToggle!<cr>",       desc = "🪟 Развернуть/восстановить окно" },
        { "<leader>Hup", "<cmd>Pets<cr>",                   desc = "🐾 Питомец (Pets)" },
        { "<leader>Hua", "<cmd>lua require('noice').toggle()<cr>", desc = "✨ Переключить анимации" },
        { "<leader>Hpt", "<cmd>PomodoroStart<cr>",          desc = "⏱️ Старт Pomodoro" },
        { "<leader>Hps", "<cmd>PomodoroStop<cr>",           desc = "⏱️ Стоп Pomodoro" },

        -------------------------------------------------------------
        --  📌 Harpoon (H + h) – без изменений
        -------------------------------------------------------------
        { "<leader>Hh",  group = "📌 Harpoon" },
        { "<leader>Hha", "<cmd>lua require('harpoon.mark').add_file()<cr>",   desc = "📍 Добавить файл в Harpoon" },
        { "<leader>Hhh", "<cmd>lua require('harpoon.ui').toggle_quick_menu()<cr>", desc = "📂 Открыть меню Harpoon" },
        { "<leader>Hh1", "<cmd>lua require('harpoon.ui').nav_file(1)<cr>",      desc = "🚀 Перейти к 1‑му файлу" },
        { "<leader>Hh2", "<cmd>lua require('harpoon.ui').nav_file(2)<cr>",      desc = "🚀 Перейти к 2‑му файлу" },

        -------------------------------------------------------------
        --  🔌 Плагины (H + p) – без изменений
        -------------------------------------------------------------
        { "<leader>Hp",  group = "🔌 Плагины" },
        { "<leader>Hpl", "<cmd>Lazy<cr>",           desc = "📦 Открыть Lazy UI" },
        { "<leader>Hpm", "<cmd>Mason<cr>",          desc = "🛠 Открыть Mason UI" },
        { "<leader>Hli", "<cmd>LspInfo<cr>",        desc = "📝 LspInfo" },
        { "<leader>Hch", "<cmd>checkhealth<cr>",    desc = "⚙️ Checkhealth" },

        -------------------------------------------------------------
        --  ⚠️ Диагностика (H + x) – без изменений
        -------------------------------------------------------------
        { "<leader>Hx",  group = "⚠️ Диагностика" },
        { "<leader>Hxx", "<cmd>TroubleToggle<cr>",   desc = "❗ Показать все ошибки (Trouble)" },

        -------------------------------------------------------------
        --  📦 Прочее (H + n) – без изменений
        -------------------------------------------------------------
        { "<leader>Hn",  group = "📦 Прочее" },
        { "<leader>Hnh", "<cmd>nohlsearch<cr>",      desc = "🔎 Убрать подсветку поиска" },
        { "<leader>He",  "<cmd>NvimTreeToggle<cr>",  desc = "🗂 Дерево файлов (nvim‑tree)" },

        -------------------------------------------------------------
        --  🖥 Терминал (toggleterm)  ← **НОВАЯ ГРУППА**
        -------------------------------------------------------------
        { "<leader>Ht",  group = "🖥 Терминал (toggleterm)" },

        --  Плавающий терминал (то, что уже открывается по <C-\>)
        { "<leader>Htt", "<cmd>ToggleTerm direction=float<cr>",    desc = "📟 Плавающий терминал" },

        --  Горизонтальный терминал (15‑строкой снизу)
        { "<leader>Hth", "<cmd>ToggleTerm direction=horizontal size=15<cr>", desc = "📟 Горизонтальный терминал" },

        --  Вертикальный терминал (40‑колонок справа)
        { "<leader>Htv", "<cmd>ToggleTerm direction=vertical size=40<cr>",     desc = "📟 Вертикальный терминал" },

        --  Закрыть **все** открытые toggle‑терминалы
        { "<leader>Htc", "<cmd>ToggleTermCloseAll<cr>",          desc = "❎ Закрыть все терминалы" },

        -------------------------------------------------------------
        --  📂 Создать файл/директорию  ← **НОВАЯ ГРУППА**
        -------------------------------------------------------------
        { "<leader>Hc",  group = "📂 Создать файл/директорию" },

        --  Открывает обычный prompt `NvimTreeCreate`. Вводишь имя,
        --  а если в конце ставишь `/` – будет создана папка.
        { "<leader>Hcf", "<cmd>NvimTreeCreate<cr>",               desc = "🆕 Создать файл/директорию (prompt)" },

      },   -- ← конец spec
    },

    config = function(_, opts)
      require("which-key").setup(opts)
    end,
  },
}
