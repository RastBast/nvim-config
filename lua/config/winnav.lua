-- ========================================================================== --
--            БЫСТРЫЙ ПЕРЕХОД МЕЖДУ ПАНЕЛЯМИ: дерево · код · терминал          --
-- ========================================================================== --
-- Клавиши под <leader>W (подсказка появляется сразу после пробела → W):
--   <leader>Wf  — фокус в дерево файлов (открывает, если закрыто)
--   <leader>Wc  — фокус в файл/код (последнее обычное окно с буфером)
--   <leader>Wt  — фокус в терминал (открывает снизу, если закрыт)
--   <leader>Wo  — оставить только текущее окно
--   <leader>Wx  — закрыть текущее окно
-- Ctrl+h/j/k/l (keymaps.lua) двигают по соседним окнам и сразу входят в
-- режим ввода, если попали в терминал.
local M = {}

local function is_term(win)
  return vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "terminal"
end

local function is_tree(win)
  return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree"
end

local function is_code(win)
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].buftype == "" and vim.bo[buf].filetype ~= "NvimTree"
end

-- Обычные (не плавающие) окна
local function normal_wins()
  local out = {}
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative == "" then
      out[#out + 1] = w
    end
  end
  return out
end

local function focus(win)
  vim.api.nvim_set_current_win(win)
  if is_term(win) then
    vim.cmd("startinsert")
  end
end

function M.focus_tree()
  for _, w in ipairs(normal_wins()) do
    if is_tree(w) then
      return focus(w)
    end
  end
  vim.cmd("NvimTreeFocus") -- дерева нет на экране — откроет и перейдёт в него
end

function M.focus_code()
  -- Сначала предыдущее окно (обычно то, откуда пришли в дерево/терминал)
  local prev = vim.fn.win_getid(vim.fn.winnr("#"))
  if prev ~= 0 and vim.api.nvim_win_is_valid(prev) and is_code(prev) then
    return focus(prev)
  end
  for _, w in ipairs(normal_wins()) do
    if is_code(w) then
      return focus(w)
    end
  end
  vim.notify("Нет открытого файла-окна", vim.log.levels.WARN)
end

function M.focus_term()
  -- Терминал может быть и снизу, и плавающим: ищем среди всех окон
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if is_term(w) then
      return focus(w)
    end
  end
  vim.cmd("ToggleTerm direction=horizontal size=15")
end

function M.setup()
  local map = vim.keymap.set
  map("n", "<leader>Wf", M.focus_tree, { desc = "🌲 Фокус: дерево файлов" })
  map("n", "<leader>Wc", M.focus_code, { desc = "💻 Фокус: файл (код)" })
  map("n", "<leader>Wt", M.focus_term, { desc = "📟 Фокус: терминал" })
  map("n", "<leader>Wo", "<cmd>only<cr>", { desc = "🪟 Оставить только это окно" })
  map("n", "<leader>Wx", "<cmd>close<cr>", { desc = "✖ Закрыть окно" })
end

return M
