-- 🐍 Змейка: гофер-голова 🐹 ест 🍬. Логика (new/turn/step) отделена от окна.
-- Управление: h j k l / стрелки — поворот · p — пауза · r — заново · q/Esc — выход.

local F = require("games.float")

local M = {}

M.W, M.H = 20, 12
M.best = 0

function M.place_food(s)
  local busy = {}
  for _, c in ipairs(s.body) do
    busy[c.x .. "," .. c.y] = true
  end
  local free = {}
  for y = 1, s.h do
    for x = 1, s.w do
      if not busy[x .. "," .. y] then
        table.insert(free, { x = x, y = y })
      end
    end
  end
  if #free == 0 then
    s.food = nil
    return
  end
  s.food = free[s.rng(#free)]
end

function M.new(rng, w, h)
  local s = {
    w = w or M.W,
    h = h or M.H,
    body = { { x = 5, y = 6 }, { x = 4, y = 6 }, { x = 3, y = 6 } },
    dir = { x = 1, y = 0 },
    nd = { x = 1, y = 0 },
    score = 0,
    alive = true,
    paused = false,
    rng = rng or math.random,
  }
  M.place_food(s)
  return s
end

-- Поворот. Разворот на 180° запрещён (иначе змейка врежется в себя).
function M.turn(s, dx, dy)
  if not s.alive then
    return
  end
  if dx == -s.dir.x and dy == -s.dir.y and #s.body > 1 then
    return
  end
  s.nd = { x = dx, y = dy }
end

-- Один шаг. Возвращает true, если змейка жива.
function M.step(s)
  if not s.alive or s.paused then
    return s.alive
  end
  s.dir = s.nd
  local head = s.body[1]
  local nx, ny = head.x + s.dir.x, head.y + s.dir.y
  if nx < 1 or ny < 1 or nx > s.w or ny > s.h then
    s.alive = false
    return false
  end
  local eat = s.food ~= nil and nx == s.food.x and ny == s.food.y
  for i, c in ipairs(s.body) do
    if c.x == nx and c.y == ny then
      -- хвост уходит с места, если не едим — наступать на него можно
      if not (i == #s.body and not eat) then
        s.alive = false
        return false
      end
    end
  end
  table.insert(s.body, 1, { x = nx, y = ny })
  if eat then
    s.score = s.score + 1
    if s.score > M.best then
      M.best = s.score
    end
    M.place_food(s)
  else
    table.remove(s.body)
  end
  return true
end

function M.interval(s)
  return math.max(55, 150 - 5 * s.score)
end

-- ------------------------------------------------------------------ UI ---
local S = { h = nil, s = nil }

local function render()
  local s = S.s
  local lines, hls = {}, {}
  local border = "+" .. string.rep("-", s.w * 2) .. "+"
  table.insert(lines, border)
  table.insert(hls, { 0, 0, -1, "GamesBorder", 50 })
  local body = {}
  for i, c in ipairs(s.body) do
    body[c.x .. "," .. c.y] = i
  end
  for y = 1, s.h do
    local row = "|"
    local cells = {}
    local line_index = #lines
    for x = 1, s.w do
      local key = x .. "," .. y
      local cell, group
      if body[key] == 1 then
        cell, group = "🐹", "GamesT2"
      elseif body[key] then
        cell, group = "▓▓", "GamesT4"
      elseif s.food and s.food.x == x and s.food.y == y then
        cell, group = "🍬", "GamesT5"
      else
        cell, group = "  ", nil
      end
      table.insert(cells, { cell, group, #row })
      row = row .. cell
    end
    row = row .. "|"
    table.insert(lines, row)
    for _, c in ipairs(cells) do
      if c[2] then
        table.insert(hls, { line_index, c[3], c[3] + #c[1], c[2], 60 })
      end
    end
  end
  table.insert(lines, border)
  table.insert(hls, { #lines - 1, 0, -1, "GamesBorder", 50 })

  local status, group
  if not s.alive then
    status = string.format("💀 Конец! Счёт: %d · рекорд: %d · r — заново", s.score, M.best)
    group = "GamesBad"
  elseif s.paused then
    status = "⏸ Пауза · p — продолжить"
    group = "GamesWarn"
  else
    status = string.format("Счёт: %d · рекорд: %d", s.score, M.best)
    group = "GamesOk"
  end
  table.insert(lines, " " .. status)
  table.insert(hls, { #lines - 1, 0, -1, group, 100 })
  table.insert(lines, " hjkl/стрелки — поворот · p пауза · r заново · q выход")
  table.insert(hls, { #lines - 1, 0, -1, "GamesHelp", 100 })
  F.render(S.h, lines, hls)
end

local function restart()
  S.s = M.new(nil)
  render()
end

function M.open()
  if F.valid(S.h) then
    vim.api.nvim_set_current_win(S.h.win)
    return
  end
  S.s = M.new(nil)
  S.h = F.open({
    width = M.W * 2 + 4,
    height = M.H + 6,
    title = "🐍 Змейка",
    footer = "гофер ест конфеты",
    on_close = function()
      S.h = nil
    end,
  })
  local function turn(dx, dy)
    return function()
      M.turn(S.s, dx, dy)
    end
  end
  F.map(S.h, { "h", "<Left>" }, turn(-1, 0))
  F.map(S.h, { "l", "<Right>" }, turn(1, 0))
  F.map(S.h, { "k", "<Up>" }, turn(0, -1))
  F.map(S.h, { "j", "<Down>" }, turn(0, 1))
  F.map(S.h, "p", function()
    S.s.paused = not S.s.paused
  end)
  F.map(S.h, "r", restart)
  F.map(S.h, { "q", "<Esc>" }, function()
    M.close()
  end)
  F.every(S.h, 40, function()
    local s = S.s
    if s.alive and not s.paused then
      -- шаг с интервалом, зависящим от счёта
      s._acc = (s._acc or 0) + 40
      if s._acc >= M.interval(s) then
        s._acc = 0
        M.step(s)
      end
    end
    render()
  end)
  render()
end

function M.close()
  F.close(S.h)
end

return M
