-- ========================================================================== --
--   INLINE SUGGESTIONS / GHOST TEXT (ПРИЗРАЧНЫЙ ТЕКСТ) — ТОЛЬКО GEMINI       --
-- ========================================================================== --
-- Встроенные серые автоподсказки при наборе кода (как в Cursor / Copilot),
-- работающие СТРОГО И ИСКЛЮЧИТЕЛЬНО через Google Gemini:
--   • Даже если чат (:AiProvider / Avante) переключён на OpenRouter, Groq,
--     DeepSeek, Kimi или локальную модель — Ghost Text НИКОГДА не отправляет
--     код в другие сервисы: используется только провайдер "gemini"
--     (ключи: AVANTE_GEMINI_API_KEY → GEMINI_API_KEY → GOOGLE_API_KEY).
--   • По умолчанию ВКЛЮЧЕНА при старте Neovim (отключить из окружения:
--     set -Ux GEMINI_GHOST_TEXT 0).
--   • Мгновенное выключение / включение по хоткею:
--       <leader>AG  или  <leader>ui   (:GhostTextToggle)
--   • Принять подсказку в режиме вставки:
--       <Tab>  или  <M-l>   — принять целиком
--       <M-w>  или  <C-Right> — принять одно следующее слово
--       <C-]>               — скрыть текущую подсказку
--       <M-g>  или  <leader>Ai — запросить подсказку вручную (:GhostTextSuggest)
local M = {}

local PROVIDER_ID = "gemini" -- ЖЁСТКО: только Google Gemini и никакой другой провайдер!
local NS_NAME = "gemini_ghost_text"
local HL_GROUP = "GhostText"

local DEFAULT_DEBOUNCE_MS = 350
local PREFIX_MAX_LINES = 60
local SUFFIX_MAX_LINES = 25
local MAX_SUGGESTION_LINES = 18
local BACKOFF_429_MS = 20000

-- По умолчанию ВКЛЮЧЕНО (если явно не выключено через GEMINI_GHOST_TEXT=0)
M.enabled = (vim.env.GEMINI_GHOST_TEXT ~= "0")
M.user_toggled = false

local setup_done = false
local ns_id = nil
local debounce_timer = nil
local inflight_job = nil
local inflight_seq = 0
local backoff_until_ms = 0

-- Текущее активное призрачное дополнение:
-- { bufnr, row (1-based), col (0-based byte), text, extmark_id, line_snapshot }
local current = nil

-- Компактный кэш последних подсказок (экономит запросы и даёт 0 мс отклик)
local cache_order = {}
local cache_map = {}
local CACHE_LIMIT = 16

local IGNORED_FILETYPES = {
  [""] = false, -- буфер без filetype разрешён, если это обычный файл
  NvimTree = true,
  ["neo-tree"] = true,
  TelescopePrompt = true,
  Avante = true,
  AvanteInput = true,
  AvanteSelectedFiles = true,
  codecompanion = true,
  lazy = true,
  mason = true,
  help = true,
  qf = true,
  trouble = true,
  toggleterm = true,
  alpha = true,
  dashboard = true,
  notify = true,
  noice = true,
  nvimarchboard = true,
  nvimerrorlog = true,
  gitcommit = true,
  gitrebase = true,
}

local function now_ms()
  local uv = vim.uv or vim.loop
  if uv and type(uv.now) == "function" then
    return uv.now()
  end
  return math.floor(os.clock() * 1000)
end

local function ensure_ns()
  if not ns_id and vim.api and type(vim.api.nvim_create_namespace) == "function" then
    ns_id = vim.api.nvim_create_namespace(NS_NAME)
  end
  return ns_id
end

local function ensure_hl()
  if vim.api and type(vim.api.nvim_set_hl) == "function" then
    -- Призрачный серый курсив поверх Comment (отлично читается в любой теме)
    pcall(vim.api.nvim_set_hl, 0, HL_GROUP, { link = "Comment", default = true })
  end
end

local function echo_status(msg, hl)
  if vim.api and type(vim.api.nvim_echo) == "function" then
    pcall(vim.api.nvim_echo, { { msg, hl or "MoreMsg" } }, true, {})
  end
end

local function refresh_statusline()
  pcall(vim.cmd, "redrawstatus")
end

--- Безопасная проверка: не отправлять файлы с секретами (.env, ключи, сертификаты).
---@param filepath string
---@return boolean
function M.is_sensitive_file(filepath)
  if type(filepath) ~= "string" or filepath == "" then
    return false
  end
  local base = (filepath:match("([^/\\]+)$") or filepath):lower()
  if base == ".env" or base:match("^%.env%.") or base:match("%.env$") then
    return true
  end
  if base == ".netrc" or base == ".git-credentials" or base:match("^id_rsa") or base:match("^id_ed25519") then
    return true
  end
  if base:match("%.pem$") or base:match("%.key$") or base:match("%.p12$") or base:match("%.pfx$") then
    return true
  end
  if base:find("secret", 1, true) or base:find("credential", 1, true) then
    return true
  end
  return false
end

--- Разрешает ТОЛЬКО провайдера Google Gemini ("gemini").
--- Никогда не использует OpenRouter, Groq, OpenAI и др.
---@return table|nil resolved, string|nil err, string|nil model
function M.resolve_gemini()
  local ok, AI = pcall(require, "config.ai_api")
  if not ok or type(AI) ~= "table" or type(AI.resolve) ~= "function" then
    return nil, "модуль config.ai_api недоступен", nil
  end
  if type(AI.sync_gemini_env) == "function" then
    AI.sync_gemini_env()
  end
  -- ЖЁСТКО передаём "gemini", игнорируя любые vim.g.ai_provider / AI_PROVIDER / AVANTE_PROVIDER!
  local resolved, why = AI.resolve(PROVIDER_ID)
  if not resolved then
    return nil, why or "ключ Gemini не задан", nil
  end
  if resolved.id ~= PROVIDER_ID then
    return nil, "разрешён только провайдер gemini", nil
  end
  local ghost_model = (type(AI.env_model) == "function" and AI.env_model("GEMINI_GHOST_MODEL", nil))
    or resolved.model
    or "gemini-3.6-flash"
  return resolved, nil, ghost_model
end

local function stop_timer()
  if debounce_timer then
    pcall(function()
      debounce_timer:stop()
      debounce_timer:close()
    end)
    debounce_timer = nil
  end
end

local function cancel_inflight()
  inflight_seq = inflight_seq + 1
  if inflight_job then
    local job = inflight_job
    inflight_job = nil
    pcall(function()
      if type(job.kill) == "function" then
        job:kill(9)
      end
    end)
    refresh_statusline()
  end
end

--- Скрыть призрачный текст в указанном (или во всех) буферах, не меняя M.enabled.
---@param bufnr? integer
function M.clear(bufnr)
  local id = ensure_ns()
  if current and (not bufnr or current.bufnr == bufnr) then
    local b = current.bufnr
    current = nil
    if id and vim.api and type(vim.api.nvim_buf_is_valid) == "function" and vim.api.nvim_buf_is_valid(b) then
      pcall(vim.api.nvim_buf_clear_namespace, b, id, 0, -1)
    end
  elseif id and bufnr and vim.api and type(vim.api.nvim_buf_is_valid) == "function" and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, id, 0, -1)
  elseif id and not bufnr and vim.api and type(vim.api.nvim_list_bufs) == "function" then
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(b) then
        pcall(vim.api.nvim_buf_clear_namespace, b, id, 0, -1)
      end
    end
  end
end

--- Полностью отменить таймер, запрос и скрыть текущую подсказку.
function M.dismiss()
  stop_timer()
  cancel_inflight()
  M.clear()
end

--- Видна ли сейчас призрачная подсказка Gemini в текущем буфере?
---@param bufnr? integer
---@return boolean
function M.is_visible(bufnr)
  local b = bufnr or (vim.api and vim.api.nvim_get_current_buf and vim.api.nvim_get_current_buf()) or 0
  if not current or current.bufnr ~= b or type(current.text) ~= "string" or current.text == "" then
    return false
  end
  local id = ensure_ns()
  if not id or not vim.api or type(vim.api.nvim_buf_get_extmarks) ~= "function" then
    return true
  end
  local ok, marks = pcall(vim.api.nvim_buf_get_extmarks, b, id, 0, -1, {})
  return ok and type(marks) == "table" and #marks > 0
end

--- Подходит ли буфер для автоподсказок кода?
---@param bufnr integer
---@return boolean
function M.is_eligible_buf(bufnr)
  if not vim.api or type(vim.api.nvim_buf_is_valid) ~= "function" or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local bt = vim.bo[bufnr] and vim.bo[bufnr].buftype or ""
  if bt ~= "" then
    return false
  end
  if vim.bo[bufnr] and vim.bo[bufnr].modifiable == false then
    return false
  end
  local ft = vim.bo[bufnr] and vim.bo[bufnr].filetype or ""
  if IGNORED_FILETYPES[ft] then
    return false
  end
  local name = (type(vim.api.nvim_buf_get_name) == "function" and vim.api.nvim_buf_get_name(bufnr)) or ""
  if M.is_sensitive_file(name) then
    return false
  end
  return true
end

--- Очищает сырой ответ модели от обёрток ```...```, <CURSOR> и дублей вокруг курсора.
---@param raw string
---@param before_cursor string текст текущей строки слева от курсора
---@param after_cursor string текст текущей строки справа от курсора
---@param next_line? string следующая строка буфера
---@return string
function M.clean_completion(raw, before_cursor, after_cursor, next_line)
  if type(raw) ~= "string" or raw == "" then
    return ""
  end
  local s = raw:gsub("\r\n", "\n")

  -- Срезаем <completion>...</completion>, если модель обернула тегом
  local tagged = s:match("<completion>\n?(.-)\n?</completion>")
  if tagged then
    s = tagged
  end

  -- Срезаем markdown-блоки ```lang ... ```
  local fenced = s:match("^%s*```[%w_%-%.]*%s*\n(.-)\n```%s*$")
  if fenced then
    s = fenced
  else
    s = s:gsub("^%s*```[%w_%-%.]*%s*\n", "")
    s = s:gsub("\n```%s*$", "")
    s = s:gsub("^`([^`\n]+)`$", "%1")
  end

  -- Убираем маркер <CURSOR>, если модель случайно повторила его
  s = s:gsub("<CURSOR>", "")

  -- Убираем только хвостовые переводы строк, сохраняя ведущие пробелы (отступ важен!)
  s = s:gsub("[\n%s]+$", "")
  if s == "" then
    return ""
  end

  local function starts_with(str, prefix)
    return type(str) == "string" and type(prefix) == "string" and str:sub(1, #prefix) == prefix
  end
  local function ends_with(str, suffix)
    return type(str) == "string" and type(suffix) == "string" and (suffix == "" or str:sub(-#suffix) == suffix)
  end

  -- Если модель повторила префикс текущей строки перед курсором — аккуратно срезаем дубль
  if type(before_cursor) == "string" and before_cursor ~= "" then
    local trimmed_before = vim.trim(before_cursor)
    if starts_with(s, before_cursor) then
      s = s:sub(#before_cursor + 1)
    elseif #trimmed_before >= 3 and starts_with(vim.trim(s), trimmed_before) then
      local idx = s:find(trimmed_before, 1, true)
      if idx then
        s = s:sub(idx + #trimmed_before)
      end
    end
  end

  -- Если на этой же строке справа от курсора уже есть закрывающая скобка/суффикс — срезаем дубль
  if type(after_cursor) == "string" and after_cursor ~= "" and ends_with(s, after_cursor) then
    s = s:sub(1, #s - #after_cursor)
  end

  -- Ограничиваем высоту призрачной подсказки и срезаем совпадение со следующей строкой
  local lines = vim.split(s, "\n", { plain = true })
  if #lines > MAX_SUGGESTION_LINES then
    lines = vim.list_slice(lines, 1, MAX_SUGGESTION_LINES)
  end
  if type(next_line) == "string" and vim.trim(next_line) ~= "" and #lines > 1 then
    if vim.trim(lines[#lines]) == vim.trim(next_line) then
      table.remove(lines, #lines)
    end
  end

  local out = table.concat(lines, "\n")
  if vim.trim(out) == "" then
    return ""
  end
  return out
end

--- Отрисовать призрачный текст в буфере `bufnr` в позиции `{row, col}`.
---@param bufnr integer
---@param row integer 1-based строка
---@param col integer 0-based байтовая колонка
---@param text string
---@return boolean rendered
function M.render(bufnr, row, col, text)
  M.clear(bufnr)
  if type(text) ~= "string" or text == "" then
    return false
  end
  local id = ensure_ns()
  ensure_hl()
  if not id or not vim.api or type(vim.api.nvim_buf_set_extmark) ~= "function" then
    return false
  end

  local buf_lines = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)
  local cur_line = buf_lines[1] or ""
  local safe_col = math.max(0, math.min(col, #cur_line))

  local parts = vim.split(text, "\n", { plain = true })
  local first_line = parts[1] or ""
  local virt_lines = {}
  for idx = 2, #parts do
    virt_lines[#virt_lines + 1] = { { parts[idx], HL_GROUP } }
  end

  local ext_opts = {
    hl_mode = "combine",
  }
  if first_line ~= "" then
    ext_opts.virt_text = { { first_line, HL_GROUP } }
    ext_opts.virt_text_pos = "inline"
  end
  if #virt_lines > 0 then
    ext_opts.virt_lines = virt_lines
  end

  local ok, mark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, id, row - 1, safe_col, ext_opts)
  if not ok then
    -- Фолбэк для окружений/стабов без virt_text_pos = "inline"
    ext_opts.virt_text_pos = "eol"
    ok, mark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, id, row - 1, safe_col, ext_opts)
  end
  if not ok then
    return false
  end

  current = {
    bufnr = bufnr,
    row = row,
    col = safe_col,
    text = text,
    extmark_id = mark_id,
    line_snapshot = cur_line,
  }
  return true
end

--- Вставить произвольный префикс текущей призрачной подсказки в буфер и сдвинуть курсор.
---@param take_text string
---@param remainder string
local function apply_text_piece(take_text, remainder)
  if not current or take_text == "" then
    return false
  end
  local bufnr = current.bufnr
  local row = current.row
  local col = current.col
  M.clear(bufnr)

  local cur_lines = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)
  local cur_line = cur_lines[1] or ""
  local safe_col = math.max(0, math.min(col, #cur_line))

  local ins_lines = vim.split(take_text, "\n", { plain = true })
  if type(vim.api.nvim_buf_set_text) == "function" then
    vim.api.nvim_buf_set_text(bufnr, row - 1, safe_col, row - 1, safe_col, ins_lines)
  else
    -- Фолбэк для минимальных тестовых стабов без nvim_buf_set_text
    local left = cur_line:sub(1, safe_col)
    local right = cur_line:sub(safe_col + 1)
    local replaced = {}
    if #ins_lines == 1 then
      replaced[1] = left .. ins_lines[1] .. right
    else
      replaced[1] = left .. ins_lines[1]
      for i = 2, #ins_lines - 1 do
        replaced[i] = ins_lines[i]
      end
      replaced[#ins_lines] = ins_lines[#ins_lines] .. right
    end
    vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, replaced)
  end

  local new_row, new_col
  if #ins_lines == 1 then
    new_row = row
    new_col = safe_col + #ins_lines[1]
  else
    new_row = row + #ins_lines - 1
    new_col = #ins_lines[#ins_lines]
  end
  pcall(vim.api.nvim_win_set_cursor, 0, { new_row, new_col })

  if type(remainder) == "string" and remainder ~= "" then
    M.render(bufnr, new_row, new_col, remainder)
  end
  return true
end

--- Принять всю призрачную подсказку целиком (<Tab> или <M-l>).
---@return boolean accepted
function M.accept()
  if not M.is_visible() or not current then
    return false
  end
  return apply_text_piece(current.text, "")
end

--- Принять только следующее слово (или перевод строки) из призрачной подсказки (<M-w> / <C-Right>).
---@return boolean accepted
function M.accept_word()
  if not M.is_visible() or not current then
    return false
  end
  local txt = current.text
  local chunk = txt:match("^(\n%s*%S+)")
    or txt:match("^(%s*%w+)")
    or txt:match("^(%s*[^\n%w%s]+)")
    or txt:sub(1, 1)
  if not chunk or chunk == "" then
    return false
  end
  local rest = txt:sub(#chunk + 1)
  return apply_text_piece(chunk, rest)
end

local function cache_get(key)
  return cache_map[key]
end

local function cache_put(key, val)
  if cache_map[key] == nil then
    cache_order[#cache_order + 1] = key
    if #cache_order > CACHE_LIMIT then
      local oldest = table.remove(cache_order, 1)
      cache_map[oldest] = nil
    end
  end
  cache_map[key] = val
end

--- Сформировать контекст вокруг курсора и отправить FIM-запрос ТОЛЬКО в Gemini.
---@param opts? { manual?: boolean }
function M.request_suggestion(opts)
  opts = opts or {}
  if not M.enabled and not opts.manual then
    return
  end
  if not opts.manual and now_ms() < backoff_until_ms then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if not M.is_eligible_buf(bufnr) then
    if opts.manual then
      echo_status("👻 Ghost Text: текущий буфер не является редактируемым файлом кода", "WarningMsg")
    end
    return
  end

  local mode = (vim.fn and type(vim.fn.mode) == "function" and vim.fn.mode()) or "i"
  if not opts.manual and not mode:match("^[iR]") then
    return
  end

  local gem, gem_err, ghost_model = M.resolve_gemini()
  if not gem then
    if opts.manual then
      echo_status("👻 Ghost Text работает только на Gemini: " .. tostring(gem_err) .. " (<leader>Ag)", "WarningMsg")
    end
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  local start_line = math.max(0, row - 1 - PREFIX_MAX_LINES)
  local end_line = math.min(total_lines, row + SUFFIX_MAX_LINES)
  local window_lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)

  local rel_row = row - start_line
  local cur_line = window_lines[rel_row] or ""
  local safe_col = math.max(0, math.min(col, #cur_line))
  local before_cursor = cur_line:sub(1, safe_col)
  local after_cursor = cur_line:sub(safe_col + 1)
  local next_line = window_lines[rel_row + 1] or ""

  local prefix_parts = {}
  for i = 1, rel_row - 1 do
    prefix_parts[#prefix_parts + 1] = window_lines[i]
  end
  prefix_parts[#prefix_parts + 1] = before_cursor
  local prefix = table.concat(prefix_parts, "\n")

  local suffix_parts = { after_cursor }
  for i = rel_row + 1, #window_lines do
    suffix_parts[#suffix_parts + 1] = window_lines[i]
  end
  local suffix = table.concat(suffix_parts, "\n")

  if not opts.manual and vim.trim(prefix) == "" and vim.trim(suffix) == "" then
    return
  end

  local ft = vim.bo[bufnr] and vim.bo[bufnr].filetype or "text"
  local full_name = (type(vim.api.nvim_buf_get_name) == "function" and vim.api.nvim_buf_get_name(bufnr)) or ""
  local short_name = full_name ~= "" and vim.fn.fnamemodify(full_name, ":t") or ("buffer." .. ft)

  local cache_key = ft .. "\0" .. prefix:sub(-800) .. "\0<C>\0" .. suffix:sub(1, 300)
  local cached = not opts.manual and cache_get(cache_key) or nil
  if cached and cached ~= "" then
    M.render(bufnr, row, safe_col, cached)
    return
  end

  cancel_inflight()
  inflight_seq = inflight_seq + 1
  local my_seq = inflight_seq

  local messages = {
    {
      role = "system",
      content = table.concat({
        "You are an ultra-fast inline code completion engine (Fill-In-the-Middle).",
        "Output ONLY the exact raw code to insert at <CURSOR>.",
        "STRICT RULES:",
        "1. NEVER wrap output in markdown fences (no ```).",
        "2. NEVER add explanations, prose, or comments about what you did.",
        "3. NEVER repeat text that already appears immediately before <CURSOR> or immediately after <CURSOR>.",
        "4. Keep completions concise and idiomatic (1 to 10 lines max).",
        "5. If nothing meaningful should be inserted at <CURSOR>, output an empty string.",
      }, "\n"),
    },
    {
      role = "user",
      content = ("File: %s (language: %s)\n%s<CURSOR>%s"):format(short_name, ft ~= "" and ft or "code", prefix, suffix),
    },
  }

  local AI = require("config.ai_api")
  local done = false
  local job = AI.chat(messages, {
    provider = PROVIDER_ID, -- СТРОГО "gemini"!
    model = ghost_model,
    temperature = 0.1,
    max_tokens = 384,
    timeout = 12,
    silent_cancel = true,
  }, function(reply, err, prov)
    done = true
    if my_seq ~= inflight_seq then
      return
    end
    inflight_job = nil
    refresh_statusline()

    -- Двойной предохранитель: ответ обязан прийти от gemini
    if prov and prov.id and prov.id ~= PROVIDER_ID then
      return
    end

    if err then
      if tostring(err):find("HTTP 429", 1, true) then
        backoff_until_ms = now_ms() + BACKOFF_429_MS
      end
      if opts.manual then
        echo_status("👻 Ghost Text (Gemini): " .. tostring(err), "WarningMsg")
      end
      return
    end

    if not M.enabled and not opts.manual then
      return
    end
    if not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_get_current_buf() ~= bufnr then
      return
    end
    local now_mode = (vim.fn and type(vim.fn.mode) == "function" and vim.fn.mode()) or "i"
    if not opts.manual and not now_mode:match("^[iR]") then
      return
    end
    local now_cur = vim.api.nvim_win_get_cursor(0)
    if now_cur[1] ~= row or now_cur[2] ~= safe_col then
      return
    end
    local check_line = (vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]) or ""
    if check_line ~= cur_line then
      return
    end

    local cleaned = M.clean_completion(reply or "", before_cursor, after_cursor, next_line)
    if cleaned == "" then
      return
    end
    cache_put(cache_key, cleaned)
    M.render(bufnr, row, safe_col, cleaned)
  end)
  if not done and my_seq == inflight_seq then
    inflight_job = job
  end
  refresh_statusline()
end

--- Запланировать автоподсказку после остановки набора (debounce).
function M.schedule()
  stop_timer()
  if not M.enabled then
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  if not M.is_eligible_buf(bufnr) then
    return
  end
  -- Не запускаем таймер зря, если ключа Gemini нет
  local gem = M.resolve_gemini()
  if not gem then
    return
  end

  local delay = tonumber(vim.g.ghost_text_debounce_ms) or DEFAULT_DEBOUNCE_MS
  local uv = vim.uv or vim.loop
  if uv and type(uv.new_timer) == "function" then
    local t = uv.new_timer()
    debounce_timer = t
    t:start(delay, 0, vim.schedule_wrap(function()
      if debounce_timer == t then
        pcall(function() t:stop(); t:close() end)
        debounce_timer = nil
      end
      M.request_suggestion({ manual = false })
    end))
  else
    vim.defer_fn(function()
      M.request_suggestion({ manual = false })
    end, delay)
  end
end

--- Запросить подсказку Gemini вручную прямо сейчас (:GhostTextSuggest / <M-g> / <leader>Ai).
function M.trigger()
  if vim.fn and type(vim.fn.mode) == "function" and vim.fn.mode() == "n" then
    pcall(vim.cmd, "startinsert")
  end
  M.request_suggestion({ manual = true })
end

--- Включить Ghost Text (только Gemini).
function M.enable()
  M.enabled = true
  M.user_toggled = true
  local gem, why, ghost_model = M.resolve_gemini()
  refresh_statusline()
  if gem then
    local msg = ("👻 Ghost Text (только Gemini · %s): ВКЛ  [принять: Tab / Alt+L · слово: Alt+W · выкл: <leader>AG]"):format(tostring(ghost_model))
    vim.notify(msg, vim.log.levels.INFO)
    echo_status(msg, "MoreMsg")
  else
    local msg = "👻 Ghost Text (только Gemini): ВКЛ, но ключ Gemini ещё не задан (" .. tostring(why) .. " → <leader>Ag)"
    vim.notify(msg, vim.log.levels.WARN)
    echo_status(msg, "WarningMsg")
  end
end

--- Выключить Ghost Text мгновенно.
function M.disable()
  M.enabled = false
  M.user_toggled = true
  M.dismiss()
  refresh_statusline()
  local msg = "👻 Ghost Text (Gemini): ВЫКЛ  [включить обратно: <leader>AG или <leader>ui]"
  vim.notify(msg, vim.log.levels.INFO)
  echo_status(msg, "WarningMsg")
end

--- Переключить Ghost Text вкл/выкл по хоткею (<leader>AG / <leader>ui).
function M.toggle()
  if M.enabled then
    M.disable()
  else
    M.enable()
  end
end

--- Показать подробный статус Ghost Text (:GhostText status).
function M.status()
  local gem, why, ghost_model = M.resolve_gemini()
  local state_str = M.enabled and "ВКЛЮЧЕН (по умолчанию)" or "ВЫКЛЮЧЕН"
  local key_str = gem and ("настроен, модель `" .. tostring(ghost_model) .. "`") or ("НЕ настроен (" .. tostring(why) .. ")")
  local msg = ("👻 Ghost Text (ТОЛЬКО Google Gemini): %s · ключ: %s · переключить: <leader>AG / <leader>ui"):format(state_str, key_str)
  vim.notify(msg, vim.log.levels.INFO)
  echo_status(msg, gem and M.enabled and "MoreMsg" or "WarningMsg")
end

--- Индикатор для Lualine: показывает статус Gemini Ghost Text и кликом переключает вкл/выкл.
---@return string
function M.lualine_component()
  if not M.enabled then
    return M.user_toggled and "👻 off" or ""
  end
  local gem = M.resolve_gemini()
  if not gem then
    return ""
  end
  if inflight_job ~= nil then
    return "👻 Gemini…"
  end
  return "👻 Gemini"
end

function M.setup()
  if setup_done then
    return
  end
  setup_done = true
  ensure_ns()
  ensure_hl()

  if vim.api and type(vim.api.nvim_create_augroup) == "function" then
    local grp = vim.api.nvim_create_augroup("GeminiGhostText", { clear = true })

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = grp,
      callback = ensure_hl,
    })

    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
      group = grp,
      callback = function()
        M.clear()
        M.schedule()
      end,
    })

    vim.api.nvim_create_autocmd("CursorMovedI", {
      group = grp,
      callback = function()
        if not current then
          return
        end
        local cur = vim.api.nvim_win_get_cursor(0)
        if cur[1] ~= current.row or cur[2] ~= current.col then
          M.clear()
        end
      end,
    })

    vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave" }, {
      group = grp,
      callback = function()
        M.dismiss()
      end,
    })
  end

  -- Команды управления Ghost Text
  vim.api.nvim_create_user_command("GhostTextToggle", function()
    M.toggle()
  end, { force = true, desc = "👻 Вкл/выкл призрачные подсказки (Ghost Text, только Gemini)" })

  vim.api.nvim_create_user_command("GhostTextOn", function()
    M.enable()
  end, { force = true, desc = "👻 Включить призрачные подсказки (Ghost Text, только Gemini)" })

  vim.api.nvim_create_user_command("GhostTextOff", function()
    M.disable()
  end, { force = true, desc = "👻 Выключить призрачные подсказки (Ghost Text, только Gemini)" })

  vim.api.nvim_create_user_command("GhostTextSuggest", function()
    M.trigger()
  end, { force = true, desc = "👻 Запросить призрачную подсказку Gemini прямо сейчас" })

  vim.api.nvim_create_user_command("GhostText", function(cmd_opts)
    local arg = vim.trim((cmd_opts and cmd_opts.args) or ""):lower()
    if arg == "on" or arg == "enable" or arg == "1" then
      M.enable()
    elseif arg == "off" or arg == "disable" or arg == "0" then
      M.disable()
    elseif arg == "status" then
      M.status()
    elseif arg == "suggest" or arg == "trigger" then
      M.trigger()
    else
      M.toggle()
    end
  end, {
    force = true,
    nargs = "?",
    complete = function()
      return { "toggle", "on", "off", "status", "suggest" }
    end,
    desc = "👻 Управление Ghost Text (только Gemini): toggle / on / off / status / suggest",
  })

  -- Хоткеи переключения вкл/выкл (Normal mode) и управления в Insert mode:
  vim.keymap.set("n", "<leader>AG", M.toggle, {
    desc = "👻 Ghost Text (только Gemini): вкл/выкл (:GhostTextToggle)",
    silent = true,
  })
  vim.keymap.set("n", "<leader>ui", M.toggle, {
    desc = "👻 Призрачные подсказки Gemini (Ghost Text): вкл/выкл",
    silent = true,
  })
  vim.keymap.set("n", "<leader>Ai", M.trigger, {
    desc = "👻 Запросить inline-подсказку Gemini сейчас (:GhostTextSuggest)",
    silent = true,
  })

  -- В режиме вставки: принять целиком (<M-l>), принять слово (<M-w> / <C-Right>), скрыть (<C-]>), вызвать (<M-g>)
  vim.keymap.set("i", "<M-l>", function()
    if M.accept() then
      return
    end
    local ok_av, av = pcall(require, "avante")
    if ok_av and type(av.get) == "function" then
      local _, _, sg = av.get()
      if sg and type(sg.is_visible) == "function" and sg:is_visible() then
        sg:accept()
      end
    end
  end, { desc = "👻 Принять Ghost Text подсказку целиком", silent = true })

  vim.keymap.set("i", "<M-w>", function()
    M.accept_word()
  end, { desc = "👻 Принять следующее слово из Ghost Text", silent = true })

  vim.keymap.set("i", "<C-Right>", function()
    if not M.accept_word() then
      local keys = vim.api.nvim_replace_termcodes("<C-Right>", true, false, true)
      vim.api.nvim_feedkeys(keys, "n", false)
    end
  end, { desc = "👻 Принять следующее слово из Ghost Text", silent = true })

  vim.keymap.set("i", "<C-]>", function()
    if M.is_visible() then
      M.dismiss()
      return
    end
    local ok_av, av = pcall(require, "avante")
    if ok_av and type(av.get) == "function" then
      local _, _, sg = av.get()
      if sg and type(sg.dismiss) == "function" then
        sg:dismiss()
      end
    end
  end, { desc = "👻 Скрыть текущую Ghost Text подсказку", silent = true })

  vim.keymap.set("i", "<M-g>", function()
    M.trigger()
  end, { desc = "👻 Запросить Ghost Text подсказку Gemini вручную", silent = true })
end

return M
