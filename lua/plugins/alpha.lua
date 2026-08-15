return {
  {
    "goolord/alpha-nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
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
           -- 2. СЦЕНА LOVE (Rast & Polina) — ЦЕЛЬНАЯ ТАЛИЯ
      local twins_scene = {
        [[      ⊚___________⊚       ⊚___________⊚       ]],
        [[     /             \\     /             \\      ]],
        [[    /   💙     💙   \\   /   🩷     🩷   \\     ]],
        [[   |        ◡        |  |        ◡       |    ]],
        [[    \_______________/   \_______________/     ]],
        [[     /             \\     \           /       ]],
        [[    /               \\     )         (        ]], -- Линии талии
        [[   |   |         |   |    /           \       ]], -- Соединение с бедрами
        [[   |   |_________|   |   |_____________|      ]],
        [[    \_______________/   \_______________/     ]],
        [[       |_|       |_|       |_|       |_|      ]],
        [[                                              ]],
        [[        (RAST)              (POLINA)          ]],
      }


      -- 3. ЭПИЧЕСКАЯ БИТВА (ОГРОМНАЯ ЗМЕЯ)
      local fight_scene = {
        [[       ⚔️  GO DEFEATS PYTHON  ⚔️      ]],
        [[                                     ]],
        [[     ⊚___________⊚        🔥  RIP 🔥  ]],
        [[    /             \\      ____________ ]],
        [[   /   ●       ●   \\    /  ❌    ❌  \\  ]],
        [[  |        ◡        |  |      __      |  ]],
        [[   \\_______________/    \\    /  \    /   ]],
        [[    /      |      \\      \\__/    \__/    ]],
        [[   /       |       \\     /  ____  \\      ]],
        [[  |   |    |    |   |   /  /    \\  \\     ]],
        [[  |___|____|____|___|   \\  \\____/  /     ]],
        [[     |_|       |_|       \\________/      ]],
      }
            -- 4. СЦЕНА HACKER (Системный взлом)
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

      -- ЛОГИКА ВЫБОРА
            local scenes = { "dance", "love", "fight", "hacker" }
      math.randomseed(os.time())
      local choice = scenes[math.random(#scenes)]

      -- Применяем выбранную сцену и цвет
            -- ПРИМЕНЯЕМ ВЫБРАННУЮ СЦЕНУ И ЦВЕТ
      if choice == "love" then
        dashboard.section.header.val = twins_scene
        -- Двухцветная раскраска: Лево - Голубой (Rast), Право - Розовый (Polina)
        dashboard.section.header.opts.hl = {
            { "Identifier", 0, 26 }, 
            { "Keyword", 27, 60 },    
        }
      elseif choice == "fight" then
        dashboard.section.header.val = fight_scene
        dashboard.section.header.opts.hl = "ErrorMsg" -- Красный (Агрессивный)
      elseif choice == "hacker" then
        dashboard.section.header.val = hacker_scene
        dashboard.section.header.opts.hl = "DiagnosticOk" -- Ярко-зеленый (Терминальный)
      else
        -- По умолчанию включается ТАНЕЦ
        dashboard.section.header.val = d1
        dashboard.section.header.opts.hl = "Identifier" -- Голубой
      end


      -- Кнопки меню
      dashboard.section.buttons.val = {
        dashboard.button("f", "  Найти файл", ":Telescope find_files <CR>"),
        dashboard.button("r", "  Недавние файлы", ":Telescope oldfiles <CR>"), -- ВОТ ЭТА КНОПКА
        dashboard.button("p", "📂 Проекты", ":Telescope projects <CR>"),
        dashboard.button("q", "  Выход", ":qa <CR>"),
      }


      alpha.setup(dashboard.config)

      -- Таймер анимации (только если выпал танец)
      if choice == "dance" then
        local timer = vim.loop.new_timer()
        local state = true
        timer:start(0, 500, vim.schedule_wrap(function()
          if vim.bo.filetype ~= "alpha" then
            timer:stop()
            return
          end
          dashboard.section.header.val = state and d2 or d1
          state = not state
          alpha.redraw()
        end))
      end
    end,
  },
}

