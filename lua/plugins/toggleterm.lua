-- ========================================================================== --
--                            TOGGLETERM                                      --
-- ========================================================================== --
-- ИСПРАВЛЕНО:
--  1) toggleterm.get_or_create_term() — такой функции в модуле toggleterm НЕТ
--     (она живёт в toggleterm.terminal), клавиша <leader>gs падала с
--     "attempt to call a nil value".
--  2) toggleterm.next() / toggleterm.prev() — тоже не существуют
--     (в lua/toggleterm.lua есть exec, exec_command, new, toggle,
--     toggle_all, toggle_command, new_command, send_lines_to_terminal, setup).
--  3) :ToggleTermSetSize — такой команды нет (есть ToggleTermSetName);
--     размер передаётся параметром: :ToggleTerm size=15 direction=horizontal
--  4) :ToggleTermCloseAll — такой команды нет, есть :ToggleTermToggleAll
--  5) <leader>t* конфликтовал с neotest.lua (<leader>tf, <leader>ts) —
--     терминал переехал на <leader>T*
return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "<c-\\>", desc = "📟 Переключить терминал" },
      { "<leader>Tt", "<cmd>ToggleTerm direction=float<cr>", desc = "📟 Плавающий терминал" },
      { "<leader>Th", "<cmd>ToggleTerm direction=horizontal size=15<cr>", desc = "📟 Терминал снизу" },
      { "<leader>Tv", "<cmd>ToggleTerm direction=vertical size=60<cr>", desc = "📟 Терминал справа" },
      { "<leader>Ta", "<cmd>ToggleTermToggleAll<cr>", desc = "❎ Показать/скрыть все терминалы" },
    },
    config = function()
      require("toggleterm").setup({
        size = function(term)
          if term.direction == "horizontal" then return 15 end
          if term.direction == "vertical" then return math.floor(vim.o.columns * 0.4) end
          return 20
        end,
        open_mapping = [[<c-\>]],   -- <C-\> открывает/переключает терминал
        hide_numbers = true,        -- скрыть номера строк в терминале
        shade_terminals = true,     -- затемнять фон терминала
        shading_factor = 2,
        start_in_insert = true,
        insert_mappings = true,
        terminal_mappings = true,
        persist_size = true,
        direction = "float",
        close_on_exit = true,
        shell = vim.o.shell,
        float_opts = {
          border = "curved",
          width = math.floor(vim.o.columns * 0.8),
          height = math.floor(vim.o.lines * 0.6),
          winblend = 10,
        },
      })

      local map = vim.keymap.set

      -- Отправить текущую строку / визуальный блок в активный терминал
      map("n", "<leader>Tl", "<cmd>ToggleTermSendCurrentLine<CR>", { desc = "➡ Строку в терминал" })
      map("v", "<leader>Tl", "<cmd>ToggleTermSendVisualSelection<CR>", { desc = "➡ Выделение в терминал" })

      -- Быстрый git status в отдельном терминале
      map("n", "<leader>Tg", function()
        require("toggleterm").exec("git status", 9)
      end, { desc = "🌿 git status" })

      -- Ленивый git — прямо в терминале toggleterm
      map("n", "<leader>TG", function()
        require("toggleterm").exec("lazygit", 10)
      end, { desc = "🌿 lazygit в терминале" })
    end,
  },
}
