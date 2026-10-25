-- ========================================================================== --
--             ЗАПУСК УТИЛИТ В ПЛАВАЮЩЕМ ТЕРМИНАЛЕ (toggleterm)               --
-- ========================================================================== --
-- Общий обработчик для Docker (lazydocker), Kubernetes (k9s), Kafka (ktea,
-- kafkactl) и клиентов БД. Если утилиты нет в PATH — понятное уведомление
-- со ссылкой и выход. Никаких обходных путей и заглушек.
local M = {}

-- Где взять утилиту, если её нет в PATH
M.hints = {
  lazydocker = "https://github.com/jesseduffield/lazydocker",
  k9s = "https://k9scli.io",
  ktea = "https://github.com/jonas-grgt/ktea",
  kafkactl = "https://github.com/fgrosse/kafkactl",
  kubectl = "https://kubernetes.io/docs/tasks/tools/",
  docker = "https://docs.docker.com/get-docker/",
  sqlite3 = "brew install sqlite / apt install sqlite3",
  mysql = "brew install mysql-client / apt install mysql-client",
  psql = "brew install libpq / apt install postgresql-client",
  sqlplus = "Oracle Instant Client: https://www.oracle.com/database/technologies/instant-client.html",
  sqlcmd = "brew install sqlcmd / Microsoft mssql-tools",
  clickhouse = "https://clickhouse.com/docs/install",
  gh = "brew install gh && gh auth login && gh extension install dlvhdr/gh-dash",
  ["gitlab-tui"] = "cargo install gitlab-tui · токен GitLab в ~/.netrc · https://github.com/niklastreml/gitlab-tui",
  ["glab-tui"] = "https://github.com/rcieri/glab-tui (нужен glab: brew install glab && glab auth login)",
}

-- Номера терминалов toggleterm. Раньше их задавали руками, и они совпадали:
-- k9s и gh dash оба были 120, kubectl pods и GitLab — 121. Из-за этого разные
-- утилиты могли делить один терминал. Теперь номер выдаётся по самой команде:
-- одна и та же команда — тот же терминал, разные команды — разные.
local term_ids, next_term_id = {}, 200
local function id_for(cmd)
  if not term_ids[cmd] then
    term_ids[cmd] = next_term_id
    next_term_id = next_term_id + 1
  end
  return term_ids[cmd]
end

--- Обработчик клавиши: открыть `cmd` в плавающем терминале.
---@param cmd string   команда целиком, например "k9s -n default"
---@param _id number   не используется (оставлен для совместимости вызовов); номер — id_for(cmd)
---@param title string
---@return function
function M.make(cmd, _id, title)
  local id = id_for(cmd)
  return function()
    local bin = cmd:match("^(%S+)")
    if vim.fn.executable(bin) == 0 then
      local hint = M.hints[bin] or "установи её и перезапусти Neovim"
      vim.notify(
        ("Команда «%s» не найдена в PATH.\n%s"):format(bin, hint),
        vim.log.levels.WARN
      )
      return
    end
    local Terminal = require("toggleterm.terminal").Terminal
    Terminal:new({
      cmd = cmd,
      direction = "float",
      id = id,
      name = title,
      close_on_exit = true,
      float_opts = {
        border = "curved",
        width = math.floor(vim.o.columns * 0.85),
        height = math.floor(vim.o.lines * 0.8),
      },
    }):toggle()
  end
end

return M
