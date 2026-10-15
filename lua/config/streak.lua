-- ========================================================================== --
--          ОГОНЁК ЗА КОММИТЫ: ДНЕВНАЯ СЕРИЯ С «СГОРАНИЕМ» В 03:00 МСК
-- ========================================================================== --
-- Правило: один коммит в день = огонёк (как стрик в TikTok). Не закоммитил
-- день — огонёк сгорает, серия обрывается. «День» заканчивается не в полуночь,
-- а в 03:00 по Москве (burn_hour), чтобы ночные коммиты в 01:40 засчитывались
-- вчерашнему дню.
--
-- МАТЕМАТИКА ДНЯ. МСК = UTC+3, поэтому «03:00 по Москве» = «00:00 UTC» ровно,
-- без переходов на летнее время (РФ отменила переводы в 2014). Отсюда:
--     id дня = floor(unix_секунд / 86400)          -- UTC-сутки
--   окно дня = [id*86400 + burn*3600 - tz,  +86400)  -- в unix-секундах
-- При tz = 3*3600 и burn = 3 смещения сокращаются, и окно = UTC-сутки. Формула
--формула общая (файл переживает смену burn_hour и tz), но именно для МСК+3 она
-- совпадает с «полночью по UTC» — это и есть то, что просил.
--
-- Почему через git, а не через API GitHub: локальный `git log` работает офлайн,
-- без токена, без лимитов и видит коммиты ДО пуша (а «сделать коммит» — это и
-- есть коммит, не push). `--branches` — чтобы коммиты в feature-ветках тоже
-- считались; `--all` тянул бы за собой stash и origin/*.
--
-- Состояние живёт в stdpath("data")/streak.json: дни, где коммит был, и дни,
-- которые сгорели. Файл нужен, чтобы серия переживала перезапуск nvim.

local S = {}
local uv = vim.uv or vim.loop

S.defaults = {
  burn_hour = 3,          -- «полночь» streak-дня, часов по МСК
  tz_offset = 3 * 3600,   -- МСК (UTC+3, переводов нет)
  goal = 1,               -- коммитов в день, чтобы огонёк зажёгся
  repos = nil,            -- nil = определить самому (см. active_repos)
  check_every = 300,      -- сек между проверками
  log_limit = 800,        -- сколько коммитов читать на репозиторий
  author_only = true,     -- считать только свои коммиты (по user.email)
  all_branches = true,    -- --branches, а не только HEAD
  notify = true,
  grid_days = 14,         -- ширина сетки дней в :Streak
}

-- Опции готовы сразу, до setup(): day_of()/report() опираются на tz_offset и
-- burn_hour, а nil в арифметике — это «attempt to perform arithmetic on nil».
S.opts = vim.tbl_deep_extend("force", {}, S.defaults)

S.state = {
  days = {},    -- [day_id] = кол-во коммитов (0 тоже пишется: «проверено, не было»)
  burned = {},  -- [day_id] = true — этот день сгорел (огонёк потерян)
  current = 0,
  best = 0,
  total = 0,
  repos = {},
  error = nil,
  timer = nil,
  burn_timer = nil,
  started = false,
  today = nil,
  today_count = 0,
  save_err = nil, -- чем закончилась последняя запись streak.json
  email = nil,
  last_day = nil,   -- последний день, о котором мы знаем (для melt_gaps)
  last_awarded = nil, -- день, за который огонёк уже засчитан (не повторять нотификейшн)
}

local function expand(p) return p and vim.fn.expand(p) or nil end

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

-- ========================================================================== --
--                              КАЛЕНДАРЬ
-- ========================================================================== --

---@return number id дня
function S.day_of(ts)
  return math.floor((ts + S.opts.tz_offset - S.opts.burn_hour * 3600) / 86400)
end

---@return number from, number to   границы дня в unix-секундах (UTC)
function S.day_window(day_id)
  local start_local = day_id * 86400 + S.opts.burn_hour * 3600
  return start_local - S.opts.tz_offset, start_local - S.opts.tz_offset + 86400
end

--- Человекочитаемая дата дня (всегда по МСК, независимо от машины).
--- День «N» от epoch -> (год, месяц, число). Свой календарь вместо
--- os.date("!%d.%m"): во-первых, «!» понимают не все рантаймы (LuaJIT — да,
--- fengari/некоторые сборки — нет и возвращают «!» литералом), во-вторых, без
--- «!» дата уехала бы на локальному поясу машины и «15 октября» стало бы
--- «14 октября» для пользователя из Хельсинки в интервале 00:00–03:00.
--- Алгоритм — civil_from_days Хиннанта, корректен для всей григорианки (1970+).
local function civil(day_number)
  local z = day_number + 719468
  local era = math.floor(z / 146097)
  local doe = z - era * 146097
  local yoe = math.floor((doe - math.floor(doe / 4) + math.floor(doe / 100) - math.floor(doe / 400)) / 365)
  local y = yoe + era * 400
  local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
  local mp = math.floor((5 * doy + 2) / 153)
  local d = doy - math.floor((153 * mp + 2) / 5) + 1
  local m = mp < 10 and mp + 3 or mp - 9
  return m <= 2 and y + 1 or y, m, d
end

local WEEK = { "четверг", "пятница", "суббота", "воскресенье", "понедельник", "вторник", "среда" }
local MONTHS = { "января", "февраля", "марта", "апреля", "мая", "июня", "июля",
  "августа", "сентября", "октября", "ноября", "декабря" }

---@param day_id number
---@return string "15.10"
function S.day_label(day_id)
  local _, m, d = civil(day_id)
  return ("%02d.%02d"):format(d, m)
end

---@param day_id number
---@return string "четверг 15 октября 2026"
function S.day_full(day_id)
  local y, m, d = civil(day_id)
  local w = (day_id + 4) % 7
  if w < 0 then w = w + 7 end
  return ("%s %d %s %d"):format(WEEK[w + 1], d, MONTHS[m], y)
end

function S.next_burn_in(now)
  now = now or os.time()
  local _, to = S.day_window(S.day_of(now))
  return math.max(1, to - now)
end

-- ========================================================================== --
--                        ХРАНИЛИЩЕ (stdpath/data/streak.json)
-- ========================================================================== --

local function store_path() return vim.fn.stdpath("data") .. "/streak.json" end

--- Пишем state-файл атомарно-ish: одна строка JSON, палл байт. Ошибку НЕ
--- глотаем молча — иначе «стрик не помнит вчерашний день» выглядит как баг
--- редактора, а на деле это право на запись в stdpath. Строчку видно в :Streak.
function S.save()
  local ok, err = pcall(function()
    local out = {
      days = {}, burned = {}, current = S.state.current, best = S.state.best,
      total = S.state.total, saved_at = os.time(),
      -- last_day = «последний день, о котором мы точно знаем»: из check(), а если
      -- nvim открыли и не успели проверить — из сохранённого ранее
      last_day = S.state.today or S.state.last_day,
    }
    for d, n in pairs(S.state.days) do out.days[tostring(d)] = n end
    for d in pairs(S.state.burned) do out.burned[tostring(d)] = true end
    vim.fn.writefile({ vim.json.encode(out) }, store_path())
  end)
  -- ВНИМАНИЕ: «ok and nil or err» — классическая ловушка Lua: при ok == true
  -- получается nil or err, то есть «nil» строкой. Только явный if.
  if ok then
    S.state.save_err = nil
  else
    S.state.save_err = tostring(err)
  end
  return ok
end

function S.load()
  local ok, raw = pcall(vim.fn.readfile, store_path())
  if not ok or not raw or not raw[1] then return end
  local ok2, parsed = pcall(vim.json.decode, raw[1])
  if not ok2 or type(parsed) ~= "table" then return end
  for d, n in pairs(parsed.days or {}) do S.state.days[tonumber(d)] = tonumber(n) or 0 end
  for d in pairs(parsed.burned or {}) do S.state.burned[tonumber(d)] = true end
  S.state.current = tonumber(parsed.current) or 0
  S.state.best = tonumber(parsed.best) or 0
  S.state.total = tonumber(parsed.total) or 0
  S.state.last_day = tonumber(parsed.last_day)
end

-- ========================================================================== --
--                            РЕПОЗИТОРИИ И КОММИТЫ
-- ========================================================================== --

--- Куда смотреть. По умолчанию: репозиторий этого конфига (его рабочий каталог)
--- и всё, что добавили через :StreakRepo.
function S.active_repos()
  if S.opts.repos and #S.opts.repos > 0 then
    local out = {}
    for _, r in ipairs(S.opts.repos) do out[#out + 1] = expand(r) end
    return out
  end
  local cfg = vim.fn.stdpath("config")
  local top = vim.fn.system({ "git", "-C", cfg, "rev-parse", "--show-toplevel" })
  top = vim.trim(top or "")
  if top ~= "" and vim.fn.isdirectory(top) == 1 then return { top } end
  return {}
end

--- Считать только свои коммиты: берём user.email из первого репозитория.
local function resolve_email(repos)
  for _, repo in ipairs(repos) do
    local out = vim.trim(vim.fn.system({ "git", "-C", repo, "config", "user.email" }) or "")
    if out ~= "" then return out end
  end
  local g = vim.trim(vim.fn.system({ "git", "config", "--global", "user.email" }) or "")
  return g ~= "" and g or nil
end

--- Число коммитов в репозитории внутри [from, to).
function S.scan(repo, from, to, cb)
  local cmd = { "git", "-C", repo, "log", "--pretty=%ct", "-n", tostring(S.opts.log_limit) }
  if S.opts.all_branches then cmd[#cmd + 1] = "--branches" end
  if S.opts.author_only and S.state.email then
    cmd[#cmd + 1] = "--author=" .. S.state.email
  end
  run(cmd, function(out, err)
    if err then return cb(nil, repo .. ": " .. err) end
    local n = 0
    for num in out:gmatch("%d+") do
      local ts = tonumber(num)
      if ts and ts >= from and ts < to then n = n + 1 end
    end
    cb(n, nil)
  end)
end

-- ========================================================================== --
--                    ПЕРЕСЧЁТ: новые огоньки и сгоревшие дни
-- ========================================================================== --

--- Текущая серия = сколько подряд дней (заканчивая сегодня, если он закрыт,
--- или вчера) закрыты коммитами.
--- ВАЖНО: «сегодня ещё нет коммита» — это НЕ обрыв серии. Серия обрывается
--- только когда прошлый день закрыт нулём (или не закрыт вовсе). Поэтому отсчёт
--- идёт от сегодня, если сегодня уже зачтено, и от вчера — если ещё нет.
function S.recompute(today)
  local goal = S.opts.goal
  local d = today
  if (S.state.days[d] or 0) < goal then d = d - 1 end
  local cur = 0
  while (S.state.days[d] or 0) >= goal do
    cur = cur + 1
    d = d - 1
  end
  S.state.current = cur
  if cur > S.state.best then S.state.best = cur end
  return cur
end

--- Дни, про которые МЫ ЗНАЕМ, что коммита не было, — сгорают.
--- Важно: перебираем именно записанные дни, а не всю историю до первой записи:
--- иначе первый же запуск «сжёг» бы все 400 дней до установки конфига, и
--- пользователь вместо честного нуля увидел бы «сгорело 400 огоньков».
---@return number[] свежие сгоревшие дни (для уведомления)
function S.melt(today)
  local fresh = {}
  for d, n in pairs(S.state.days) do
    if d < today and n < S.opts.goal and not S.state.burned[d] then
      S.state.burned[d] = true
      fresh[#fresh + 1] = d
    end
  end
  table.sort(fresh)
  return fresh
end

--- Дни, которые мы не видели вообще (nvim был закрыт неделю), тоже не должны
--- жить как ни в чём не бывало: помечаем сгоревшими ТИХО, без уведомления.
function S.melt_gaps(today)
  local last = S.state.last_day
  if not last or last >= today then return end
  for d = last + 1, today - 1 do
    if not S.state.days[d] then S.state.burned[d] = true end
  end
end

local function say(msg, level)
  if not S.opts.notify then return end
  if level and level >= vim.log.levels.WARN then
    -- vim.notify в init.lua фильтруется до ERROR — идем в notify.nvim напрямую
    local impl = package.loaded["notify"] or (package.loaded["snacks"] and package.loaded["snacks"].notifier)
    if impl and impl.notify and pcall(impl.notify, impl, msg, level, { title = "🔥 Стрик", timeout = 8000 }) then
      return
    end
  end
  vim.api.nvim_echo({ { msg, "Normal" } }, false, {})
end

--- Главная проверка: закрыт ли сегодняшний день, не сгорели ли вчерашние.
function S.check(cb)
  local now = os.time()
  local today = S.day_of(now)
  S.state.today = today
  S.state.last_day = today -- точка, с которой мы «всё видели»; для melt_gaps
  local repos = S.active_repos()
  S.state.repos = repos
  if #repos == 0 then
    S.state.error = "не найдено ни одного git-репозитория: добавь "
      .. "(:StreakRepo ~/code/api) или включи этот каталог в конфиг"
    if cb then cb(false) end
    return
  end
  S.state.error = nil
  if not S.state.email then S.state.email = resolve_email(repos) end

  local from, to = S.day_window(today)
  local pending, sum, errs = #repos, 0, {}
  local function finish()
    pending = pending - 1
    if pending > 0 then return end

    local before = S.state.current
    S.melt_gaps(today)
    S.state.days[today] = sum
    S.state.today_count = sum
    local burned = S.melt(today)
    local cur = S.recompute(today)

    if sum >= S.opts.goal and before < cur and (S.state.last_awarded ~= today) then
      S.state.last_awarded = today
      S.state.total = S.state.total + 1
      say(("🔥 Огонёк за %s зажжён! Серия %d %s"):format(
        S.day_label(today), cur, cur == 1 and "день" or (cur < 5 and "дня" or "дней")),
        vim.log.levels.INFO)
    end
    if #burned > 0 and cur < before then
      local lost = {}
      for _, d in ipairs(burned) do lost[#lost + 1] = S.day_label(d) end
      say(("💀 %s: огонёк сгорает в %02d:00 МСК, а коммита не было. Серия %d → %d. Рекорд: %d."):format(
        table.concat(lost, ", "), S.opts.burn_hour, before, cur, S.state.best),
        vim.log.levels.WARN)
    end
    S.save()
    S.refresh_hud()
    if cb then cb(true) end
  end

  for _, repo in ipairs(repos) do
    S.scan(repo, from, to, function(n, err)
      if err then errs[#errs + 1] = err else sum = sum + (n or 0) end
      finish()
    end)
  end
end

--- Только что закоммитил? Пересчитаться сразу, не ждать таймера.
function S.refresh_hud()
  pcall(function()
    local hud = package.loaded["config.hud"]
    if hud and hud.refresh then hud.refresh() end
  end)
  pcall(function()
    if package.loaded["lualine"] then require("lualine").refresh({ force = true }) end
  end)
end

-- ========================================================================== --
--                                  ОТЧЁТ
-- ========================================================================== --

---@return string
function S.component()
  if S.state.current > 0 then return ("🔥%d"):format(S.state.current) end
  if S.state.error or not S.state.started then return "" end
  return "🔥0"
end

function S.report()
  local today = S.state.today or S.day_of(os.time())
  local cells, today_n = {}, S.state.today_count or 0
  for i = S.opts.grid_days - 1, 0, -1 do
    local d = today - i
    local n = S.state.days[d] or 0
    if n >= S.opts.goal then
      cells[#cells + 1] = "▇"
    elseif S.state.burned[d] then
      cells[#cells + 1] = "×"
    elseif d == today then
      cells[#cells + 1] = today_n > 0 and "▇" or "░"
    else
      cells[#cells + 1] = "░"
    end
  end
  local lines = {
    ("🔥 ОГОНЁК ЗА КОММИТЫ  ·  цель %d в день  ·  сгорание в %02d:00 МСК"):format(
      S.opts.goal, S.opts.burn_hour),
    ("   серия %d  ·  рекорд %d  ·  всего огоньков %d"):format(
      S.state.current, S.state.best, S.state.total),
    ("   %s   (%s: %d комм.)"):format(table.concat(cells, ""), S.day_label(today), today_n),
    "   ▇ закрыт · ░ ещё идёт · × сгорел",
    ("   до сгорания %s (следующий день — %s %s)"):format(
      (function()
        local s = math.floor(S.next_burn_in())
        return ("%d ч %02d мин"):format(math.floor(s / 3600), math.floor((s % 3600) / 60))
      end)(),
      S.day_label(today), S.day_full(today)),
    "   репозитории: " .. ((#S.state.repos > 0) and table.concat(S.state.repos, ", ") or "—"),
    ("   автор: %s"):format(S.state.email or "не определён (считаю все коммиты)"),
  }
  if S.state.error then lines[#lines + 1] = "   ⚠ " .. S.state.error end
  if S.state.save_err then lines[#lines + 1] = "   ⚠ не сохранилось: " .. S.state.save_err end
  return table.concat(lines, "\n")
end

-- ========================================================================== --
--                        ТАЙМЕРЫ И КОМАНДЫ
-- ========================================================================== --

--- В 03:00 МСК надо пересчитаться немедленно: пользователь не должен ждать
--- до следующего планового опроса, чтобы узнать о сгорании.
function S.arm_burn_timer()
  if S.state.burn_timer then
    S.state.burn_timer:stop()
    S.state.burn_timer:close()
    S.state.burn_timer = nil
  end
  local ms = math.floor(S.next_burn_in() * 1000) + 1500
  S.state.burn_timer = uv.new_timer()
  S.state.burn_timer:start(ms, 0, vim.schedule_wrap(function()
    S.check(function()
      -- день сменился: ставим таймер на следующие сутки
      S.arm_burn_timer()
    end)
  end))
end

function S.start()
  if S.state.started then return end
  S.state.started = true
  S.load()
  S.state.repos = S.active_repos()
  S.state.email = resolve_email(S.state.repos)
  S.check()
  S.state.timer = uv.new_timer()
  S.state.timer:start(S.opts.check_every * 1000, S.opts.check_every * 1000,
    vim.schedule_wrap(function() S.check() end))
  S.arm_burn_timer()
end

function S.stop()
  S.state.started = false
  for _, key in ipairs({ "timer", "burn_timer" }) do
    local t = S.state[key]
    if t then
      t:stop()
      t:close()
      S.state[key] = nil
    end
  end
end

function S.add_repo(path)
  local abs = vim.trim(path or "")
  if abs == "" then return "укажи путь: :StreakRepo ~/code/api" end
  abs = expand(abs)
  if vim.fn.isdirectory(abs .. "/.git") ~= 1 and vim.fn.isdirectory(abs .. "/HEAD") ~= 1 then
    local out = vim.trim(vim.fn.system({ "git", "-C", abs, "rev-parse", "--show-toplevel" }) or "")
    if out == "" or vim.fn.isdirectory(out) ~= 1 then
      return "это не git-репозиторий: " .. abs
    end
    abs = out
  end
  S.opts.repos = S.opts.repos or S.active_repos()
  local list = {}
  for _, r in ipairs(S.opts.repos) do
    if expand(r) ~= abs then list[#list + 1] = r end
  end
  list[#list + 1] = abs
  S.opts.repos = list
  S.state.email = resolve_email({ abs })
  S.check()
  return "плюс репозиторий: " .. abs .. " (всего " .. #list .. ")"
end

function S.commands()
  vim.api.nvim_create_user_command("Streak", function(o)
    if o.args == "sync" then
      return S.check(function() vim.api.nvim_echo({ { S.report(), "Normal" } }, true, {}) end)
    elseif o.args == "reset" then
      S.state.days, S.state.burned, S.state.current, S.state.best, S.state.total = {}, {}, 0, 0, 0
      S.save()
      return vim.api.nvim_echo({ { "стрик обнулён", "Normal" } }, false, {})
    end
    vim.api.nvim_echo({ { S.report(), "Normal" } }, true, {})
  end, {
    nargs = "?",
    desc = "🔥 огонёк за коммиты: отчёт (sync — пересчитать, reset — обнулить)",
    complete = function() return { "sync", "reset" } end,
  })
  vim.api.nvim_create_user_command("StreakRepo", function(o)
    vim.api.nvim_echo({ { S.add_repo(o.args), "Normal" } }, false, {})
  end, { nargs = 1, desc = "🔥 добавить репозиторий в зачёт огонька" })
  vim.api.nvim_create_user_command("StreakGoal", function(o)
    S.opts.goal = math.max(1, tonumber(o.args) or 1)
    S.check()
    vim.api.nvim_echo({ { ("цель: %d комм. в день"):format(S.opts.goal), "Normal" } }, false, {})
  end, { nargs = 1, desc = "🔥 сколько коммитов зажигают огонёк" })
  vim.api.nvim_create_user_command("StreakHour", function(o)
    S.opts.burn_hour = math.max(0, math.min(23, tonumber(o.args) or 3))
    S.check()
    S.arm_burn_timer()
    vim.api.nvim_echo({ { ("сгорание в %02d:00 МСК"):format(S.opts.burn_hour), "Normal" } }, false, {})
  end, { nargs = 1, desc = "🔥 во сколько МСК день считается законченным" })
  vim.api.nvim_create_user_command("StreakNotify", function(o)
    S.opts.notify = o.args ~= "off"
    vim.api.nvim_echo({ { "уведомления стрика: " .. (S.opts.notify and "вкл" or "выкл"), "Normal" } }, false, {})
  end, { nargs = "?", desc = "🔥 сообщения о огоньках" })
end

function S.setup(user_opts)
  S.opts = vim.tbl_deep_extend("force", {}, S.defaults, user_opts or {})
  S.commands()
  S.start()
end

return S
