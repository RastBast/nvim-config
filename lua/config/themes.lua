-- ========================================================================== --
--                 ТЕМЫ: выбор прямо в Neovim (две темы)                      --
-- ========================================================================== --
-- Выбрать тему:   <leader>uT   или   :Theme   или   :Theme new | :Theme classic
-- Выбор запоминается в stdpath("state")/theme.txt и применяется при старте.
--
--   new     — «Новая»: чёрный фон, палитра пользователя, синее свечение #0d00ff,
--             жёлтые строки, зелёные переменные, красные ключевые слова.
--   classic — «Старая»: тот же catppuccin-mocha с прежними цветами (фон #000000,
--             неоново-зелёный номер строки, фиолетовые функции). Это состояние
--             до правок цветов (коммит 338f31f).
--
-- Обе темы строятся на catppuccin-mocha. Отличаются только подсветка
-- (apply-функции ниже), поэтому переключение мгновенное.
local M = {}

local BASE = "catppuccin-mocha"

-- ---------------------------------------------------------------------------
-- Тема «new»
-- ---------------------------------------------------------------------------
local function apply_new()
  local P = {
    black = "#000000",  -- фон (обязательно)
    violet = "#6902de", -- комментарии, номера строк, константы
    orange = "#ff9500", -- типы, параметры, активный номер строки
    green = "#2bff00",  -- переменные и поля
    red = "#ff0000",    -- ключевые слова
    yellow = "#fffb00", -- строки в кавычках
    cyan = "#00eeff",   -- функции и методы
    glow = "#0d00ff",   -- синее свечение: рамки, выделение, поиск
    text = "#e6e6e6",   -- описания в подсказках
  }

  for _, group in ipairs({
    "Normal", "NormalFloat", "SignColumn", "MsgArea",
    "StatusLine", "StatusLineNC", "Pmenu", "NormalNC",
  }) do
    vim.api.nvim_set_hl(0, group, { bg = P.black })
  end

  vim.api.nvim_set_hl(0, "CursorLine", { bg = "#0a0a1a" })
  vim.api.nvim_set_hl(0, "FloatBorder", { fg = P.glow, bg = P.black })
  vim.api.nvim_set_hl(0, "WinSeparator", { fg = P.glow })
  vim.api.nvim_set_hl(0, "Visual", { bg = P.glow, fg = "#ffffff" })
  vim.api.nvim_set_hl(0, "Search", { bg = P.glow, fg = "#ffffff" })
  vim.api.nvim_set_hl(0, "IncSearch", { bg = P.glow, fg = "#ffffff", bold = true })

  vim.api.nvim_set_hl(0, "CursorLineNr", { fg = P.orange, bold = true })
  vim.api.nvim_set_hl(0, "LineNr", { fg = P.violet })

  vim.api.nvim_set_hl(0, "@keyword", { fg = P.red, bold = true })
  vim.api.nvim_set_hl(0, "@keyword.function", { fg = P.red, bold = true })
  vim.api.nvim_set_hl(0, "@repeat", { fg = P.red })
  vim.api.nvim_set_hl(0, "@conditional", { fg = P.red })
  vim.api.nvim_set_hl(0, "@function", { fg = P.cyan, underline = true })
  vim.api.nvim_set_hl(0, "@function.call", { fg = P.cyan, underline = true })
  vim.api.nvim_set_hl(0, "@function.builtin", { fg = P.cyan, underline = true })
  vim.api.nvim_set_hl(0, "@method", { fg = P.cyan, underline = true })
  vim.api.nvim_set_hl(0, "@variable", { fg = P.green })
  vim.api.nvim_set_hl(0, "@variable.member", { fg = P.green })
  vim.api.nvim_set_hl(0, "@parameter", { fg = P.orange, italic = true })
  vim.api.nvim_set_hl(0, "@variable.parameter", { fg = P.orange, italic = true })
  vim.api.nvim_set_hl(0, "@string", { fg = P.yellow })
  vim.api.nvim_set_hl(0, "@string.special", { fg = P.yellow })
  vim.api.nvim_set_hl(0, "@number", { fg = P.violet, bold = true })
  vim.api.nvim_set_hl(0, "@boolean", { fg = P.violet, bold = true })
  vim.api.nvim_set_hl(0, "@constant", { fg = P.violet, bold = true })
  vim.api.nvim_set_hl(0, "@type", { fg = P.orange })

  vim.api.nvim_set_hl(0, "WhichKey", { fg = P.red, bold = true })
  vim.api.nvim_set_hl(0, "WhichKeyGroup", { fg = P.cyan, bold = true })
  vim.api.nvim_set_hl(0, "WhichKeyDesc", { fg = P.text })
  vim.api.nvim_set_hl(0, "WhichKeySeparator", { fg = P.glow })
end

-- ---------------------------------------------------------------------------
-- Тема «classic» — прежние цвета (состояние до правок, коммит 338f31f)
-- ---------------------------------------------------------------------------
local function apply_classic()
  for _, group in ipairs({
    "Normal", "NormalFloat", "SignColumn", "MsgArea",
    "StatusLine", "StatusLineNC", "Pmenu", "NormalNC", "FloatBorder",
  }) do
    vim.api.nvim_set_hl(0, group, { bg = "#000000" })
  end

  -- catppuccin custom_highlights (как были)
  vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#00ff00", bold = true })
  vim.api.nvim_set_hl(0, "CursorLine", { bg = "#0d0d0d" })
  vim.api.nvim_set_hl(0, "LineNr", { fg = "#4d4d4d" })

  -- Go: ключевые слова голубые
  vim.api.nvim_set_hl(0, "@keyword", { fg = "#82aaff", bold = true })
  vim.api.nvim_set_hl(0, "@keyword.function", { fg = "#82aaff", bold = true })
  vim.api.nvim_set_hl(0, "@repeat", { fg = "#82aaff" })
  vim.api.nvim_set_hl(0, "@conditional", { fg = "#82aaff" })

  -- Функции фиолетовые с подчёркиванием
  vim.api.nvim_set_hl(0, "@function", { fg = "#c792ea", underline = true })
  vim.api.nvim_set_hl(0, "@function.call", { fg = "#c792ea", underline = true })
  vim.api.nvim_set_hl(0, "@function.builtin", { fg = "#c792ea", underline = true })
  vim.api.nvim_set_hl(0, "@method", { fg = "#c792ea", underline = true })

  -- Переменные лаймовые
  vim.api.nvim_set_hl(0, "@variable", { fg = "#c3e88d" })
  vim.api.nvim_set_hl(0, "@variable.member", { fg = "#c3e88d" })
  vim.api.nvim_set_hl(0, "@parameter", { fg = "#c3e88d", italic = true })
end

M.themes = {
  new = { label = "🆕 Новая: чёрный фон, яркая палитра", apply = apply_new },
  classic = { label = "🕰 Старая: прежние цвета", apply = apply_classic },
}
M.order = { "new", "classic" }
M.default = "new"
M.current = M.default

local function state_file()
  return vim.fn.stdpath("state") .. "/theme.txt"
end

local function load_saved()
  local f = io.open(state_file(), "r")
  if not f then
    return
  end
  local name = vim.trim(f:read("*l") or "")
  f:close()
  if M.themes[name] then
    M.current = name
  end
end

local function save(name)
  local f = io.open(state_file(), "w")
  if f then
    f:write(name, "\n")
    f:close()
  end
end

--- Применить подсветку текущей темы (вызывается на событие ColorScheme).
function M.apply(name)
  local t = M.themes[name or M.current]
  if t then
    t.apply()
  end
end

--- Выбрать тему по имени: сохраняет выбор и включает базовую схему.
function M.set(name)
  if not M.themes[name] then
    vim.notify("Нет темы «" .. tostring(name) .. "». Есть: " .. table.concat(M.order, ", "), vim.log.levels.WARN)
    return
  end
  M.current = name
  save(name)
  pcall(vim.cmd.colorscheme, BASE)
  M.apply(name) -- на случай, если ColorScheme уже не сработал
  vim.notify("Тема: " .. M.themes[name].label, vim.log.levels.INFO)
end

--- Меню выбора (vim.ui.select — у нас это snacks.picker).
function M.pick()
  local items = {}
  for _, name in ipairs(M.order) do
    items[#items + 1] = name
  end
  vim.ui.select(items, {
    prompt = "🎨 Тема",
    format_item = function(name)
      local mark = (name == M.current) and "● " or "  "
      return mark .. M.themes[name].label
    end,
  }, function(choice)
    if choice then
      M.set(choice)
    end
  end)
end

function M.setup()
  load_saved()

  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
      M.apply(M.current)
    end,
  })

  vim.api.nvim_create_user_command("Theme", function(opts)
    if opts.args == "" then
      M.pick()
    else
      M.set(opts.args)
    end
  end, {
    nargs = "?",
    complete = function()
      return M.order
    end,
    desc = "Выбрать тему: new | classic (без аргумента — меню)",
  })

  vim.keymap.set("n", "<leader>uT", M.pick, { desc = "🎨 Выбрать тему (новая / старая)" })
end

return M
