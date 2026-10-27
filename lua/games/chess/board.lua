-- Шахматы: правила (ход, взятие на проходе, рокировка, превращение, мат, пат,
-- ничья). Чистая логика без UI — проверяется perft-тестами (tests/chess_perft.py).
--
-- Представление:
--   b[sq]  — 64 клетки, sq = (ранг-1)*8 + файл, файл 1..8 (a..h), ранг 1..8 (1..8).
--            "." — пусто; заглавные — белые (PNBRQK), строчные — чёрные.
--   st     — { b, turn = "w"|"b", cast = {K,Q,k,q}, ep = sq|0, half, full, keys = {} }
--
-- Без `//` и битовых операций: код работает и в LuaJIT (Neovim), и в Lua 5.x.

local M = {}

M.START_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

local KN = { { 1, 2 }, { 2, 1 }, { 2, -1 }, { 1, -2 }, { -1, -2 }, { -2, -1 }, { -2, 1 }, { -1, 2 } }
local KG = { { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 } }
local DIAG = { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
local ORTH = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local PROMO = { "Q", "R", "B", "N" }

local function sq_of(f, r)
  if f < 1 or f > 8 or r < 1 or r > 8 then
    return nil
  end
  return (r - 1) * 8 + f
end
M.sq_of = sq_of

local function file_of(sq)
  return (sq - 1) % 8 + 1
end
M.file_of = file_of

local function rank_of(sq)
  return math.floor((sq - 1) / 8) + 1
end
M.rank_of = rank_of

-- "e4" → 29
function M.parse_sq(s)
  if not s or #s ~= 2 then
    return nil
  end
  local f = s:byte(1) - string.byte("a") + 1
  local r = tonumber(s:sub(2, 2))
  return sq_of(f, r)
end

function M.sq_name(sq)
  return string.char(string.byte("a") + file_of(sq) - 1) .. tostring(rank_of(sq))
end

local function color(p)
  if p == "." then
    return nil
  end
  if p:match("%u") then
    return "w"
  end
  return "b"
end
M.color = color

local function other(c)
  return c == "w" and "b" or "w"
end
M.other = other

local function copy_cast(c)
  return { K = c.K, Q = c.Q, k = c.k, q = c.q }
end

-- ------------------------------------------------------------------ FEN ---
function M.from_fen(fen)
  local st = { b = {}, turn = "w", cast = { K = false, Q = false, k = false, q = false }, ep = 0, half = 0, full = 1, keys = {} }
  for i = 1, 64 do
    st.b[i] = "."
  end
  local parts = {}
  for w in fen:gmatch("%S+") do
    table.insert(parts, w)
  end
  local rows = {}
  for row in parts[1]:gmatch("[^/]+") do
    table.insert(rows, row)
  end
  for i, row in ipairs(rows) do
    local r = 9 - i
    local f = 1
    for ch in row:gmatch(".") do
      if ch:match("%d") then
        f = f + tonumber(ch)
      else
        st.b[sq_of(f, r)] = ch
        f = f + 1
      end
    end
  end
  st.turn = parts[2] or "w"
  local c = parts[3] or "-"
  st.cast.K = c:find("K") ~= nil
  st.cast.Q = c:find("Q") ~= nil
  st.cast.k = c:find("k") ~= nil
  st.cast.q = c:find("q") ~= nil
  st.ep = M.parse_sq(parts[4] or "-") or 0
  st.half = tonumber(parts[5] or "0") or 0
  st.full = tonumber(parts[6] or "1") or 1
  st.track = true -- партия: ведём историю ключей для ничьей повтором
  table.insert(st.keys, M.key(st))
  return st
end

function M.to_fen(st)
  local rows = {}
  for r = 8, 1, -1 do
    local line, empty = "", 0
    for f = 1, 8 do
      local p = st.b[sq_of(f, r)]
      if p == "." then
        empty = empty + 1
      else
        if empty > 0 then
          line = line .. empty
          empty = 0
        end
        line = line .. p
      end
    end
    if empty > 0 then
      line = line .. empty
    end
    table.insert(rows, line)
  end
  local c = (st.cast.K and "K" or "") .. (st.cast.Q and "Q" or "") .. (st.cast.k and "k" or "") .. (st.cast.q and "q" or "")
  if c == "" then
    c = "-"
  end
  local ep = st.ep ~= 0 and M.sq_name(st.ep) or "-"
  return table.concat(rows, "/") .. " " .. st.turn .. " " .. c .. " " .. ep .. " " .. st.half .. " " .. st.full
end

function M.new(fen)
  return M.from_fen(fen or M.START_FEN)
end

-- Ключ позиции для повторений (без счётчиков ходов).
function M.key(st)
  local c = (st.cast.K and "K" or "") .. (st.cast.Q and "Q" or "") .. (st.cast.k and "k" or "") .. (st.cast.q and "q" or "")
  return table.concat(st.b) .. st.turn .. c .. tostring(st.ep)
end

-- --------------------------------------------------------------- атаки ---
local function ray(b, sq, df, dr, by, kinds)
  local f, r = file_of(sq) + df, rank_of(sq) + dr
  while true do
    local s = sq_of(f, r)
    if not s then
      return false
    end
    local p = b[s]
    if p ~= "." then
      return color(p) == by and kinds[p:upper()] == true
    end
    f = f + df
    r = r + dr
  end
end

-- Атакована ли клетка sq фигурами цвета `by`.
function M.attacked(st, sq, by)
  local b = st.b
  local f, r = file_of(sq), rank_of(sq)
  local pr = by == "w" and -1 or 1 -- пешка атакует с ранга r-1 (белые) / r+1 (чёрные)
  local pawn = by == "w" and "P" or "p"
  for _, df in ipairs({ -1, 1 }) do
    local s = sq_of(f + df, r + pr)
    if s and b[s] == pawn then
      return true
    end
  end
  local knight = by == "w" and "N" or "n"
  for _, o in ipairs(KN) do
    local s = sq_of(f + o[1], r + o[2])
    if s and b[s] == knight then
      return true
    end
  end
  local king = by == "w" and "K" or "k"
  for _, o in ipairs(KG) do
    local s = sq_of(f + o[1], r + o[2])
    if s and b[s] == king then
      return true
    end
  end
  for _, d in ipairs(DIAG) do
    if ray(b, sq, d[1], d[2], by, { B = true, Q = true }) then
      return true
    end
  end
  for _, d in ipairs(ORTH) do
    if ray(b, sq, d[1], d[2], by, { R = true, Q = true }) then
      return true
    end
  end
  return false
end

function M.king_sq(st, c)
  local k = c == "w" and "K" or "k"
  for sq = 1, 64 do
    if st.b[sq] == k then
      return sq
    end
  end
  return nil
end

function M.in_check(st, c)
  local k = M.king_sq(st, c)
  return k ~= nil and M.attacked(st, k, other(c))
end

-- ----------------------------------------------------------- ходы ---------
-- Псевдолегальные ходы. captures_only — только взятия/превращения (для quiescence).
function M.pseudo_moves(st, captures_only)
  local moves = {}
  local b = st.b
  local us = st.turn
  local them = other(us)
  local function add(f, t, extra)
    local m = { f = f, t = t }
    if extra then
      for k, v in pairs(extra) do
        m[k] = v
      end
    end
    table.insert(moves, m)
  end
  for sq = 1, 64 do
    local p = b[sq]
    if p ~= "." and color(p) == us then
      local t = p:upper()
      local f, r = file_of(sq), rank_of(sq)
      if t == "P" then
        local dir = us == "w" and 1 or -1
        local start = us == "w" and 2 or 7
        local promo_rank = us == "w" and 8 or 1
        local one = sq_of(f, r + dir)
        if one and b[one] == "." then
          if not captures_only then
            if rank_of(one) == promo_rank then
              for _, pc in ipairs(PROMO) do
                add(sq, one, { p = pc })
              end
            else
              add(sq, one)
              if r == start then
                local two = sq_of(f, r + 2 * dir)
                if two and b[two] == "." then
                  add(sq, two)
                end
              end
            end
          end
        end
        for _, df in ipairs({ -1, 1 }) do
          local s = sq_of(f + df, r + dir)
          if s then
            if b[s] ~= "." and color(b[s]) == them then
              if rank_of(s) == promo_rank then
                for _, pc in ipairs(PROMO) do
                  add(sq, s, { p = pc })
                end
              else
                add(sq, s)
              end
            elseif s == st.ep and st.ep ~= 0 and b[s] == "." then
              add(sq, s, { ep = true })
            end
          end
        end
      elseif t == "N" or t == "K" then
        local offs = t == "N" and KN or KG
        for _, o in ipairs(offs) do
          local s = sq_of(f + o[1], r + o[2])
          if s and (b[s] == "." or color(b[s]) == them) then
            if not captures_only or b[s] ~= "." then
              add(sq, s)
            end
          end
        end
      else
        local dirs = {}
        if t == "B" or t == "Q" then
          for _, d in ipairs(DIAG) do
            table.insert(dirs, d)
          end
        end
        if t == "R" or t == "Q" then
          for _, d in ipairs(ORTH) do
            table.insert(dirs, d)
          end
        end
        for _, d in ipairs(dirs) do
          local ff, rr = f + d[1], r + d[2]
          while true do
            local s = sq_of(ff, rr)
            if not s then
              break
            end
            if b[s] == "." then
              if not captures_only then
                add(sq, s)
              end
            else
              if color(b[s]) == them then
                add(sq, s)
              end
              break
            end
            ff = ff + d[1]
            rr = rr + d[2]
          end
        end
      end
    end
  end
  -- рокировка (не в quiescence)
  if not captures_only and not M.in_check(st, us) then
    if us == "w" then
      if st.cast.K and b[5] == "K" and b[8] == "R" and b[6] == "." and b[7] == "."
        and not M.attacked(st, 6, them) and not M.attacked(st, 7, them) then
        add(5, 7, { castle = true })
      end
      if st.cast.Q and b[5] == "K" and b[1] == "R" and b[2] == "." and b[3] == "." and b[4] == "."
        and not M.attacked(st, 4, them) and not M.attacked(st, 3, them) then
        add(5, 3, { castle = true })
      end
    else
      if st.cast.k and b[61] == "k" and b[64] == "r" and b[62] == "." and b[63] == "."
        and not M.attacked(st, 62, them) and not M.attacked(st, 63, them) then
        add(61, 63, { castle = true })
      end
      if st.cast.q and b[61] == "k" and b[57] == "r" and b[58] == "." and b[59] == "." and b[60] == "."
        and not M.attacked(st, 60, them) and not M.attacked(st, 59, them) then
        add(61, 59, { castle = true })
      end
    end
  end
  return moves
end

-- Применить ход (in place). Возвращает запись для unmake.
function M.make(st, m)
  local b = st.b
  local us = st.turn
  local u = {
    m = m,
    moved = b[m.f],
    cap = b[m.t],
    capsq = m.t,
    ep = st.ep,
    cast = copy_cast(st.cast),
    half = st.half,
    full = st.full,
    keys_n = st.track and #st.keys or 0,
  }
  if m.ep then
    local csq = sq_of(file_of(m.t), rank_of(m.f))
    u.cap = b[csq]
    u.capsq = csq
    b[csq] = "."
  end
  local piece = b[m.f]
  if m.p then
    piece = us == "w" and m.p or m.p:lower()
  end
  b[m.t] = piece
  b[m.f] = "."
  if m.castle then
    if m.t == 7 then
      b[6], b[8] = b[8], "."
    elseif m.t == 3 then
      b[4], b[1] = b[1], "."
    elseif m.t == 63 then
      b[62], b[64] = b[64], "."
    elseif m.t == 59 then
      b[60], b[57] = b[57], "."
    end
  end
  -- права на рокировку
  local c = st.cast
  if piece == "K" then
    c.K, c.Q = false, false
  elseif piece == "k" then
    c.k, c.q = false, false
  end
  for _, sq in ipairs({ m.f, m.t }) do
    if sq == 1 then
      c.Q = false
    elseif sq == 8 then
      c.K = false
    elseif sq == 57 then
      c.q = false
    elseif sq == 64 then
      c.k = false
    end
  end
  -- взятие на проходе: ставим цель после двойного хода пешки
  st.ep = 0
  if (piece == "P" or piece == "p") and math.abs(m.t - m.f) == 16 then
    st.ep = math.floor((m.t + m.f) / 2)
  end
  if piece:upper() == "P" or u.cap ~= "." then
    st.half = 0
  else
    st.half = st.half + 1
  end
  if us == "b" then
    st.full = st.full + 1
  end
  st.turn = other(us)
  if st.track then
    table.insert(st.keys, M.key(st))
  end
  return u
end

function M.unmake(st, u)
  local b = st.b
  local m = u.m
  local us = other(st.turn) -- сторона, которая ходила
  st.turn = us
  b[m.f] = u.moved
  b[m.t] = "."
  if m.ep then
    b[u.capsq] = u.cap
  else
    b[m.t] = u.cap
  end
  if m.castle then
    if m.t == 7 then
      b[8], b[6] = b[6], "."
    elseif m.t == 3 then
      b[1], b[4] = b[4], "."
    elseif m.t == 63 then
      b[64], b[62] = b[62], "."
    elseif m.t == 59 then
      b[57], b[60] = b[60], "."
    end
  end
  st.ep = u.ep
  st.cast = u.cast
  st.half = u.half
  st.full = u.full
  if st.track then
    for i = #st.keys, u.keys_n + 1, -1 do
      st.keys[i] = nil
    end
  end
end

-- Легальные ходы: псевдолегальные, после которых свой король не под боем.
function M.legal_moves(st, captures_only)
  local out = {}
  local us = st.turn
  for _, m in ipairs(M.pseudo_moves(st, captures_only)) do
    local u = M.make(st, m)
    local k = M.king_sq(st, us)
    if not M.attacked(st, k, st.turn) then
      table.insert(out, m)
    end
    M.unmake(st, u)
  end
  return out
end

-- Ход из строки "e2e4" / "e7e8q" (для тестов и ввода).
function M.find_move(st, text)
  local f = M.parse_sq(text:sub(1, 2))
  local t = M.parse_sq(text:sub(3, 4))
  local promo = text:sub(5, 5)
  for _, m in ipairs(M.legal_moves(st)) do
    if m.f == f and m.t == t then
      if m.p == nil or (promo ~= "" and m.p:lower() == promo:lower()) then
        return m
      end
    end
  end
  return nil
end

-- Статус: "play" | "mate" | "stalemate" | "draw50" | "repetition" | "material"
-- Возвращает статус и (для мата) победителя.
function M.status(st)
  local moves = M.legal_moves(st)
  if #moves == 0 then
    if M.in_check(st, st.turn) then
      return "mate", other(st.turn)
    end
    return "stalemate"
  end
  if st.half >= 100 then
    return "draw50"
  end
  local same = 0
  local k = M.key(st)
  for _, kk in ipairs(st.keys) do
    if kk == k then
      same = same + 1
    end
  end
  if same >= 3 then
    return "repetition"
  end
  -- недостаточно материала: только короли, или король + одна лёгкая фигура
  local minors, other_pieces = 0, false
  for sq = 1, 64 do
    local p = st.b[sq]
    if p ~= "." and p:upper() ~= "K" then
      if p:upper() == "N" or p:upper() == "B" then
        minors = minors + 1
      else
        other_pieces = true
      end
    end
  end
  if not other_pieces and minors <= 1 then
    return "material"
  end
  return "play"
end

-- Подсчёт листьев дерева ходов (perft) — для проверки генератора.
function M.perft(st, depth)
  if depth == 0 then
    return 1
  end
  local total = 0
  for _, m in ipairs(M.legal_moves(st)) do
    local u = M.make(st, m)
    total = total + M.perft(st, depth - 1)
    M.unmake(st, u)
  end
  return total
end

-- Текст хода для списка: e2-e4, e7-e8=Q, O-O, O-O-O.
function M.move_text(st, m)
  if m.castle then
    return (m.t == 7 or m.t == 63) and "O-O" or "O-O-O"
  end
  local s = M.sq_name(m.f) .. "-" .. M.sq_name(m.t)
  if m.p then
    s = s .. "=" .. m.p
  end
  return s
end

return M
