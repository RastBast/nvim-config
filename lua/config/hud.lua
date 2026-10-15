-- ========================================================================== --
--         HUD: ВРЕМЯ (МСК) · ЗАРЯД · IP · ОГОНЁК — В ПРАВОМ ВЕРХНЕМ УГЛУ
-- ========================================================================== --
-- Одна строка в нефокусируемом float-окне в углу редактора.
-- Почему float, а не virtual text: virtual text на первой строке сдвигал код и
-- прыгал вместе с скроллом; статус-лайн — внизу (и он тут глобальный,
-- laststatus=3), а просили именно правый верхний угол.
--
-- ВРЕМЯ: сдвиг добавляем сами и делим сами —
--     daysecs = (os.time() + tz_offset) % 86400;  hh = daysecs / 3600
-- ни os.date, ни локали машины. os.date("!%H:%M") tempted тем, что «!» понимают
-- не все рантаймы (некоторые возвращают «!» литералом), а os.date без «!»
-- считает по поясу системы: на ноуте с TZ=Europe/Helsinki показывалось бы
-- хельсинкское время под подписью «МСК». 12-часовой формат: hh % 12, ноль -> 12,
-- PM после полудня — то есть полночь это 12:00 AM, а не 0:00.
--
-- ЗАРЯД: macOS — `pmset -g batt` (он же сообщает AC Power, поэтому ⚡ честная:
-- 95% на зарядке и 95% без розетки — разные истории). Linux —
-- /sys/class/power_supply/BAT*/capacity. На десктопе без батареи сегмент
-- исчезает, а не врёт «0%».
--
-- IP: локальный — из `route`/`ipconfig` (macOS) или `ip` (Linux), без сети;
-- публичный — curl раз в 10 минут. Не чаще: это и трафик, и лишний прокси-
-- запрос (см. PROXY.md), а висящий curl под VPN блокирует вывод. При таймауте
-- оставляем последний известный и помечаем «~».
--
-- Огонёк (🔥N) берётся из config.streak — тот пересчитывается сам и дёргает
-- hud.refresh().

local H = {}
local uv = vim.uv or vim.loop

H.defaults = {
  enabled = true,
  segments = { time = true, battery = true, ip = true, flames = true },
  ip_mode = "both",        -- lan | public | both | off
  clock = 12,              -- 12 | 24
  tz_offset = 3 * 3600,    -- МСК = UTC+3 (переводов времени нет с 2014)
  tz_label = "МСК",
  time_every = 15000,      -- мс
  battery_every = 60000,
  ip_every = 600000,
  public_url = "https://api.ipify.org",
  public_timeout = 4,
  low_at = 20,             -- ниже этого заряд краснеет
  margin = 0,
  zindex = 60,
  avoid_overlap = true,    -- не залезать на чужой float (tele, telescope, which-key)
  sep = "   ",
  icons = {
    time = "🕐", battery = "🔋", charging = "⚡", low = "🪫",
    lan = "🏠", ip = "🌐", flames = "🔥",
  },
}

-- Опции готовы СРАЗУ (до setup): на них опираются функции, которые могут
-- прилететь из autocmd раньше, чем дойдёт очередь до require().setup().
H.opts = vim.tbl_deep_extend("force", {}, H.defaults)

H.state = {
  buf = nil, win = nil, width = 0,
  battery = nil, charging = false, ac = false,
  lan = nil, public = nil, public_stale = false,
  timers = {}, started = false, last_err = nil, renders = 0,
}

-- ========================================================================== --
--                            ЗАПУСК ВНЕШНИХ КОМАНД
-- ========================================================================== --

---@param cmd string[]
---@param cb fun(out: string, err: string|nil)
local function run(cmd, cb)
  if vim.system then
    local ok = pcall(vim.system, cmd, { text = true }, function(res)
      vim.schedule(function()
        if (res.code or 1) ~= 0 then
          cb("", "код " .. tostring(res.code) .. " " .. vim.trim(res.stderr or ""))
        else
          cb(res.stdout or "", nil)
        end
      end)
    end)
    if ok then return end
  end
  local quoted = {}
  for _, part in ipairs(cmd) do quoted[#quoted + 1] = vim.fn.shellescape(part) end
  cb(vim.fn.system(table.concat(quoted, " ")), nil)
end

H.run = run -- наружу для :HudNow/тестов

-- ========================================================================== --
--                                 СЕГМЕНТЫ
-- ========================================================================== --

---@param ts number|nil
---@return string "2:15 PM" | "14:15"
function H.time_str(ts)
  local t = (ts or os.time()) + (H.opts.tz_offset or 0)
  -- Арифметика вместо os.date("!%H:%M"): «!» понимают не все рантаймы (fengari
  -- возвращает «!» литералом), а os.date БЕЗ «!» считает по локали машины —
  -- тогда «время в МСК» на ноутбуке в Суоми показывало бы хельсинкское.
  local daysecs = t % 86400
  if daysecs < 0 then daysecs = daysecs + 86400 end
  local hh = math.floor(daysecs / 3600)
  local mm = math.floor((daysecs % 3600) / 60)
  if H.opts.clock == 12 then
    local ap = hh >= 12 and "PM" or "AM"
    hh = hh % 12
    if hh == 0 then hh = 12 end
    -- %02d для минут обязателен: hh/mm теперь числа, а не строки из os.date,
    -- и «%s» дало бы «7:5 PM» вместо «7:05 PM»
    return ("%d:%02d %s"):format(hh, mm, ap)
  end
  return ("%02d:%02d"):format(hh, mm)
end

--- Парсинг вывода `pmset -g batt`:
---   Now drawing from 'AC Power'
---    -InternalBattery-0 (id=6684827)   82%, charging; 1:20 remaining  present: true
--- «charged» (заряжено) — это НЕ «charging»: на розетке и полный заряд.
---@return number|nil percent, boolean charging, boolean on_ac
function H.parse_pmset(out)
  if not out or out == "" then return nil, false, false end
  local pct = tonumber(out:match("(%d+)%%") or "")
  -- Состояние берём СЛОВОМ целиком: «charging» подстрокой встречается и внутри
  -- «discharging», и внутри «Not charging» — иначе разряжающийся ноутбук
  -- гордо показывал бы молнию.
  local state = out:match("(%a+)%s*;")
  local charging = state == "charging"
  local ac = out:find("AC Power") ~= nil
  return pct, charging, ac
end

--- Linux-путь: sysfs. Возвращает то же, что parse_pmset.
function H.read_sysfs_battery()
  for _, name in ipairs({ "BAT0", "BAT1", "BAT" }) do
    local dir = "/sys/class/power_supply/" .. name
    local f = io.open(dir .. "/capacity", "r")
    if f then
      local n = tonumber(vim.trim(f:read("*a") or ""))
      f:close()
      local status = ""
      local sf = io.open(dir .. "/status", "r")
      if sf then status = vim.trim(sf:read("*a") or "") sf:close() end
      local low = status:lower()
      -- «Not charging» (втыкнули, но батарея полна) — это НЕ зарядка
      return n, low == "charging", (low == "full" or low == "charging")
    end
  end
  return nil, false, false
end

--- Обновить заряд. На macOS асинхронно (pmset ~10 мс, но не в момент нажатия
--- клавиши), на Linux — sysfs читается быстрее, чем спавнится процесс.
function H.read_battery()
  if vim.fn.has("macunix") == 1 then
    run({ "pmset", "-g", "batt" }, function(out, err)
      if err then
        H.state.last_err = "pmset: " .. err
        return
      end
      local pct, charging, ac = H.parse_pmset(out)
      H.state.battery, H.state.charging, H.state.ac = pct, charging, ac
      H.render()
    end)
    return
  end
  local pct, charging, ac = H.read_sysfs_battery()
  H.state.battery, H.state.charging, H.state.ac = pct, charging, ac
end

--- Локальный адрес. en0 — только на «голом» маке; с доком/юсб-адаптером это
--- en5…en7, поэтому сначала спрашиваем, с какого интерфейса идёт дефолтный
--- маршрут, и только потом пробуем перебор.
function H.read_lan_ip()
  if vim.fn.has("macunix") == 1 then
    run({ "sh", "-c",
      'iface=$(route -n get default 2>/dev/null | awk \'/interface:/{print $2}\'); '
      .. 'for i in $iface en0 en1 en2 en3 en5 en6 en7; do '
      .. 'ip=$(ipconfig getifaddr "$i" 2>/dev/null); [ -n "$ip" ] && { echo "$ip"; exit 0; }; done; exit 1' },
      function(out, err)
        local ip = out and vim.trim(out):match("%d+%.%d+%.%d+%.%d+")
        H.state.lan = ip
        if not ip and err then H.state.last_err = "ipconfig: " .. err end
        H.render()
      end)
    return
  end
  run({ "sh", "-c", "ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1" },
    function(out, err)
      local ip = out and vim.trim(out):match("%d+%.%d+%.%d+%.%d+")
      H.state.lan = ip
      if not ip and err then H.state.last_err = "ip: " .. err end
      H.render()
    end)
end

function H.read_public_ip()
  if H.opts.ip_mode == "lan" or H.opts.ip_mode == "off" then return end
  run({ "curl", "-s", "--max-time", tostring(H.opts.public_timeout), H.opts.public_url },
    function(out, err)
      local ip = out and vim.trim(out):match("^%d+%.%d+%.%d+%.%d+$")
      if ip then
        H.state.public, H.state.public_stale = ip, false
      elseif H.state.public then
        H.state.public_stale = true -- кэш есть: показываем, но честно помечаем
      else
        H.state.last_err = "публичный IP не получен: " .. tostring(err or out)
      end
      H.render()
    end)
end

-- ========================================================================== --
--                            СБОРКА ОДНОЙ СТРОКИ
-- ========================================================================== --

---@return string|nil text, string hl
local function battery_text()
  local b = H.state.battery
  if not b then return nil, "HudBattery" end
  local icon, hl = H.opts.icons.battery, "HudBattery"
  if H.state.charging then
    icon, hl = H.opts.icons.charging, "HudBatteryOk"
  elseif b <= H.opts.low_at then
    icon, hl = H.opts.icons.low, "HudBatteryLow"
  end
  return ("%s %d%%"):format(icon, b), hl
end

--- Сегменты + их подсветки одним списком: порядок и состав меняются
--- (нет батареи — нет сегмента), поэтому hl едет рядом с текстом, а не
--- «по индексу из другой функции».
---@return string[] texts, string[] hl_groups
function H.build()
  local out, hls = {}, {}
  local function push(text, hl)
    out[#out + 1] = text
    hls[#hls + 1] = hl
  end
  if H.opts.segments.time then
    push(H.opts.icons.time .. " " .. H.time_str(), "HudTime")
  end
  if H.opts.segments.battery then
    local b, hl = battery_text()
    if b then push(b, hl) end
  end
  if H.opts.segments.ip then
    if (H.opts.ip_mode == "lan" or H.opts.ip_mode == "both") and H.state.lan then
      push(H.opts.icons.lan .. " " .. H.state.lan, "HudIp")
    end
    if (H.opts.ip_mode == "public" or H.opts.ip_mode == "both") and H.state.public then
      push(H.opts.icons.ip .. " " .. H.state.public
        .. (H.state.public_stale and "~" or ""), "HudIp")
    end
  end
  if H.opts.segments.flames then
    -- streak может быть не подключён (нет git) или не успеть посчитаться:
    -- компонент тогда пустой, и сегмента просто нет
    local ok, streak = pcall(require, "config.streak")
    local flames = ok and streak and streak.component and streak.component() or nil
    if flames and flames ~= "" then push(flames, "HudFlames") end
  end
  return out, hls
end

---@return string[]
function H.segments()
  return H.build()
end

---@param list string[]
local function join(list) return table.concat(list, H.opts.sep) end

--- Собирает строку и byte-смещения каждого сегмента. Не влезает — режем ЦЕЛЫЕ
--- сегменты слева (время и заряд жертвуют первыми), а не символы: «14:1» вместо
--- «14:15 PM» хуже, чем «🔥 12» без IP. Смещения — в БАЙТАХ (как просят
--- extmark'и), поэтому эмодзи в начале сегмента не сдвигают разметку.
---@return string text, { text: string, hl: string, from: number, to: number }[] items
function H.line()
  local parts, hls = H.build()
  while #parts > 1 and vim.fn.strdisplaywidth(join(parts)) + 2 + H.opts.margin > vim.o.columns - 2 do
    table.remove(parts, 1)
    table.remove(hls, 1)
  end
  if #parts == 0 then return "", {} end
  if vim.fn.strdisplaywidth(join(parts)) + 2 > vim.o.columns - 2 then return "", {} end
  local text = join(parts)
  local items, off = {}, 0
  for i, part in ipairs(parts) do
    items[#items + 1] = { text = part, hl = hls[i], from = off, to = off + #part }
    off = off + #part + #H.opts.sep
  end
  return text, items
end

---@return string
function H.text()
  return (H.line())
end

--- Наш текст мог измениться по ширине — пересчитать окно.
function H.render()
  H.state.renders = H.state.renders + 1
  if not H.opts.enabled then
    H.hide_window()
    return
  end
  if H.avoids() then
    H.hide_window()
    return
  end
  -- ОДИН вызов line(): text и разметка обязаны быть с одного кадра. Два
  -- раздельных вызова (text() + line()) на границе минуты давали бы строку из
  -- «4:06», а смещения — из «4:07», и подсветка уезжала бы на символ вправо.
  local text, items = H.line()
  if text == "" then return H.hide_window() end

  if not H.state.buf or not vim.api.nvim_buf_is_valid(H.state.buf) then
    H.state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[H.state.buf].bufhidden = "hide"
    vim.bo[H.state.buf].swapfile = false
    vim.bo[H.state.buf].spell = false
    vim.bo[H.state.buf].filetype = "hud"
  end
  vim.bo[H.state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(H.state.buf, 0, -1, false, { text })
  vim.bo[H.state.buf].modifiable = false
  H.paint(items)

  local width = vim.fn.strdisplaywidth(text) + 2
  width = math.min(width, math.max(8, vim.o.columns - 2))
  local col = math.max(0, vim.o.columns - width - 1 - H.opts.margin)
  local cfg = {
    relative = "editor", row = H.opts.margin, col = col,
    width = width, height = 1, focusable = false, style = "minimal",
    zindex = H.opts.zindex,
  }
  if not H.state.win or not vim.api.nvim_win_is_valid(H.state.win) then
    H.state.win = vim.api.nvim_open_win(H.state.buf, false, cfg)
  else
    pcall(vim.api.nvim_win_set_config, H.state.win, cfg)
  end
  H.state.width = width
  pcall(vim.api.nvim_set_option_value, "winhighlight", "Normal:HudNormal,NormalFloat:HudNormal",
    { win = H.state.win })
end

--- Краска по сегментам. extmark, а не vim.highlight.range: тому нужны открытый
--- буфер с окном, а наш буфер живёт в плашке, которую мы перерисовываем каждые
--- 15 секунд — range-подсветка на такой частоте только копится.
function H.paint(items)
  if not H.state.buf then return end
  pcall(vim.api.nvim_buf_clear_namespace, H.state.buf, H.ns(), 0, -1)
  for _, it in ipairs(items or {}) do
    pcall(vim.api.nvim_buf_set_extmark, H.state.buf, H.ns(), 0, it.from, {
      end_col = it.to, hl_group = it.hl, strict = false,
    })
  end
end

--- Пересекается ли наш угол с чужим float-окном? Тогда прячемся (окно tele
--- размером с треть экрана не должно терять половину строки hud-а).
function H.avoids()
  if not H.opts.avoid_overlap then return false end
  local mine = { row = H.opts.margin, col = vim.o.columns - (H.state.width or 40) - 1,
    width = (H.state.width or 40), height = 1 }
  for _, w in ipairs(vim.fn.getwininfo()) do
    if w.floater == 1 and w.winid ~= H.state.win then
      local overlap_rows = not (w.row + (w.height or 1) <= mine.row or mine.row + mine.height <= w.row)
      local overlap_cols = not (w.col + (w.width or 1) <= mine.col or mine.col + mine.width <= w.col)
      if overlap_rows and overlap_cols then return true end
    end
  end
  return false
end

function H.hide_window()
  if H.state.win and vim.api.nvim_win_is_valid(H.state.win) then
    vim.api.nvim_win_close(H.state.win, true)
  end
  H.state.win = nil
end

function H.refresh()
  H.read_battery()
  H.read_lan_ip()
  H.read_public_ip()
  H.render()
end

function H.toggle()
  H.opts.enabled = not H.opts.enabled
  H.render()
  return H.opts.enabled
end

-- ========================================================================== --
--                              ПОДСВЕТКА / ТАЙМЕРЫ
-- ========================================================================== --

H._ns = nil
function H.ns()
  if not H._ns then H._ns = vim.api.nvim_create_namespace("hud") end
  return H._ns
end

-- Отдельная группа-фон, чтобы тема (catppuccin, у которой NormalFloat перекрашен
-- в #000000 прямо в init.lua) не сделала плашку невидимой на таком же фоне.
-- Дальше — НИКАКИХ хардкодных цветов: только линки на семантические группы,
-- иначе на habamax (запасная тема в init.lua) HUD был бы в цветах mocha.
function H.highlight()
  local set = vim.api.nvim_set_hl
  set(0, "HudNormal", { link = "NormalFloat", default = true })
  set(0, "HudTime", { link = "Normal", default = true })
  set(0, "HudBattery", { link = "Normal", default = true })
  set(0, "HudBatteryOk", { link = "DiagnosticOk", default = true })
  set(0, "HudBatteryLow", { link = "DiagnosticError", default = true, bold = true })
  set(0, "HudIp", { link = "DiagnosticInfo", default = true })
  set(0, "HudFlames", { link = "DiagnosticWarn", default = true, bold = true })
end

local function every(key, ms, fn)
  local old = H.state.timers[key]
  if old then
    old:stop()
    old:close()
  end
  H.state.timers[key] = uv.new_timer()
  H.state.timers[key]:start(ms, ms, vim.schedule_wrap(fn))
end

function H.start()
  if H.state.started then return end
  H.state.started = true
  H.highlight()
  H.refresh()
  every("time", H.opts.time_every, H.render)
  every("battery", H.opts.battery_every, H.read_battery)
  every("ip", H.opts.ip_every, function()
    H.read_lan_ip()
    H.read_public_ip()
  end)

  local group = vim.api.nvim_create_augroup("Hud", { clear = true })
  vim.api.nvim_create_autocmd({ "VimResized", "WinNew", "WinClosed", "WinEnter", "TabEnter" }, {
    group = group, pattern = "*", callback = function() vim.schedule(H.render) end,
    desc = "hud: держать плашку в углу и не залезать на чужие окна",
  })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group, callback = H.highlight, desc = "hud: тон подсветки за темой",
  })
end

function H.stop()
  H.state.started = false
  for _, t in pairs(H.state.timers) do
    t:stop()
    t:close()
  end
  H.state.timers = {}
  H.hide_window()
end

function H.debug()
  local lines = {
    "🕐 HUD",
    ("   время    : %s (%s, %d-часовой)"):format(H.time_str(), H.opts.tz_label, H.opts.clock),
    ("   заряд    : %s%s"):format(H.state.battery and (H.state.battery .. "%") or "нет данных",
      H.state.charging and " (заряжается)" or (H.state.ac and " (от сети)" or "")),
    ("   ip lan   : %s"):format(H.state.lan or "—"),
    ("   ip public: %s%s"):format(H.state.public or "—", H.state.public_stale and " (устарел)" or ""),
    ("   окно     : %s · ширина %d · columns %d · перерисовок %d"):format(
      H.state.win and "есть" or "нет", H.state.width or 0, vim.o.columns, H.state.renders),
    ("   чужие float: %s"):format(H.avoids() and "перекрывают → hud скрыт" or "нет"),
    ("   строка   : [%s]"):format(H.text()),
  }
  if H.state.last_err then lines[#lines + 1] = "   ⚠ " .. H.state.last_err end
  if not pcall(require, "config.streak") then lines[#lines + 1] = "   ⚠ config.streak не загрузился" end
  vim.api.nvim_echo({ { table.concat(lines, "\n"), "Normal" } }, true, {})
end

-- ========================================================================== --
--                              КЛАВИШИ / КОМАНДЫ
-- ========================================================================== --
-- <leader>Hu* — группа «🎨 Визуал и UI» в which-key.lua; us/ur/uz/um/up/ua/ut/uP
-- там уже заняты, взяты свободные h/d/i/c.

local ip_cycle = { lan = "public", public = "both", both = "off", off = "lan" }

function H.keymaps()
  local map = vim.keymap.set
  map("n", "<leader>Huh", function()
    H.render()
    vim.api.nvim_echo({ { "🕐 hud: " .. (H.opts.enabled and "показан" or "скрыт"), "Normal" } }, false, {})
  end, { desc = "🕐 HUD: плашка в углу (вкл/выкл)" })
  map("n", "<leader>Hud", H.debug, { desc = "🕐 HUD: что он видит (диагностика)" })
  map("n", "<leader>Hui", function()
    H.opts.ip_mode = ip_cycle[H.opts.ip_mode] or "lan"
    H.read_public_ip()
    H.render()
    vim.api.nvim_echo({ { "🌐 ip: " .. H.opts.ip_mode, "Normal" } }, false, {})
  end, { desc = "🌐 HUD: какой IP (lan → public → both → off)" })
  map("n", "<leader>Huc", function()
    H.opts.clock = (H.opts.clock == 12) and 24 or 12
    H.render()
    vim.api.nvim_echo({ { ("🕐 часы %d-часовые"):format(H.opts.clock), "Normal" } }, false, {})
  end, { desc = "🕐 HUD: 12/24-часовой формат" })
  map("n", "<leader>Huk", function()
    local ok, streak = pcall(require, "config.streak")
    if ok then vim.api.nvim_echo({ { streak.report(), "Normal" } }, true, {}) end
  end, { desc = "🔥 HUD: огонёк за коммиты (:Streak)" })
end

function H.commands()
  vim.api.nvim_create_user_command("Hud", function(o)
    local a = vim.trim((o.args or ""):lower())
    if a == "off" then
      H.opts.enabled = false
    elseif a == "on" then
      H.opts.enabled = true
    elseif a == "refresh" then
      return H.refresh()
    elseif a == "debug" then
      return H.debug()
    elseif a == "" or a == "toggle" then
      return H.toggle()
    end
    H.render()
    vim.api.nvim_echo({ { "🕐 hud: " .. (H.opts.enabled and "показан" or "скрыт"), "Normal" } }, false, {})
  end, { nargs = "?", desc = "🕐 плашка в правом верхнем углу (on|off|toggle|refresh|debug)",
    complete = function() return { "on", "off", "toggle", "refresh", "debug" } end })

  vim.api.nvim_create_user_command("HudIp", function(o)
    local a = vim.trim((o.args or "both"):lower())
    if a ~= "lan" and a ~= "public" and a ~= "both" and a ~= "off" then
      return vim.api.nvim_echo({ { "HudIp lan | public | both | off", "WarningMsg" } }, false, {})
    end
    H.opts.ip_mode = a
    H.read_public_ip()
    H.render()
  end, {
    nargs = "?", desc = "🌐 какой IP показывать",
    complete = function() return { "lan", "public", "both", "off" } end,
  })

  vim.api.nvim_create_user_command("HudClock", function(o)
    local n = tonumber(o.args)
    if n ~= 12 and n ~= 24 then
      return vim.api.nvim_echo({ { ":HudClock 12 | 24", "WarningMsg" } }, false, {})
    end
    H.opts.clock = n
    H.render()
  end, { nargs = 1, desc = "🕐 12 или 24 часа" })

  vim.api.nvim_create_user_command("HudNow", H.refresh, { desc = "🕐 опросить заново, не waiting таймеры" })
  vim.api.nvim_create_user_command("HudTz", function(o)
    local n = tonumber(o.args)
    if not n then return vim.api.nvim_echo({ { ":HudTz 3   (часов от UTC)", "WarningMsg" } }, false, {}) end
    H.opts.tz_offset = n * 3600
    H.opts.tz_label = ("UTC%+d"):format(n)
    H.render()
  end, { nargs = 1, desc = "🕐 смещение часового пояса (3 = МСК)" })
end

function H.setup(user_opts)
  H.opts = vim.tbl_deep_extend("force", {}, H.defaults, user_opts or {})
  H.opts.segments = vim.tbl_deep_extend("force", {}, H.defaults.segments, (user_opts or {}).segments or {})
  H.opts.icons = vim.tbl_deep_extend("force", {}, H.defaults.icons, (user_opts or {}).icons or {})
  H.commands()
  H.keymaps()
  H.start()
end

return H
