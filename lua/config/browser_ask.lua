-- ========================================================================== --
--              ЗАПРОС В БРАУЗЕР: спросил в Neovim → ответ в Firefox          --
-- ========================================================================== --
-- <leader>Ab  (обычный режим): Neovim спрашивает запрос, открывает Firefox
--             с готовым поиском/ответом.
-- Сервис выбирается префиксом в начале запроса:
--   P=как сделать X    → Perplexity   (можно и ?P=как сделать X)
--   G=как сделать X    → Google       (можно и ?G=как сделать X)
--   D= / C=            → DuckDuckGo / ChatGPT
--   без префикса       → сервис по умолчанию (M.engine)
-- <leader>Ab  (визуальный):    в запрос сразу подставляется выделенный текст.
-- :Ask [текст]                 то же из командной строки.
--
-- Сервис выбирается в M.engine. Поддерживаемые ключи: см. ENGINES.
-- Firefox на macOS вызывается через `open -a Firefox`, на Linux — `firefox`.
local M = {}

local ENGINES = {
  perplexity = "https://www.perplexity.ai/search?q=", -- ответ с источниками (по умолчанию)
  duckduckgo = "https://duckduckgo.com/?q=",
  google = "https://www.google.com/search?q=",
  chatgpt = "https://chatgpt.com/?q=",
}

M.engine = "perplexity"

-- Префикс запроса → сервис
local PREFIX = {
  P = "perplexity",
  G = "google",
  D = "duckduckgo",
  C = "chatgpt",
}

local function encode(text)
  if vim.uri_encode then
    return vim.uri_encode(text, "rfc3986")
  end
  return (text:gsub("[^%w%-%._~]", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

local function open_firefox(url)
  local cmd
  if vim.fn.has("mac") == 1 then
    cmd = { "open", "-a", "Firefox", url }
  else
    cmd = { "firefox", url }
  end
  if vim.fn.executable(cmd[1]) == 0 then
    vim.notify("Команда «" .. cmd[1] .. "» не найдена. Установи Firefox или поправь open_firefox().", vim.log.levels.ERROR)
    return
  end
  vim.fn.jobstart(cmd, { detach = true })
end

--- Разбор запроса: возвращает сервис и текст без префикса.
--- «P=текст», «?P=текст», «G=текст», «?G=текст» и т. д.
function M.parse(query)
  query = vim.trim(query or "")
  local key, rest = query:match("^%??([PGDCpgdc])=(.*)$")
  if key then
    return PREFIX[key:upper()], vim.trim(rest)
  end
  return M.engine, query
end

--- Открыть запрос в браузере. Пустой запрос ничего не делает.
function M.ask(query)
  local engine, text = M.parse(query)
  if text == "" then
    vim.notify("Пустой запрос: напиши текст после префикса (например P=как ...)", vim.log.levels.WARN)
    return
  end
  local base = ENGINES[engine] or ENGINES[M.engine] or ENGINES.perplexity
  open_firefox(base .. encode(text))
end

--- Спросить через ввод (vim.ui.input), с необязательным текстом по умолчанию.
function M.prompt(default)
  vim.ui.input({ prompt = "Запрос в Firefox (P= Perplexity, G= Google): ", default = default or "" }, function(text)
    if text == nil then
      return -- отмена (Esc)
    end
    M.ask(text)
  end)
end

local function visual_selection()
  local mode = vim.fn.mode()
  local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
  return table.concat(lines, " ")
end

function M.setup()
  vim.keymap.set("n", "<leader>Ab", function()
    M.prompt("")
  end, { desc = "🦊 Спросить в Firefox (запрос)" })

  vim.keymap.set("x", "<leader>Ab", function()
    local text = visual_selection()
    -- Выходим из визуального режима до показа ввода
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
    M.prompt(text)
  end, { desc = "🦊 Спросить в Firefox (выделение)" })

  vim.api.nvim_create_user_command("Ask", function(opts)
    if opts.args == "" then
      M.prompt("")
    else
      M.ask(opts.args)
    end
  end, { nargs = "*", desc = "Открыть запрос в Firefox" })
end

return M
