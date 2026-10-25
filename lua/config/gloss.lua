-- ========================================================================== --
--        АНГЛИЙСКИЙ ПО СЛОВАМ: перевод выделения с разбором (учим язык)        --
-- ========================================================================== --
-- Что делает (K в визуальном режиме на фразе, <leader>Kw на слове, :Gloss):
--   1) исходный английский текст;
--   2) перевод всей фразы на русский;
--   3) разбор по словам в порядке следования, каждое слово в формате:
--        - **слово** [транскрипция по-русски] — «перевод в этом контексте» (часть речи, грамматика)
--
-- Два источника разбора:
--   * ИИ (основной): Gemini, тот же ключ, что у avante — GEMINI_API_KEY (или
--     AVANTE_GEMINI_API_KEY), модель — GEMINI_MODEL. Даёт перевод и грамматику
--     с учётом контекста фразы («are — форма to be для you»).
--   * Словарь (запасной, без ключа): dictionaryapi.dev даёт IPA-транскрипцию,
--     часть речи и первое значение. IPA переводится в русскую транскрипцию
--     таблицей, перевод слова — через ru_util (DeepL / Google / MyMemory).
--     Контекста словарь не знает, поэтому разбор менее точный.
--
-- Честно: русская транскрипция от ИИ — его оценка, не словарь произношения.
-- Из-за IPA → кириллица в запасном варианте возможны расхождения.

local M = {}

local RU = require("config.ru_util")

local MAX_WORDS = 40
local ENTRY_URL = "https://api.dictionaryapi.dev/api/v2/entries/en/"
local GEMINI_TIMEOUT = 40 -- секунд
local NOTE_MAX = 140      -- длина значения в запасном варианте

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

M.entry_cache = {}  -- слово (нижний регистр) -> запись словаря или false
M.gemini_cache = {} -- фраза -> результат ИИ

-- ---------------------------------------------------------------------------
-- Токенизация
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- IPA → русская транскрипция (запасной вариант, без ИИ)
-- ---------------------------------------------------------------------------

-- Порядок важен: сначала более длинные сочетания
local IPA_MULTI = {
  { "juː", "ю" }, { "ju", "ю" },
  { "aɪ", "ай" }, { "eɪ", "эй" }, { "ɔɪ", "ой" }, { "aʊ", "ау" },
  { "oʊ", "оу" }, { "əʊ", "оу" },
  { "ɪə", "иа" }, { "eə", "эа" }, { "ʊə", "уа" },
  { "tʃ", "ч" }, { "dʒ", "дж" },
}

local IPA_SINGLE = {
  ["i"] = "и", ["ɪ"] = "и", ["e"] = "е", ["ɛ"] = "э", ["æ"] = "э",
  ["a"] = "а", ["ɑ"] = "а", ["ʌ"] = "а", ["ə"] = "а", ["ɜ"] = "ё",
  ["ɒ"] = "о", ["ɔ"] = "о", ["o"] = "о", ["ʊ"] = "у", ["u"] = "у",
  ["p"] = "п", ["b"] = "б", ["t"] = "т", ["d"] = "д", ["k"] = "к",
  ["g"] = "г", ["ɡ"] = "г", ["f"] = "ф", ["v"] = "в", ["θ"] = "с",
  ["ð"] = "з", ["s"] = "с", ["z"] = "з", ["ʃ"] = "ш", ["ʒ"] = "ж",
  ["h"] = "х", ["m"] = "м", ["n"] = "н", ["ŋ"] = "нг", ["l"] = "л",
  ["r"] = "р", ["ɹ"] = "р", ["ɾ"] = "р", ["j"] = "й", ["w"] = "у",
}

-- Служебные знаки IPA, которые ничего не озвучивают
local IPA_SKIP = { "ˈ", "ˌ", "ː", "ˑ", "͡", ".", "/", "[", "]", "ʔ" }

--- Транскрипция IPA (например «/ɪf/») → кириллица («иф»). nil, если нечего переводить.
function M.ipa_to_ru(ipa)
  if type(ipa) ~= "string" or ipa == "" then
    return nil
  end
  local s = ipa
  for _, m in ipairs(IPA_SKIP) do
    s = s:gsub(vim.pesc(m), "")
  end
  local out, i = {}, 1
  while i <= #s do
    local hit = false
    for _, pair in ipairs(IPA_MULTI) do
      local ipa_part, ru = pair[1], pair[2]
      if s:sub(i, i + #ipa_part - 1) == ipa_part then
        out[#out + 1] = ru
        i = i + #ipa_part
        hit = true
        break
      end
    end
    if not hit then
      -- один символ UTF-8 целиком
      local ch = s:match("^[\0-\127\194-\244][\128-\191]*", i)
      if not ch then
        break
      end
      if IPA_SINGLE[ch] then
        out[#out + 1] = IPA_SINGLE[ch]
      end
      i = i + #ch
    end
  end
  local res = table.concat(out)
  return res ~= "" and res or nil
end

-- ---------------------------------------------------------------------------
-- Словарь (dictionaryapi.dev): IPA, часть речи, первое значение
-- ---------------------------------------------------------------------------

--- Разбор ответа словаря. Возвращает {ipa, pos, def} или nil.
--- Ответ: [ { phonetic, phonetics=[{text}], meanings=[{partOfSpeech, definitions=[{definition}]}] } ]
--- Для неизвестного слова приходит объект {title, message} — тогда nil.
function M.parse_entry(stdout)
  local ok, data = pcall(vim.json.decode, stdout)
  if not ok or type(data) ~= "table" or type(data[1]) ~= "table" then
    return nil
  end
  local e = data[1]
  local res = {}

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
  if not ok then -- нет curl
    cb(nil)
  end
end

-- ---------------------------------------------------------------------------
-- Gemini: разбор фразы целиком (перевод + транскрипция + грамматика по контексту)
-- ---------------------------------------------------------------------------

function M.gemini_key()
  local k = vim.env.AVANTE_GEMINI_API_KEY
  if k == nil or k == "" then
    k = vim.env.GEMINI_API_KEY
  end
  if k == nil or k == "" then
    return nil
  end
  return k
end

function M.gemini_model()
  return vim.env.GEMINI_MODEL or "gemini-3.6-flash"
end

function M.gemini_endpoint()
  return vim.env.GEMINI_ENDPOINT or "https://generativelanguage.googleapis.com/v1beta/models"
end

local GEMINI_PROMPT = [[
Ты — репетитор английского для русскоязычного ученика. Разбери фразу ниже и верни JSON.
Поля:
- sentence_ru: перевод всей фразы на естественный русский язык.
- words: по одному объекту на каждое английское слово в порядке следования в тексте
  (повторы тоже). Сокращение вроде don't — одно слово.
  - word: слово, как оно написано в тексте.
  - tr: русская транскрипция, как читается слово, без квадратных скобок. Пример: if → иф, you → ю, like → лайк.
  - ru: перевод этого слова именно в этом контексте, одно-два слова по-русски.
  - pos: часть речи по-русски (существительное, глагол, местоимение, союз…).
  - note: короткая грамматическая заметка по-русски, что значит форма или роль слова в предложении.
    Пример: «сокращение от do not», «форма глагола to be для you». Без повтора части речи. Пустая строка, если заметки не нужно.
Фраза:
]]

--- Разбор ответа Gemini. Возвращает {sentence_ru, words} или nil, причина.
function M.parse_gemini(stdout)
  local ok, data = pcall(vim.json.decode, stdout)
  if not ok or type(data) ~= "table" then
    return nil, "ответ не JSON"
  end
  if type(data.error) == "table" then
    local msg = data.error.message
    return nil, "Gemini: " .. (type(msg) == "string" and msg or "ошибка")
  end
  local cand = type(data.candidates) == "table" and data.candidates[1] or nil
  local parts = type(cand) == "table" and type(cand.content) == "table" and cand.content.parts or nil
  local text = type(parts) == "table" and type(parts[1]) == "table" and parts[1].text or nil
  if type(text) ~= "string" then
    return nil, "пустой ответ Gemini"
  end
  local ok2, res = pcall(vim.json.decode, text)
  if not ok2 or type(res) ~= "table" or type(res.words) ~= "table" then
    return nil, "Gemini вернул не тот формат"
  end
  local words = {}
  for _, w in ipairs(res.words) do
    if type(w) == "table" and type(w.word) == "string" then
      words[#words + 1] = {
        word = w.word,
        tr = type(w.tr) == "string" and w.tr or nil,
        ru = type(w.ru) == "string" and w.ru or nil,
        pos = type(w.pos) == "string" and w.pos or nil,
        note = type(w.note) == "string" and w.note ~= "" and w.note or nil,
      }
    end
  end
  if #words == 0 then
    return nil, "Gemini не вернул слов"
  end
  return {
    sentence_ru = type(res.sentence_ru) == "string" and res.sentence_ru or nil,
    words = words,
  }
end

--- Разбор фразы через Gemini. cb(result|nil, причина|nil), асинхронно.
function M.gemini_analyze(text, cb)
  local key = M.gemini_key()
  if not key then
    return cb(nil, "нет GEMINI_API_KEY")
  end
  local hit = M.gemini_cache[text]
  if hit then
    return cb(hit)
  end

  local body = vim.json.encode({
    contents = { { role = "user", parts = { { text = GEMINI_PROMPT .. text } } } },
    generationConfig = {
      temperature = 0.2,
      responseMimeType = "application/json",
      responseSchema = {
        type = "OBJECT",
        properties = {
          sentence_ru = { type = "STRING" },
          words = {
            type = "ARRAY",
            items = {
              type = "OBJECT",
              properties = {
                word = { type = "STRING" },
                tr = { type = "STRING" },
                ru = { type = "STRING" },
                pos = { type = "STRING" },
                note = { type = "STRING" },
              },
              required = { "word", "tr", "ru", "pos", "note" },
            },
          },
        },
        required = { "sentence_ru", "words" },
      },
    },
  })
  local url = ("%s/%s:generateContent"):format(M.gemini_endpoint(), M.gemini_model())
  local ok = pcall(vim.system, {
    "curl", "-sS", "--max-time", tostring(GEMINI_TIMEOUT),
    "-H", "Content-Type: application/json",
    "-H", "x-goog-api-key: " .. key,
    "-d", "@-", url,
  }, { text = true, stdin = body }, function(res)
    vim.schedule(function()
      if res.code ~= 0 or not res.stdout or res.stdout == "" then
        local err = vim.trim(res.stderr or "")
        return cb(nil, "сеть: " .. (err ~= "" and err or "curl код " .. tostring(res.code)))
      end
      local parsed, why = M.parse_gemini(res.stdout)
      if parsed then
        M.gemini_cache[text] = parsed
      end
      cb(parsed, why)
    end)
  end)
  if not ok then
    cb(nil, "нет curl")
  end
end

-- ---------------------------------------------------------------------------
-- Вывод
-- ---------------------------------------------------------------------------

-- Значение поля: «…» пока грузится, «—» если данных нет
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

--- Строка разбора: - **слово** [транскр] — «перевод» (часть речи, заметка)
local function word_line(r)
  local tr = field(r.tr_done, r.tr)
  local ru = field(r.ru_done, r.ru)
  local ru_txt = (ru == "…" or ru == "—") and ru or ("«" .. ru .. "»")
  local parts = {}
  if r.pos and r.pos ~= "" then
    parts[#parts + 1] = r.pos
  elseif not r.pos_done then
    parts[#parts + 1] = "…"
  end
  if r.note and r.note ~= "" then
    parts[#parts + 1] = r.note
  elseif r.note_pending then
    parts[#parts + 1] = "…"
  end
  local tail = #parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or ""
  return ("- **%s** [%s] — %s%s"):format(r.word, tr, ru_txt, tail)
end

--- Собрать строки окна из состояния.
--- st = { src, sentence, rows, note }
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
    add("**Разбор по словам (Vocabulary)**")
    add("")
    for _, r in ipairs(st.rows) do
      add(word_line(r))
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
  local longest = 0
  for _, l in ipairs(lines) do
    longest = math.max(longest, vim.fn.strdisplaywidth(l))
  end
  local width = math.min(math.max(longest + 4, 40), vim.o.columns - 6)
  -- высота с учётом переноса длинных строк (wrap включён)
  local rows = 0
  for _, l in ipairs(lines) do
    local w = vim.fn.strdisplaywidth(l)
    rows = rows + math.max(1, math.ceil(w / (width - 2)))
  end
  local height = math.min(rows + 1, vim.o.lines - 6)
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

--- Запасной вариант: словарь + перевод слов. Заполняет st.rows по мере ответов.
local function dictionary_fallback(st, refresh)
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

    RU.translate(group[1].word, function(tr)
      for _, r in ipairs(group) do
        r.ru = tr
        r.ru_done = true
      end
      refresh()
    end)

    M.fetch_entry(key, function(e)
      local ipa_ru = M.ipa_to_ru(e and e.ipa or nil)
      for _, r in ipairs(group) do
        r.tr = ipa_ru
        r.tr_done = true
        r.pos = M.pos_ru(e and e.pos or nil)
        r.pos_done = true
      end
      refresh()
      if e and e.def then
        for _, r in ipairs(group) do
          r.note_pending = true
        end
        refresh()
        RU.translate(e.def, function(def_ru)
          for _, r in ipairs(group) do
            r.note = def_ru and clip(def_ru, NOTE_MAX) or nil
            r.note_pending = false
          end
          refresh()
        end)
      end
    end)
  end
end

--- Основная работа: окно, перевод фразы, разбор слов (ИИ или словарь).
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

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  local lines = M.render(st)
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
  vim.wo[win].conceallevel = 2
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

  if #words == 0 then
    refresh()
    return
  end

  for i, w in ipairs(words) do
    st.rows[i] = { word = w }
  end

  -- Перевод фразы (запасной вариант; ИИ тоже даёт перевод, но он придёт с разбором)
  local function fallback_sentence()
    RU.translate(src, function(tr)
      st.sentence = tr or "не удалось перевести (нет сети или переводчика)"
      refresh()
    end)
  end

  local function use_dictionary(reason)
    if reason then
      st.note = ("(ИИ-разбор недоступен: %s. Показан словарь — без контекста.)"):format(reason)
    end
    for _, r in ipairs(st.rows) do
      r.tr_done, r.ru_done, r.pos_done = false, false, false
    end
    fallback_sentence()
    dictionary_fallback(st, refresh)
    refresh()
  end

  if not M.gemini_key() then
    st.note = "Для разбора с учётом контекста задай ключ Gemini: set -Ux GEMINI_API_KEY \"…\" (fish). Пока — словарь."
    use_dictionary(nil)
    return
  end

  -- ИИ: одна фраза — один запрос; пока ждём, показываем «…»
  st.note = "…разбираю фразу"
  refresh()
  M.gemini_analyze(src, function(res, why)
    if not res then
      return use_dictionary(why)
    end
    st.note = nil
    st.sentence = res.sentence_ru or "…"
    st.rows = {}
    for i, w in ipairs(res.words) do
      st.rows[i] = {
        word = w.word,
        tr = w.tr, tr_done = true,
        ru = w.ru, ru_done = true,
        pos = w.pos, pos_done = true,
        note = w.note,
      }
    end
    refresh()
  end)
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
  vim.keymap.set("x", "K", M.from_visual, { desc = "📖 Английский: перевод и разбор выделения" })
  vim.keymap.set("n", "<leader>Kw", function()
    M.show(vim.fn.expand("<cword>"))
  end, { desc = "📖 Слово под курсором: транскрипция, часть речи, перевод" })
  vim.api.nvim_create_user_command("Gloss", function(o)
    local lines = vim.api.nvim_buf_get_lines(0, o.line1 - 1, o.line2, false)
    M.show(table.concat(lines, " "))
  end, { range = true, desc = "📖 Английский по словам для диапазона строк" })
end

return M
