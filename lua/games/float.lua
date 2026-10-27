-- Общий каркас для игр: плавающее окно с чёрным фоном и синей рамкой (#0d00ff),
-- подсветка через extmarks, локальные клавиши и таймеры, которые гасятся при закрытии.
local M = {}

M.ns = vim.api.nvim_create_namespace("games_float")

-- Палитра пользователя (см. themes.lua): фиолетовый, оранжевый, зелёный, красный, жёлтый, голубой.
local PAL = {
  purple = "#6902de",
  orange = "#ff9500",
  green = "#2bff00",
  red = "#ff0000",
  yellow = "#fffb00",
  cyan = "#00eeff",
  glow = "#0d00ff",
  black = "#000000",
  white = "#ffffff",
}
M.PAL = PAL

function M.setup_highlights()
  local set = vim.api.nvim_set_hl
  set(0, "GamesNormal", { fg = PAL.white, bg = PAL.black })
  set(0, "GamesBorder", { fg = PAL.glow, bg = PAL.black, bold = true })
  set(0, "GamesTitle", { fg = PAL.cyan, bg = PAL.black, bold = true })
  set(0, "GamesDim", { fg = "#6b6b6b", bg = PAL.black })
  set(0, "GamesHelp", { fg = PAL.orange, bg = PAL.black })
  set(0, "GamesOk", { fg = PAL.green, bg = PAL.black, bold = true })
  set(0, "GamesWarn", { fg = PAL.yellow, bg = PAL.black, bold = true })
  set(0, "GamesBad", { fg = PAL.red, bg = PAL.black, bold = true })
  set(0, "GamesCursor", { fg = PAL.white, bg = PAL.purple, bold = true })
  set(0, "GamesSel", { fg = PAL.black, bg = PAL.orange, bold = true })
  set(0, "GamesTarget", { fg = PAL.black, bg = PAL.green })
  set(0, "GamesLast", { fg = PAL.black, bg = PAL.cyan })
  set(0, "GamesCheck", { fg = PAL.white, bg = PAL.red, bold = true })
  set(0, "GamesSquareLight", { fg = PAL.white, bg = "#2a1450" })
  set(0, "GamesSquareDark", { fg = PAL.white, bg = PAL.black })
  set(0, "GamesWhitePiece", { fg = PAL.yellow, bg = "#2a1450", bold = true })
  set(0, "GamesBlackPiece", { fg = PAL.cyan, bg = "#2a1450", bold = true })
  -- тетрамино (тетрис): 7 цветов из палитры
  local tet = { PAL.cyan, PAL.yellow, PAL.purple, PAL.green, PAL.red, PAL.orange, PAL.white }
  for i, c in ipairs(tet) do
    set(0, "GamesT" .. i, { fg = c, bg = PAL.black, bold = true })
  end
end

-- Открыть окно по центру. opts: width, height, title, footer
function M.open(opts)
  M.setup_highlights()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  local cols, rows = vim.o.columns, vim.o.lines
  local width = math.min(opts.width, cols - 4)
  local height = math.min(opts.height, rows - 4)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((rows - height) / 2),
    col = math.floor((cols - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " " .. (opts.title or "Игра") .. " ",
    title_pos = "center",
    footer = opts.footer and (" " .. opts.footer .. " ") or nil,
    footer_pos = "center",
  })
  vim.wo[win].winhighlight = "Normal:GamesNormal,FloatBorder:GamesBorder,FloatTitle:GamesTitle,FloatFooter:GamesTitle"
  vim.wo[win].cursorline = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = false
  vim.wo[win].list = false
  local h = { buf = buf, win = win, timers = {}, closed = false }
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      M.stop_timers(h)
      h.closed = true
      if opts.on_close then
        opts.on_close()
      end
    end,
  })
  return h
end

function M.valid(h)
  return h and not h.closed and vim.api.nvim_win_is_valid(h.win) and vim.api.nvim_buf_is_valid(h.buf)
end

function M.close(h)
  if M.valid(h) then
    vim.api.nvim_win_close(h.win, true)
  end
end

-- lines: список строк; hls: { {row, col_start, col_end, group}, ... } (0-based, байты)
function M.render(h, lines, hls)
  if not M.valid(h) then
    return
  end
  vim.bo[h.buf].modifiable = true
  vim.api.nvim_buf_set_lines(h.buf, 0, -1, false, lines)
  vim.bo[h.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(h.buf, M.ns, 0, -1)
  for _, hl in ipairs(hls or {}) do
    local row, cs, ce, group = hl[1], hl[2], hl[3], hl[4]
    pcall(vim.api.nvim_buf_set_extmark, h.buf, M.ns, row, cs, {
      end_col = ce,
      hl_group = group,
      priority = hl[5] or 100,
    })
  end
end

-- Локальная клавиша в окне игры.
function M.map(h, lhs, fn, desc)
  if not M.valid(h) then
    return
  end
  local keys = type(lhs) == "table" and lhs or { lhs }
  for _, k in ipairs(keys) do
    vim.keymap.set("n", k, fn, { buffer = h.buf, nowait = true, silent = true, desc = desc })
  end
end

-- Повторяющийся таймер, гаснет при закрытии окна.
function M.every(h, ms, fn)
  local t = vim.uv.new_timer()
  table.insert(h.timers, t)
  t:start(ms, ms, vim.schedule_wrap(function()
    if not M.valid(h) then
      M.stop_timers(h)
      return
    end
    fn()
  end))
  return t
end

function M.stop_timers(h)
  for _, t in ipairs(h.timers or {}) do
    if not t:is_closing() then
      t:stop()
      t:close()
    end
  end
  h.timers = {}
end

return M
