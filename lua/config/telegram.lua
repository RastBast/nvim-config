-- ========================================================================== --
--                    TELEGRAM В РЕДАКТОРЕ: МОСТ К КОНСОЛЬНОМУ `tele`
-- ========================================================================== --
-- Что здесь происходит и ПОЧЕМУ именно так. Прочитай перед правкой, иначе
-- починишь то, как и было задумано. Всё проверено по исходникам
-- github.com/sorokin-vladimir/tele (main, v1.11.x).
--
-- 1. У tele НЕТ программируемого интерфейса. `cmd/tele/main.go` разбирает
--    только --config, -e, --trace, --version, --theme-check/--theme-dump.
--    Команд «tele send» / «tele read» не существует; пакет internal/ipc в
--    дереве есть, но «resident daemon with attachable TUI and CLI clients» —
--    это обещанный v2.0, в main он не подключён. Значит нельзя ни дёрнуть
--    CLI, ни подписаться на сокет.
--
-- 2. Зато tele пишет всю переписку в локальный SQLite:
--       <state_dir>/state.db   (по умолчанию ~/.local/state/tele/state.db)
--    Путь читаем из state_dir в ~/.config/tele/config.yml, а не зашиваем.
--    Схема — internal/store/sqlite.go:
--       chats(id, title, unread_count, read_inbox_max_id, last_message,
--             is_muted, is_archived, unread_mentions_count, ...)
--       messages(chat_id, msg_id, topic_id, date, data)   -- data = JSON домена
--    Пишется пачками: persistFlushInterval = 2 секунды (write-behind). Наш опрос
--    раз в 2 секунды — это РОВНО та задержка, с которой tele сам доводит
--    сообщение до диска; быстрее всё равно ничего не узнать.
--    ЧИТАЕМ мы, ПИШЕТ tele — конкурентность SQLite это переживает, для
--    SQLITE_BUSY ставим busy_timeout. Нужен sqlite3 >= 3.33 (ради --json);
--    это все сборки 2020 года и новее, :TeleCheck скажет, если не так.
--
-- 3. Как уведомляет сам tele (internal/app/notify.go): OSC 777
--    (ESC ]777;notify;title;body BEL) в stderr, если TERM_PROGRAM =
--    ghostty/WezTerm/iTerm.app или TERM=foot*, иначе beeep (уведомление ОС).
--    Neovim OSC 777 не понимает — перехватить его из терминала внутри nvim
--    нельзя физически. Поэтому popup рисуем СВОЙ, а :TeleQuiet выключает
--    дублирование на стороне ОС (ui.notifications.desktop: false).
--
-- 4. Новое сообщение определяем по РОСТУ unread_count, а не по «последняя
--    строка поменялась»: last_message меняется и от собственных сообщений
--    (написал с телефона), и от отметки «прочитано». Рост unread_count —
--    единственный надёжный смысл «входящее, которое ты ещё не видел».
--    Оттуда же бесплатный mute: is_muted — это Telegram-мьют чата.
--
-- 5. «Ответить из nvim» и «открыть нужный чат» делаем через PTY: Neovim умеет
--    писать в терминальный канал (nvim_chan_send по b:terminal_job_id), а tele
--    принимает обычные клавиши. Никакой магии и правок tele — просто печатаем
--    за тебя: Esc, 1, /чат, Enter, 2 (штатные клавиши из docs/keybindings.md).
--
-- 6. tele держит РОВНО ОДИН экземпляр на state_dir (statedir.Acquire; второй
--    процесс сразу выходит с «tele is already running»). Поэтому все три
--    режима (full / panel / chat) — это ОДНО окно поверх ОДНОГО буфера и ОДНОГО
--    процесса: меняется геометрия, процесс не перезапускается. Буфер жив → PTY
--    жив → уведомления идут, даже когда окно закрыто (:TeleHide).
--
-- 7. «Показать только чат, без папок и списка» сам tele не умеет:
--    internal/ui/layout/layout.go всегда делит ширину на sidebar + chat.
--    Поэтому <leader>mc = маленький float, сразу открытый на нужном чате и
--    с фокусом на панели чата, а «совсем чисто, только текст» = :TeleRead
--    (нативное окно nvim из кэша tele, читать можно, писать через R).
--
-- Публичный API:
--   require("config.telegram").setup{...}
--   require("config.telegram").on_message(function(ev) ... end)
--   события User TeleMessage / User TeleUnread

local uv = vim.uv or vim.loop

local T = {}

-- ========================================================================== --
--                                НАСТРОЙКИ
-- ========================================================================== --

T.defaults = {
  bin = "tele",              -- бинарь tele
  poll = 2000,               -- мс; 2000 = persistFlushInterval у tele
  timeout = 5000,            -- сколько висит popup (0 = не закрывать сам)
  style = "auto",            -- auto | notify | float | echo | none
  bell = false,              -- BEL в терминал на каждое входящее
  statusline = true,         -- компонент в lualine (lua/plugins/lualine.lua)

  respect_mute = true,       -- мьют-чаты: считаем, но не всплываем
  skip_archived = true,      -- архив: не всплываем
  loud_mentions = true,      -- @mention всплывает даже из мьюта
  notify_read_activity = false, -- всплывать и на входящие, которые tele прочитал сам
                                -- (ты смотришь чат в tele — popup только мешает)
  enrich = true,             -- доставать автора/текст из messages.data

  focus = {},                -- {"Иван", "#go-prod"} — всплывать ТОЛЬКО про них
  ignore = {},               -- про эти — не всплывать вовсе

  history_keep = 200,        -- строк истории в :TeleInbox
  inbox_open_on_start = false,

  terminal_id = 42,          -- id терминала toggleterm: один на все режимы
  kill_on_exit = true,       -- убивать tele при выходе из nvim
  key_delay = 150,           -- мс между «нажатиями» в PTY (bubbletea должен успеть)
  mode = "chat",             -- режим по умолчанию для <leader>mm и :Tele

  panel = { direction = "vertical", size = 68 },
  float = { width = 96, height = 24 },
  full = { direction = "editor" },

  theme = { name = "nvim-mocha", palette = "mocha" },
}

T.opts = {}

-- ========================================================================== --
--                                 СОСТОЯНИЕ
-- ========================================================================== --

T.state = {
  timer = nil,
  started = false,
  inflight = false,
  ticks = 0,
  dnd = false,

  db = nil,        -- найденный state.db
  db_error = nil,
  sqlite = nil,    -- путь к sqlite3 (nil = бинаря нет)
  mode = nil,      -- какой вариант запуска sqlite3 сработал (кэш на след. тик)

  prev = nil,      -- предыдущий снимок chats — по нему ищем разницу
  chats = {},      -- id -> снимок чата
  titles = {},     -- имена чатов: completion и выбор в :TeleChatPick
  unread_total = 0,
  mention_chats = 0,
  last_event = nil,

  history = {},    -- из чего собран :TeleInbox
  inbox_buf = nil,
  inbox_win = nil,
  inbox_index = {},
  follow = true,

  term = nil,      -- объект toggleterm.Terminal (ОДИН на все три режима)
  term_mode = nil,
  term_buf = nil,
  term_job = nil,
  ask_retries = 0,
}

local function expand(path)
  if not path or path == "" then return nil end
  return vim.fn.expand(path)
end

local function executable(name) return vim.fn.executable(name) == 1 end

local function num(v, def)
  local n = tonumber(v)
  return n and math.floor(n) or (def or 0)
end

--- Короткое сообщение в message area. WARN/ERROR идут через vim.notify — их
--- фильтр из init.lua пропускает; INFO печатаем тихо, чтобы не спамить notify.
function T.say(msg, level)
  if level and level >= vim.log.levels.WARN then
    -- В init.lua стоит перехватчик vim.notify, выбрасывающий ВСЁ кроме ERROR.
    -- Предупреждения моста («нет sqlite3», «БД недоступна», «tele уже запущен») —
    -- как раз WARN, и через vim.notify они исчезли бы молча. Поэтому идём
    -- напрямую в notify.nvim / Snacks (фильтр их не касается), а если их нет —
    -- в echo с соответствующей подсветкой.
    local impl = package.loaded["notify"] or (package.loaded["snacks"] and package.loaded["snacks"].notifier)
    if impl and impl.notify then
      local ok = pcall(impl.notify, impl, "[tele] " .. msg, level, {
        title = "✈ Telegram", icon = "✈", timeout = 8000,
      })
      if ok then return end
    end
    vim.api.nvim_echo({
      { "[tele] " .. msg, (level >= vim.log.levels.ERROR) and "ErrorMsg" or "WarningMsg" },
    }, false, {})
    return
  end
  vim.api.nvim_echo({ { "[tele] " .. msg, "Normal" } }, false, {})
end

-- ========================================================================== --
--                       ПОИСК state.db (ничего не зашито)
-- ========================================================================== --

local function config_path()
  local p = vim.fn.glob(expand("$HOME") .. "/.config/tele/config.yml", false, true)[1]
  if not p and vim.env.XDG_CONFIG_HOME then
    p = vim.fn.glob(vim.env.XDG_CONFIG_HOME .. "/tele/config.yml", false, true)[1]
  end
  return p
end

local function candidate_dirs()
  local out, seen = {}, {}
  local function push(dir)
    dir = dir and expand(dir)
    if dir and dir ~= "" and not seen[dir] then
      seen[dir] = true
      out[#out + 1] = dir
    end
  end

  -- 1) явный state_dir из конфига tele
  local cfg = config_path()
  if cfg then
    local fh = io.open(cfg, "r")
    if fh then
      for line in fh:lines() do
        local v = line:match("^state_dir:%s*(.-)%s*$") -- только верхнеуровневый ключ
        if v and v ~= "" then
          push(v:gsub("^['\"]", ""):gsub("['\"]$", ""))
        end
      end
      fh:close()
    end
  end

  -- 2) типичные места: XDG state (Linux+macOS с xdg), старое data, Application Support
  push(vim.env.TELE_STATE_DIR)
  if vim.fn.has("macunix") == 1 then push("$HOME/Library/Application Support/tele") end
  push("$XDG_STATE_HOME/tele")
  push("$HOME/.local/state/tele")
  push("$XDG_DATA_HOME/tele")
  push("$HOME/.local/share/tele")
  return out
end

---@return string|nil db, string why
function T.find_db()
  local tried = {}
  for _, dir in ipairs(candidate_dirs()) do
    tried[#tried + 1] = dir
    local st = uv.fs_stat(dir .. "/state.db")
    if st and st.size and st.size > 0 then
      return dir .. "/state.db", "state.db в " .. dir
    end
    local others = vim.fn.glob(dir .. "/*.db", false, true)
    if #others > 0 then
      table.sort(others, function(a, b)
        local sa, sb = uv.fs_stat(a), uv.fs_stat(b)
        return (sa and sa.size or 0) > (sb and sb.size or 0)
      end)
      return others[1], "state.db не найден, взят самый большой .db в " .. dir
    end
  end
  return nil, "ни в одном каталоге tele нет БД: " .. table.concat(tried, ", ")
end

-- ========================================================================== --
--                             ЗАПУСК sqlite3
-- ========================================================================== --

local CHAT_SQL = table.concat({
  "SELECT id, title, unread_count, read_inbox_max_id, is_muted,",
  "is_archived, unread_mentions_count, COALESCE(last_message,'') AS last_message",
  "FROM chats;",
}, " ")

---@param cmd string[]
---@param cb fun(out: string|nil, err: string|nil)
local function spawn(cmd, cb)
  if vim.system then
    local ok = pcall(vim.system, cmd, { text = true }, function(res)
      vim.schedule(function()
        local stderr = vim.trim(res.stderr or "")
        if (res.code or 1) ~= 0 then
          cb(nil, stderr ~= "" and stderr or ("sqlite3: код " .. tostring(res.code)))
        else
          cb(res.stdout or "", nil)
        end
      end)
    end)
    if ok then return end
  end
  -- Neovim < 0.10: синхронно (десятки ms, не страшно)
  local quoted = {}
  for _, part in ipairs(cmd) do quoted[#quoted + 1] = vim.fn.shellescape(part) end
  local fh = io.popen(table.concat(quoted, " ") .. " 2>/dev/null", "r")
  if not fh then return cb(nil, "не удалось запустить sqlite3") end
  local out = fh:read("*a") or ""
  fh:close()
  cb(out, nil)
end

--- Выполнить SQL. Сначала самый аккуратный запуск (только чтение), при отказе
--- — обычный: в WAL-режиме -readonly требует читаемый -shm, и на древних
--- sqlite3 отказывается открывать базу. SELECT при этом ничего не меняет.
---@param sql string
---@param cb fun(rows: table[]|nil, err: string|nil)
function T.sql(sql, cb)
  if not T.state.sqlite then return cb(nil, "sqlite3 не найден в PATH") end
  if not T.state.db then return cb(nil, "state.db не найден (:TeleCheck)") end

  local all = {
    { mode = "ro", flags = { "-readonly", "-json" } },
    { mode = "rw", flags = { "-json" } },
  }
  local list = {}
  for _, v in ipairs(all) do
    if not T.state.mode or v.mode == T.state.mode then list[#list + 1] = v end
  end
  if #list == 0 then list = all end

  local i, last_err = 0, "sqlite3 не ответил"
  local function attempt()
    i = i + 1
    local v = list[i]
    if not v then
      T.state.mode = nil -- на следующий тик прогнать оба варианта заново
      return cb(nil, last_err)
    end
    local cmd = { T.state.sqlite, "-cmd", "PRAGMA busy_timeout=1500;" }
    for _, f in ipairs(v.flags) do cmd[#cmd + 1] = f end
    cmd[#cmd + 1] = T.state.db
    cmd[#cmd + 1] = sql
    spawn(cmd, function(out, err)
      if err then
        last_err = err
        return attempt()
      end
      local rows
      if vim.trim(out or "") == "" then
        rows = {} -- пустой результат — это не ошибка
      else
        local ok, decoded = pcall(vim.json.decode, out)
        rows = (ok and type(decoded) == "table") and decoded or nil
      end
      if not rows then
        last_err = "вывод sqlite3 не разобран (нужен sqlite3 >= 3.33 для --json)"
        return attempt()
      end
      T.state.mode = v.mode
      cb(rows)
    end)
  end
  attempt()
end

-- ========================================================================== --
--                  РАЗБОР messages.data (best effort, без схемы)
-- ========================================================================== --
-- messages.data — JSON приватного домена tele, меняется от релиза к релизу.
-- Схему НЕ проверяем: ищем поле с похожим именем в любом регистре. Не нашли —
-- покажем last_message из таблицы chats, он всегда под рукой.

local function lower_keys(t)
  local map = {}
  for k, v in pairs(t) do
    if type(k) == "string" then map[k:lower()] = v end
  end
  return map
end

local function pick(fields, names)
  for _, n in ipairs(names) do
    local v = fields[n]
    if type(v) == "string" and v ~= "" then return v end
    if type(v) == "number" then return tostring(v) end
  end
  return nil
end

---@return { text: string, author: string|nil, out: boolean }
function T.decode_message(data)
  local out = { text = "", author = nil, out = false }
  if not data or data == "" then return out end
  local ok, decoded = pcall(vim.json.decode, data)
  if not ok or type(decoded) ~= "table" then return out end
  local f = lower_keys(decoded)

  out.text = pick(f, { "text", "message", "body", "content" }) or ""
  out.author = pick(f, {
    "sendername", "sender_name", "sender", "author", "authorname", "displayname", "name",
  })
  local is_out = f["out"] or f["isoutgoing"] or f["is_outgoing"] or f["outgoing"]
  if type(is_out) == "number" then is_out = (is_out ~= 0) end
  out.out = (is_out == true)

  if out.text == "" then
    local media
    if type(f.media) == "table" then
      media = lower_keys(f.media)
    elseif type(f.mediaref) == "table" then
      media = lower_keys(f.mediaref)
    end
    if media then
      out.text = pick(media, { "filename", "title", "emoji", "performer" }) or "[медиа]"
    end
  end
  if not out.author and type(f.user) == "table" then
    out.author = pick(lower_keys(f.user), { "displayname", "firstname", "username" })
  end
  return out
end

-- ========================================================================== --
--                  POPUP: ПУСКАЕМ МИМО ФИЛЬТРА ИЗ init.lua
-- ========================================================================== --
-- В init.lua стоит перехватчик vim.notify, выбрасывающий ВСЁ кроме ERROR.
-- Поэтому в notify.nvim / Snacks.notifier обращаемся НАПРЯМУЮ, а не через
-- vim.notify; плюс есть собственный float — на случай, когда ни того, ни
-- другого не установлено (или notify отключён конфигом).

local popups, popup_seq = {}, 0

local function close_popup(id)
  local p = popups[id]
  if not p then return end
  if p.timer then
    p.timer:stop()
    p.timer:close()
  end
  if p.win and vim.api.nvim_win_is_valid(p.win) then vim.api.nvim_win_close(p.win, true) end
  if p.buf and vim.api.nvim_buf_is_valid(p.buf) then vim.api.nvim_buf_delete(p.buf, { force = true }) end
  popups[id] = nil
end

T.close_popup = close_popup

--- Собственный побуквенный перенос (UTF-8 безопасный) — на случай Neovim < 0.9,
--- где vim.fn.wordwrap отсутствует.
local function chop(text, width)
  local out, line, w, i = {}, "", 0, 1
  while i <= #text do
    local b = text:byte(i)
    local len = (b < 0x80 and 1) or (b >= 0xF0 and 4 or (b >= 0xE0 and 3 or (b >= 0xC0 and 2 or 1)))
    local ch = text:sub(i, i + len - 1)
    local cw = vim.fn.strdisplaywidth(ch)
    if w + cw > width and line ~= "" then
      out[#out + 1] = line
      line, w = "", 0
    end
    line, w, i = line .. ch, w + cw, i + len
  end
  out[#out + 1] = line
  return out
end

--- Перенос по ширине: wordwrap знает про UTF-8 и double-width символы.
local function wrap(text, width)
  local out = {}
  for _, raw in ipairs(vim.split(text, "\n", { plain = true })) do
    if type(vim.fn.wordwrap) == "function" then
      local wrapped = vim.fn.wordwrap(raw, { max_size = width })
      for _, line in ipairs(vim.split(wrapped, "\n", { plain = true })) do
        out[#out + 1] = line
      end
    else
      for _, line in ipairs(chop(raw, width)) do out[#out + 1] = line end
    end
  end
  if #out == 0 then out[1] = "" end
  return out
end

local function show_float(title, body, kind)
  local inner = math.max(24, math.min(58, vim.o.columns - 12))
  local lines = { ("✈  %s"):format(title) }
  for _, line in ipairs(wrap(body, inner)) do lines[#lines + 1] = "   " .. line end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = 0
  for _, line in ipairs(lines) do width = math.max(width, vim.fn.strdisplaywidth(line)) end
  width = math.min(vim.o.columns - 4, width + 2)
  local height = #lines
  -- стек: каждое следующее окно выше предыдущего, чтобы не лепиться друг в друга
  local row = math.max(1, vim.o.lines - height - 3 - #vim.tbl_keys(popups) * (height + 1))

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = row,
    col = math.max(0, vim.o.columns - width - 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    zindex = 300,
  })
  local group = (kind == "mention") and "TeleMention" or "TeleNotify"
  local border = (kind == "mention") and "TeleMentionBorder" or "TeleNotifyBorder"
  pcall(vim.api.nvim_set_option_value, "winhighlight",
    ("Normal:%s,NormalFloat:%s,FloatBorder:%s"):format(group, group, border), { win = win })
  pcall(vim.api.nvim_set_option_value, "winblend", 6, { win = win })

  popup_seq = popup_seq + 1
  local id = popup_seq
  popups[id] = { win = win, buf = buf }
  if T.opts.timeout > 0 then
    local timer = uv.new_timer()
    popups[id].timer = timer
    timer:start(T.opts.timeout, 0, vim.schedule_wrap(function() close_popup(id) end))
  end
  return id
end

--- Стоит ли подписывать автора: да, если это не повтор заголовка чата.
function T.names_differ(author, title)
  if not author or author == "" then return false end
  local a, t = author:lower(), (title or ""):lower()
  if a == t then return false end
  if t == "" then return true end
  return not (t:find(a, 1, true) or a:find(t, 1, true))
end

---@param title string
---@param body string
---@param kind string "message"|"mention"|"quiet"
function T.popup(title, body, kind)
  if T.opts.style == "none" then return end
  if T.opts.style == "echo" then
    vim.api.nvim_echo({ { ("✈ %s: %s"):format(title, (body:gsub("[\r\n]+", " "))), "Normal" } }, false, {})
    return
  end

  local notify_mod = package.loaded["notify"]
  local snacks = package.loaded["snacks"]
  local external = notify_mod or (snacks and snacks.notifier)
  local use_external = T.opts.style == "notify"
      or (T.opts.style == "auto" and external ~= nil)
  if use_external and external and external.notify then
    local ok = pcall(external.notify, external, body,
      kind == "mention" and vim.log.levels.WARN or vim.log.levels.INFO, {
        title = "✈ " .. title,
        icon = kind == "mention" and "󰱺" or "✈",
        timeout = T.opts.timeout,
      })
    if ok then return end
  end
  show_float(title, body, kind)
end

--- Гудок: BEL прямо в stderr Neovim — терминал сам решает, звенеть или мигать.
local function bell()
  if not T.opts.bell then return end
  pcall(vim.api.nvim_chan_send, 2, "\a")
end

-- ========================================================================== --
--                          ФИЛЬТРЫ: focus / ignore / mute
-- ========================================================================== --

local function matches_any(name, list)
  local low = (name or ""):lower()
  for _, pat in ipairs(list or {}) do
    if pat ~= "" and low:find(pat:lower(), 1, true) then return true end
  end
  return false
end

---@return boolean show, boolean loud
local function decide(c)
  local name = c.title or ""
  if T.opts.skip_archived and c.archived then return false, false end
  if matches_any(name, T.opts.ignore) then return false, false end

  local loud = false
  if #T.opts.focus > 0 then
    if not matches_any(name, T.opts.focus) then return false, false end
    loud = true
  end
  if (c.mentions_delta or 0) > 0 and T.opts.loud_mentions then loud = true end
  if T.opts.respect_mute and c.muted and not loud then return false, false end
  return true, loud
end

-- ========================================================================== --
--                       ИСТОРИЯ И БУФЕР :TeleInbox
-- ========================================================================== --

function T.render_inbox()
  local buf = T.state.inbox_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

  local lines = {
    ("✈ TELEGRAM   непрочитанных %d · чатов с упоминаниями %d · %s"):format(
      T.state.unread_total, T.state.mention_chats,
      T.state.dnd and "РЕЖИМ ТИШИНЫ (:TeleDnd)"
        or ("опрос БД раз в " .. math.floor(T.opts.poll / 1000) .. " c")),
    ("  БД: %s   tele: %s"):format(
      T.state.db or "не найдена (:TeleCheck)",
      T.state.term_job and ("наш процесс, job " .. T.state.term_job) or "нашего процесса нет"),
    "",
  }
  local index = {} -- номер строки -> имя чата, чтобы <cr> знал, что открывать

  if #T.state.history == 0 then
    lines[#lines + 1] = "  пока пусто: с запуска Neovim новых входящих не было."
    lines[#lines + 1] = "  (ловим сообщения из кэша tele, поэтому tele должен быть запущен"
    lines[#lines + 1] = "   где-то: <leader>mm здесь или любая другая вкладка терминала.)"
  else
    for i = #T.state.history, 1, -1 do
      local ev = T.state.history[i]
      local mark = ev.kind == "mention" and "●!"
          or ((ev.unread or 0) > 1 and ("×" .. ev.unread) or "●")
      local when = os.date("%H:%M", math.floor(ev.at or os.time()))
      local head = (ev.author and ev.author ~= "") and (ev.author .. ": ") or ""
      local text = head .. ((ev.text or ""):gsub("[\r\n]+", " "))
      lines[#lines + 1] = ("  %s  %s  %-22s  %s"):format(mark, when, (ev.title or "?"):sub(1, 22), text)
      index[#lines] = ev.title
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  <cr> открыть чат в tele · o читать историю · R ответить · i обновить · f следить · q закрыть"

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  T.state.inbox_index = index
end

function T.push_history(ev)
  local h = T.state.history
  h[#h + 1] = ev
  while #h > T.opts.history_keep and #h > 0 do table.remove(h, 1) end
  if T.state.inbox_buf and vim.api.nvim_buf_is_valid(T.state.inbox_buf) and T.state.follow then
    T.render_inbox()
  end
end

function T.open_inbox()
  local buf = T.state.inbox_buf
  if buf and vim.api.nvim_buf_is_valid(buf) then
    if T.state.inbox_win and vim.api.nvim_win_is_valid(T.state.inbox_win) then
      pcall(vim.api.nvim_set_current_win, T.state.inbox_win)
      T.render_inbox()
      return
    end
    T.state.inbox_win = vim.api.nvim_open_win(buf, true, { split = true, height = 16 })
    T.render_inbox()
    return
  end

  buf = vim.api.nvim_create_buf(false, true)
  T.state.inbox_buf = buf
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "teleinbox"
  local win = vim.api.nvim_open_win(buf, true, { split = true, height = 16 })
  T.state.inbox_win = win
  vim.wo[win].spell = false -- window-локальная: на окно, не на буфер
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  pcall(function() vim.wo[win].winfixbuf = true end)
  T.render_inbox()

  local function at_line()
    return T.state.inbox_index[vim.api.nvim_win_get_cursor(0)[1]]
  end
  local function key(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true, desc = "✈ " .. desc })
  end
  key("q", function()
    if T.state.inbox_win and vim.api.nvim_win_is_valid(T.state.inbox_win) then
      vim.api.nvim_win_close(T.state.inbox_win, true)
    end
    T.state.inbox_win = nil
  end, "закрыть")
  key("i", function() T.poll_once(true) end, "обновить из БД")
  key("f", function()
    T.state.follow = not T.state.follow
    T.say("следить за новыми: " .. (T.state.follow and "да" or "нет"))
  end, "автообновление буфера")
  key("<cr>", function()
    local name = at_line()
    if not name then return T.say("под курсором нет строки чата", vim.log.levels.WARN) end
    T.open(T.opts.mode, name)
  end, "открыть этот чат в tele")
  key("o", function()
    local name = at_line()
    if name then T.read_chat(name, 40) end
  end, "прочитать переписку, не открывая tele")
  key("R", T.reply_prompt, "ответить через tele")

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    callback = function()
      if T.state.inbox_win == win then T.state.inbox_win = nil end
    end,
  })
end

-- ========================================================================== --
--                               ЦИКЛ ОПРОСА
-- ========================================================================== --

--- Снимок таблицы chats в удобный вид, ключ — id чата строкой.
local function snapshot(rows)
  local by_id = {}
  for _, r in ipairs(rows) do
    by_id[tostring(r.id)] = {
      id = tonumber(r.id) or 0,
      title = r.title or "",
      unread = num(r.unread_count),
      read = num(r.read_inbox_max_id),
      muted = num(r.is_muted) ~= 0,
      archived = num(r.is_archived) ~= 0,
      mentions = num(r.unread_mentions_count),
      text = r.last_message or "",
    }
  end
  return by_id
end

--- Автор и текст самого свежего сообщения чата, чтобы в группе было видно
--- «кто написал», а не только превью из last_message.
function T.enrich(events, cb)
  local pending = #events
  local fired = false
  local function finish()
    pending = pending - 1
    if pending <= 0 and not fired then
      fired = true
      cb()
    end
  end
  for _, ev in ipairs(events) do
    local q = ("SELECT data FROM messages WHERE chat_id = %d ORDER BY date DESC, msg_id DESC LIMIT 1;")
        :format(math.floor(tonumber(ev.id) or 0))
    T.sql(q, function(rows)
      local row = rows and rows[1]
      if row then
        local msg = T.decode_message(row.data)
        if msg.text ~= "" then ev.text = msg.text end
        ev.author = msg.author
        ev.out = msg.out
      end
      finish()
    end)
  end
  -- если sqlite3 отвалится на середине, доставка всё равно состоится
  vim.defer_fn(function()
    if not fired then
      fired = true
      cb()
    end
  end, 2500)
end

--- Один опрос БД.
function T.poll_once(force)
  if T.state.inflight and not force then return end
  T.state.inflight = true

  T.sql(CHAT_SQL, function(rows, err)
    T.state.inflight = false
    if not rows then
      T.state.db_error = err
      -- не чаще раза в ~30 с, иначе message area съест редактор
      if err and T.state.ticks % 15 == 0 then T.say("БД tele недоступна: " .. err, vim.log.levels.WARN) end
      return
    end
    T.state.db_error = nil
    T.state.ticks = T.state.ticks + 1

    local snap = snapshot(rows)
    local titles, total, mention_chats = {}, 0, 0
    for _, c in pairs(snap) do
      if c.title ~= "" then titles[#titles + 1] = c.title end
      total = total + c.unread
      if c.mentions > 0 then mention_chats = mention_chats + 1 end
    end
    table.sort(titles, function(a, b) return a:lower() < b:lower() end)

    T.state.chats = snap
    T.state.titles = titles
    T.state.unread_total = total
    T.state.mention_chats = mention_chats

    local prev = T.state.prev
    T.state.prev = snap
    if not prev then
      -- первый снимок — базовая линия: не всплываем про то, что случилось
      -- до запуска Neovim
      T.refresh_status()
      return
    end

    ---@type table[]
    local events = {}
    for id, cur in pairs(snap) do
      local old = prev[id]
      if old then
        local du = cur.unread - old.unread
        local dm = cur.mentions - old.mentions
        if du > 0 or dm > 0 then
          events[#events + 1] = {
            id = tonumber(id), title = cur.title, text = cur.text,
            unread = du > 0 and du or 1,
            mentions_delta = dm > 0 and dm or 0,
            muted = cur.muted, archived = cur.archived,
            kind = (dm > 0) and "mention" or "message",
            at = os.time(),
          }
        elseif T.opts.notify_read_activity and cur.read > old.read and cur.text ~= old.text then
          events[#events + 1] = {
            id = tonumber(id), title = cur.title, text = cur.text, unread = 0,
            mentions_delta = 0, muted = cur.muted, archived = cur.archived,
            kind = "quiet", at = os.time(),
          }
        end
      end
    end

    local function deliver()
      for _, ev in ipairs(events) do
        local show, loud = decide(ev)
        if show and not T.state.dnd and ev.kind ~= "quiet" then
          local body = (ev.text ~= "" and ev.text) or "(без текста)"
          -- Автор нужен в группах и каналах (там заголовок — название, а не
          -- собеседник). В личном чате имя уже в заголовке, и «Иван: привет»
          -- под заголовком «Иван Петров» — просто шум.
          if T.names_differ(ev.author, ev.title) then
            body = ev.author .. ": " .. body
          end
          if (ev.unread or 0) > 1 then body = ("+%d  "):format(ev.unread) .. body end
          T.popup(ev.title, body, loud and "mention" or "message")
          bell()
        end
        T.state.last_event = ev
        T.push_history(ev)
        vim.api.nvim_exec_autocmds("User", { pattern = "TeleMessage", modeline = false, data = ev })
      end
      T.refresh_status()
      vim.api.nvim_exec_autocmds("User", {
        pattern = "TeleUnread", modeline = false,
        data = { unread = total, mention_chats = mention_chats },
      })
    end

    if #events == 0 then
      T.refresh_status()
    elseif T.opts.enrich then
      T.enrich(events, deliver)
    else
      deliver()
    end
  end)
end

--- Своя реакция на входящее: T.on_message(function(ev) ... end).
function T.on_message(cb)
  return vim.api.nvim_create_autocmd("User", {
    pattern = "TeleMessage",
    callback = function(opts) cb(opts.data) end,
    desc = "tele: свой обработчик входящего сообщения",
  })
end

-- ========================================================================== --
--                     СЧЁТЧИК ДЛЯ LUALINE
-- ========================================================================== --

function T.refresh_status()
  pcall(function()
    if package.loaded["lualine"] then require("lualine").refresh({ force = true }) end
  end)
  if T.state.inbox_win and vim.api.nvim_win_is_valid(T.state.inbox_win) then T.render_inbox() end
end

---@return string
function T.component()
  local s = T.state
  if not s.started then return "" end
  if s.unread_total == 0 and s.mention_chats == 0 then
    return s.dnd and " ✈⌀ " or ""
  end
  local icon = s.mention_chats > 0 and "✈!" or "✈"
  if s.dnd then icon = icon .. "⌀" end
  return (" %s %d "):format(icon, s.unread_total)
end

function T.counts() return T.state.unread_total, T.state.mention_chats end

-- ========================================================================== --
--                 ТЕРМИНАЛ С tele: ТРИ РЕЖИМА, ОДИН ПРОЦЕСС
-- ========================================================================== --

--- id PTY-процесса. toggleterm хранит его в term.job_id, Neovim — в
--- b:terminal_job_id; берём то и другое (первое появляется чуть раньше).
local function job_of(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return nil end
  return (vim.b[buf] and vim.b[buf].terminal_job_id) or nil
end

---@return table поля для toggleterm
local function geometry(mode)
  if mode == "full" then
    return { direction = T.opts.full.direction, name = "telegram (tele)" }
  elseif mode == "panel" then
    return {
      direction = T.opts.panel.direction,
      size = T.opts.panel.size,
      name = "telegram (tele)",
    }
  end
  return {
    direction = "float",
    size = 6,
    name = "telegram (tele)",
    float_opts = {
      border = "rounded",
      width = math.min(T.opts.float.width, math.max(40, vim.o.columns - 4)),
      height = math.min(T.opts.float.height, math.max(8, vim.o.lines - 4)),
    },
  }
end

--- Оформление окна tele в тон редактору. Поле окна в toggleterm — window.
function T.paint(term)
  local win = term and (term.window or term.winid)
  if not win or not vim.api.nvim_win_is_valid(win) then return end
  pcall(vim.api.nvim_set_option_value, "winhighlight",
    "Normal:TeleTerm,NormalFloat:TeleTerm,FloatBorder:TeleTermBorder,EndOfBuffer:TeleTerm",
    { win = win })
end

--- tele говорит «already running», если state_dir занят другим экземпляром.
function T.check_startup(buf)
  vim.defer_fn(function()
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, 25, false), "\n")
    if text:find("already running") then
      T.say("tele уже запущен в другом терминале — второй процесс не поднялся "
        .. "(у него lock на state_dir). Уведомления в nvim при этом РАБОТАЮТ: "
        .. "мы читаем state.db. Не работают только «ответить» и «открыть чат» — "
        .. "они печатают в НАШ PTY, а его нет.", vim.log.levels.WARN)
    elseif text:find("api_id") or text:find("Get credentials") then
      T.say("tele просит api_id/api_hash и вход в аккаунт: пройдись по экрану "
        .. "один раз (номер → код из Telegram), дальше всё само.", vim.log.levels.WARN)
    end
  end, 1200)
end

---@param mode string "chat"|"panel"|"full"
---@param chat string|nil имя чата, в который прыгнуть сразу после старта
function T.open(mode, chat)
  mode = mode or T.opts.mode
  T.state.term_mode = mode

  local ok = pcall(require, "toggleterm")
  if not ok then
    return T.say("toggleterm.nvim не загрузился — окна tele строить не на что",
      vim.log.levels.ERROR)
  end
  if not executable(T.opts.bin) then
    return T.say(("«%s» не найден в PATH. Установка: brew install tele · apt/dnf из "
      .. "репозитория автора · nix · либо go build -o tele ./cmd/tele"):format(T.opts.bin),
      vim.log.levels.ERROR)
  end

  local Terminal = require("toggleterm.terminal").Terminal
  local term = T.state.term
  local geom = geometry(mode)

  if term and term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then
    -- Тот же буфер и тот же процесс, другая геометрия (см. п.6 шапки).
    -- open(size, direction) — публичный API toggleterm: внутри он зовёт
    -- change_direction (сбрасывает self.window) и делает opener + switch_buf,
    -- то есть ПЕРЕИСПОЛЬЗУЕТ буфер, а процесс живёт дальше. Своих полей типа
    -- term.winid у toggleterm нет — окно лежит в term.window.
    pcall(term.close, term)
    if geom.float_opts then term.float_opts = geom.float_opts end
    if geom.size then term.size = geom.size end
    T.state.term_buf = term.bufnr
    T.state.term_job = term.job_id or job_of(term.bufnr)
    pcall(term.open, term, geom.size, geom.direction)
    vim.schedule(function()
      T.paint(term)
      T.state.term_job = term.job_id or job_of(term.bufnr)
    end)
    if chat then vim.defer_fn(function() T.open_chat(chat) end, 250) end
    return
  end

  term = Terminal:new(vim.tbl_extend("force", {
    cmd = T.opts.bin,
    id = T.opts.terminal_id,
    close_on_exit = true,
    persist_size = false,
    start_in_insert = true,
    insert_mappings = false,
  }, geom))
  term:toggle(geom.size, geom.direction)
  T.state.term = term
  T.state.term_buf = term.bufnr
  vim.schedule(function() T.paint(term) end)

  vim.defer_fn(function()
    T.state.term_job = term.job_id or job_of(term.bufnr)
    T.check_startup(term.bufnr)
    if chat then T.open_chat(chat) end
  end, 300)
end

---@return string|nil режим, который сейчас показан
function T.toggle_term(mode)
  if T.is_open() and (not mode or mode == T.state.term_mode) then
    T.hide()
    return nil
  end
  T.open(mode or T.opts.mode)
  return mode or T.opts.mode
end

--- Спрятать окно; процесс остаётся живым, потому что буфер не wipe-ается.
function T.hide()
  if T.state.term then pcall(T.state.term.close, T.state.term) end
end

function T.is_open()
  local term = T.state.term
  return term ~= nil and term:is_open() == true
end

--- Убить процесс (освободить lock state_dir).
function T.shutdown()
  local term = T.state.term
  if term then
    pcall(term.shutdown, term)
    pcall(term.close, term)
  end
  T.state.term_job = nil
end

--- Набрать клавиши в PTY tele. Между кусками пауза: bubbletea должен успеть.
function T.send_keys(keys)
  local job = T.state.term_job
  if not job then
    job = job_of(T.state.term_buf)
    T.state.term_job = job
  end
  if not job then
    T.say("нет живого терминала с tele — сначала <leader>mm (float), <leader>mf "
      .. "(весь экран) или <leader>mp (панель)", vim.log.levels.WARN)
    return false
  end
  if type(keys) == "string" then keys = { keys } end
  local delay = math.max(20, T.opts.key_delay)
  for i, chunk in ipairs(keys) do
    vim.defer_fn(function() pcall(vim.api.nvim_chan_send, job, chunk) end, (i - 1) * delay)
  end
  return true
end

--- Открыть чат по имени штатными клавишами tele:
--- Esc → 1 (фокус списка чатов) → /имя ⏎ (поиск, Enter = открыть) → 2 (фокус чата).
function T.open_chat(name)
  if not name or name == "" then return end
  T.send_keys({ "\027", "1", "/" .. name, "\r", "2" })
end

--- Ответить в чат, который сейчас открыт в tele: Esc → i <текст> ⏎.
function T.reply(text)
  if not text or text == "" then return end
  if T.send_keys({ "\027", "i", (text:gsub("[\r\n]+", " ")), "\r" }) then
    T.say("набрано и отправлено в tele — в тот чат, который сейчас открыт там на экране")
  end
end

function T.reply_prompt()
  vim.ui.input({ prompt = "✈ Ответить через tele: " }, function(text)
    if text and text ~= "" then T.reply(text) end
  end)
end

--- Текущая строка -> сообщение (без перехода в визуальный режим).
function T.send_current()
  T.send_lines({ vim.api.nvim_get_current_line() })
end

--- Ответить в чат последнего уведомления (если это тот чат, что тебе нужен).
function T.reply_last()
  local ev = T.state.last_event
  if not ev then
    return T.say("последнего уведомления ещё не было", vim.log.levels.WARN)
  end
  T.open_chat(ev.title)
  vim.defer_fn(T.reply_prompt, math.max(4, T.opts.key_delay) * 6)
end

--- Отправить строку/выделение как сообщение (для :TeleSend с range).
function T.send_lines(lines)
  T.reply(table.concat(lines or {}, "\n"))
end

-- ========================================================================== --
--              ТЕМА И КОНФИГ tele: ВСЁ В ГАММЕ ТВОЕГО NVIM
-- ========================================================================== --
-- tele умеет свои темы (файлы в ~/.config/tele/themes/, наследование base:),
-- а catppuccin-macchiato у него вшит в бинарь. Берём его базой и перекрашиваем
-- точной палитрой mocha — той же, что у твоего colorscheme.

local PALETTES = {
  mocha = {
    base = "#1e1e2e", mantle = "#181825", crust = "#11111b",
    surface0 = "#313244", surface1 = "#45475a", surface2 = "#585b70",
    overlay0 = "#6c7086", overlay1 = "#7f849c", overlay2 = "#9399a2",
    text = "#cdd6f4", subtext1 = "#bac2de", subtext0 = "#a6adc8",
    red = "#f38ba8", maroon = "#eba0ac", peach = "#fab387", yellow = "#f9e2af",
    green = "#a6e3a1", teal = "#94e2d5", sky = "#89dceb", sapphire = "#74c7ec",
    blue = "#89b4fa", lavender = "#b4befe", mauve = "#cba6f7", pink = "#f5c2e7",
  },
  -- «как мой nvim»: init.lua красит Normal/NormalFloat в #000000, поэтому фон
  -- tele отдаём терминалу (none = видно прозрачность терминала), панели —
  -- ступени mocha.
  black = {
    base = "none", mantle = "#000000", crust = "#000000",
    surface0 = "#181825", surface1 = "#313244", surface2 = "#45475a",
    overlay0 = "#6c7086", overlay1 = "#7f849c", overlay2 = "#9399a2",
    text = "#cdd6f4", subtext1 = "#bac2de", subtext0 = "#a6adc8",
    red = "#f38ba8", maroon = "#eba0ac", peach = "#fab387", yellow = "#f9e2af",
    green = "#a6e3a1", teal = "#94e2d5", sky = "#89dceb", sapphire = "#74c7ec",
    blue = "#89b4fa", lavender = "#b4befe", mauve = "#cba6f7", pink = "#f5c2e7",
  },
}

--- { токен tele, ключ палитры }. Имена токенов — themes/catppuccin-macchiato.yml
--- tele и docs/themes.md; неизвестный теле токен он игнорирует с предупреждением,
--- так что список можно смело расширять после обновления tele.
local TOKENS = {
  { "background", "base" },
  { "surface_overlay", "surface0" }, { "surface_help", "surface0" },
  { "surface_toast", "surface1" }, { "surface_status_bar", "mantle" },
  { "surface_selected", "blue" }, { "surface_self_mention", "pink" },
  { "surface_code", "mantle" },
  { "text", "text" }, { "text_dim", "overlay1" }, { "text_muted", "overlay0" },
  { "text_faint", "overlay0" }, { "text_subtle", "subtext0" },
  { "text_on_surface", "text" }, { "text_status_bar", "text" },
  { "text_on_selected", "crust" }, { "text_on_toast", "text" },
  { "text_mode_label", "crust" }, { "text_code", "text" },
  { "accent", "blue" }, { "accent_on_surface", "blue" },
  { "accent_status_bar", "blue" }, { "accent_insert", "green" },
  { "accent_mode_normal", "blue" }, { "accent_mode_insert", "green" },
  { "status_error", "red" }, { "status_warning", "peach" },
  { "status_info", "sapphire" }, { "status_online", "green" },
  { "tick_sent", "overlay1" }, { "tick_outbox", "overlay1" },
  { "tick_read", "sapphire" }, { "tick_failed", "red" },
  { "name_incoming", "green" }, { "name_editing", "yellow" },
  { "indicator", "teal" }, { "unread_separator", "sapphire" },
  { "waveform_played", "sapphire" }, { "reaction_chosen", "green" },
  { "unread_reaction", "pink" }, { "unread_mention", "blue" },
  { "border_pane_active", "green" }, { "border_bubble_in", "surface2" },
  { "border_bubble_out", "sapphire" }, { "border_overlay", "surface2" },
  { "border_composer_focused", "green" }, { "border_composer_flash", "red" },
  { "border_status_sep", "surface0" },
  { "markup_link", "sky" }, { "markup_ref", "mauve" },
  { "markup_self_mention_fg", "crust" },
  { "highlight_accent", "peach" }, { "highlight_error", "red" },
  { "highlight_base_chat", "text" }, { "highlight_base_bubble", "surface2" },
  { "overlay_dim", "overlay0" },
  { "composer_counter_dim", "overlay0" }, { "composer_glyph_idle", "overlay0" },
  { "composer_glyph_ready", "blue" },
}

local SENDER = { "red", "peach", "yellow", "green", "teal", "blue", "mauve", "pink" }

---@param which string "mocha"|"black"
function T.theme_yaml(which)
  local p = PALETTES[which] or PALETTES.mocha
  local function lit(key)
    local v = p[key]
    if not v or v == "none" then return "none" end
    return ('"%s"'):format(v) -- кавычки обязательны: иначе YAML съест # как комментарий
  end
  local out = {
    "# сгенерировано lua/config/telegram.lua (:TeleTheme) — перезапишется.",
    "#",
    "# База — штатная catppuccin-macchiato из бинаря tele, поверх — точная",
    "# палитра catppuccin-mocha, она же в lua/plugins/colorscheme.lua, поэтому",
    "# tele и редактор выглядят одним приложением.",
    "base: catppuccin-macchiato",
    "",
  }
  for _, pair in ipairs(TOKENS) do
    out[#out + 1] = ("%s: %s"):format(pair[1], lit(pair[2]))
  end
  out[#out + 1] = ""
  out[#out + 1] = "sender_palette:"
  for _, key in ipairs(SENDER) do
    out[#out + 1] = ("  - %s # %s"):format(lit(key), key)
  end
  out[#out + 1] = ""
  out[#out + 1] = "logo_gradient:"
  out[#out + 1] = ("  - { pos: 0.00, color: %s }"):format(lit("surface0"))
  out[#out + 1] = ("  - { pos: 0.35, color: %s }"):format(lit("surface2"))
  out[#out + 1] = ("  - { pos: 0.65, color: %s }"):format(lit("sapphire"))
  out[#out + 1] = ("  - { pos: 0.85, color: %s }"):format(lit("sky"))
  out[#out + 1] = ("  - { pos: 1.00, color: %s }"):format(lit("text"))
  out[#out + 1] = ""
  return table.concat(out, "\n")
end

-- ========================================================================== --
--            ТОЧЕЧНАЯ ПРАВКА ~/.config/tele/config.yml (с бэкапом)
-- ========================================================================== --
-- tele бережно читает чужие комментарии и неизвестные ключи, поэтому и мы не
-- переписываем файл целиком, а меняем/вставляем ровно нужные строки. Правим
-- конфиг другого приложения — право на ошибку нулевое, поэтому всегда пишем
-- рядом config.yml.bak.

--- Строка YAML -> key, indent, значение (nil, если это заголовок секции).
--- Комментарий (а tele генерирует сотни закомментированных строк keybindings)
--- не считается никогда.
local function yaml_entry(line)
  if not line or line:match("^%s*#") then return nil end
  local indent = #(line:match("^ *") or "")
  local key = line:match("^ *([%w_%-%?]+):")
  if not key then return nil end
  local rest = (line:match("^ *[%w_%-%?]+:%s*(.*)$") or ""):gsub("%s*#.*$", "")
  return key, indent, (vim.trim(rest) ~= "") and vim.trim(rest) or nil
end

--- Ищем ТОЛЬКО среди строк нужного отступа внутри [from, to]: иначе похожее имя
--- в чужой секции (или в `#   theme: ...` из шаблона) дал бы ложное попадание.
---@return number|nil i, string kind "section"|"scalar"
local function locate(lines, from, to, indent, key)
  for i = from, to do
    local k, ind, value = yaml_entry(lines[i])
    if k == key and ind == indent then
      return i, value == nil and "section" or "scalar"
    end
  end
  return nil
end

--- Границы тела секции: заголовок в строке i с отступом indent. Заодно
--- возвращаем ФАКТИЧЕСКИЙ детский отступ (tele пишет 2, но чужой конфиг может 4).
local function body_of(lines, i, indent, to)
  local last, child = to, nil
  for j = i + 1, to do
    local k, ind = yaml_entry(lines[j])
    if k and ind <= indent then
      last = j - 1
      break
    elseif k and not child then
      child = ind
    end
  end
  return last, child or (indent + 2)
end

local function write_lines(file, lines, why)
  local backup = file .. ".bak"
  pcall(function() vim.fn.writefile(vim.fn.readfile(file), backup) end)
  local ok, err = pcall(vim.fn.writefile, lines, file)
  if not ok then
    return false, "не записано: " .. tostring(err)
  end
  return true, ("%s · прежняя версия в %s"):format(why, backup)
end

--- @param path table путь по секциям, например {"ui","notifications","desktop"}
--- @param value string что записать (уже в YAML-нотации)
--- @return boolean ok, string why
function T.set_yaml(path, value)
  local file = config_path()
  if not file then
    return false, "~/.config/tele/config.yml не найден — первый запуск tele создаст его"
  end
  local fh = io.open(file, "r")
  if not fh then return false, "не читается: " .. file end
  local lines = {}
  for line in fh:lines() do lines[#lines + 1] = line end
  fh:close()

  local full = table.concat(path, ".")
  local from, to, indent = 1, #lines, 0

  -- спуск по секциям (последний элемент пути — это сам ключ, его не ищем тут)
  for level = 1, #path - 1 do
    local i, kind = locate(lines, from, to, indent, path[level])
    if not i then
      -- секции нет: дописываем недостающий хвост пути в конец текущего диапазона
      local pad = indent
      local at = to
      for l = level, #path - 1 do
        at = at + 1
        table.insert(lines, at, ("%s%s:"):format(string.rep(" ", pad), path[l]))
        pad = pad + 2
      end
      table.insert(lines, at + 1, ("%s%s: %s"):format(string.rep(" ", pad), path[#path], value))
      return write_lines(file, lines, ("%s = %s (секции не было — создана)"):format(full, value))
    end
    if kind == "scalar" then
      -- скаляр вместо секции (ui.theme: nord, а нам нужен ui.theme.dark) —
      -- превращаем в секцию и дописываем детей
      lines[i] = ("%s%s:"):format(string.rep(" ", indent), path[level])
      local at, child = i, indent + 2
      for l = level + 1, #path - 1 do
        at = at + 1
        table.insert(lines, at, ("%s%s:"):format(string.rep(" ", child), path[l]))
        child = child + 2
      end
      table.insert(lines, at + 1, ("%s%s: %s"):format(string.rep(" ", child), path[#path], value))
      return write_lines(file, lines, ("%s = %s (скаляр стал секцией)"):format(full, value))
    end
    local last, child = body_of(lines, i, indent, to)
    from, to, indent = i + 1, last, child
  end

  local key = path[#path]
  local pad = string.rep(" ", indent)
  local i, kind = locate(lines, from, to, indent, key)
  if i and kind == "scalar" then
    lines[i] = ("%s%s: %s"):format(pad, key, value)
    return write_lines(file, lines, ("%s = %s (строка %d)"):format(full, value, i))
  end
  if i and kind == "section" then
    -- ключ записан пустой секцией с детьми (ui.theme:\n  dark: x) -> схлопнуть
    local last = body_of(lines, i, indent, to)
    for j = last, i + 1, -1 do table.remove(lines, j) end
    lines[i] = ("%s%s: %s"):format(pad, key, value)
    return write_lines(file, lines, ("%s = %s (дети секции убраны)"):format(full, value))
  end
  -- ключа нет: вставляем в начало тела секции, отступ уже правильный
  table.insert(lines, math.min(from, to + 1), ("%s%s: %s"):format(pad, key, value))
  return write_lines(file, lines, ("%s = %s (добавлено)"):format(full, value))
end

function T.install_theme(which)
  which = which or T.opts.theme.palette
  if not PALETTES[which] then
    return T.say("не знаю палитру «" .. tostring(which) .. "»: бывает mocha или black",
      vim.log.levels.WARN)
  end
  local dir = expand("$HOME") .. "/.config/tele/themes"
  vim.fn.mkdir(dir, "p")
  local name = T.opts.theme.name
  local file = ("%s/%s.yml"):format(dir, name)
  local ok, err = pcall(vim.fn.writefile, vim.split(T.theme_yaml(which), "\n", { plain = true }), file)
  if not ok then
    return T.say("не записать " .. file .. ": " .. tostring(err), vim.log.levels.ERROR)
  end
  local applied, why = T.set_yaml({ "ui", "theme" }, name)
  T.say(("тема «%s» → %s. %s"):format(name, file,
    applied and (why .. " · перезапусти tele: q в его окне, потом <leader>mm")
      or ("включи сам: ui.theme: " .. name .. " (" .. why .. ")")))
end

--- Уведомления показывает nvim, а не ОС (чтобы не было двойни).
function T.quiet(on)
  local ok, why = T.set_yaml({ "ui", "notifications", "desktop" }, on and "false" or "true")
  T.say(("ui.notifications.desktop = %s · %s · применится со следующего запуска tele"):format(
    on and "false" or "true", why))
  if not ok then
    return T.say("вручную: в ~/.config/tele/config.yml в секции ui.notifications поставь desktop: false",
      vim.log.levels.WARN)
  end
end

-- ========================================================================== --
--                    ЧИТАЕМ ОДИН ЧАТ, НЕ ОТКРЫВАЯ tele
-- ========================================================================== --
-- Нативное окно nvim с историей: маленькое, ровно один чат, без папок и списка.
-- Так можно, потому что теле держит последние ~500 сообщений каждого
-- открывавшегося чата (store.MaxMessagesPerChat).

function T.read_chat(name, limit)
  if not name or name == "" then
    return T.say("нужно имя чата: :TeleRead <имя или кусок>, Tab подскажет варианты",
      vim.log.levels.WARN)
  end
  limit = math.floor(limit or 40)
  local sql = ("SELECT c.title AS title, m.date AS date, m.data AS data "
    .. "FROM messages m JOIN chats c ON c.id = m.chat_id "
    .. "WHERE c.title LIKE '%%%s%%' ORDER BY m.date DESC, m.msg_id DESC LIMIT %d;")
      :format((name:gsub("'", "''")), limit)

  T.sql(sql, function(rows, err)
    if not rows then
      return T.say("история не читается: " .. tostring(err), vim.log.levels.ERROR)
    end
    if #rows == 0 then
      return T.say(("в кэше tele нет сообщений чата «%s». tele хранит последние ~500 "
        .. "сообщений только тех чатов, что ты в нём открывал — открой чат в tele и повтори.")
        :format(name), vim.log.levels.WARN)
    end

    local title = rows[1].title or name
    local lines = {
      ("✈ %s  ·  %d сообщений из кэша tele  ·  %s"):format(title, #rows, os.date("%H:%M")),
      "  R — ответить через tele · o — открыть чат в tele · q — закрыть",
      "",
    }
    for i = #rows, 1, -1 do
      local r = rows[i]
      local msg = T.decode_message(r.data)
      local who = msg.author or (msg.out and "ты" or "?")
      lines[#lines + 1] = ("  %s  [%s]  %s"):format(
        os.date("%d.%m %H:%M", math.floor(num(r.date, os.time()))), who,
        msg.text ~= "" and msg.text or "…"
      )
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local win = vim.api.nvim_open_win(buf, true, { split = true, height = math.min(#lines, 26) })
    vim.bo[buf].modifiable = false
    vim.wo[win].spell = false -- window-локальная: на окно, не на буфер
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].wrap = true
    pcall(vim.api.nvim_set_option_value, "winhighlight",
      "Normal:TeleNotify,NormalFloat:TeleNotify,FloatBorder:TeleNotifyBorder", { win = win })

    local function key(lhs, rhs) vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true }) end
    key("q", function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end)
    key("R", T.reply_prompt)
    key("o", function() T.open("chat", title) end)
    T.say("история: " .. #lines .. " строк")
  end)
end

--- Выбор чата списком (из того, что есть в кэше).
function T.ask_chat(cb, prompt)
  if #T.state.titles == 0 then
    if T.state.ask_retries > 6 then
      T.state.ask_retries = 0
      return T.say("в БД tele пока нет ни одного чата: открой tele (<leader>mm) — "
        .. "список чатов появляется после первой синхронизации", vim.log.levels.WARN)
    end
    T.state.ask_retries = T.state.ask_retries + 1
    T.poll_once(true)
    return vim.defer_fn(function() T.ask_chat(cb, prompt) end, 500)
  end
  T.state.ask_retries = 0
  vim.ui.select(T.state.titles, { prompt = prompt or "✈ Чат: " }, cb)
end

-- ========================================================================== --
--                               ДИАГНОСТИКА
-- ========================================================================== --

function T.check()
  if not T.state.db then T.state.db, T.state.db_error = T.find_db() end
  local version = "?"
  if executable("sqlite3") == 1 then
    version = (vim.fn.system({ "sqlite3", "--version" }):match("^(%d+%.%d+%.?%d*)") or "?")
  end
  local tele_version = "?"
  if executable(T.opts.bin) == 1 then
    tele_version = vim.trim(vim.fn.system({ T.opts.bin, "--version" }) or "?")
    if tele_version == "" then tele_version = "?" end
  end

  local rows = {
    { "tele", "v" .. tele_version .. "  " .. (executable(T.opts.bin) == 1 and vim.fn.exepath(T.opts.bin)
        or "НЕТ В PATH — brew install tele / apt / nix / go build ./cmd/tele") },
    { "sqlite3", executable("sqlite3") == 1 and (vim.fn.exepath("sqlite3") .. "  v" .. version)
        or "НЕТ — ловить сообщения нечем (brew install sqlite / apt install sqlite3)" },
    { "state.db", T.state.db or ("НЕ НАЙДЕН · " .. tostring(T.state.db_error)) },
    { "чтение БД", T.state.mode == "ro" and "только чтение (-readonly)"
        or T.state.mode == "rw" and "обычное (WAL не даёт readonly)"
        or "ещё не выполнялось" },
    { "опрос", T.state.started and ("%d мс · тиков %d"):format(T.opts.poll, T.state.ticks) or "ВЫКЛ · :TeleStart" },
    { "чатов в кэше", tostring(vim.tbl_count(T.state.chats)) },
    { "непрочитано / чатов с @men", ("%d / %d"):format(T.state.unread_total, T.state.mention_chats) },
    { "popup", ("%s · notify=%s · snacks=%s"):format(T.opts.style,
        tostring(package.loaded["notify"] ~= nil), tostring(package.loaded["snacks"] ~= nil)) },
    { "наш процесс tele", T.state.term_job and ("job " .. T.state.term_job .. " · режим " .. tostring(T.state.term_mode))
        or "не запущен (<leader>mm / <leader>mf / <leader>mp)" },
    { "режим тишины", T.state.dnd and "ВКЛ: счётчик растёт, popup молчит (:TeleDnd)" or "выкл (:TeleDnd включит)" },
    { "фильтр focus", #T.opts.focus > 0 and table.concat(T.opts.focus, ", ") or "не задан (все чаты)" },
    { "фильтр ignore", #T.opts.ignore > 0 and table.concat(T.opts.ignore, ", ") or "не задан" },
    { "ошибка БД", T.state.db_error or "нет" },
  }

  local width = 0
  for _, r in ipairs(rows) do width = math.max(width, vim.fn.strdisplaywidth(r[1])) end
  local msg = { { "✈ ТЕЛЕГРАМ-МОСТ — ДИАГНОСТИКА\n", "Title" } }
  for _, r in ipairs(rows) do
    local bad = r[2]:find("НЕТ") or r[2]:find("ВЫКЛ") or r[2]:find("НЕ НАЙДЕН")
    msg[#msg + 1] = { ("  %-" .. width .. "s  "):format(r[1]), "Function" }
    msg[#msg + 1] = { tostring(r[2]), bad and "ErrorMsg" or "String" }
    msg[#msg + 1] = { "\n" }
  end
  msg[#msg + 1] = { "\n  Сообщения ловятся из кэша tele (state.db), поэтому tele может жить "
    .. "в ЛЮБОМ терминале, не в nvim.\n  Ответ и прыжок по чатам идут через наш PTY: они "
    .. "работают, только если tele поднят отсюда.\n", "Comment" }
  vim.api.nvim_echo(msg, true, {})
end

-- ========================================================================== --
--                     СТАРТ / СТОП / КОМАНДЫ / АВТОКОМАНДЫ
-- ========================================================================== --

function T.start()
  if T.state.started then return end
  if not T.state.db then T.state.db, T.state.db_error = T.find_db() end
  if executable("sqlite3") == 1 then
    local p = vim.fn.exepath("sqlite3")
    T.state.sqlite = (p ~= "" and p) or nil
  end
  if not T.state.sqlite then
    return T.say("sqlite3 не найден — слежение выключено. Окно tele при этом открывается "
      .. "обычно (<leader>mm). Поставь sqlite3 и выполни :TeleStart", vim.log.levels.WARN)
  end
  if not T.state.db then
    return T.say("state.db не найден · " .. tostring(T.state.db_error)
      .. " · если БД в необычном месте:  :TeleDb <путь>/state.db", vim.log.levels.WARN)
  end

  T.state.started = true
  T.state.timer = uv.new_timer()
  T.state.timer:start(300, math.max(500, T.opts.poll), vim.schedule_wrap(function() T.poll_once() end))
  T.poll_once(true)
  if T.opts.inbox_open_on_start then T.open_inbox() end
  T.refresh_status()
end

function T.stop()
  T.state.started = false
  if T.state.timer then
    T.state.timer:stop()
    T.state.timer:close()
    T.state.timer = nil
  end
  T.refresh_status()
end

function T.toggle()
  if T.state.started then
    T.stop()
    T.say("слежение за state.db выключено (:TeleStart вернуть)")
  else
    T.start()
    if T.state.started then T.say("слежу за " .. tostring(T.state.db) .. " раз в " .. T.opts.poll .. " мс") end
  end
end

function T.toggle_dnd()
  T.state.dnd = not T.state.dnd
  T.say(T.state.dnd and "тишина: входящие идут в :TeleInbox и в счётчик, popup молчит"
      or "показываем popup-ы")
  T.refresh_status()
end

local function split_list(arg)
  local out = {}
  for _, part in ipairs(vim.split(arg or "", ",", { trimempty = true })) do
    local trimmed = vim.trim(part)
    if trimmed ~= "" then out[#out + 1] = trimmed end
  end
  return out
end

function T.set_focus(arg)
  T.opts.focus = split_list(arg)
  T.say(#T.opts.focus > 0 and ("всплываем только про: " .. table.concat(T.opts.focus, ", "))
      or "всплываем про все чаты (кроме ignore и мьюта)")
end

function T.set_ignore(arg)
  T.opts.ignore = split_list(arg)
  T.say(#T.opts.ignore > 0 and ("молчим про: " .. table.concat(T.opts.ignore, ", ")) or "игнор снят")
end

function T.complete_chat(arglead)
  local out = {}
  for _, t in ipairs(T.state.titles) do
    if t:lower():find((arglead or ""):lower(), 1, true) then out[#out + 1] = t end
  end
  return out
end

local function def(name, fn, o)
  o = o or {}
  vim.api.nvim_create_user_command(name, fn, {
    desc = "✈ " .. (o.desc or name),
    nargs = o.nargs,
    range = o.range,
    complete = o.complete,
  })
end

function T.commands()
  def("Tele", function(o)
    local arg = vim.trim(o.args or "")
    local modes = { full = "full", panel = "panel", chat = "chat", small = "chat", float = "chat" }
    if arg == "" then return T.open(T.opts.mode) end
    if modes[arg:lower()] then return T.open(modes[arg:lower()]) end
    T.open("chat", arg) -- не имя режима → считаем именем чата
  end, { nargs = "?", desc = "tele: full | panel | chat | <имя чата>" })

  def("TeleFull", function() T.open("full") end, { desc = "tele на весь экран" })
  def("TelePanel", function() T.open("panel") end, { desc = "tele боковой панелью рядом с кодом" })
  def("TeleChat", function(o)
    if vim.trim(o.args or "") ~= "" then return T.open("chat", o.args) end
    T.ask_chat(function(name)
      if name then T.open("chat", name) end
    end)
  end, {
    nargs = "?",
    complete = function(lead) return T.complete_chat(lead) end,
    desc = "tele в маленьком окне, сразу на один чат",
  })
  def("TeleOpen", function()
    if not T.is_open() then T.open(T.state.term_mode or T.opts.mode) end
  end, { desc = "вернуть окно tele" })
  def("TeleHide", T.hide, { desc = "спрятать окно, процесс оставить живым" })
  def("TeleKill", T.shutdown, { desc = "убить процесс tele" })

  def("TeleInbox", T.open_inbox, { desc = "буфер истории входящих" })
  def("TeleRead", function(o) T.read_chat(o.args, 40) end, {
    nargs = 1,
    complete = function(lead) return T.complete_chat(lead) end,
    desc = "прочитать переписку чата, не открывая tele",
  })
  def("TeleChatPick", function()
    T.ask_chat(function(name)
      if name then T.read_chat(name, 60) end
    end, "✈ Чат для чтения: ")
  end, { desc = "то же, но чат выбирается списком" })
  def("TeleReply", T.reply_prompt, { desc = "ответить в tele, не выходя из кода" })
  def("TeleReplyLast", T.reply_last, { desc = "ответить в чат последнего уведомления" })
  def("TeleSend", function(o)
    -- range = true: без выделения это текущая строка; из визуального режима
    -- Neovim сам передаст '<,'> — тогда уходят ровно строки выделения.
    -- (range = "?" — НЕДОПУСТИМО: nvim_create_user_command принимает только
    -- true, "%" или число; иначе E5113 «Invalid 'range'» и setup() падает.)
    local first, last = tonumber(o.line1) or 0, tonumber(o.line2) or 0
    if last < 1 then
      T.send_lines({ vim.api.nvim_get_current_line() })
      return
    end
    T.send_lines(vim.api.nvim_buf_get_lines(0, first - 1, last, false))
  end, { range = true, desc = "отправить строки/выделение в tele как сообщение" })

  def("TeleStart", T.start, { desc = "включить слежение за state.db" })
  def("TeleStop", T.stop, { desc = "выключить слежение" })
  def("TeleToggle", T.toggle, { desc = "слежение вкл/выкл" })
  def("TeleDnd", T.toggle_dnd, { desc = "режим тишины" })
  def("TeleFocus", function(o) T.set_focus(o.args) end, { nargs = "?", desc = "всплывать только про эти чаты" })
  def("TeleIgnore", function(o) T.set_ignore(o.args) end, { nargs = "?", desc = "не всплывать про эти чаты" })

  def("TeleTheme", function(o) T.install_theme(vim.trim(o.args) ~= "" and o.args or nil) end, {
    nargs = "?",
    complete = function() return { "mocha", "black" } end,
    desc = "тема tele в палитре nvim (mocha | black)",
  })
  def("TeleQuiet", function(o) T.quiet(vim.trim(o.args):lower() ~= "off") end, {
    nargs = "?", desc = "уведомления только в nvim, без уведомления ОС",
  })
  def("TeleBell", T.toggle_bell, { desc = "гудок терминала на входящее" })
  def("TeleDb", function(o)
    T.state.db = expand(o.args)
    T.state.mode = nil
    T.state.prev = nil
    if T.state.started then T.poll_once(true) else T.start() end
  end, { nargs = 1, desc = "путь к state.db вручную" })

  def("TeleCheck", T.check, { desc = "что нашлось и что работает" })
  def("TeleStatus", function()
    vim.api.nvim_echo({ { ("✈ %s · непрочитанных %d · чатов с @men %d · окно: %s"):format(
      T.state.started and "следит" or "молчит", T.state.unread_total, T.state.mention_chats,
      T.state.term_mode or "закрыто"), "Title" } }, true, {})
  end, { desc = "краткое состояние" })
  def("TeleTest", function()
    T.popup("Тестовый чат", "Вот так выглядит уведомление. Заодно проверим перенос: "
      .. "длинная строка должна аккуратно сломаться по ширине окна, а не вылезти за край.", "message")
    T.popup("Тестовый чат", "А так выглядит упоминание @тебя — оно громче и жёлтое.", "mention")
  end, { desc = "показать, как будет выглядеть popup" })
  def("TeleDocs", function()
    vim.api.nvim_echo({ { T.cheatsheet(), "Normal" } }, true, {})
  end, { desc = "шпаргалка по клавишам и командам" })
end

function T.cheatsheet()
  return [[
✈ ТЕЛЕГРАМ В NVIM — ШПАРГАЛКА

  <leader>mm  tele в маленьком окне (плавающее, один чат после <leader>mc)
  <leader>mf  tele на весь экран   ·   <leader>mp  tele боковой панелью
  <leader>mc  выбрать чат и сесть на него   ·   <leader>mo  чат последнего уведомления
  <leader>mh  спрятать окно (процесс ЖИВЁТ, уведомления идут)
  <leader>mi  лента входящих   ·   <leader>mt  читать переписку чата без tele
  <leader>mr  ответить через tele · <leader>ms  выделение -> сообщение
  <leader>mq  ответить в чат последнего уведомления · <leader>mS  строку -> сообщение
  <leader>mn  тишина   ·   <leader>mb  гудок   ·   <leader>md  диагностика
  <leader>mk  убить процесс tele

  :TeleCheck — что нашлось и что работает   ·   :TeleTest — вид уведомления
  :TeleTheme mocha|black — тема tele в палитре nvim (перезапусти tele)
  :TeleQuiet — уведомляет только nvim, ОС молчит
  :TeleFocus Иван,#go-prod — всплывать только про эти чаты
  :TeleStop / :TeleStart — перестать / начать читать state.db

Куда смотреть, если не работает:
  state.db — кэш tele (~/.local/state/tele/state.db). tele пишет в него пачками
  раз в 2 секунды, поэтому popup приходит с задержкой до ~2-3 с. Если tele не
  запущен нигде, новые сообщения не прилетают физически: sync живёт в TUI.
  Подробности — в шапке lua/config/telegram.lua.
]]
end

function T.highlight()
  local mocha = PALETTES[T.opts.theme and T.opts.theme.palette] or PALETTES.mocha
  local function set(group, defs)
    pcall(vim.api.nvim_set_hl, 0, group, vim.tbl_extend("force", defs, { default = true }))
  end
  set("TeleNotify", { bg = mocha.base ~= "none" and mocha.base or "#1e1e2e", fg = mocha.text })
  set("TeleNotifyBorder", { fg = mocha.mauve })
  set("TeleMention", { bg = mocha.surface0, fg = mocha.yellow, bold = true })
  set("TeleMentionBorder", { fg = mocha.yellow })
  set("TeleTerm", { bg = mocha.base ~= "none" and mocha.base or "#1e1e2e", fg = mocha.text })
  set("TeleTermBorder", { fg = mocha.mauve })
  set("TeleInboxTitle", { link = "Directory" })
  set("TeleInboxUnread", { link = "DiagnosticSignWarn" })
end

-- ========================================================================== --
--                          КЛАВИШИ И WHICH-KEY
-- ========================================================================== --
-- Префикс <leader>m («messenger») свободен во всём конфиге; <leader>t* и
-- <leader>T* уже заняты переводчиком (tt/te) и toggleterm (Tt/Tv/Tg/TG), а
-- <leader>Tg к тому же git status — связывать Telegram с ними значило бы
-- вечно промахиваться.

function T.toggle_bell()
  T.opts.bell = not T.opts.bell
  T.say("гудок на входящее: " .. (T.opts.bell and "вкл" or "выкл"))
end

function T.keymaps()
  local map = vim.keymap.set
  local function n(lhs, rhs, desc)
    map("n", lhs, rhs, { desc = desc, nowait = true })
  end

  -- три способа открыть: весь экран / панель / маленький float на один чат
  n("<leader>mm", function() T.toggle_term("chat") end, "✈ tele: маленькое окно (float)")
  n("<leader>mf", function() T.toggle_term("full") end, "✈ tele: на весь экран")
  n("<leader>mp", function() T.toggle_term("panel") end, "✈ tele: боковой панелью")
  n("<leader>mh", T.hide, "✈ спрятать окно (tele останется живым)")
  n("<leader>mo", function()
    local ev = T.state.last_event
    if not ev then return T.say("последнего уведомления ещё не было", vim.log.levels.WARN) end
    T.open("chat", ev.title)
  end, "✈ открыть чат последнего уведомления")
  n("<leader>mc", function()
    T.ask_chat(function(name)
      if name then T.open("chat", name) end
    end, "✈ Открыть в tele чат: ")
  end, "✈ выбрать чат и сесть на него")

  n("<leader>mi", T.open_inbox, "✈ история входящих")
  n("<leader>mt", function()
    T.ask_chat(function(name)
      if name then T.read_chat(name, 60) end
    end, "✈ Читать переписку чата: ")
  end, "✈ прочитать чат, не открывая tele")
  n("<leader>mr", T.reply_prompt, "✈ ответить через tele")
  n("<leader>mq", T.reply_last, "✈ ответить в чат последнего уведомления")
  map("v", "<leader>ms", ":TeleSend<cr>", { desc = "✈ отправить выделение в tele" })
  n("<leader>mS", T.send_current, "✈ отправить текущую строку в tele")

  n("<leader>mn", T.toggle_dnd, "✈ режим тишины")
  n("<leader>mb", T.toggle_bell, "✈ гудок вкл/выкл")
  n("<leader>md", T.check, "✈ диагностика (:TeleCheck)")
  n("<leader>mk", function()
    T.shutdown()
    T.say("процесс tele убит (lock state_dir освобождён)")
  end, "✈ убить процесс tele")
  n("<leader>m?", function() vim.api.nvim_echo({ { T.cheatsheet(), "Normal" } }, true, {}) end,
    "✈ шпаргалка")

  -- which-key грузится на VeryLazy, регистрироваться позже него
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
      local ok, wk = pcall(require, "which-key")
      if ok and type(wk.add) == "function" then
        pcall(wk.add, { { "<leader>m", group = "TG ✈ Telegram (tele)", icon = "✈" } })
      end
    end,
  })
end

function T.setup(user_opts)
  T.opts = vim.tbl_deep_extend("force", {}, T.defaults, user_opts or {})
  T.highlight()
  T.commands()
  T.keymaps()

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("TelegramTheme", { clear = true }),
    callback = T.highlight,
    desc = "tele: popup-ы в тон теме",
  })

  -- Выход из nvim: убить tele, иначе он останется висеть с занятым state_dir
  -- и в следующем nvim не откроется («tele is already running»).
  if T.opts.kill_on_exit then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      pattern = "*",
      callback = T.shutdown,
      desc = "tele: закрыть процесс при выходе из nvim",
    })
  end

  -- Буфер терминала wipe-нули (закрыли совсем) — забыть его, иначе полезем
  -- в несуществующий job.
  vim.api.nvim_create_autocmd("BufWipeout", {
    pattern = "*",
    callback = function()
      if T.state.term_buf and not vim.api.nvim_buf_is_valid(T.state.term_buf) then
        T.state.term, T.state.term_buf, T.state.term_job = nil, nil, nil
      end
    end,
    desc = "tele: забыть буфер терминала после wipe",
  })

  vim.defer_fn(T.start, 700)
end

return T
