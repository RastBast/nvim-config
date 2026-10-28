-- ========================================================================== --
--                 ПОКАЗ НАЖАТИЙ В NEOVIM (строка внизу экрана)               --
-- ========================================================================== --
-- Включить / выключить: <leader>kk или :KeyShow
-- Пока включено, последние нажатые клавиши всплывают строкой по центру снизу
-- и гаснут через ~1.5 с. Считаются только набранные вручную клавиши (то, что
-- пришло из клавиатуры, а не из макросов и маппингов), поэтому подсказка
-- показывает именно то, что ты нажал.
-- Системный показ (вне Neovim, на весь macOS) — отдельно, через Hammerspoon.
local M = {}

local TTL = 1500 -- мс: сколько клавиша остаётся на экране
local MAX = 10 -- сколько клавиш показываем разом
local NS = vim.api.nvim_create_namespace("config_keyshow")

local enabled = false
local items = {} -- { raw = "<typed>", t = ms }
local buf, win, timer

local function now()
  return vim.uv.now()
end

local function close_win()
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
  win = nil
end

local function ensure_buf()
  if buf and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  return buf
end

local function render()
  local t = now()
  local fresh = {}
  for _, it in ipairs(items) do
    if t - it.t < TTL then
      fresh[#fresh + 1] = it
    end
  end
  while #fresh > MAX do
    table.remove(fresh, 1)
  end
  items = fresh

  if #items == 0 then
    close_win()
    return
  end

  local parts = {}
  for _, it in ipairs(items) do
    parts[#parts + 1] = vim.fn.keytrans(it.raw)
  end
  local text = " " .. table.concat(parts, "  ") .. " "
  local width = math.min(vim.fn.strdisplaywidth(text), vim.o.columns - 4)
  local b = ensure_buf()
  vim.bo[b].modifiable = true
  vim.api.nvim_buf_set_lines(b, 0, -1, false, { text })
  vim.bo[b].modifiable = false

  local cfg = {
    relative = "editor",
    row = math.max(0, vim.o.lines - 6),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    width = width,
    height = 1,
    style = "minimal",
    border = "rounded",
    focusable = false,
    noautocmd = true,
    zindex = 250,
  }
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_config(win, cfg)
  else
    win = vim.api.nvim_open_win(b, false, cfg)
    vim.wo[win].winhighlight = "Normal:Pmenu,FloatBorder:Pmenu"
  end
end

local function restart_timer()
  if not timer then
    timer = vim.uv.new_timer()
  end
  timer:stop()
  -- Перерисовка после того, как самая свежая клавиша погаснет
  timer:start(TTL + 50, 0, vim.schedule_wrap(render))
end

local function on_key(_, typed)
  -- Только то, что реально набрано руками (не макросы и не маппинги)
  if typed == nil or typed == "" then
    return
  end
  items[#items + 1] = { raw = typed, t = now() }
  -- vim.on_key вызывается в «заблокированном» контексте: рисуем отложенно
  vim.schedule(function()
    if enabled then
      render()
      restart_timer()
    end
  end)
end

function M.enable()
  if enabled then
    return
  end
  enabled = true
  vim.on_key(on_key, NS)
end

function M.disable()
  enabled = false
  vim.on_key(nil, NS)
  items = {}
  if timer then
    timer:stop()
  end
  close_win()
end

function M.toggle()
  if enabled then
    M.disable()
    vim.notify("Показ нажатий: выключен", vim.log.levels.INFO)
  else
    M.enable()
    vim.notify("Показ нажатий: включён (<leader>kk — выключить)", vim.log.levels.INFO)
  end
end

function M.setup()
  vim.keymap.set("n", "<leader>kk", M.toggle, { desc = "⌨️ Показ нажатий: вкл/выкл" })
  vim.api.nvim_create_user_command("KeyShow", M.toggle, { desc = "Показ нажатий в Neovim" })
end

return M
