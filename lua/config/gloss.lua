-- ========================================================================== --
--        АНГЛИЙСКИЙ ПО СЛОВАМ: перевод выделения с разбором (учим язык)        --
-- ========================================================================== --
-- Что делает:
--   * визуальный режим, выделил фразу или предложение, нажал K — откроется окно:
--       1) перевод всей фразы на русский;
--       2) таблица «слово — часть речи — перевод» в порядке следования в тексте.
--   * <leader>Kw — то же для слова под курсором.
--   * :Gloss — то же для диапазона строк (например :'<,'>Gloss).
--
-- Откуда данные:
--   * перевод фразы и каждого слова — lua/config/ru_util.lua (DeepL, если задан
--     DEEPL_API_KEY; иначе Google/MyMemory, как у подсказок K);
--   * часть речи — бесплатный словарь dictionaryapi.dev (без ключа). Если слова
--     там нет (например, форма «running»), колонка показывает «—».
--
-- Ограничения (честно):
--   * DeepL не выдаёт грамматику. Поэтому грамматика здесь = часть речи из словаря
--     и перевод словаря, а не разбор времён и падежей.
--   * Слова переводятся по отдельности, без контекста фразы: «bank» даст «банк»
--     даже в значении «берег». Для этого есть перевод фразы под таблицей.
--   * За раз разбирается не больше MAX_WORDS слов (защита от большого выделения).

local M = {}

local RU = require("config.ru_util")

local MAX_WORDS = 40
local POS_URL = "https://api.dictionaryapi.dev/api/v2/entries/en/"

-- Части речи по-русски (ключи — то, что отдаёт словарь)
local POS_RU = {
  noun = "существительное",
  verb = "глагол",
  adjective = "прилагательное",
  adverb = "наречие",
  pronoun = "местоимение",
  preposition = "предлог",
  conjunction = "союз",
  interjection = "междометие",
  exclamation = "междометие",
  determiner = "определитель",
  article = "артикль",
  numeral = "числительное",
  abbreviation = "сокращение",
}

M.pos_cache = {} -- слово (нижний регистр) -> часть речи (строка) или false

--- Слова латиницей в порядке следования. Апостроф и дефис входят в слово.
function M.tokens(text)
  local out, seen_limit = {}, false
  for w in text:gmatch("[%a][%a'%-]*") do
    if #out >= MAX_WORDS then
      seen_limit = true
      break
    end
    out[#out + 1] = w
  end
  return out, seen_limit
end

--- Разбор ответа dictionaryapi.dev: [ {meanings=[{partOfSpeech=...}]} ]
function M.parse_pos(stdout)
  local ok, data = pcall(vim.json.decode, stdout)
  if not ok or type(data) ~= "table" or type(data[1]) ~= "table" then
    return nil
  end
  local meanings = data[1].meanings
  if type(meanings) ~= "table" or type(meanings[1]) ~= "table" then
    return nil
  end
  local pos = meanings[1].partOfSpeech
  if type(pos) == "string" and pos ~= "" then
    return pos
  end
  return nil
end

function M.pos_ru(pos)
  if not pos then
    return nil
  end
  return POS_RU[pos] or pos
end

--- Часть речи слова. cb(pos|nil), асинхронно; результат кешируется в памяти.
function M.fetch_pos(word, cb)
  local key = word:lower()
  local hit = M.pos_cache[key]
  if hit ~= nil then
    return cb(hit or nil)
  end
  vim.system({ "curl", "-sS", "--max-time", "5", POS_URL .. key }, { text = true }, function(res)
    vim.schedule(function()
      local pos = nil
      if res.code == 0 and res.stdout then
        pos = M.parse_pos(res.stdout)
      end
      M.pos_cache[key] = pos or false
      cb(pos)
    end)
  end)
end

-- Выравнивание по видимой ширине (кириллица и эмодзи учитываются)
local function pad(s, width)
  return s .. string.rep(" ", math.max(0, width - vim.fn.strdisplaywidth(s)))
end

--- Собрать строки окна из текущего состояния.
--- st = { src, sentence, rows = { {word, pos, tr}, ... }, note }
function M.render(st)
  local lines = {}
  local function add(s)
    lines[#lines + 1] = s
  end
  add("Оригинал: " .. st.src)
  add("")
  add("Перевод фразы: " .. (st.sentence or "…переводится"))
  add("")
  local wword, wpos = 0, 0
  for _, r in ipairs(st.rows) do
    wword = math.max(wword, vim.fn.strdisplaywidth(r.word))
    wpos = math.max(wpos, vim.fn.strdisplaywidth(r.pos or "—"))
  end
  wword = math.max(wword, 6)
  wpos = math.max(wpos, 12)
  if #st.rows > 0 then
    add(pad("Слово", wword) .. "  " .. pad("Часть речи", wpos) .. "  Перевод")
    add(string.rep("─", wword + wpos + 14))
    for _, r in ipairs(st.rows) do
      local pos = r.pos_done and (r.pos or "—") or "…"
      local tr = r.tr_done and (r.tr or "—") or "…"
      add(pad(r.word, wword) .. "  " .. pad(pos, wpos) .. "  " .. tr)
    end
  end
  if st.note then
    add("")
    add(st.note)
  end
  return lines
end

local function set_buf_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function window_size(lines)
  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  width = math.min(math.max(width + 4, 40), vim.o.columns - 6)
  local height = math.min(#lines, vim.o.lines - 6)
  return width, math.max(height, 3)
end

local function place(win, lines)
  local width, height = window_size(lines)
  pcall(vim.api.nvim_win_set_config, win, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
  })
end

--- Основная работа: перевод фразы + построчный разбор + обновление окна.
function M.show(text)
  local src = vim.trim(text):gsub("%s+", " ")
  if src == "" or not src:find("%a%a%a") then
    vim.notify("Выдели английский текст (есть буквы латиницы).", vim.log.levels.WARN)
    return
  end

  local words, limited = M.tokens(src)
  local st = {
    src = #src > 200 and (src:sub(1, 200) .. "…") or src,
    sentence = nil,
    rows = {},
    note = nil,
  }
  if limited then
    st.note = ("(разобраны первые %d слов — выдели фрагмент покороче, чтобы увидеть всё)"):format(MAX_WORDS)
  end
  if #words == 0 then
    st.note = "В выделении нет английских слов."
  end
  for i, w in ipairs(words) do
    st.rows[i] = { word = w, tr_done = false, pos_done = false }
  end

  local lines = M.render(st)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  set_buf_lines(buf, lines)
  local width, height = window_size(lines)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " 📖 Английский по словам ",
    title_pos = "center",
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  for _, k in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", k, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true, desc = "Закрыть" })
  end

  local function refresh()
    if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local new = M.render(st)
    set_buf_lines(buf, new)
    place(win, new)
  end

  -- Фраза целиком
  RU.translate(src, function(tr)
    st.sentence = tr or "не удалось перевести (нет сети или переводчика)"
    refresh()
  end)

  -- Каждое уникальное слово: перевод и часть речи (по одному запросу на слово)
  local by_word = {}
  for _, r in ipairs(st.rows) do
    local key = r.word:lower()
    by_word[key] = by_word[key] or {}
    table.insert(by_word[key], r)
  end
  for key, group in pairs(by_word) do
    RU.translate(group[1].word, function(tr)
      for _, r in ipairs(group) do
        r.tr = tr or nil
        r.tr_done = true
      end
      refresh()
    end)
    M.fetch_pos(key, function(pos)
      local ru_pos = M.pos_ru(pos)
      for _, r in ipairs(group) do
        r.pos = ru_pos
        r.pos_done = true
      end
      refresh()
    end)
  end
  refresh()
end

--- K в визуальном режиме: забираем выделение, выходим из visual, открываем окно.
function M.from_visual()
  local a = vim.fn.getpos("v")
  local b = vim.fn.getpos(".")
  local mode = vim.fn.mode()
  local ok, lines = pcall(vim.fn.getregion, a, b, { type = mode })
  local text = ok and table.concat(lines, " ") or ""
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  vim.schedule(function()
    M.show(text)
  end)
end

function M.setup()
  vim.keymap.set("x", "K", M.from_visual, { desc = "📖 Английский: перевод выделения по словам" })
  vim.keymap.set("n", "<leader>Kw", function()
    M.show(vim.fn.expand("<cword>"))
  end, { desc = "📖 Перевод слова под курсором с частью речи" })
  vim.api.nvim_create_user_command("Gloss", function(o)
    local lines = vim.api.nvim_buf_get_lines(0, o.line1 - 1, o.line2, false)
    M.show(table.concat(lines, " "))
  end, { range = true, desc = "📖 Английский по словам для диапазона строк" })
end

return M
