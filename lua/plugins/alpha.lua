-- ========================================================================== --
--                        ДАШБОРД (alpha-nvim)                                --
-- ========================================================================== --
-- ИСПРАВЛЕНО:
--  1) Кнопка "📂 Проекты" вела на :Telescope projects — такого расширения
--     (telescope-project.nvim) в конфиге нет, нажатие давало E492.
--     Заменено на :Telescope oldfiles.
--  2) Таймер анимации создавался без close() и продолжал тикать после
--     закрытия дашборда — добавлены остановка и закрытие таймера.
return {
  {
    "goolord/alpha-nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VimEnter",
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      -- 1. КАДРЫ ТАНЦА (Анимация)
      local d1 = {
        [[            ⊚___________⊚      ]],
        [[   \\\\      /             \\      ]],
        [[    \\\\    /   ●       ●   \\     ]],
        [[     \\\\  |        ◡        |    ]],
        [[      \\\\  \\_______________/     ]],
        [[            /               \\     ]],
        [[           /                 \\    ]],
        [[          |   |         |     |   ]],
        [[          |_|       |_|       ]],
      }
      local d2 = {
        [[            ⊚___________⊚      ]],
        [[            /             \\      ////]],
        [[           /   ●       ●   \\    //// ]],
        [[          |        o        |  ////  ]],
        [[           \\_______________/  ////   ]],
        [[            /               \\        ]],
        [[           /                 \\       ]],
        [[          |   |         |     |      ]],
        [[            \\_\\       /_/          ]],
      }

      -- 2. СЦЕНА LOVE (Rast & Polina)
      local twins_scene = {
        [[      ⊚___________⊚       ⊚___________⊚       ]],
        [[     /             \\     /             \\      ]],
        [[    /   💙     💙   \\   /   🩷     🩷   \\     ]],
        [[   |        ◡        |  |        ◡       |    ]],
        [[    \\_______________/   \\_______________/     ]],
        [[     /             \\     \\           /       ]],
        [[    /               \\     )         (        ]],
        [[   |   |         |   |    /           \\       ]],
        [[   |   |_________|   |   |_____________|      ]],
        [[    \\_______________/   \\_______________/     ]],
        [[       |_|       |_|       |_|       |_|      ]],
        [[                                              ]],
        [[        (RAST)              (POLINA)          ]],
      }

      -- 3. ЭПИЧЕСКАЯ БИТВА (GO DEFEATS PYTHON)
      local fight_scene = {
        [[       ⚔️  GO DEFEATS PYTHON  ⚔️      ]],
        [[                                     ]],
        [[     ⊚___________⊚        🔥  RIP 🔥  ]],
        [[    /             \\      ____________ ]],
        [[   /   ●       ●   \\    /  ❌    ❌  \\  ]],
        [[  |        ◡        |  |      __      |  ]],
        [[   \\_______________/    \\    /  \\    /   ]],
        [[    /      |      \\      \\__/    \\__/    ]],
        [[   /       |       \\     /  ____  \\      ]],
        [[  |   |    |    |   |   /  /    \\  \\     ]],
        [[  |___|____|____|___|   \\  \\____/  /     ]],
        [[     |_|       |_|       \\________/      ]],
      }

      -- 4. СЦЕНА HACKER
      local hacker_scene = {
        [[       ░▒▓█ SYSTEM OVERLOAD █▓▒░       ]],
        [[                                       ]],
        [[   010101   ⊚___________⊚   101010     ]],
        [[   110011  /             \\  001100    ]],
        [[   001101 /   ●       ●   \\ 110110    ]],
        [[   [LOAD] |      ---      |  [INIT]    ]],
        [[   011011  \\_______________/  101101   ]],
        [[   101010   /      |      \\   010101   ]],
        [[   root@go:/# _  /   \\  _  tail -f    ]],
        [[   |   |        /     \\        |   |  ]],
        [[   |___|_______/       \\_______|___|  ]],
        [[      |_|      [HACKED]       |_|      ]],
      }

      -- ЛОГИКА ВЫБОРА СЦЕНЫ
      local scenes = { "dance", "love", "fight", "hacker" }
      math.randomseed(os.time())
      local choice = scenes[math.random(#scenes)]

      if choice == "love" then
        dashboard.section.header.val = twins_scene
        -- Двухцветная раскраска по колонкам: слева Rast, справа Polina
        dashboard.section.header.opts.hl = {
          { "Identifier", 0, 26 },
          { "Keyword", 27, 60 },
        }
      elseif choice == "fight" then
        dashboard.section.header.val = fight_scene
        dashboard.section.header.opts.hl = "ErrorMsg"
      elseif choice == "hacker" then
        dashboard.section.header.val = hacker_scene
        dashboard.section.header.opts.hl = "DiagnosticOk"
      else
        dashboard.section.header.val = d1
        dashboard.section.header.opts.hl = "Identifier"
      end

      -- Кнопки меню (все команды существуют в конфиге)
      dashboard.section.buttons.val = {
        dashboard.button("f", "  Найти файл", ":Telescope find_files<CR>"),
        dashboard.button("r", "  Недавние файлы", ":Telescope oldfiles<CR>"),
        dashboard.button("g", "  Текст по проекту", ":Telescope live_grep<CR>"),
        dashboard.button("e", "  Дерево файлов", ":NvimTreeToggle<CR>"),
        dashboard.button("q", "  Выход", ":qa<CR>"),
      }

      alpha.setup(dashboard.config)

      -- Таймер анимации (только если выпал танец)
      if choice == "dance" then
        local timer = (vim.uv or vim.loop).new_timer()
        local state = true
        timer:start(0, 500, vim.schedule_wrap(function()
          if vim.bo.filetype ~= "alpha" then
            pcall(function() timer:stop() end)
            pcall(function() timer:close() end)
            return
          end
          dashboard.section.header.val = state and d2 or d1
          state = not state
          pcall(alpha.redraw)
        end))
      end
    end,
  },
}
