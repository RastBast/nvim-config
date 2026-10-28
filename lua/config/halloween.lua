-- ========================================================================== --
--                       HALLOWEEN: эффекты прямо в терминале                  --
-- ========================================================================== --
-- Что здесь есть:
--   1) ОВЕРЛЕЙ (<leader>uH, :Halloween [on|off]): летучие мыши, призраки и пауки
--      летят справа налево ПОВЕРХ всего редактора и терминала (прозрачная
--      строка, winblend=100). Включает тему «halloween», тыкву в статус-баре
--      (lualine) и палитру терминала nvim (цвета из нашего ghostty-конфига).
--      Состояние переживает перезапуск (stdpath("state")/halloween.txt).
--   2) ОКНО-АНИМАЦИЯ (<leader>uHw, :HalloweenWin): ночная сцена в плавающем окне
--      с летучими мышами и призраком. Закрыть: q или Esc.
--   3) :Boo — призрак пролетает над текущим окном и исчезает.
--   4) При выборе темы Halloween (<leader>uT) — уведомление с ASCII-тыквой.
-- Цвета темы Halloween — в lua/config/themes.lua (apply_halloween).

local M = {}

M.on_flag = false

local NS = vim.api.nvim_create_namespace("halloween_fx")
local W, H = 60, 12 -- ширина и высота сцены окна
local TICKS = 60 -- длина цикла анимации окна (тиков)
local MS = 90 -- задержка тика окна, мс
local TICK_MS = 120 -- задержка тика оверлея, мс

local BAT = { "\\^v^/", "_^v^_" }
local GHOST = { "(o.o)", "(O.O)" }

local PUMPKIN = {
  "     ,--.      ",
  "   _/ ^^ \\_    ",
  "  ( ^    ^ )   ",
  "   \\_ vv _/    ",
  "     `--'      ",
}

-- Кодточки: летучая мышь, призрак, паук (+вариатор), тыква. Эмодзи — 2 ячейки.
local function cp(n)
  return vim.fn.nr2char(n)
end
local STATE_GLYPHS = { cp(0x1F987), cp(0x1F987), cp(0x1F47B), cp(0x1F577) .. cp(0xFE0F), cp(0x1F383) }

-- Палитра терминала nvim = палитра нашего ghostty-конфига (macos/ghostty/config),
-- чтобы :terminal внутри nvim выглядел так же, как сам Ghostty.
local TERM_PALETTE = {
  "#000000", "#ff0000", "#2bff00", "#fffb00", "#6902de", "#ff9500", "#00eeff", "#e6e6e6",
  "#6902de", "#ff5c5c", "#7dff5c", "#fff870", "#9d5cff", "#ffb84d", "#8ff7ff", "#ffffff",
}

-- ----------------------------------------------------------- состояние ----
local bats_win, bats_buf, bats_timer = nil, nil, nil
local bats = {}
local saved_term_colors = nil
local prev_theme = nil

local function state_file()
  return vim.fn.stdpath("state") .. "/halloween.txt"
end

local function save_flag(on)
  local f = io.open(state_file(), "w")
  if f then
    f:write(on and "on" or "off", "\n")
    f:close()
  end
end

local function load_flag()
  local f = io.open(state_file(), "r")
  if not f then
    return false
  end
  local v = vim.trim(f:read("*l") or "")
  f:close()
  return v == "on"
end

-- ------------------------------------------------ окно-анимация (кадры) ----
-- Кадр сцены: строки одинаковой длины W, без цветов (цвет даёт highlight)
local function frame(t)
  local grid = {}
  for y = 1, H do
    grid[y] = {}
    for x = 1, W do
      grid[y][x] = " "
    end
  end
  local function put(y, x, s)
    if y < 1 or y > H then
      return
    end
    for i = 1, #s do
      local col = x + i - 1
      if col >= 1 and col <= W then
        grid[y][col] = s:sub(i, i)
      end
    end
  end
  -- летучие мыши: летят справа налево, каждая на своей высоте и со своим ритмом
  for k = 0, 3 do
    local x = W - ((t * 2 + k * 15) % (W + 10))
    local y = 3 + k * 2 + math.floor(math.sin((t + k * 5) / 3) + 0.5)
    put(y, x, BAT[math.floor(t / 3) % 2 + 1])
  end
  -- призрак плывёт слева направо внизу сцены
  local gx = 2 + (t * 2) % (W - 8)
  put(H - 2, gx, GHOST[math.floor(t / 4) % 2 + 1])

  local lines = {}
  for y = 1, H do
    lines[y] = table.concat(grid[y])
  end
  return lines
end

local function open_window(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  local cols, rows = vim.o.columns, vim.o.lines
  local width = math.min(W + 2, cols - 4)
  local height = math.min(#lines + 2, rows - 4)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((rows - height) / 2),
    col = math.floor((cols - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " 🎃 HAPPY HALLOWEEN 🎃 ",
    title_pos = "center",
    footer = " q / Esc — закрыть ",
    footer_pos = "center",
  })
  vim.wo[win].winhighlight = "Normal:HalloweenFx,FloatBorder:HalloweenBorder,FloatTitle:HalloweenBorder"
  return buf, win
end

--- Анимация «ночь Хэллоуина» в плавающем окне (<leader>uHw, :HalloweenWin).
function M.show()
  local t = 0
  local buf, win = open_window({ "" })
  local timer = vim.uv.new_timer()

  local function set(lines)
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
  end

  local function stop()
    if timer and not timer:is_closing() then
      timer:stop()
      timer:close()
    end
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- закрытие клавишами
  for _, k in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", k, stop, { buffer = buf, nowait = true, desc = "Закрыть Хэллоуин" })
  end

  timer:start(0, MS, vim.schedule_wrap(function()
    if not vim.api.nvim_win_is_valid(win) then
      stop()
      return
    end
    set(frame(t % TICKS))
    t = t + 1
  end))
end

-- ------------------------------------------------ оверлей: мыши над экраном ----
-- Одна прозрачная строка поверх редактора: существа летят справа налево.
local function glyph_width()
  return 2 -- эмодзи занимают 2 ячейки, паук с вариатором — тоже 2
end

local function new_bat(cols, from_right)
  return {
    x = from_right and (cols + math.random(2, 30)) or math.random(0, cols),
    speed = math.random(1, 3),
    glyph = STATE_GLYPHS[math.random(#STATE_GLYPHS)],
  }
end

local function render_bats()
  if not (bats_win and vim.api.nvim_win_is_valid(bats_win)) then
    return
  end
  local cols = vim.o.columns
  local cells = {}
  for _, b in ipairs(bats) do
    if b.x >= 0 and b.x < cols then
      cells[#cells + 1] = b
    end
  end
  table.sort(cells, function(a, b) return a.x < b.x end)
  local out, cur = {}, 0
  for _, b in ipairs(cells) do
    if b.x > cur then
      out[#out + 1] = string.rep(" ", b.x - cur)
      cur = b.x
    end
    out[#out + 1] = b.glyph
    cur = cur + glyph_width()
  end
  pcall(vim.api.nvim_buf_set_lines, bats_buf, 0, -1, false, { table.concat(out) })
end

local function tick()
  local cols = vim.o.columns
  for i, b in ipairs(bats) do
    b.x = b.x - b.speed
    if b.x < -4 then
      bats[i] = new_bat(cols, true)
    end
  end
  render_bats()
end

local function start_bats()
  if bats_win and vim.api.nvim_win_is_valid(bats_win) then
    return
  end
  bats_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[bats_buf].buftype = "nofile"
  vim.bo[bats_buf].bufhidden = "hide"
  vim.bo[bats_buf].filetype = "halloween-bats"
  local ok, win = pcall(vim.api.nvim_open_win, bats_buf, false, {
    relative = "editor",
    row = 0,
    col = 0,
    width = vim.o.columns,
    height = 1,
    focusable = false,
    style = "minimal",
    zindex = 60,
    border = "none",
  })
  if not ok then
    return
  end
  bats_win = win
  vim.wo[win].winblend = 100 -- полностью прозрачный фон: видны только мыши
  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].statuscolumn = ""
  vim.wo[win].foldcolumn = "0"

  bats = {}
  for _ = 1, 4 do
    bats[#bats + 1] = new_bat(vim.o.columns, false)
  end
  render_bats()

  bats_timer = vim.uv.new_timer()
  bats_timer:start(TICK_MS, TICK_MS, vim.schedule_wrap(function()
    if bats_win and vim.api.nvim_win_is_valid(bats_win) then
      tick()
    end
  end))

  -- держим ширину строки равной ширине редактора
  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("HalloweenBats", { clear = true }),
    callback = function()
      if bats_win and vim.api.nvim_win_is_valid(bats_win) then
        pcall(vim.api.nvim_win_set_width, bats_win, vim.o.columns)
        render_bats()
      end
    end,
  })
end

local function stop_bats()
  if bats_timer then
    pcall(function() bats_timer:stop() end)
    pcall(function() bats_timer:close() end)
    bats_timer = nil
  end
  if bats_win and vim.api.nvim_win_is_valid(bats_win) then
    pcall(vim.api.nvim_win_close, bats_win, true)
  end
  bats_win, bats_buf = nil, nil
  bats = {}
end

-- ------------------------------------------------- цвета терминала nvim ----
local function set_term_colors()
  if saved_term_colors then
    return
  end
  saved_term_colors = {}
  for i = 0, 15 do
    saved_term_colors[i] = vim.g["terminal_color_" .. i]
  end
  for i, c in ipairs(TERM_PALETTE) do
    vim.g["terminal_color_" .. (i - 1)] = c
  end
end

local function restore_term_colors()
  if not saved_term_colors then
    return
  end
  for i = 0, 15 do
    vim.g["terminal_color_" .. i] = saved_term_colors[i]
  end
  saved_term_colors = nil
end

-- ------------------------------------------------------ вкл / выкл оверлея ----
function M.is_on()
  return M.on_flag
end

function M.on()
  if M.on_flag then
    return
  end
  M.on_flag = true
  save_flag(true)
  vim.g.halloween_on = 1

  local themes = require("config.themes")
  if themes.current ~= "halloween" then
    prev_theme = themes.current
  end
  themes.set("halloween", { silent = true })

  set_term_colors()
  start_bats()
  vim.notify("🎃 Хэллоуин включён: тема, мыши над экраном и тыква в статус-баре. Выкл: :Halloween off", vim.log.levels.INFO)
end

function M.off()
  if not M.on_flag then
    return
  end
  M.on_flag = false
  save_flag(false)
  vim.g.halloween_on = 0

  stop_bats()
  restore_term_colors()

  local themes = require("config.themes")
  if themes.current == "halloween" then
    themes.set(prev_theme or "new", { silent = true })
  end
  prev_theme = nil
  vim.notify("🕯 Хэллоуин выключен: всё вернулось как было", vim.log.levels.INFO)
end

function M.toggle()
  if M.on_flag then
    M.off()
  else
    M.on()
  end
end

--- Уведомление с тыквой (при выборе темы Halloween).
function M.pumpkin_notify(text)
  local msg = table.concat(PUMPKIN, "\n") .. "\n" .. (text or "Тема Halloween включена 🎃")
  vim.notify(msg, vim.log.levels.INFO, { title = "🎃 Halloween" })
end

--- :Boo — призрак пролетает над текущим окном (короткая анимация, без выделения).
function M.boo()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  local cfg = {
    relative = "win",
    win = win,
    row = 1,
    col = vim.api.nvim_win_get_width(win) - 8,
    width = 7,
    height = 1,
    style = "minimal",
    focusable = false,
    zindex = 250,
  }
  local ghost = vim.api.nvim_open_win(buf, false, cfg)
  vim.wo[ghost].winhighlight = "Normal:HalloweenFx"
  local steps = 0
  local max = math.max(cfg.col, 1)
  local timer = vim.uv.new_timer()
  timer:start(0, 60, vim.schedule_wrap(function()
    steps = steps + 1
    if steps > max or not vim.api.nvim_win_is_valid(ghost) or not vim.api.nvim_win_is_valid(win) then
      if not timer:is_closing() then
        timer:stop()
        timer:close()
      end
      if vim.api.nvim_win_is_valid(ghost) then
        vim.api.nvim_win_close(ghost, true)
      end
      return
    end
    local g = GHOST[math.floor(steps / 3) % 2 + 1]
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "boo " .. g })
    vim.bo[buf].modifiable = false
    vim.api.nvim_win_set_config(ghost, { relative = "win", win = win, row = 1, col = math.max(cfg.col - steps, 0), width = 7, height = 1 })
  end))
end

-- Для тестов (tests/halloween_test.py): чистая функция кадра.
M._frame = frame
M._W, M._H, M._TICKS = W, H, TICKS

function M.setup()
  vim.api.nvim_set_hl(0, "HalloweenFx", { fg = "#ff9500", bg = "#000000" })
  vim.api.nvim_set_hl(0, "HalloweenBorder", { fg = "#6902de", bg = "#000000", bold = true })
  vim.g.halloween_on = 0

  vim.api.nvim_create_user_command("Halloween", function(opts)
    local a = (opts.args or ""):lower()
    if a == "on" then
      M.on()
    elseif a == "off" then
      M.off()
    else
      M.toggle()
    end
  end, {
    nargs = "?",
    complete = function() return { "on", "off" } end,
    desc = "🎃 Хэллоуин: мыши над экраном + тема + тыква (вкл/выкл)",
  })
  vim.api.nvim_create_user_command("HalloweenWin", M.show, { desc = "🎃 Хэллоуин: окно-анимация (мыши, призрак)" })
  vim.api.nvim_create_user_command("Boo", M.boo, { desc = "Призрак «буу» над текущим окном" })

  vim.keymap.set("n", "<leader>uH", M.toggle, { desc = "🎃 Хэллоуин вкл/выкл (мыши над экраном, тема, тыква)" })
  vim.keymap.set("n", "<leader>uHw", M.show, { desc = "🎃 Хэллоуин: окно-анимация (мыши, призрак)" })

  -- пережило перезапуск: флаг on → поднимаем мышей и палитру терминала
  -- (тема halloween к этому моменту уже применена themes.setup)
  if load_flag() then
    M.on_flag = true
    vim.g.halloween_on = 1
    set_term_colors()
    vim.schedule(start_bats)
  end
end

return M
