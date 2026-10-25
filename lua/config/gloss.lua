-- ========================================================================== --
--        АНГЛИЙСКИЙ ПО СЛОВАМ: перевод выделения с разбором (учим язык)        --
-- ========================================================================== --
-- Что делает (нажал K в визуальном режиме на фразе, или <leader>Kw на слове):
--   1) исходный английский текст;
--   2) перевод всей фразы на русский;
--   3) разбор по словам в порядке следования в тексте:
--        слово · транскрипция (как читается) · часть речи · перевод слова
--        ↳ значение (по-английски и по-русски) — грамматический смысл слова.
-- :Gloss — то же для диапазона строк.
--
-- Откуда данные:
--   * перевод фразы и слов — lua/config/ru_util.lua (DeepL, если задан
--     DEEPL_API_KEY; иначе Google/MyMemory);
--   * транскрипция, часть речи и первое значение — бесплатный словарь
--     dictionaryapi.dev (ключ не нужен). Если слова там нет — «—».
--
-- Ограничения (честно):
--   * Грамматика — это часть речи и значение из словаря. Полного разбора времён
--     и падежей здесь нет: для формы «ran» словарь обычно пишет «past tense of run».
--   * Слова переводятся по отдельности, без контекста: «bank» даст «банк».
--     Смысл всей фразы — в строке «Перевод фразы».
--   * За раз разбирается не больше MAX_WORDS слов.

local M = {}

local RU = require("config.ru_util")

local MAX_WORDS = 40
local ENTRY_URL = "https://api.dictionaryapi.dev/api/v2/entries/en/"
local DEF_MAX = 160 -- длина английского значения в окне (символов)

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

M.entry_cache = {} -- слово (нижний регистр) -> таблица записи или false

--- Слова латиницей в порядке следования. Апостроф и дефис входят в слово.
--- Возвращает список слов и флаг «слов было больше лимита».
function M.tokens(text)
  local out, limited = {}, false
  for w in text:gmatch("[%a][%a'%-]*") do
    if #out >= MAX_WORDS then
      limited = true
      break
    end
    out[#out + 1] = w
  end
  return out, limited
end

--- Разбор ответа dictionaryapi.dev. Возвращает {ipa, pos, def} или nil.
--- Ответ: [ { phonetic, phonetics=[{text}], meanings=[{partOfSpeech, definitions=[{definition}]}] } ]
--- При неизвестном слове приходит объект {title, message} — тогда nil.
function M.parse_entry(stdout)
  local ok, data = pcall(vim.json.decode, stdout)
  if not ok or type(data) ~= "table" or type(data[1]) ~= "table" then
    return nil
  end
  local e = data[1]
  local res = {}

  -- Транскрипция: сначала верхнеуровневая, иначе первая непустая из phonetics
  if type(e.phonetic) == "string" and e.phonetic ~= "" then
    res.ipa = e.phonetic
  elseif type(e.phonetics) == "table" then
    for _, p in ipairs(e.phonetics) do
      if type(p) == "table" and type(p.text) == "string" and p.text ~= "" then
        res.ipa = p.text
        break
      end
    end
  end

  -- Часть речи и первое значение первой группы значений
  if type(e.meanings) == "table" and type(e.meanings[1]) == "table" then
    local m = e.meanings[1]
    if type(m.partOfSpeech) == "string" and m.partOfSpeech ~= "" then
      res.pos = m.partOfSpeech
    end
    if type(m.definitions) == "table" and type(m.definitions[1]) == "table" then
      local d = m.definitions[1].definition
      if type(d) == "string" and d ~= "" then
        res.def = d
      end
    end
  end

  if not res.ipa and not res.pos and not res.def then
    return nil
  end
  return res
end

function M.pos_ru(pos)
  if not pos then
    return nil
  end
  return POS_RU[pos] or pos
end

--- Запись словаря для слова. cb(entry|nil), асинхронно; кеш в памяти.
function M.fetch_entry(word, cb)
  local key = word:lower()
  local hit = M.entry_cache[key]
  if hit ~= nil then
    return cb(hit or nil)
  end
  local ok = pcall(vim.system, { "curl", "-sS", "--max-time", "5", ENTRY_URL .. key }, { text = true }, function(res)
    vim.schedule(function()
      local e = nil
      if res.code == 0 and res.stdout then
        e = M.parse_entry(res.stdout)
      end
      M.entry_cache[key] = e or false
      cb(e)
    end)
  end)
  if not ok then -- нет curl: просто без словаря
    cb(nil)
  end
end

-- Выравнивание по видимой ширине (кириллица учитывается)
local function pad(s, width)
  return s .. string.rep(" ", math.max(0, width - vim.fn.strdisplaywidth(s)))
end

-- Значение поля для строки: «…» пока грузится, «—» если словарь пуст
local function field(done, v)
  if not done then
    return "…"
  end
  return v or "—"
end

local function clip(s, n)
  if #s > n then
    return s:sub(1, n) .. "…"
  end
  return s
end

--- Собрать строки окна из текущего состояния.
--- st = { src, sentence, rows = { {word, ipa, pos, def, def_ru, tr, ...} }, note }
function M.render(st)
  local lines = {}
  local function add(s)
    lines[#lines + 1] = s
  end

  add("Оригинал: " .. st.src)
  add("")
  add("Перевод фразы: " .. (st.sentence or "…переводится"))

  if #st.rows > 0 then
    add("")
    add("Разбор по словам (слово · как читается · часть речи · перевод):")
    local ww, wi = 0, 0
    for _, r in ipairs(st.rows) do
      ww = math.max(ww, vim.fn.strdisplaywidth(r.word))
      wi = math.max(wi, vim.fn.strdisplaywidth(field(r.entry_done, r.ipa)))
    end
    local num_w = #tostring(#st.rows)
    for i, r in ipairs(st.rows) do
      local ipa = field(r.entry_done, r.ipa)
      local pos = field(r.entry_done, M.pos_ru(r.pos))
      local tr = field(r.tr_done, r.tr)
      add(("%s. %s  %s  %s  → %s"):format(
        pad(tostring(i), num_w), pad(r.word, ww), pad(ipa, wi), pos, tr))
      if r.def then
        add("     ↳ значение: " .. clip(r.def, DEF_MAX))
        add("       по-русски: " .. field(r.def_done, r.def_ru))
      end
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

--- Основная работа: окно, перевод фразы, разбор каждого слова.
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
    st.rows[i] = { word = w, entry_done = false, tr_done = false, def_done = false }
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

  -- По одному запросу на уникальное слово: словарь и перевод
  local by_word, order = {}, {}
  for _, r in ipairs(st.rows) do
    local key = r.word:lower()
    if not by_word[key] then
      by_word[key] = {}
      order[#order + 1] = key
    end
    table.insert(by_word[key], r)
  end
  for _, key in ipairs(order) do
    local group = by_word[key]
    local first = group[1].word

    RU.translate(first, function(tr)
      for _, r in ipairs(group) do
        r.tr = tr
        r.tr_done = true
      end
      refresh()
    end)

    M.fetch_entry(key, function(e)
      for _, r in ipairs(group) do
        r.ipa = e and e.ipa or nil
        r.pos = e and e.pos or nil
        r.def = e and e.def or nil
        r.entry_done = true
      end
      refresh()
      if e and e.def then
        RU.translate(e.def, function(def_ru)
          for _, r in ipairs(group) do
            r.def_ru = def_ru
            r.def_done = true
          end
          refresh()
        end)
      else
        for _, r in ipairs(group) do
          r.def_done = true
        end
      end
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
  vim.keymap.set("x", "K", M.from_visual, { desc = "📖 Английский: перевод выделения и разбор по словам" })
  vim.keymap.set("n", "<leader>Kw", function()
    M.show(vim.fn.expand("<cword>"))
  end, { desc = "📖 Слово под курсором: транскрипция, часть речи, перевод" })
  vim.api.nvim_create_user_command("Gloss", function(o)
    local lines = vim.api.nvim_buf_get_lines(0, o.line1 - 1, o.line2, false)
    M.show(table.concat(lines, " "))
  end, { range = true, desc = "📖 Английский по словам для диапазона строк" })
end

return M
