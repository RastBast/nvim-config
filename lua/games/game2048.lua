-- 🔢 2048: сдвиги и слияния 4x4. Логика отделена от окна (тесты: tests/games_logic.py).
-- Управление: h j k l / стрелки — сдвиг · u — отменить ход · r — заново · q/Esc — выход.
-- Правило слияния: при сдвиге каждая плитка сливается не более одного раза.

local F = require("games.float")

local M = {}

M.N = 4
M.best = 0

-- Сдвиг одной линии к началу: вернуть новую линию, очки и признак изменения.
function M.slide_line(line)
  local n = #line
  local vals = {}
  for _, v in ipairs(line) do
    if v ~= 0 then
      table.insert(vals, v)
    end
  end
  local out, gained, i = {}, 0, 1
  while i <= #vals do
    if i < #vals and vals[i] == vals[i + 1] then
      local merged = vals[i] * 2
      table.insert(out, merged)
      gained = gained + merged
      i = i + 2
    else
      table.insert(out, vals[i])
      i = i + 1
    end
  end
  while #out < n do
    table.insert(out, 0)
  end
  local changed = false
  for k = 1, n do
    if out[k] ~= line[k] then
      changed = true
      break
    end
  end
  return out, gained, changed
end

local function copy(board)
  local c = {}
  for r = 1, M.N do
    c[r] = {}
    for x = 1, M.N do
      c[r][x] = board[r][x]
    end
  end
  return c
end
M.copy = copy

-- dir: "left" | "right" | "up" | "down". Возвращает новую доску, очки, изменилась ли.
function M.move(board, dir)
  local n = M.N
  local out = copy(board)
  local gained_total, any = 0, false
  for k = 1, n do
    local line = {}
    for i = 1, n do
      if dir == "left" then
        line[i] = board[k][i]
      elseif dir == "right" then
        line[i] = board[k][n + 1 - i]
      elseif dir == "up" then
        line[i] = board[i][k]
      else
        line[i] = board[n + 1 - i][k]
      end
    end
    local res, gained, changed = M.slide_line(line)
    gained_total = gained_total + gained
    any = any or changed
    for i = 1, n do
      if dir == "left" then
        out[k][i] = res[i]
      elseif dir == "right" then
        out[k][n + 1 - i] = res[i]
      elseif dir == "up" then
        out[i][k] = res[i]
      else
        out[n + 1 - i][k] = res[i]
      end
    end
  end
  return out, gained_total, any
end

function M.empty_cells(board)
  local out = {}
  for r = 1, M.N do
    for x = 1, M.N do
      if board[r][x] == 0 then
        table.insert(out, { r = r, x = x })
      end
    end
  end
  return out
end

function M.spawn(board, rng)
  local free = M.empty_cells(board)
  if #free == 0 then
    return false
  end
  local c = free[rng(#free)]
  board[c.r][c.x] = rng(10) == 1 and 4 or 2
  return true
end

function M.can_move(board)
  if #M.empty_cells(board) > 0 then
    return true
  end
  for _, d in ipairs({ "left", "right", "up", "down" }) do
    local _, _, changed = M.move(board, d)
    if changed then
      return true
    end
  end
  return false
end

function M.new(rng)
  local b = {}
  for r = 1, M.N do
    b[r] = {}
    for x = 1, M.N do
      b[r][x] = 0
    end
  end
  rng = rng or math.random
  M.spawn(b, rng)
  M.spawn(b, rng)
  return { board = b, score = 0, rng = rng, won = false, over = false, undo = nil }
end

-- Один ход игрока. Возвращает true, если доска изменилась.
function M.play(g, dir)
  if g.over then
    return false
  end
  local nb, gained, changed = M.move(g.board, dir)
  if not changed then
    return false
  end
  g.undo = { board = copy(g.board), score = g.score }
  g.board = nb
  g.score = g.score + gained
  if g.score > M.best then
    M.best = g.score
  end
  M.spawn(g.board, g.rng)
  if not g.won then
    for r = 1, M.N do
      for x = 1, M.N do
        if g.board[r][x] >= 2048 then
          g.won = true
        end
      end
    end
  end
  if not M.can_move(g.board) then
    g.over = true
  end
  return true
end

function M.undo(g)
  if not g.undo then
    return false
  end
  g.board = g.undo.board
  g.score = g.undo.score
  g.undo = nil
  g.over = false
  return true
end

-- ------------------------------------------------------------------ UI ---
local S = { h = nil, g = nil }

-- цвет плитки по степени двойки (палитра пользователя)
local function group_for(v)
  if v == 0 then
    return "GamesDim"
  end
  -- math.log(x, base) нет в LuaJIT — считаем через натуральный логарифм
  local k = math.floor(math.log(v) / math.log(2) + 0.5)
  return "GamesT" .. ((k - 1) % 7 + 1)
end

local function render()
  local g = S.g
  local lines, hls = {}, {}
  local cw = 7
  local sep = "+" .. string.rep(string.rep("-", cw) .. "+", M.N)
  table.insert(lines, sep)
  table.insert(hls, { 0, 0, -1, "GamesBorder", 50 })
  for r = 1, M.N do
    local row = "|"
    local segs = {}
    for x = 1, M.N do
      local v = g.board[r][x]
      local txt = v == 0 and "." or tostring(v)
      local pad = cw - #txt
      local left = math.floor(pad / 2)
      local cell = string.rep(" ", left) .. txt .. string.rep(" ", pad - left)
      table.insert(segs, { #row, #cell, group_for(v) })
      row = row .. cell .. "|"
    end
    table.insert(lines, row)
    local li = #lines - 1
    for _, s in ipairs(segs) do
      table.insert(hls, { li, s[1], s[1] + s[2], s[3], 60 })
    end
    table.insert(lines, sep)
    table.insert(hls, { #lines - 1, 0, -1, "GamesBorder", 50 })
  end
  local status, group
  if g.over then
    status, group = string.format("💀 Ходов нет. Счёт: %d · рекорд: %d", g.score, M.best), "GamesBad"
  elseif g.won and not g.won_ack then
    status, group = "🏆 2048! Продолжайте или r — заново", "GamesOk"
  else
    status, group = string.format("Счёт: %d · рекорд: %d", g.score, M.best), "GamesOk"
  end
  table.insert(lines, " " .. status)
  table.insert(hls, { #lines - 1, 0, -1, group, 100 })
  table.insert(lines, " hjkl сдвиг · u отмена · r заново · q выход")
  table.insert(hls, { #lines - 1, 0, -1, "GamesHelp", 100 })
  F.render(S.h, lines, hls)
end

local function restart()
  S.g = M.new(nil)
  render()
end

function M.open()
  if F.valid(S.h) then
    vim.api.nvim_set_current_win(S.h.win)
    return
  end
  S.g = M.new(nil)
  S.h = F.open({
    width = M.N * 8 + 3,
    height = M.N * 2 + 5,
    title = "🔢 2048",
    footer = "сливай одинаковые плитки",
    on_close = function()
      S.h = nil
    end,
  })
  local function act(dir)
    return function()
      M.play(S.g, dir)
      render()
    end
  end
  F.map(S.h, { "h", "<Left>" }, act("left"))
  F.map(S.h, { "l", "<Right>" }, act("right"))
  F.map(S.h, { "k", "<Up>" }, act("up"))
  F.map(S.h, { "j", "<Down>" }, act("down"))
  F.map(S.h, "u", function()
    M.undo(S.g)
    render()
  end)
  F.map(S.h, "r", restart)
  F.map(S.h, { "q", "<Esc>" }, function()
    M.close()
  end)
  render()
end

function M.close()
  F.close(S.h)
end

return M
