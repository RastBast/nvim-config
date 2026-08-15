-- ~/.c/n/lua/plugins/toggleterm.lua
return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        -- Общее
        size = 15,                     -- высота (для горизонтального) / ширина (для вертикального)
        open_mapping = [[<c-\>]],      -- <C-\> открывает/переключает терминал
        hide_numbers = true,           -- скрыть номера строк в терминале
        shade_terminals = true,        -- затемнять фон терминала (делает его менее резким)
        shading_factor = 2,           -- степень затемнения
        start_in_insert = true,        -- сразу в режиме ввода
        insert_mappings = true,        -- позволять использовать клавиши ввода в терминале
        persist_size = true,           -- сохранять размер между открытыми терминалами
        direction = "float",            -- "horizontal" | "vertical" | "float" | "tab"
        close_on_exit = true,          -- закрывать терминал, когда процесс завершится
        shell = vim.o.shell,           -- используем ту же оболочку, что указана в Vim
        float_opts = {
          border = "curved",           -- стиль рамки: "single" | "double" | "rounded" | "curved"
          width = math.ceil(vim.o.columns * 0.8),
          height = math.ceil(vim.o.lines * 0.6),
          winblend = 10,              -- прозрачность окна (0 = без, 100 = полностью прозрачно)
        },

        -- Если хотите несколько терминалов разного типа, задайте их в `terminals`:
        -- terminals = {
        --   { direction = "horizontal", size = 12 },
        --   { direction = "vertical",   size = 40 },
        --   { direction = "float",      size = 15, float_opts = { border = "rounded" } },
        -- },
      })

      ------------------------------------------------------------
      -- Удобные маппы (можно добавить в ваш `keymaps.lua`)
      ------------------------------------------------------------
      local map = vim.keymap.set
      local toggleterm = require("toggleterm")

      -- 1️⃣ Обычное открытие/закрытие (Ctrl-\ уже работает, но добавим описание)
      map("n", "<leader>tt", "<cmd>ToggleTerm<CR>", { desc = "Toggle floating terminal" })

      -- 2️⃣ Открыть **горизонтальный** терминал снизу
      map("n", "<leader>th", function()
        toggleterm.toggle(1)   -- открываем/переключаем первый терминал
        vim.cmd("ToggleTermSetSize 15")   -- задаём высоту (можно изменить)
      end, { desc = "Horizontal terminal (bottom)" })

      -- 3️⃣ Открыть **вертикальный** терминал справа
      map("n", "<leader>tv", function()
        toggleterm.toggle(2)   -- переключаем второй терминал
        -- Меняем направление на вертикальный
        vim.api.nvim_win_set_config(0, {
          relative = "editor",
          width = math.floor(vim.o.columns * 0.35),
          col = vim.o.columns - 2,
        })
      end, { desc = "Vertical terminal (right)" })

      -- 4️⃣ Открыть **плавающий** терминал (по‑умолчанию)
      map("n", "<leader>tf", "<cmd>ToggleTerm direction=float<CR>", { desc = "Floating terminal" })

      -- 5️⃣ Переключаться между несколькими открытыми терминалами
      map("n", "<leader>tn", function() toggleterm.next() end,
          { desc = "Next terminal" })
      map("n", "<leader>tp", function() toggleterm.prev() end,
          { desc = "Previous terminal" })

      -- 6️⃣ Отправить текущую строку в активный терминал
      map("n", "<leader>ts", "<cmd>ToggleTermSendCurrentLine<CR>",
          { desc = "Send current line to terminal" })

      -- 7️⃣ Отправить визуальный блок в терминал
      map("v", "<leader>ts", "<Esc><cmd>ToggleTermSendVisualSelection<CR>",
          { desc = "Send selection to terminal" })

      -- 8️⃣ Запуск однократных команд без открытия окна
      map("n", "<leader>gs", function()
        -- Откроем терминал, если его нет, потом отправим `git status`
        local term = toggleterm.get_or_create_term()
        vim.cmd("ToggleTermSendCmdBelow git status")
      end, { desc = "Git status (quick)" })
    end,
  },
}

