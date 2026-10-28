-- Игры в nvim: ♟ шахматы, 🐍 змейка, 🧱 тетрис, 🔢 2048.
-- Клавиши под <leader>X (игры), зеркала — под <leader>HX.
--   <leader>Xc — шахматы (2 игрока / против ПК, 5 уровней)
--   <leader>Xs — змейка · <leader>Xt — тетрис · <leader>Xf — 2048
--   <leader>Xm — меню игр (выбор через picker)
-- Команды: :Chess :Snake :Tetris :Game2048 :Games

local M = {}

local GAMES = {
  { id = "chess", label = "♟ Шахматы (2 игрока / против ПК)", open = function() require("games.chess.ui").open() end },
  { id = "snake", label = "🐍 Змейка (гофер ест конфеты)", open = function() require("games.snake").open() end },
  { id = "tetris", label = "🧱 Тетрис", open = function() require("games.tetris").open() end },
  { id = "2048", label = "🔢 2048", open = function() require("games.game2048").open() end },
}

function M.menu()
  vim.ui.select(GAMES, {
    prompt = "🎮 Во что сыграем?",
    format_item = function(g)
      return g.label
    end,
  }, function(choice)
    if choice then
      choice.open()
    end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("Chess", function()
    require("games.chess.ui").open()
  end, { desc = "Шахматы: 2 игрока или против ПК" })
  vim.api.nvim_create_user_command("Snake", function()
    require("games.snake").open()
  end, { desc = "Змейка" })
  vim.api.nvim_create_user_command("Tetris", function()
    require("games.tetris").open()
  end, { desc = "Тетрис" })
  vim.api.nvim_create_user_command("Game2048", function()
    require("games.game2048").open()
  end, { desc = "2048" })
  vim.api.nvim_create_user_command("Games", function()
    M.menu()
  end, { desc = "Меню игр" })

  local map = vim.keymap.set
  map("n", "<leader>Xc", function() require("games.chess.ui").open() end, { desc = "♟ Шахматы (2 игрока / против ПК)" })
  map("n", "<leader>Xs", function() require("games.snake").open() end, { desc = "🐍 Змейка" })
  map("n", "<leader>Xt", function() require("games.tetris").open() end, { desc = "🧱 Тетрис" })
  map("n", "<leader>Xf", function() require("games.game2048").open() end, { desc = "🔢 2048" })
  map("n", "<leader>Xm", function() M.menu() end, { desc = "🎮 Меню игр" })
end

return M
