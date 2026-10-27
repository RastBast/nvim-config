-- Шахматы в nvim: окно с доской, курсор и выбор клеток.
-- Режимы: 👥 два игрока на одной клавиатуре; 🤖 против ПК (5 уровней, выбор цвета).
--
-- Управление: h j k l / стрелки — курсор · Enter/Space — выбрать фигуру, затем клетку ·
--             Esc — отменить выбор (или закрыть) · u — отменить ход · f — перевернуть доску ·
--             n — новая партия · q — выход.

local B = require("games.chess.board")
local AI = require("games.chess.ai")
local F = require("games.float")

local M = {}

local S = {
  h = nil, -- окно
  g = nil, -- партия: { st, mode = "pvp"|"pc", level, human, undo = {}, last = nil, over = nil }
  cursor = 0, -- клетка курсора (sq)
  sel = nil, -- выбранная фигура (sq)
  targets = {}, -- ходы из sel
  flip = false,
  seq = 0, -- для отмены отложенного хода ПК
  msg = "",
}

local FILES = "abcdefgh"
local PIECE_NAMES = { Q = "ферзь", R = "ладья", B = "слон", N = "конь" }

local function is_human_turn(g)
  return g.mode == "pvp" or g.st.turn == g.human
end

local function side_name(c)
  return c == "w" and "Белые" or "Чёрные"
end

-- ----------------------------------------------------------- отрисовка ---
local function render()
  if not F.valid(S.h) then
    return
  end
  local g = S.g
  local lines, hls = {}, {}
  local function add(s)
    table.insert(lines, s)
    return #lines - 1
  end

  add("")
  -- клетки: строки ранга 8..1 (или 1..8 при перевороте)
  local ranks = {}
  for r = 8, 1, -1 do
    table.insert(ranks, r)
  end
  if S.flip then
    local rev = {}
    for i = #ranks, 1, -1 do
      table.insert(rev, ranks[i])
    end
    ranks = rev
  end

  local checked_king = nil
  if g and B.in_check(g.st, g.st.turn) then
    checked_king = B.king_sq(g.st, g.st.turn)
  end
  local last = g and g.last or nil
  local target_set = {}
  for _, m in ipairs(S.targets) do
    target_set[m.t] = true
  end

  for _, r in ipairs(ranks) do
    local parts = { " " .. r .. " " }
    local row = #lines
    local col = 3
    for fi = 1, 8 do
      local f = S.flip and (9 - fi) or fi
      local sq = B.sq_of(f, r)
      local p = g and g.st.b[sq] or "."
      -- ASCII-буквы фигур (белые — заглавные), точка — пусто; клетка 3 символа
      local cell = " " .. p .. " "
      table.insert(parts, cell)
      -- подсветка клетки
      local group
      if sq == S.sel then
        group = "GamesSel"
      elseif sq == S.cursor then
        group = "GamesCursor"
      elseif sq == checked_king then
        group = "GamesCheck"
      elseif target_set[sq] then
        group = "GamesTarget"
      elseif last and (sq == last.f or sq == last.t) then
        group = "GamesLast"
      else
        local light = (f + r) % 2 == 0
        group = light and "GamesSquareLight" or "GamesSquareDark"
        if p ~= "." then
          group = B.color(p) == "w" and "GamesWhitePiece" or "GamesBlackPiece"
        end
      end
      table.insert(hls, { row, col, col + 3, group, 150 })
      col = col + 3
    end
    local line = table.concat(parts) .. " " .. r
    add(line)
  end
  local files = "   "
  for fi = 1, 8 do
    local f = S.flip and (9 - fi) or fi
    files = files .. " " .. FILES:sub(f, f) .. " "
  end
  add(files)
  add("")

  -- статус
  local status_text, status_group = "", "GamesTitle"
  if g then
    if g.over then
      status_text = g.over
      status_group = "GamesOk"
    else
      local check = B.in_check(g.st, g.st.turn)
      if g.mode == "pc" and not is_human_turn(g) then
        status_text = "🤖 ПК (" .. AI.LEVELS[g.level].name .. ") думает…"
        status_group = "GamesWarn"
      else
        status_text = "Ход: " .. side_name(g.st.turn) .. (check and " — ШАХ!" or "")
        status_group = check and "GamesBad" or "GamesOk"
      end
      if g.mode == "pc" then
        status_text = status_text .. "   (ты: " .. side_name(g.human):lower() .. ")"
      end
    end
  end
  add(" " .. status_text)
  table.insert(hls, { #lines - 1, 0, -1, status_group, 200 })
  local lm = g and g.last
  add(lm and (" Последний ход: " .. B.move_text(g.st, lm)) or " Партия начинается.")
  -- короткий список ходов (последние 6)
  local tail = {}
  if g then
    local hist = g.hist or {}
    for i = math.max(1, #hist - 5), #hist do
      table.insert(tail, hist[i])
    end
  end
  add(" " .. (#tail > 0 and ("Ходы: " .. table.concat(tail, "  ")) or ""))
  add(" " .. (S.msg or ""))
  add("")
  add(" hjkl Enter ход · u отмена · f доска · n новая · q выход")
  table.insert(hls, { #lines - 1, 0, -1, "GamesHelp", 100 })

  F.render(S.h, lines, hls)
end

-- ------------------------------------------------------------ ход ---------
local function after_move()
  local g = S.g
  local status, winner = B.status(g.st)
  if status == "mate" then
    g.over = "🏆 Мат! Победили " .. side_name(winner):lower() .. "."
  elseif status == "stalemate" then
    g.over = "🤝 Пат — ничья."
  elseif status == "draw50" then
    g.over = "🤝 Ничья: правило 50 ходов."
  elseif status == "repetition" then
    g.over = "🤝 Ничья: троекратное повторение."
  elseif status == "material" then
    g.over = "🤝 Ничья: недостаточно материала."
  end
  render()
  if g.over then
    return
  end
  if g.mode == "pc" and not is_human_turn(g) then
    S.seq = S.seq + 1
    local seq = S.seq
    vim.defer_fn(function()
      if seq ~= S.seq or not S.g or S.g.over or not F.valid(S.h) then
        return
      end
      local m = AI.choose(S.g.st, S.g.level)
      if m then
        M.apply(m)
      end
    end, 120)
  end
end

-- Применить ход (человек или ПК): запись в историю и undo-стек.
function M.apply(m)
  local g = S.g
  local st = g.st
  local text = B.move_text(st, m)
  local u = B.make(st, m)
  table.insert(g.undo, { u = u, text = text })
  g.last = m
  g.hist = g.hist or {}
  if st.turn == "b" then
    -- ход белых только что сделан: номер хода = текущий st.full
    table.insert(g.hist, st.full .. ". " .. text)
  else
    local n = #g.hist
    g.hist[n] = (g.hist[n] or "") .. " " .. text
  end
  S.sel, S.targets = nil, {}
  S.msg = ""
  after_move()
end

local function undo()
  local g = S.g
  if not g or #g.undo == 0 then
    S.msg = "Нечего отменять."
    return render()
  end
  -- против ПК откатываем два полухода (свой и ответ ПК), если он уже ответил
  local steps = 1
  if g.mode == "pc" and #g.undo >= 2 and is_human_turn(g) then
    steps = 2
  end
  if g.mode == "pc" and not is_human_turn(g) then
    S.msg = "Подождите ход ПК."
    return render()
  end
  S.seq = S.seq + 1
  for _ = 1, steps do
    local rec = table.remove(g.undo)
    if rec then
      B.unmake(g.st, rec.u)
      if g.st.turn == "b" then
        -- откат хода чёрных: убираем текст из последней строки
        local n = #g.hist
        local s = g.hist[n] or ""
        local suffix = " " .. rec.text
        if s:sub(-#suffix) == suffix then
          g.hist[n] = s:sub(1, #s - #suffix)
        end
      else
        table.remove(g.hist)
      end
    end
  end
  g.over = nil
  g.last = #g.undo > 0 and g.undo[#g.undo].u.m or nil
  S.sel, S.targets = nil, {}
  S.msg = "Ход отменён."
  render()
end

local function promotion_choice(m_list, done)
  local opts = {}
  for _, m in ipairs(m_list) do
    table.insert(opts, m)
  end
  vim.ui.select(opts, {
    prompt = "Превращение пешки",
    format_item = function(m)
      return (PIECE_NAMES[m.p] or m.p) .. " (" .. m.p .. ")"
    end,
  }, function(choice)
    if choice then
      done(choice)
    end
  end)
end

local function try_move_to(sq)
  local g = S.g
  local picks = {}
  for _, m in ipairs(S.targets) do
    if m.t == sq then
      table.insert(picks, m)
    end
  end
  if #picks == 0 then
    return false
  end
  if picks[1].p then
    promotion_choice(picks, function(m)
      M.apply(m)
    end)
    return true
  end
  M.apply(picks[1])
  return true
end

local function on_select()
  local g = S.g
  if not g or g.over then
    S.msg = "Партия окончена. Нажмите n — новая."
    return render()
  end
  if not is_human_turn(g) then
    S.msg = "Сейчас ходит ПК."
    return render()
  end
  local c = S.cursor
  if S.sel then
    if c == S.sel then
      S.sel, S.targets = nil, {}
      S.msg = ""
      return render()
    end
    if try_move_to(c) then
      return
    end
    -- клик по своей фигуре — переназначить выбор
    local p = g.st.b[c]
    if p ~= "." and B.color(p) == g.st.turn then
      S.sel = c
      S.targets = {}
      for _, m in ipairs(B.legal_moves(g.st)) do
        if m.f == c then
          table.insert(S.targets, m)
        end
      end
      S.msg = ""
    else
      S.sel, S.targets = nil, {}
      S.msg = "Туда нельзя."
    end
    return render()
  end
  local p = g.st.b[c]
  if p == "." or B.color(p) ~= g.st.turn then
    S.msg = "Выберите свою фигуру (" .. side_name(g.st.turn):lower() .. ")."
    return render()
  end
  S.sel = c
  S.targets = {}
  for _, m in ipairs(B.legal_moves(g.st)) do
    if m.f == c then
      table.insert(S.targets, m)
    end
  end
  if #S.targets == 0 then
    S.sel = nil
    S.msg = "У этой фигуры нет ходов."
  else
    S.msg = ""
  end
  render()
end

local function move_cursor(df, dr)
  local f = B.file_of(S.cursor) + df
  local r = B.rank_of(S.cursor) + dr
  local sq = B.sq_of(f, r)
  if sq then
    S.cursor = sq
    render()
  end
end

-- ------------------------------------------------------------ меню ---------
local LEVEL_ITEMS = {}
for i, l in ipairs(AI.LEVELS) do
  table.insert(LEVEL_ITEMS, { level = i, label = i .. " · " .. l.name })
end

local function start(g)
  S.g = g
  S.cursor = B.sq_of(5, 2) -- e2
  S.sel, S.targets = nil, {}
  S.flip = g.human == "b"
  S.seq = S.seq + 1
  S.msg = ""
  render()
  if g.mode == "pc" and not is_human_turn(g) then
    local seq = S.seq
    vim.defer_fn(function()
      if seq ~= S.seq or not S.g or S.g.over then
        return
      end
      local m = AI.choose(S.g.st, S.g.level)
      if m then
        M.apply(m)
      end
    end, 200)
  end
end

function M.new_game()
  vim.ui.select({
    { mode = "pvp", label = "👥 Два игрока на одной клавиатуре" },
    { mode = "pc", label = "🤖 Против ПК" },
  }, {
    prompt = "Режим шахмат",
    format_item = function(i)
      return i.label
    end,
  }, function(mode)
    if not mode then
      if not S.g then
        M.close()
      end
      return
    end
    if mode.mode == "pvp" then
      start({ st = B.new(), mode = "pvp", undo = {}, hist = {}, human = "w" })
      return
    end
    vim.ui.select(LEVEL_ITEMS, {
      prompt = "Сложность ПК",
      format_item = function(i)
        return i.label
      end,
    }, function(lvl)
      if not lvl then
        return
      end
      vim.ui.select({
        { human = "w", label = "♔ Играю белыми (ходишь первым)" },
        { human = "b", label = "♚ Играю чёрными" },
      }, {
        prompt = "За кого играете",
        format_item = function(i)
          return i.label
        end,
      }, function(side)
        if not side then
          return
        end
        start({ st = B.new(), mode = "pc", level = lvl.level, human = side.human, undo = {}, hist = {} })
      end)
    end)
  end)
end

local function keymaps()
  local h = S.h
  F.map(h, { "h", "<Left>" }, function() move_cursor(-1, 0) end, "Курсор влево")
  F.map(h, { "l", "<Right>" }, function() move_cursor(1, 0) end, "Курсор вправо")
  F.map(h, { "j", "<Down>" }, function() move_cursor(0, -1) end, "Курсор вниз")
  F.map(h, { "k", "<Up>" }, function() move_cursor(0, 1) end, "Курсор вверх")
  F.map(h, { "<CR>", "<Space>" }, on_select, "Выбрать фигуру / клетку")
  F.map(h, "u", undo, "Отменить ход")
  F.map(h, "f", function()
    S.flip = not S.flip
    render()
  end, "Перевернуть доску")
  F.map(h, "n", function()
    M.new_game()
  end, "Новая партия")
  F.map(h, "q", function()
    M.close()
  end, "Закрыть")
  F.map(h, "<Esc>", function()
    if S.sel then
      S.sel, S.targets = nil, {}
      render()
    else
      M.close()
    end
  end, "Отмена выбора / закрыть")
end

function M.open()
  if F.valid(S.h) then
    vim.api.nvim_set_current_win(S.h.win)
    return
  end
  S.h = F.open({
    width = 46,
    height = 22,
    title = "♟ Шахматы",
    footer = "n новая · u отмена · q выход",
    on_close = function()
      S.h = nil
      S.seq = S.seq + 1 -- отменяем отложенный ход ПК
    end,
  })
  keymaps()
  if not S.g then
    render()
    M.new_game()
  else
    start(S.g) -- продолжить текущую партию
  end
end

function M.close()
  F.close(S.h)
end

M._state = S -- для тестов интерфейса
return M
