-- ========================================================================== --
--   macOS: ЭКРАННАЯ КЛАВИАТУРА + ПОДСКАЗКА СОЧЕТАНИЙ (работает во ВСЕЙ системе)  --
-- ========================================================================== --
-- Что показывает:
--   * плашка сверху: последнее сочетание, например «⌘⇧P»;
--   * ANSI-клавиатура внизу экрана: нажатые клавиши подсвечиваются.
-- Включить/выключить: ⌃⌥⌘K.   Нужен Hammerspoon + разрешение Accessibility.
-- Установка и подключение — см. macos/README.md.
-- Окна/оверлей не зависят от Neovim: это отдельный слой поверх всех приложений.

local UNIT, GAP, PAD = 42, 4, 12          -- размер клавиши, зазор, отступ
local PILL_H = 40                          -- высота верхней плашки

-- Коды клавиш macOS (kVK_*) → подпись на клавише
-- Ряды: { подпись, код, ширина в единицах }
local ROWS = {
  { { "esc", 53, 1.5 }, { "1", 18 }, { "2", 19 }, { "3", 20 }, { "4", 21 }, { "5", 23 },
    { "6", 22 }, { "7", 26 }, { "8", 28 }, { "9", 25 }, { "0", 29 }, { "-", 27 }, { "=", 24 },
    { "⌫", 51, 2 } },
  { { "⇥", 48, 1.5 }, { "Q", 12 }, { "W", 13 }, { "E", 14 }, { "R", 15 }, { "T", 17 },
    { "Y", 16 }, { "U", 32 }, { "I", 34 }, { "O", 31 }, { "P", 35 }, { "[", 33 }, { "]", 30 },
    { "\\", 42, 1.5 } },
  { { "⇪", 57, 1.75 }, { "A", 0 }, { "S", 1 }, { "D", 2 }, { "F", 3 }, { "G", 5 }, { "H", 4 },
    { "J", 38 }, { "K", 40 }, { "L", 37 }, { ";", 41 }, { "'", 39 }, { "⏎", 36, 2.25 } },
  { { "⇧", 56, 2.25 }, { "Z", 6 }, { "X", 7 }, { "C", 8 }, { "V", 9 }, { "B", 11 }, { "N", 45 },
    { "M", 46 }, { ",", 43 }, { ".", 47 }, { "/", 44 }, { "⇧", 60, 2.75 } },
  { { "fn", 63 }, { "⌃", 59, 1.25 }, { "⌥", 58, 1.25 }, { "⌘", 55, 1.25 }, { "space", 49, 6.25 },
    { "⌘", 54, 1.25 }, { "⌥", 61, 1.25 }, { "←", 123 }, { "↑", 126 }, { "↓", 125 }, { "→", 124 } },
}

-- Символы модификаторов для плашки (порядок как в macOS: ⌃⌥⇧⌘)
local MOD_ORDER = { { "ctrl", "⌃" }, { "alt", "⌥" }, { "shift", "⇧" }, { "cmd", "⌘" } }

-- Подписи для клавиш, которых нет на клавише, в плашке
local NAMES = { [36] = "⏎", [48] = "⇥", [49] = "Space", [51] = "⌫", [53] = "Esc", [123] = "←", [124] = "→", [125] = "↓", [126] = "↑" }
local KEYLABEL = {}
for _, row in ipairs(ROWS) do
  for _, k in ipairs(row) do
    KEYLABEL[k[2]] = k[1]
  end
end

local canvas = nil
local pillIdx = nil        -- индекс элемента-плашки на холсте
local keyEls = {}          -- код клавиши → индекс элемента-прямоугольника
local down = {}            -- код → true, пока клавиша нажата
local hideTimer = nil
local tap = nil

local function label_for(code)
  return NAMES[code] or KEYLABEL[code] or ("#" .. tostring(code))
end

local function build()
  local width, height, rowsCount = 0, 0, #ROWS
  for _, row in ipairs(ROWS) do
    local w = 0
    for _, k in ipairs(row) do
      w = w + (k[3] or 1) * UNIT + GAP
    end
    width = math.max(width, w)
  end
  width = width + PAD * 2
  height = PILL_H + PAD + rowsCount * (UNIT + GAP) + PAD

  local scr = hs.screen.mainScreen():frame()
  local x = scr.x + (scr.w - width) / 2
  local y = scr.y + scr.h - height - 60

  canvas = hs.canvas.new({ x = x, y = y, w = width, h = height })
  canvas:level(hs.canvas.windowLevels.overlay)
  canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
  canvas:clickActivating(false)

  -- фон
  canvas:appendElements({
    type = "rectangle", action = "fill", fillColor = { white = 0, alpha = 0.72 },
    roundedRectRadii = { xRadius = 12, yRadius = 12 }, frame = { x = 0, y = 0, w = width, h = height },
  })
  -- плашка сочетания
  canvas:appendElements({
    type = "text", text = "", textColor = { white = 1 }, textSize = 22,
    textAlignment = "center", frame = { x = 0, y = 6, w = width, h = PILL_H },
  })
  pillIdx = canvas:elementCount()

  local yRow = PILL_H + PAD
  for _, row in ipairs(ROWS) do
    local x0 = PAD
    for _, k in ipairs(row) do
      local w = (k[3] or 1) * UNIT
      local idx = canvas:elementCount() + 1
      canvas:appendElements({
        type = "rectangle", action = "fill", fillColor = { white = 0.25, alpha = 0.9 },
        roundedRectRadii = { xRadius = 6, yRadius = 6 },
        frame = { x = x0, y = yRow, w = w, h = UNIT },
      })
      keyEls[k[2]] = idx
      canvas:appendElements({
        type = "text", text = k[1], textColor = { white = 1 }, textSize = 12,
        textAlignment = "center", frame = { x = x0, y = yRow + 12, w = w, h = UNIT },
      })
      x0 = x0 + w + GAP
    end
    yRow = yRow + UNIT + GAP
  end
end

local function paint_keys()
  for code, idx in pairs(keyEls) do
    local on = down[code]
    canvas:elementAttribute(idx, "fillColor", on and { red = 0.35, green = 0.75, blue = 1, alpha = 1 } or { white = 0.25, alpha = 0.9 })
  end
end

local function show_pill(text)
  if canvas then
    canvas:elementAttribute(pillIdx, "text", text)
  end
  if hideTimer then
    hideTimer:stop()
  end
  hideTimer = hs.timer.doAfter(1.8, function()
    if canvas then
      canvas:elementAttribute(pillIdx, "text", "")
    end
  end)
end

local function combo_text(flags, code)
  local s = ""
  for _, m in ipairs(MOD_ORDER) do
    if flags[m[1]] then
      s = s .. m[2]
    end
  end
  -- Сами клавиши-модификаторы в плашке не дублируем: видно уже ⌃⌥⇧⌘
  local MODIFIER_CODES = { [55] = true, [54] = true, [56] = true, [60] = true, [58] = true, [61] = true, [59] = true, [62] = true, [63] = true, [57] = true }
  if MODIFIER_CODES[code] then
    return s
  end
  return s .. label_for(code)
end

local function toggle()
  if canvas and canvas:isShowing() then
    canvas:hide()
    if tap then
      tap:stop()
    end
    return
  end
  if not canvas then
    build()
  end
  canvas:show()
  if not tap then
    tap = hs.eventtap.new({
      hs.eventtap.event.types.keyDown,
      hs.eventtap.event.types.keyUp,
      hs.eventtap.event.types.flagsChanged,
    }, function(e)
      local code = e:getKeyCode()
      local t = e:getType()
      local flags = e:getFlags()
      if t == hs.eventtap.event.types.keyDown then
        down[code] = true
        show_pill(combo_text(flags, code))
      elseif t == hs.eventtap.event.types.keyUp then
        down[code] = nil
      else -- flagsChanged: модификатор нажат или отпущен
        local active = flags.cmd or flags.alt or flags.ctrl or flags.shift or flags.fn
        down[code] = active and true or nil
        if active then
          show_pill(combo_text(flags, code))
        end
      end
      paint_keys()
      return false -- не перехватываем событие: клавиши работают как обычно
    end)
  end
  tap:start()
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "K", toggle)
hs.alert.show("Клавиатура-оверлей: ⌃⌥⌘K", 1.2)
