-- ========================================================================== --
--                 БАЗЫ ДАННЫХ: КАТАЛОГ <leader>D → СУБД → КОМАНДЫ             --
-- ========================================================================== --
-- <leader>D  → выбор СУБД (группа) → команды этой СУБД:
--   c  🔌 подключиться (интерактивная консоль через vim-dadbod)
--   r  ▶  выполнить: буфер (normal) или выделение (visual) — ТОЛЬКО в SQL-буфере
--   t  📋 список таблиц
--   d  🔍 описание таблицы (спросит имя)
--   n  📄 новый SQL-буфер, привязанный к подключению
--   u  🗄 панель vim-dadbod-ui (DBUI)
--
-- Адреса подключений: переменная окружения (NVIM_DB_SQLITE, NVIM_DB_MYSQL,
-- NVIM_DB_PG, NVIM_DB_ORACLE, NVIM_DB_MSSQL, NVIM_DB_CLICKHOUSE) или ввод при
-- первом обращении. Пароли НЕ пишутся в файлы — только на время сессии
-- (vim.g.nvim_db_urls). Спецсимволы в пароле — в виде %XX (см. :h dadbod-url).
--
-- Клиентские утилиты (sqlite3, mysql, psql, sqlplus, sqlcmd, clickhouse) — системные.
-- Если их нет, отсюда будет понятное сообщение со ссылкой, без обходных путей.
local M = {}

local termcmd = require("config.termcmd")

-- key — буква в <leader>D<key>…; bins — клиенты, нужные vim-dadbod для этой СУБД
M.dbs = {
  {
    key = "s", name = "SQLite", icon = "🪶", env = "NVIM_DB_SQLITE",
    example = "sqlite:./app.db", bins = { "sqlite3" },
    tables = "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name;",
    describe = function(t) return ("PRAGMA table_info(%s);"):format(t) end,
  },
  {
    key = "m", name = "MySQL / MariaDB", icon = "🐬", env = "NVIM_DB_MYSQL",
    example = "mysql://user@localhost/app", bins = { "mysql" },
    tables = "SHOW TABLES;",
    describe = function(t) return ("DESCRIBE %s;"):format(t) end,
  },
  {
    key = "p", name = "PostgreSQL", icon = "🐘", env = "NVIM_DB_PG",
    example = "postgresql://user@localhost/app", bins = { "psql" },
    tables = "\\dt",
    describe = function(t) return ("\\d %s"):format(t) end,
  },
  {
    key = "o", name = "Oracle", icon = "🏛", env = "NVIM_DB_ORACLE",
    example = "oracle://user:pass@host:1521/service", bins = { "sqlplus" },
    tables = "SELECT table_name FROM user_tables ORDER BY table_name;",
    describe = function(t) return ("DESCRIBE %s"):format(t) end,
  },
  {
    key = "x", name = "SQL Server", icon = "🟦", env = "NVIM_DB_MSSQL",
    example = "sqlserver://user:pass@host:1433/app", bins = { "sqlcmd" },
    tables = "SELECT name FROM sys.tables ORDER BY name;",
    describe = function(t) return ("EXEC sp_help '%s';"):format(t) end,
  },
  {
    key = "c", name = "ClickHouse", icon = "🏠", env = "NVIM_DB_CLICKHOUSE",
    example = "clickhouse://user:pass@host:9000/app", bins = { "clickhouse", "clickhouse-client" },
    tables = "SHOW TABLES;",
    describe = function(t) return ("DESCRIBE TABLE %s;"):format(t) end,
  },
}

local ACTIONS = {
  { id = "c", desc = "🔌 Подключиться (консоль)" },
  { id = "r", desc = "▶ Выполнить буфер / выделение (SQL)" },
  { id = "t", desc = "📋 Список таблиц" },
  { id = "d", desc = "🔍 Описание таблицы" },
  { id = "n", desc = "📄 Новый SQL-буфер с подключением" },
  { id = "u", desc = "🗄 Панель DBUI" },
}

local function by_key(key)
  for _, db in ipairs(M.dbs) do
    if db.key == key then return db end
  end
end

local function has_client(db)
  for _, bin in ipairs(db.bins) do
    if vim.fn.executable(bin) == 1 then return true end
  end
  local hint = termcmd.hints[db.bins[1]] or "установи клиент и перезапусти Neovim"
  vim.notify(("Клиент «%s» не найден в PATH.\n%s"):format(db.bins[1], hint), vim.log.levels.WARN)
  return false
end

--- Получить URL: из кэша сессии → из переменной окружения → спросить (не сохраняется в файлы).
local function with_url(db, fn)
  local urls = vim.g.nvim_db_urls or {}
  local url = urls[db.key] or os.getenv(db.env)
  if url and url ~= "" then
    urls[db.key] = url
    vim.g.nvim_db_urls = urls
    return fn(url)
  end
  vim.ui.input({ prompt = ("URL для %s (%s): "):format(db.name, db.example) }, function(input)
    if not input or input == "" then return end
    local cache = vim.g.nvim_db_urls or {}
    cache[db.key] = input
    vim.g.nvim_db_urls = cache
    fn(input)
  end)
end

local function is_sql_buffer()
  if vim.bo.filetype == "sql" then return true end
  vim.notify("Выполнение запросов — из SQL-буфера (filetype sql).\n"
    .. "Открой .sql или создай буфер через «Новый SQL-буфер» в каталоге СУБД.",
    vim.log.levels.WARN)
  return false
end

--- Новый scratch-буфер (sql) внизу экрана с подключением; опционально сразу выполнить.
local function scratch(db, url, lines, title, run)
  vim.cmd("botright 12new")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "sql"
  pcall(vim.api.nvim_buf_set_name, buf, ("db-%s-%s-%d"):format(db.key, title, buf))
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.b[buf].db = url
  if run then vim.cmd("%DB") end
end

local function header(db)
  return {
    ("-- %s %s"):format(db.icon, db.name),
    ("-- Выполнить буфер: <leader>D%sr   ·  выделение: выдели и <leader>D%sr"):format(db.key, db.key),
    "",
  }
end

function M.connect(db)
  if not has_client(db) then return end
  with_url(db, function(url)
    vim.cmd("DB " .. url) -- интерактивная консоль vim-dadbod
  end)
end

function M.run_buffer(db)
  if not is_sql_buffer() or not has_client(db) then return end
  with_url(db, function(url)
    vim.b.db = url
    vim.cmd("%DB")
  end)
end

function M.run_visual(key)
  local db = by_key(key)
  if not db or not is_sql_buffer() or not has_client(db) then return end
  local first, last = vim.fn.line("'<"), vim.fn.line("'>")
  with_url(db, function(url)
    vim.b.db = url
    vim.cmd(("%d,%dDB"):format(first, last))
  end)
end

function M.tables(db)
  if not has_client(db) then return end
  with_url(db, function(url)
    scratch(db, url, { db.tables }, "tables", true)
  end)
end

function M.describe(db)
  if not has_client(db) then return end
  with_url(db, function(url)
    vim.ui.input({ prompt = "Имя таблицы: " }, function(name)
      if not name or name == "" then return end
      if not name:match("^[%w_%.%$]+$") then
        vim.notify("Имя таблицы: только буквы, цифры, _ . $", vim.log.levels.WARN)
        return
      end
      scratch(db, url, { db.describe(name) }, "describe", true)
    end)
  end)
end

function M.new_buffer(db)
  if not has_client(db) then return end
  with_url(db, function(url)
    scratch(db, url, header(db), "new", false)
  end)
end

function M.dbui(db)
  vim.cmd("DBUI")
end

local HANDLERS = {
  c = M.connect,
  r = M.run_buffer,
  t = M.tables,
  d = M.describe,
  n = M.new_buffer,
  u = M.dbui,
}

--- Обработчик для клавиши: act("s", "t") → список таблиц SQLite.
function M.act(key, action)
  local db = by_key(key)
  if not db then return end
  HANDLERS[action](db)
end

--- Клавиши для lazy.nvim (keys = …). Подписи видны в which-key сразу.
function M.keys()
  local out = {}
  for _, db in ipairs(M.dbs) do
    for _, a in ipairs(ACTIONS) do
      local lhs = "<leader>D" .. db.key .. a.id
      local short = (a.desc:gsub("^%S+%s*", ""))
      local desc = ("%s %s: %s"):format(db.icon, db.name, short)
      if a.id == "r" then
        out[#out + 1] = {
          lhs,
          function() M.act(db.key, "r") end,
          mode = "n",
          desc = desc,
        }
        out[#out + 1] = {
          lhs,
          (":<C-u>lua require('config.db_menu').run_visual('%s')<cr>"):format(db.key),
          mode = "x",
          desc = desc,
        }
      else
        out[#out + 1] = {
          lhs,
          function() M.act(db.key, a.id) end,
          desc = desc,
        }
      end
    end
  end
  return out
end

return M
