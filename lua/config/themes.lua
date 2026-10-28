-- ========================================================================== --
--                 ТЕМЫ: 8 штук, выбор прямо в Neovim                         --
-- ========================================================================== --
-- Выбрать тему:   <leader>uT   или   :Theme   или   :Theme tokyonight
-- Выбор запоминается в stdpath("state")/theme.txt и применяется при старте.
--
--   new        — «Новая»: чёрный фон, палитра пользователя, синее свечение #0d00ff
--                (оверлей поверх catppuccin-mocha, см. apply_new).
--   classic    — «Старая»: прежние цвета до правок (оверлей поверх catppuccin-mocha).
--   halloween  — «Хэллоуин»: чёрный фон, тыква/неон/фиолет (оверлей поверх catppuccin).
--   tokyonight — Tokyo Night (night), folke/tokyonight.nvim      — полная схема.
--   gruvbox    — Gruvbox, ellisonleao/gruvbox.nvim               — полная схема.
--   kanagawa   — Kanagawa (wave), rebelot/kanagawa.nvim          — полная схема.
--   rosepine   — Rosé Pine (moon), rose-pine/neovim              — полная схема.
--   carbonfox  — Carbonfox, EdenEast/nightfox.nvim               — полная схема.
--
-- Полные схемы — отдельные плагины (lazy = true, priority = 1000): грузятся при
-- первом выборе через require("lazy").load. С 2026-10-28 (вечер) они живут В
-- ОРИГИНАЛЬНОМ стиле: свои цвета И свои фоны, без принудительного #000000 —
-- пользователь попросил «переделай в оригинальном стиле, можно все цвета и
-- фоны». Чёрный фон #000000 остаётся только у оверлейных тем (new/classic/
-- halloween) — это их фирменный знак.
--
-- СТАРТ БЕЗ МЕРЦАНИЯ: раньше init.lua сначала ставил страховочный colorscheme,
-- потом themes.setup() переключал на сохранённый — тема мигала на старте.
-- Теперь setup() САМ сначала пытается включить сохранённую тему (плагины тем
-- зарегистрированы lazy.setup к этому моменту, у всех priority = 1000 — схема
-- встаёт до первой отрисовки UI), и только если это не удалось — падает на
-- catppuccin-mocha / habamax. Переключение ровно одно.
local M = {}

local BASE = "catppuccin-mocha"
local BLACK = "#000000"

-- Фон редактора, дерева и всех плавающих окон у оверлейных тем.
local BG_GROUPS = {
  "Normal", "NormalFloat", "SignColumn", "MsgArea",
  "StatusLine", "StatusLineNC", "Pmenu", "NormalNC", "FloatBorder",
  -- дерево файлов (nvim-tree): без этого фон остаётся цветом схемы
  "NvimTreeNormal", "NvimTreeNormalNC", "NvimTreeEndOfBuffer",
  "NvimTreeStatusLine", "NvimTreeStatuslineNc",
}

-- «Серые» группы: у схем они серо-стальные и выглядят чужеродными пятнами
-- (скриншот пользователя: серое пятно в дереве файлов на чёрном фоне).
-- У оверлейных тем фон этих групп = фон редактора (#000000), а где нужна
-- видимость (Visual, Search, MatchParen…) — свечение темы, не серый.
local EXTRA_BG_GROUPS = {
  "NvimTreeCursorLine", "NvimTreeCursorLineNC",
  "NvimTreeWinSeparator", "NvimTreeVertSplit",
  "WinSeparator", "VertSplit", "WinBar", "WinBarNC",
  "Folded", "FoldColumn", "ColorColumn",
  "TabLine", "TabLineFill",
  "PmenuSel", "PmenuSbar", "PmenuThumb",
  "QuickFixLine", "CursorLineNr",
  "WhichKeyFloat", "WhichKeyBorder",
}

--- Фон «серых» групп = чёрный; сами группы видимость не теряют (fg остаётся).
local function black_extra()
  for _, group in ipairs(EXTRA_BG_GROUPS) do
    vim.api.nvim_set_hl(0, group, { bg = BLACK })
  end
end

-- --------------------------------------------------------------------------- --
-- Тема «new»
-- --------------------------------------------------------------------------- --
local function apply_new()
  local P = {
    black = BLACK,      -- фон (обязательно)
    violet = "#6902de", -- комментарии, номера строк, константы
    orange = "#ff9500", -- типы, параметры, активный номер строки
    green = "#2bff00",  -- переменные и поля
    red = "#ff0000",    -- ключевые слова
    yellow = "#fffb00", -- строки в кавычках
    cyan = "#00eeff",   -- функции и методы
    glow = "#0d00ff",   -- синее свечение: рамки, выделение, поиск
    text = "#e6e6e6",   -- описания в подсказках
  }

  for _, group in ipairs(BG_GROUPS) do
    vim.api.nvim_set_hl(0, group, { bg = P.black })
  end
  black_extra()

  vim.api.nvim_set_hl(0, "CursorLine", { bg = "#0a0a1a" })
  vim.api.nvim_set_hl(0, "FloatBorder", { fg = P.glow, bg = P.black })
  vim.api.nvim_set_hl(0, "WinSeparator", { fg = P.glow, bg = P.black })
  vim.api.nvim_set_hl(0, "Visual", { bg = P.glow, fg = "#ffffff" })
  vim.api.nvim_set_hl(0, "Search", { bg = P.glow, fg = "#ffffff" })
  vim.api.nvim_set_hl(0, "IncSearch", { bg = P.glow, fg = "#ffffff", bold = true })
  vim.api.nvim_set_hl(0, "MatchParen", { bg = P.glow, fg = "#ffffff", bold = true })
  vim.api.nvim_set_hl(0, "PmenuSel", { bg = P.glow, fg = "#ffffff" })
  vim.api.nvim_set_hl(0, "QuickFixLine", { bg = P.glow, fg = "#ffffff" })
  vim.api.nvim_set_hl(0, "Folded", { bg = P.black, fg = P.violet, italic = true })

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

-- --------------------------------------------------------------------------- --
-- Тема «classic» — прежние цвета (состояние до правок, коммит 338f31f)
-- --------------------------------------------------------------------------- --
local function apply_classic()
  for _, group in ipairs(BG_GROUPS) do
    vim.api.nvim_set_hl(0, group, { bg = BLACK })
  end
  black_extra()

  vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#4d4d4d", bg = BLACK })
  vim.api.nvim_set_hl(0, "Folded", { bg = BLACK, fg = "#4d4d4d", italic = true })

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

-- --------------------------------------------------------------------------- --
-- Тема «halloween» — тыква, неон и фиолетовый туман (оверлей, чёрный фон)
-- --------------------------------------------------------------------------- --
local function apply_halloween()
  local P = {
    black = BLACK,
    pumpkin = "#ff7a00", -- тыква: ключевые слова, активный номер строки
    bone = "#e8e3d5",    -- костяной текст подсказок
    purple = "#9d5cff",  -- комментарии, номера строк, константы
    deep = "#6a00b8",    -- фиолетовое свечение: рамки, выделение, поиск
    slime = "#7dff5c",   -- слизь: переменные и поля
    candy = "#ffd75c",   -- конфета: строки в кавычках
    witch = "#b36bff",   -- ведьма: функции и методы
    amber = "#ffb84d",   -- параметры, типы
    blood = "#ff3b3b",   -- ошибки/boolean
  }

  for _, group in ipairs(BG_GROUPS) do
    vim.api.nvim_set_hl(0, group, { bg = P.black })
  end
  black_extra()

  vim.api.nvim_set_hl(0, "CursorLine", { bg = "#140a00" })
  vim.api.nvim_set_hl(0, "FloatBorder", { fg = P.deep, bg = P.black })
  vim.api.nvim_set_hl(0, "WinSeparator", { fg = P.deep, bg = P.black })
  vim.api.nvim_set_hl(0, "Visual", { bg = P.deep, fg = "#ffffff" })
  vim.api.nvim_set_hl(0, "Search", { bg = P.pumpkin, fg = "#000000", bold = true })
  vim.api.nvim_set_hl(0, "IncSearch", { bg = P.pumpkin, fg = "#000000", bold = true })
  vim.api.nvim_set_hl(0, "MatchParen", { bg = P.deep, fg = "#ffffff", bold = true })
  vim.api.nvim_set_hl(0, "PmenuSel", { bg = P.deep, fg = "#ffffff" })
  vim.api.nvim_set_hl(0, "QuickFixLine", { bg = P.deep, fg = "#ffffff" })
  vim.api.nvim_set_hl(0, "Folded", { bg = P.black, fg = P.purple, italic = true })

  vim.api.nvim_set_hl(0, "CursorLineNr", { fg = P.pumpkin, bold = true })
  vim.api.nvim_set_hl(0, "LineNr", { fg = P.purple })

  vim.api.nvim_set_hl(0, "@keyword", { fg = P.pumpkin, bold = true })
  vim.api.nvim_set_hl(0, "@keyword.function", { fg = P.pumpkin, bold = true })
  vim.api.nvim_set_hl(0, "@repeat", { fg = P.pumpkin })
  vim.api.nvim_set_hl(0, "@conditional", { fg = P.pumpkin })
  vim.api.nvim_set_hl(0, "@function", { fg = P.witch, underline = true })
  vim.api.nvim_set_hl(0, "@function.call", { fg = P.witch, underline = true })
  vim.api.nvim_set_hl(0, "@function.builtin", { fg = P.witch, underline = true })
  vim.api.nvim_set_hl(0, "@method", { fg = P.witch, underline = true })
  vim.api.nvim_set_hl(0, "@variable", { fg = P.slime })
  vim.api.nvim_set_hl(0, "@variable.member", { fg = P.slime })
  vim.api.nvim_set_hl(0, "@parameter", { fg = P.amber, italic = true })
  vim.api.nvim_set_hl(0, "@variable.parameter", { fg = P.amber, italic = true })
  vim.api.nvim_set_hl(0, "@string", { fg = P.candy })
  vim.api.nvim_set_hl(0, "@string.special", { fg = P.candy })
  vim.api.nvim_set_hl(0, "@number", { fg = P.purple, bold = true })
  vim.api.nvim_set_hl(0, "@boolean", { fg = P.blood, bold = true })
  vim.api.nvim_set_hl(0, "@constant", { fg = P.purple, bold = true })
  vim.api.nvim_set_hl(0, "@type", { fg = P.amber })
  vim.api.nvim_set_hl(0, "@comment", { fg = P.purple, italic = true })

  vim.api.nvim_set_hl(0, "WhichKey", { fg = P.pumpkin, bold = true })
  vim.api.nvim_set_hl(0, "WhichKeyGroup", { fg = P.witch, bold = true })
  vim.api.nvim_set_hl(0, "WhichKeyDesc", { fg = P.bone })
  vim.api.nvim_set_hl(0, "WhichKeySeparator", { fg = P.deep })
end

M.themes = {
  new = {
    label = "🆕 Новая: чёрный фон, яркая палитра",
    base = BASE, plugin = "catppuccin", apply = apply_new,
  },
  classic = {
    label = "🕰 Старая: прежние цвета",
    base = BASE, plugin = "catppuccin", apply = apply_classic,
  },
  halloween = {
    label = "🎃 Хэллоуин: тыква, неон, фиолетовый туман",
    base = BASE, plugin = "catppuccin", apply = apply_halloween,
  },
  -- Полные схемы — ОРИГИНАЛЬНЫЙ стиль: свои палитры и свои фоны (apply = nil).
  tokyonight = {
    label = "🌃 Tokyo Night (night): оригинал, тёмно-синяя",
    base = "tokyonight-night", plugin = "tokyonight.nvim", apply = nil,
  },
  gruvbox = {
    label = "🟤 Gruvbox: оригинал, тёплая ретро",
    base = "gruvbox", plugin = "gruvbox.nvim", apply = nil,
  },
  kanagawa = {
    label = "🌊 Kanagawa (wave): оригинал, японская тушь",
    base = "kanagawa-wave", plugin = "kanagawa.nvim", apply = nil,
  },
  rosepine = {
    label = "🌙 Rosé Pine (moon): оригинал, мягкая роза",
    base = "rose-pine-moon", plugin = "rose-pine", apply = nil,
  },
  carbonfox = {
    label = "🟦 Carbonfox: оригинал, графит и неон",
    base = "carbonfox", plugin = "nightfox.nvim", apply = nil,
  },
}
M.order = { "new", "classic", "halloween", "tokyonight", "gruvbox", "kanagawa", "rosepine", "carbonfox" }
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
  if t and t.apply then
    t.apply()
  end
end

--- Загрузить плагин темы (если это полная схема) и включить базовую схему.
local function activate(name)
  local t = M.themes[name]
  if not t then
    return false, "нет темы " .. tostring(name)
  end
  if t.plugin then
    local ok_lazy, lazy = pcall(require, "lazy")
    if ok_lazy then
      local ok, err = pcall(lazy.load, { plugins = { t.plugin } })
      if not ok then
        return false, err
      end
    end
  end
  return pcall(vim.cmd.colorscheme, t.base)
end

--- Выбрать тему по имени: сохраняет выбор и включает схему.
--- opts.silent — без уведомления (используется на старте).
function M.set(name, opts)
  opts = opts or {}
  if not M.themes[name] then
    vim.notify("Нет темы «" .. tostring(name) .. "». Есть: " .. table.concat(M.order, ", "), vim.log.levels.WARN)
    return
  end
  M.current = name
  save(name)
  local ok, err = activate(name)
  if not ok then
    vim.notify("Тема «" .. name .. "» не загрузилась: " .. tostring(err) .. "\nЗапусти :Lazy sync", vim.log.levels.ERROR)
    return
  end
  M.apply(name) -- на случай, если ColorScheme уже не сработал
  if not opts.silent then
    vim.notify("Тема: " .. M.themes[name].label, vim.log.levels.INFO)
  end
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

-- --------------------------------------------------------------------------- --
-- СТАРТ: одно переключение, без мерцания дефолтной темы.
-- --------------------------------------------------------------------------- --
function M.setup()
  load_saved()

  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
      M.apply(M.current)
    end,
  })

  -- 1) Пытаемся включить СОХРАНЁННУЮ тему сразу: плагины тем уже
  --    зарегистрированы lazy.setup (вызван до нас в init.lua), у всех
  --    priority = 1000 — схема встаёт до первой отрисовки UI.
  -- 2) Не удалось (плагин не скачан, схема упала) — страховка catppuccin/habamax.
  -- Переключение ровно одно, поэтому дефолтная тема не мелькает.
  local started = false
  if M.current ~= M.default then
    started = activate(M.current)
  end
  if not started then
    -- сохранённая схема не встала (плагин не скачан и т.п.) — страховка
    if not pcall(vim.cmd.colorscheme, BASE) then
      pcall(vim.cmd.colorscheme, "habamax")
    end
    M.current = M.default
  end
  M.apply(M.current) -- оверлей поверх включённой схемы

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
    desc = "Выбрать тему: " .. table.concat(M.order, " | ") .. " (без аргумента — меню)",
  })

  vim.keymap.set("n", "<leader>uT", M.pick, { desc = "🎨 Выбрать тему (8 штук)" })
end

return M
