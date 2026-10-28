-- ========================================================================== --
--             GITHUB · GITLAB · ХАБР — прямо в Neovim                       --
-- ========================================================================== --
-- <leader>Gh  — GitHub: дашборд PR и issues (gh dash) в плавающем терминале
-- <leader>Gl  — GitLab: merge requests и issues (glab-tui) в терминале
-- <leader>Gb  — Хабр: список свежих статей → статья во вкладке, читается в nvim
-- :Habr        — то же, что <leader>Gb
--
-- Требования (ставятся один раз на Mac):
--   GitHub: brew install gh && gh auth login && gh extension install dlvhdr/gh-dash
--   GitLab: brew install glab && glab auth login && установка glab-tui (github.com/rcieri/glab-tui)
--   Хабр:   curl (есть в macOS). pandoc — по желанию, даёт аккуратную разметку.
local M = {}

local termcmd = require("config.termcmd")

-- ---------------------------------------------------------------------------
-- GitHub / GitLab: терминальные TUI
-- ---------------------------------------------------------------------------

local function gh_dash_installed()
  if vim.fn.executable("gh") == 0 then
    return false, "Нет команды «gh». Установи: brew install gh && gh auth login"
  end
  local out = vim.fn.system({ "gh", "extension", "list" })
  if not out:find("gh-dash", 1, true) then
    return false, "Не установлено расширение gh-dash. Выполни: gh extension install dlvhdr/gh-dash"
  end
  return true
end

local function github_dash()
  local ok, why = gh_dash_installed()
  if not ok then
    vim.notify(why, vim.log.levels.WARN)
    return
  end
  termcmd.make("gh dash", 120, "GitHub (gh dash)")()
end

local GITLAB_BIN = "glab-tui" -- альтернатива: "gitlab-tui" (см. README проекта)

local function gitlab_tui()
  termcmd.make(GITLAB_BIN, 121, "GitLab (" .. GITLAB_BIN .. ")")()
end

-- ---------------------------------------------------------------------------
-- Хабр: лента и чтение статьи
-- ---------------------------------------------------------------------------

local FEED = "https://habr.com/ru/rss/articles/"
local API = "https://habr.com/kek/v2/articles/"

local ENT = {
  amp = "&", lt = "<", gt = ">", quot = '"', apos = "'", nbsp = " ",
  mdash = "—", ndash = "–", laquo = "«", raquo = "»", hellip = "…",
}

local function decode_entities(s)
  s = s:gsub("&#x(%x+);", function(h)
    return utf8.char(tonumber(h, 16))
  end)
  s = s:gsub("&#(%d+);", function(d)
    return utf8.char(tonumber(d))
  end)
  s = s:gsub("&(%a+);", function(n)
    return ENT[n] or ("&" .. n .. ";")
  end)
  return s
end

--- Простая конвертация HTML → текст (Markdown-подобный), без внешних зависимостей.
function M.html_to_text_lua(html)
  html = html:gsub("<[Pp][Rr][Ee][^>]*>", "\n```\n")
  html = html:gsub("</[Pp][Rr][Ee]>", "\n```\n")
  html = html:gsub("<[Bb][Rr]%s*/?>", "\n")
  html = html:gsub("<[Ll][Ii][^>]*>", "\n• ")
  html = html:gsub("</[Pp]>", "\n\n")
  html = html:gsub("<[Pp][^>]*>", "")
  html = html:gsub("<[Hh]([1-6])[^>]*>", function(l)
    return "\n\n" .. string.rep("#", tonumber(l)) .. " "
  end)
  html = html:gsub("</[Hh][1-6]>", "\n\n")
  html = html:gsub("<[^>]+>", "")
  html = decode_entities(html)
  html = html:gsub("\r", "")
  html = html:gsub("[ \t]+\n", "\n")
  html = html:gsub("\n\n\n+", "\n\n")
  return vim.trim(html)
end

--- Если есть pandoc — он даёт лучшую разметку, иначе встроенный конвертер.
local function html_to_text(html, cb)
  if vim.fn.executable("pandoc") == 1 then
    vim.system({ "pandoc", "-f", "html", "-t", "gfm", "--wrap=none" }, { stdin = html, text = true }, function(res)
      vim.schedule(function()
        if res.code == 0 and res.stdout and res.stdout ~= "" then
          cb(vim.trim(res.stdout))
        else
          cb(M.html_to_text_lua(html))
        end
      end)
    end)
  else
    cb(M.html_to_text_lua(html))
  end
end

local function fetch(url, cb)
  vim.system({ "curl", "-sSL", "--max-time", "12", "-A", "Mozilla/5.0", url }, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        cb(nil, "curl: код " .. tostring(res.code) .. " (" .. url .. ")")
      else
        cb(res.stdout or "", nil)
      end
    end)
  end)
end

--- Разбор RSS: список {id, title, link, date}.
function M.parse_feed(xml)
  local items = {}
  for block in xml:gmatch("<item>(.-)</item>") do
    local id = block:match("habr%.com/ru/articles/(%d+)")
    local title = block:match("CDATA%[(.-)%]%]>") or block:match("<title>(.-)</title>")
    local date = block:match("<pubDate>(.-)</pubDate>")
    if id and title then
      items[#items + 1] = {
        id = id,
        title = decode_entities(vim.trim(title)),
        link = "https://habr.com/ru/articles/" .. id .. "/",
        date = date and (date:match("%d+ %a+ %d+ %d+:%d+") or date) or "",
      }
    end
  end
  return items
end

local function show_article(item, data)
  vim.cmd("tabnew")
  local buf = vim.api.nvim_get_current_buf()
  local header = {
    "# " .. item.title,
    "",
    ("Автор: %s · Опубликовано: %s"):format(
      (data.author and data.author.fullname) or "—",
      data.timePublished or item.date or "—"
    ),
    "Ссылка: " .. item.link,
    "",
    "----",
    "",
  }
  local body = vim.split(data.body or "", "\n", { plain = true })
  local lines = {}
  vim.list_extend(lines, header)
  vim.list_extend(lines, body)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.api.nvim_buf_set_name(buf, "habr://" .. item.id)

  local win = vim.api.nvim_get_current_win()
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].breakindent = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].spell = false

  vim.keymap.set("n", "q", "<cmd>tabclose<cr>", { buffer = buf, desc = "Закрыть статью" })
  vim.keymap.set("n", "o", function()
    vim.fn.jobstart({ "open", item.link }, { detach = true })
  end, { buffer = buf, desc = "Открыть статью в браузере" })
end

local function open_article(item)
  vim.notify("Хабр: загружаю «" .. item.title .. "»…", vim.log.levels.INFO)
  fetch(API .. item.id .. "/?fl=ru&hl=ru", function(body, err)
    if err then
      vim.notify("Хабр: не удалось загрузить статью. " .. err, vim.log.levels.ERROR)
      return
    end
    local ok, data = pcall(vim.json.decode, body)
    if not ok or type(data) ~= "table" or not data.textHtml then
      vim.notify("Хабр: статья не разобралась (возможно, она только для подписчиков).", vim.log.levels.WARN)
      return
    end
    html_to_text(data.textHtml, function(text)
      show_article(item, {
        body = text,
        author = data.author,
        timePublished = data.timePublished and data.timePublished:gsub("T", " "):gsub("%+.*$", "") or nil,
      })
    end)
  end)
end

function M.habr()
  vim.notify("Хабр: загружаю ленту…", vim.log.levels.INFO)
  fetch(FEED, function(xml, err)
    if err then
      vim.notify("Хабр: лента недоступна. " .. err, vim.log.levels.ERROR)
      return
    end
    local items = M.parse_feed(xml or "")
    if #items == 0 then
      vim.notify("Хабр: в ленте не нашлось статей.", vim.log.levels.WARN)
      return
    end
    vim.ui.select(items, {
      prompt = "📰 Хабр — свежие статьи",
      format_item = function(it)
        return ("%s  %s"):format(it.date, it.title)
      end,
    }, function(choice)
      if choice then
        open_article(choice)
      end
    end)
  end)
end

-- ---------------------------------------------------------------------------

function M.setup()
  vim.keymap.set("n", "<leader>Gh", github_dash, { desc = "🐙 GitHub: дашборд PR и issues (gh dash)" })
  vim.keymap.set("n", "<leader>Gl", gitlab_tui, { desc = "🦊 GitLab: MR и issues (glab-tui)" })
  vim.keymap.set("n", "<leader>Gb", M.habr, { desc = "📰 Хабр: читать статьи во вкладке" })
  vim.api.nvim_create_user_command("Habr", M.habr, { desc = "Хабр: лента и чтение статьи" })
end

return M
