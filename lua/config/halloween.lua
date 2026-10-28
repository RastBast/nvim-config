-- ========================================================================== --
--                       HALLOWEEN: эффекты прямо в терминале                  --
-- ========================================================================== --
-- Что здесь есть (всё — текст, работает в любом терминале, без картинок):
--   1) Анимация «ночь Хэллоуина»: летучие мыши и призрак летают по плавающему
--      окну. Открывается по <leader>uH или :Halloween. Закрыть: q или Esc.
--   2) При выборе темы Halloween (<leader>uT) — уведомление с ASCII-тыквой.
--   3) Эффект «буу»: :Boo — призрак пролетает над текущим окном и исчезает.
-- Цвета темы Halloween — в lua/config/themes.lua (apply_halloween).

local M = {}

local NS = vim.api.nvim_create_namespace("halloween_fx")
local W, H = 60, 12 -- ширина и высота сцены
local TICKS = 60 -- длина цикла анимации (тиков)
local MS = 90 -- задержка тика, мс

local BAT = { "\\^v^/", "_^v^_" }
local GHOST = { "(o.o)", "(O.O)" }

local PUMPKIN = {
  "     ,--.      ",
  "   _/ ^^ \\_    ",
  "  ( ^    ^ )   ",
  "   \\_ vv _/    ",
  "     `--'      ",
}

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
    put(y, x, BAT[(t // 3) % 2 + 1])
  end
  -- призрак плывёт слева направо внизу сцены
  local gx = 2 + (t * 2) % (W - 8)
  put(H - 2, gx, GHOST[(t // 4) % 2 + 1])

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

--- Анимация «ночь Хэллоуина» в плавающем окне.
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
    local g = GHOST[(steps // 3) % 2 + 1]
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "boo " .. g })
    vim.bo[buf].modifiable = false
    vim.api.nvim_win_set_config(ghost, { relative = "win", win = win, row = 1, col = math.max(cfg.col - steps, 0), width = 7, height = 1 })
  end))
end

function M.setup()
  vim.api.nvim_set_hl(0, "HalloweenFx", { fg = "#ff9500", bg = "#000000" })
  vim.api.nvim_set_hl(0, "HalloweenBorder", { fg = "#6902de", bg = "#000000", bold = true })
  vim.keymap.set("n", "<leader>uH", M.show, { desc = "🎃 Хэллоуин: ночная сцена (летучие мыши, призрак)" })
  vim.api.nvim_create_user_command("Halloween", M.show, { desc = "Анимация Хэллоуина" })
  vim.api.nvim_create_user_command("Boo", M.boo, { desc = "Призрак «буу» над текущим окном" })
end

return M
