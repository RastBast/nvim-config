-- ИИ для шахмат: negamax + альфа-бета + покой (взятия) + оценка по материалу и
-- таблицам позиции. Пять уровней сложности:
--   1 Новичок   — случайный легальный ход
--   2 Лёгкий    — поиск на 1 ход, шум в оценке (ошибается)
--   3 Средний   — поиск на 2 полухода
--   4 Сильный   — поиск на 3 полухода
--   5 Мастер    — поиск на 4 полухода
-- Ход выбирается случайно среди равнозначных лучших (игра не повторяется).

local B = require("games.chess.board")

local M = {}

M.LEVELS = {
  { name = "Новичок", depth = 0, noise = 0 },
  { name = "Лёгкий", depth = 1, noise = 150 },
  { name = "Средний", depth = 2, noise = 0 },
  { name = "Сильный", depth = 3, noise = 0 },
  { name = "Мастер", depth = 4, noise = 0 },
}

local VAL = { P = 100, N = 320, B = 330, R = 500, Q = 900, K = 0 }
local MATE = 100000
local INF = 1000000

-- таблицы позиции (сверху вниз: ранг 8 → 1), для белых; для чёрных — зеркально
local PST = {
  P = {
    0, 0, 0, 0, 0, 0, 0, 0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5, 5, 10, 25, 25, 10, 5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, -5, -10, 0, 0, -10, -5, 5,
    5, 10, 10, -20, -20, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
  },
  N = {
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
  },
  B = {
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
  },
  R = {
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, 10, 10, 10, 10, 5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    0, 0, 0, 5, 5, 0, 0, 0,
  },
  Q = {
    -20, -10, -10, -5, -5, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 5, 5, 5, 0, -10,
    -5, 0, 5, 5, 5, 5, 0, -5,
    0, 0, 5, 5, 5, 5, 0, -5,
    -10, 5, 5, 5, 5, 5, 0, -10,
    -10, 0, 5, 0, 0, 0, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
  },
  K = {
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    20, 20, 0, 0, 0, 0, 20, 20,
    20, 30, 10, 0, 0, 10, 30, 20,
  },
}

-- индекс в таблице PST для клетки sq и цвета c
local function pst_index(sq, c)
  local f, r = B.file_of(sq), B.rank_of(sq)
  if c == "w" then
    return (8 - r) * 8 + f
  end
  return (r - 1) * 8 + f
end

-- Оценка с точки зрения стороны, которая ходит.
local function evaluate(st)
  local s = 0
  local b = st.b
  for sq = 1, 64 do
    local p = b[sq]
    if p ~= "." then
      local t = p:upper()
      local c = B.color(p)
      local v = VAL[t] + PST[t][pst_index(sq, c)]
      if c == "w" then
        s = s + v
      else
        s = s - v
      end
    end
  end
  if st.turn == "b" then
    return -s
  end
  return s
end

local function victim_value(st, m)
  local p = st.b[m.t]
  if m.ep then
    return VAL.P
  end
  if p == "." then
    return 0
  end
  return VAL[p:upper()]
end

-- Сортировка ходов: превращения и взятия (наибольшая жертва, наименьший атакующий) первыми.
local function order(st, moves)
  for _, m in ipairs(moves) do
    local score = 0
    local v = victim_value(st, m)
    if v > 0 then
      score = 10 * v - VAL[st.b[m.f]:upper()] / 10
    end
    if m.p then
      score = score + VAL[m.p]
    end
    m.score = score
  end
  table.sort(moves, function(a, b)
    return a.score > b.score
  end)
  return moves
end

local function quiesce(st, alpha, beta, depth)
  local stand = evaluate(st)
  if stand >= beta then
    return stand
  end
  if stand > alpha then
    alpha = stand
  end
  if depth <= 0 then
    return alpha
  end
  for _, m in ipairs(order(st, B.legal_moves(st, true))) do
    local u = B.make(st, m)
    local score = -quiesce(st, -beta, -alpha, depth - 1)
    B.unmake(st, u)
    if score >= beta then
      return score
    end
    if score > alpha then
      alpha = score
    end
  end
  return alpha
end

local function negamax(st, depth, alpha, beta, ply, nodes)
  nodes.n = nodes.n + 1
  if depth <= 0 then
    return quiesce(st, alpha, beta, 4)
  end
  local moves = B.legal_moves(st)
  if #moves == 0 then
    if B.in_check(st, st.turn) then
      return -MATE + ply
    end
    return 0
  end
  local best = -INF
  for _, m in ipairs(order(st, moves)) do
    local u = B.make(st, m)
    local score = -negamax(st, depth - 1, -beta, -alpha, ply + 1, nodes)
    B.unmake(st, u)
    if score > best then
      best = score
    end
    if score > alpha then
      alpha = score
    end
    if alpha >= beta then
      break
    end
  end
  return best
end

-- Выбор хода. level 1..5. rng — функция(n) → 1..n (по умолчанию math.random).
-- Возвращает ход (таблица из B.legal_moves) или nil, если ходов нет.
function M.choose(st, level, rng)
  rng = rng or math.random
  local cfg = M.LEVELS[level] or M.LEVELS[3]
  local moves = B.legal_moves(st)
  if #moves == 0 then
    return nil
  end
  if cfg.depth == 0 then
    return moves[rng(#moves)]
  end

  -- поиск ведём без истории ключей (быстрее); статус ничьей проверяет вызывающий код
  local track = st.track
  st.track = false
  local nodes = { n = 0 }
  local best_score, best_list = -INF, {}
  for _, m in ipairs(order(st, moves)) do
    -- окно корня: (лучший-1, +inf). Так ничья с лучшим ходом находится точно,
    -- а заведомо худшие ветки отсекаются. При шуме — полное окно.
    local lo = (cfg.noise > 0 or best_score == -INF) and -INF or best_score - 1
    local u = B.make(st, m)
    local score = -negamax(st, cfg.depth - 1, -INF, -lo, 1, nodes)
    B.unmake(st, u)
    if cfg.noise > 0 then
      score = score + (rng(2 * cfg.noise + 1) - cfg.noise - 1)
    end
    if score > best_score then
      best_score = score
      best_list = { m }
    elseif score == best_score then
      table.insert(best_list, m)
    end
  end
  st.track = track
  M.last_nodes = nodes.n
  return best_list[rng(#best_list)]
end

M.MATE = MATE
return M
