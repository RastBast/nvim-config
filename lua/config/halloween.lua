-- ========================================================================== --
--                 🎃 ХЭЛЛОУИН: вайб прямо в терминале                        --
-- ========================================================================== --
-- :Halloween          — переключить (вкл/выкл)
-- :Halloween on|off   — явно
-- <leader>uH          — то же самое клавишей
--
-- Что включает:
--   1. Тему «halloween» (lua/config/themes.lua): чёрный фон, тыква #ff7a00,
--      фиолетовое свечение #6a00b8, слизь #7dff5c, конфеты #ffd75c.
--   2. Летучих мышей: прозрачная плавающая строка поверх ВСЕГО редактора
--      (winblend=100, zindex=60) — мыши/призраки/пауки летят справа налево
--      через весь экран, поверх любого буфера, включая терминал.
--   3. Тыкву в статус-баре (lualine читает vim.g.halloween_on).
--   4. «Терминальные» цвета nvim (g:terminal_color_*): открываешь :terminal
--      внутри nvim — палитра уже хэллоуинская. Вайб даже в терминале.
--
-- Состояние живёт в stdpath("state")/halloween.txt: включил — переживёт
-- перезапуск nvim (тема восстановится сама через themes.lua, мыши и палитра
-- терминала поднимаются здесь на старте).
local M = {}

M.on_flag = false

-- Кодточки пишем через nr2char: летучая мышь, призрак, паук, тыква.
-- (Эмодзи шириной 2 ячейки — см. glyph_width.)
local function cp(n)
  return vim.fn.nr2char(n)
end
local STATE_GLYPHS = { cp(0x1F987), cp(0x1F987), cp(0x1F47B), cp(0x1F577) .. cp(0xFE0F), cp(0x1F383) }
local TICK_MS = 120

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

-- ------------------------------------------------------------------ мыши ---
-- Одна прозрачная строка поверх редактора: существа летят справа налево.
local function glyph_width(g)
  -- эмодзи занимают 2 ячейки, пауки с вариатором — тоже 2
  return 2
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
    cur = cur + glyph_width(b.glyph)
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

  bats_timer = vim.loop.new_timer()
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
local TERM_PALETTE = {
  "#000000", "#ff3b3b", "#7dff5c", "#ffd75c",
  "#9d5cff", "#ff7a00", "#00eeff", "#e8e3d5",
  "#6a00b8", "#ff5c5c", "#a4ff7d", "#ffe28a",
  "#b36bff", "#ffb84d", "#8ff7ff", "#ffffff",
}

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

-- ---------------------------------------------------------------- вкл/выкл -
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

function M.setup()
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
    desc = "🎃 Хэллоуин-вайб: тема + летучие мыши + тыква (вкл/выкл)",
  })

  vim.keymap.set("n", "<leader>uH", M.toggle, { desc = "🎃 Хэллоуин-вайб вкл/выкл" })

  -- пережило перезапуск: флаг on → поднимаем мышей и палитру терминала
  -- (тема halloween к этому моменту уже применена themes.setup)
  if load_flag() then
    M.on_flag = true
    vim.g.halloween_on = 1
    set_term_colors()
    vim.schedule(function()
      start_bats()
    end)
  end
end

return M
