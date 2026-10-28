-- 🧱 Тетрис: 10x20, «мешок» из 7 фигур, повороты с простыми сдвигами (wall kick),
-- очистка линий (100/300/500/800 × уровень), рост скорости по уровням.
-- Управление: h/l — влево/вправо · j — мягкое падение · k или x — поворот ·
--             Space — жёсткое падение · p — пауза · r — заново · q/Esc — выход.

local F = require("games.float")

local M = {}

M.W, M.H = 10, 20

local SHAPES = {
  { { 0, 0, 0, 0 }, { 1, 1, 1, 1 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }, -- I
  { { 1, 1 }, { 1, 1 } }, -- O
  { { 0, 1, 0 }, { 1, 1, 1 }, { 0, 0, 0 } }, -- T
  { { 0, 1, 1 }, { 1, 1, 0 }, { 0, 0, 0 } }, -- S
  { { 1, 1, 0 }, { 0, 1, 1 }, { 0, 0, 0 } }, -- Z
  { { 1, 0, 0 }, { 1, 1, 1 }, { 0, 0, 0 } }, -- J
  { { 0, 0, 1 }, { 1, 1, 1 }, { 0, 0, 0 } }, -- L
}
M.SHAPES = SHAPES

local POINTS = { 0, 100, 300, 500, 800 }

-- Поворот матрицы по часовой стрелке.
function M.rotate(m)
  local n = #m
  local out = {}
  for i = 1, n do
    out[i] = {}
    for j = 1, n do
      out[i][j] = m[n - j + 1][i]
    end
  end
  return out
end

local function cells_of(p)
  local out = {}
  for i, row in ipairs(p.m) do
    for j, v in ipairs(row) do
      if v == 1 then
        table.insert(out, { x = p.x + j - 1, y = p.y + i - 1 })
      end
    end
  end
  return out
end
M.cells_of = cells_of

-- Свободно ли место для фигуры p на доске g (строки выше верхнего края разрешены).
function M.fits(g, p)
  for _, c in ipairs(cells_of(p)) do
    if c.x < 1 or c.x > M.W or c.y > M.H then
      return false
    end
    if c.y >= 1 and g.board[c.y][c.x] ~= 0 then
      return false
    end
  end
  return true
end

function M.new(rng)
  local g = { board = {}, rng = rng or math.random, score = 0, lines = 0, level = 1, over = false, paused = false, bag = {} }
  for y = 1, M.H do
    g.board[y] = {}
    for x = 1, M.W do
      g.board[y][x] = 0
    end
  end
  g.next = M.take(g)
  M.spawn(g)
  return g
end

-- Следующая фигура из перемешанного мешка 1..7.
function M.take(g)
  if #g.bag == 0 then
    for i = 1, 7 do
      table.insert(g.bag, i)
    end
    for i = #g.bag, 2, -1 do
      local j = g.rng(i)
      g.bag[i], g.bag[j] = g.bag[j], g.bag[i]
    end
  end
  return table.remove(g.bag)
end

function M.spawn(g)
  local kind = g.next
  g.next = M.take(g)
  local m = SHAPES[kind]
  g.cur = { kind = kind, m = m, x = math.floor((M.W - #m[1]) / 2) + 1, y = 0 }
  if not M.fits(g, g.cur) then
    g.over = true
  end
end

function M.move(g, dx, dy)
  if g.over or g.paused then
    return false
  end
  local p = { kind = g.cur.kind, m = g.cur.m, x = g.cur.x + dx, y = g.cur.y + dy }
  if M.fits(g, p) then
    g.cur = p
    return true
  end
  return false
end

function M.rotate_cur(g)
  if g.over or g.paused then
    return
  end
  local r = M.rotate(g.cur.m)
  for _, k in ipairs({ 0, -1, 1, -2, 2 }) do
    local p = { kind = g.cur.kind, m = r, x = g.cur.x + k, y = g.cur.y }
    if M.fits(g, p) then
      g.cur = p
      return
    end
  end
end

-- Фиксация фигуры и очистка линий. Возвращает число очищенных линий.
function M.lock(g)
  for _, c in ipairs(cells_of(g.cur)) do
    if c.y >= 1 then
      g.board[c.y][c.x] = g.cur.kind
    end
  end
  local cleared = 0
  local y = M.H
  while y >= 1 do
    local full = true
    for x = 1, M.W do
      if g.board[y][x] == 0 then
        full = false
        break
      end
    end
    if full then
      table.remove(g.board, y)
      local row = {}
      for x = 1, M.W do
        row[x] = 0
      end
      table.insert(g.board, 1, row)
      cleared = cleared + 1
    else
      y = y - 1
    end
  end
  if cleared > 0 then
    g.score = g.score + POINTS[cleared + 1] * g.level
    g.lines = g.lines + cleared
    g.level = 1 + math.floor(g.lines / 10)
  end
  M.spawn(g)
  return cleared
end

-- Шаг гравитации: вниз или фиксация.
function M.tick(g)
  if g.over or g.paused then
    return
  end
  if not M.move(g, 0, 1) then
    M.lock(g)
  end
end

function M.hard_drop(g)
  if g.over or g.paused then
    return
  end
  local dropped = 0
  while M.move(g, 0, 1) do
    dropped = dropped + 1
  end
  g.score = g.score + 2 * dropped
  M.lock(g)
end

function M.soft_drop(g)
  if M.move(g, 0, 1) then
    g.score = g.score + 1
  else
    M.lock(g)
  end
end

function M.interval(g)
  return math.max(70, 600 - 50 * (g.level - 1))
end

-- ------------------------------------------------------------------ UI ---
local S = { h = nil, g = nil, acc = 0 }

local function render()
  local g = S.g
  local lines, hls = {}, {}
  -- ghost: позиция падения текущей фигуры
  local ghost_y = g.cur.y
  local probe = { kind = g.cur.kind, m = g.cur.m, x = g.cur.x, y = g.cur.y }
  while M.fits(g, { kind = probe.kind, m = probe.m, x = probe.x, y = probe.y + 1 }) do
    probe.y = probe.y + 1
  end
  ghost_y = probe.y
  local ghost_cells = {}
  for _, c in ipairs(cells_of({ m = g.cur.m, x = g.cur.x, y = ghost_y })) do
    ghost_cells[c.x .. "," .. c.y] = true
  end
  local cur_cells = {}
  for _, c in ipairs(cells_of(g.cur)) do
    cur_cells[c.x .. "," .. c.y] = g.cur.kind
  end

  local side = {
    "  Счёт:  " .. g.score,
    "  Линии: " .. g.lines,
    "  Уровень: " .. g.level,
    "",
    "  Следующая:",
  }
  -- мини-превью следующей фигуры
  local nm = SHAPES[g.next]
  for _, row in ipairs(nm) do
    local s = "    "
    for _, v in ipairs(row) do
      s = s .. (v == 1 and "[]" or "  ")
    end
    table.insert(side, s)
  end
  table.insert(side, "")
  if g.over then
    table.insert(side, "  💥 Игра окончена")
    table.insert(side, "  r — заново")
  elseif g.paused then
    table.insert(side, "  ⏸ Пауза")
  end

  table.insert(lines, "+" .. string.rep("-", M.W * 2) .. "+")
  table.insert(hls, { 0, 0, -1, "GamesBorder", 50 })
  for y = 1, M.H do
    local row = "|"
    local segs = {}
    for x = 1, M.W do
      local key = x .. "," .. y
      local kind = cur_cells[key] or (g.board[y][x] ~= 0 and g.board[y][x]) or nil
      local cell, group
      if kind then
        cell, group = "[]", "GamesT" .. kind
      elseif ghost_cells[key] then
        cell, group = "░░", "GamesDim"
      else
        cell, group = " .", "GamesDim"
      end
      table.insert(segs, { #row, #cell, group })
      row = row .. cell
    end
    row = row .. "|"
    local sline = side[y] or ""
    local line = row .. sline
    table.insert(lines, line)
    local li = #lines - 1
    for _, sgm in ipairs(segs) do
      table.insert(hls, { li, sgm[1], sgm[1] + sgm[2], sgm[3], 60 })
    end
    table.insert(hls, { li, #row, #line, "GamesTitle", 10 })
  end
  table.insert(lines, "+" .. string.rep("-", M.W * 2) .. "+")
  table.insert(hls, { #lines - 1, 0, -1, "GamesBorder", 50 })
  table.insert(lines, " hjkl ходить · k поворот · Space вниз · p пауза · r заново · q выход")
  table.insert(hls, { #lines - 1, 0, -1, "GamesHelp", 100 })
  F.render(S.h, lines, hls)
end

local function restart()
  S.g = M.new(nil)
  render()
end

local function tick_loop()
  local g = S.g
  S.acc = S.acc + 40
  if S.acc >= M.interval(g) then
    S.acc = 0
    M.tick(g)
  end
  render()
end

function M.open()
  if F.valid(S.h) then
    vim.api.nvim_set_current_win(S.h.win)
    return
  end
  S.g = M.new(nil)
  S.h = F.open({
    width = M.W * 2 + 2 + 26,
    height = M.H + 4,
    title = "🧱 Тетрис",
    footer = "жёлтые — ряды, очки растут с уровнем",
    on_close = function()
      S.h = nil
    end,
  })
  local function act(fn)
    return function()
      fn(S.g)
      render()
    end
  end
  F.map(S.h, { "h", "<Left>" }, act(function(g) M.move(g, -1, 0) end))
  F.map(S.h, { "l", "<Right>" }, act(function(g) M.move(g, 1, 0) end))
  F.map(S.h, { "j", "<Down>" }, act(function(g) M.soft_drop(g) end))
  F.map(S.h, { "k", "<Up>", "x" }, act(function(g) M.rotate_cur(g) end))
  F.map(S.h, "<Space>", act(function(g) M.hard_drop(g) end))
  F.map(S.h, "p", act(function(g) g.paused = not g.paused end))
  F.map(S.h, "r", restart)
  F.map(S.h, { "q", "<Esc>" }, function()
    M.close()
  end)
  F.every(S.h, 40, tick_loop)
  render()
end

function M.close()
  F.close(S.h)
end

return M
