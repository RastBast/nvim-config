-- ========================================================================== --
--        TUI-УТИЛИТЫ ВНУТРИ NEOVIM: <leader>U (как Tele — плавающее окно)        --
-- ========================================================================== --
-- Каждая утилита открывается в плавающем терминале через config.termcmd.
-- Окно можно закрыть (q внутри терминала, или ещё раз клавишу) — процесс не
-- умирает, он висит в фоне, как Tele. Вернуться: та же клавиша.
--
--   <leader>U  🧰 группа «TUI-утилиты»
--     Uk  k9s            — Kubernetes: поды, сервисы, логи, контексты
--     Ur  iredis         — Redis с автодополнением и подсветкой
--     Uc  redis-cli      — Redis, классический клиент
--     Up  pgcli          — PostgreSQL с автодополнением (psql-подобный)
--     Ul  lazysql        — TUI-клиент БД: PostgreSQL, MySQL, SQLite, MSSQL
--     Ud  lazydocker     — Docker: контейнеры, логи, образы
--     Ui  dive           — слои Docker-образа (спросит имя образа)
--     Ub  btop           — монитор процессов и ресурсов
--     Ua  ktea           — Kafka: топики, группы, сообщения
--     Uu  меню всех утилит (выбор списком)
--     Uh  проверка: что установлено и как поставить недостающее
--   :Tui       — то же, что <leader>Uu
--   :TuiCheck  — то же, что <leader>Uh
--
-- Адреса подключений — из переменных окружения, пароли в файлы не пишутся:
--   NVIM_REDIS_URL   redis://[user:пароль@]host:6379/0   → iredis, redis-cli
--   NVIM_DB_PG       postgresql://user@host/db           → pgcli (та же, что у <leader>Dp)
-- Без переменной утилита стартует со своими настройками (localhost / PG-переменные).
--
-- Что НЕ входит сюда (уже есть в других местах):
--   gh-dash (<leader>Gh), glab-tui (<leader>Gl), lazygit (<leader>gg), discordo (<leader>Hyd).
local M = {}

local termcmd = require("config.termcmd")

-- Подстановка переменной в команду; если её нет — команда без аргументов.
local function with_url(bin, env_name, flag)
  local url = vim.env[env_name]
  if url and url ~= "" then
    local arg = vim.fn.shellescape(url)
    return flag == "" and (bin .. " " .. arg) or (bin .. " " .. flag .. " " .. arg)
  end
  return bin
end

M.tools = {
  {
    key = "k", bin = "k9s", icon = "☸", name = "k9s",
    what = "Kubernetes: поды, сервисы, логи, контексты",
    cmd = function() return "k9s" end,
    hint = "brew install derailed/k9s/k9s · https://k9scli.io (нужен kubeconfig)",
  },
  {
    key = "r", bin = "iredis", icon = "🟥", name = "iredis",
    what = "Redis: автодополнение, подсветка, история",
    cmd = function() return with_url("iredis", "NVIM_REDIS_URL", "--url") end,
    hint = "brew install iredis · pipx install iredis",
  },
  {
    key = "c", bin = "redis-cli", icon = "🟥", name = "redis-cli",
    what = "Redis: классический клиент (команды в одну строку)",
    cmd = function() return with_url("redis-cli", "NVIM_REDIS_URL", "-u") end,
    hint = "brew install redis",
  },
  {
    key = "p", bin = "pgcli", icon = "🐘", name = "pgcli",
    what = "PostgreSQL: автодополнение таблиц и колонок",
    cmd = function() return with_url("pgcli", "NVIM_DB_PG", "") end,
    hint = "brew install pgcli · pipx install pgcli",
  },
  {
    key = "l", bin = "lazysql", icon = "🗄", name = "lazysql",
    what = "TUI-клиент БД: PostgreSQL, MySQL, SQLite, MSSQL (подключения — внутри)",
    cmd = function() return "lazysql" end,
    hint = "brew install lazysql · go install github.com/jorgerojas26/lazysql@latest",
  },
  {
    key = "d", bin = "lazydocker", icon = "🐳", name = "lazydocker",
    what = "Docker: контейнеры, логи, образы, сети",
    cmd = function() return "lazydocker" end,
    hint = "brew install lazydocker",
  },
  {
    key = "i", bin = "dive", icon = "🔬", name = "dive",
    what = "Docker: слои образа и что в каждом слое (спросит имя образа)",
    cmd = nil, -- имя образа спрашиваем при запуске, см. M.run_dive
    hint = "brew install dive · https://github.com/wagoodman/dive",
  },
  {
    key = "b", bin = "btop", icon = "📈", name = "btop",
    what = "Процессы, CPU, память, диски, сеть",
    cmd = function() return "btop" end,
    hint = "brew install btop",
  },
  {
    key = "a", bin = "ktea", icon = "📨", name = "ktea",
    what = "Kafka: топики, consumer-группы, сообщения",
    cmd = function() return "ktea" end,
    hint = "https://github.com/jonas-grgt/ktea",
  },
}

-- Подсказки установки — в общий словарь termcmd (его читают все утилиты)
for _, t in ipairs(M.tools) do
  termcmd.hints[t.bin] = termcmd.hints[t.bin] or t.hint
end

--- Запуск dive: спрашиваем образ. Пустой ввод — отмена.
function M.run_dive()
  if vim.fn.executable("dive") == 0 then
    vim.notify("Команда «dive» не найдена.\n" .. termcmd.hints.dive, vim.log.levels.WARN)
    return
  end
  vim.ui.input({ prompt = "🔬 Образ для dive (например myapp:latest): " }, function(img)
    if not img or vim.trim(img) == "" then
      return
    end
    termcmd.make("dive " .. vim.fn.shellescape(vim.trim(img)), 0, "dive " .. vim.trim(img))()
  end)
end

--- Запуск одной утилиты по записи из M.tools.
function M.run(t)
  if t.cmd == nil then
    return M.run_dive()
  end
  termcmd.make(t.cmd(), 0, t.name)()
end

--- Меню всех утилит.
function M.pick()
  local items = {}
  for _, t in ipairs(M.tools) do
    items[#items + 1] = t
  end
  vim.ui.select(items, {
    prompt = "🧰 TUI-утилиты",
    format_item = function(t)
      local mark = vim.fn.executable(t.bin) == 1 and "✓" or "✗"
      return ("%s %s %s — %s"):format(mark, t.icon, t.name, t.what)
    end,
  }, function(choice)
    if choice then
      M.run(choice)
    end
  end)
end

--- Проверка: что установлено, что нет (и как поставить), и переменные подключений.
function M.check()
  local lines = { "🩺 TUI-утилиты: проверка" }
  for _, t in ipairs(M.tools) do
    if vim.fn.executable(t.bin) == 1 then
      lines[#lines + 1] = ("✓ %s — установлено"):format(t.name)
    else
      lines[#lines + 1] = ("✗ %s — нет. Установка: %s"):format(t.name, t.hint)
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Адреса подключений (переменные окружения, не файлы):"
  lines[#lines + 1] = "  NVIM_REDIS_URL: " .. (vim.env.NVIM_REDIS_URL and "задана" or "не задана (localhost:6379)")
  lines[#lines + 1] = "  NVIM_DB_PG:     " .. (vim.env.NVIM_DB_PG and "задана" or "не задана (PG-переменные оболочки)")
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

function M.setup()
  for _, t in ipairs(M.tools) do
    vim.keymap.set("n", "<leader>U" .. t.key, function()
      M.run(t)
    end, { desc = t.icon .. " " .. t.name .. " — " .. t.what })
  end
  vim.keymap.set("n", "<leader>Uu", M.pick, { desc = "🧰 Все TUI-утилиты (меню)" })
  vim.keymap.set("n", "<leader>Uh", M.check, { desc = "🩺 Проверить TUI-утилиты (что установлено)" })
  vim.api.nvim_create_user_command("Tui", M.pick, { desc = "🧰 Меню TUI-утилит" })
  vim.api.nvim_create_user_command("TuiCheck", M.check, { desc = "🩺 Проверка TUI-утилит" })
end

return M
