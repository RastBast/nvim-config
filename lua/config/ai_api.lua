-- ========================================================================== --
--        ЕДИНЫЙ API ДЛЯ ЛЮБОГО ИИ: Groq, Gemini, OpenAI, OpenRouter, Mistral… --
-- ========================================================================== --
-- Почти все современные сервисы ИИ понимают один и тот же формат запроса —
-- OpenAI chat/completions. Поэтому весь код конфига общается с ИИ через этот
-- модуль: меняется только адрес, ключ и модель, сама логика не меняется.
--
-- КЛЮЧИ — ТОЛЬКО из переменных окружения (fish, постоянно):
--     set -Ux GROQ_API_KEY "..."
-- В файлы конфига, в git и в память Neovim ключ не пишется. Значение ключа
-- никогда не печатается (в :AiStatus видно только имя переменной).
--
-- ВЫБОР ПРОВАЙДЕРА:
--   * <leader>Ap или :AiProvider groq — на текущую сессию;
--   * set -Ux AI_PROVIDER groq         — постоянно;
--   * ничего не задано — берётся первый провайдер, для которого есть ключ.
-- МОДЕЛЬ: <ИМЯ>_MODEL (например GROQ_MODEL); AI_MODEL — только для провайдера из
-- AI_PROVIDER; иначе модель по умолчанию из реестра ниже.
--
-- СВОЙ СЕРВИС (любой OpenAI-совместимый): AI_BASE_URL, AI_API_KEY, AI_MODEL —
-- провайдер «custom».
local M = {}

local TIMEOUT = 40 -- секунд на один запрос

-- Реестр. base — адрес БЕЗ /chat/completions; key — имена переменных с ключом
-- по приоритету; model — модель по умолчанию (меняется переменной model_env).
M.providers = {
  {
    id = "groq", label = "Groq — очень быстрый, есть бесплатный тариф",
    base = "https://api.groq.com/openai/v1", key = { "GROQ_API_KEY" },
    model = "openai/gpt-oss-120b", model_env = "GROQ_MODEL", -- Llama 3.3 выведена Groq 16.08.2026
  },
  {
    id = "gemini", label = "Google Gemini",
    base = "https://generativelanguage.googleapis.com/v1beta/openai",
    key = { "AVANTE_GEMINI_API_KEY", "GEMINI_API_KEY" },
    model = "gemini-3.6-flash", model_env = "GEMINI_MODEL",
    -- Ретранслятор и прокси (PROXY.md, INSTALL.md §4.5): те же переменные, что раньше
    endpoint_env = "GEMINI_ENDPOINT", proxy_env = "GEMINI_PROXY", insecure_env = "GEMINI_INSECURE",
  },
  {
    id = "openai", label = "OpenAI",
    base = "https://api.openai.com/v1", key = { "OPENAI_API_KEY" },
    model = "gpt-4o-mini", model_env = "OPENAI_MODEL",
  },
  {
    id = "openrouter", label = "OpenRouter — сотни моделей (в т.ч. Claude, бесплатные)",
    base = "https://openrouter.ai/api/v1", key = { "OPENROUTER_API_KEY" },
    model = "openrouter/free", model_env = "OPENROUTER_MODEL",
  },
  {
    id = "mistral", label = "Mistral",
    base = "https://api.mistral.ai/v1", key = { "MISTRAL_API_KEY" },
    model = "mistral-small-latest", model_env = "MISTRAL_MODEL",
  },
  {
    id = "deepseek", label = "DeepSeek",
    base = "https://api.deepseek.com", key = { "DEEPSEEK_API_KEY" },
    model = "deepseek-chat", model_env = "DEEPSEEK_MODEL",
  },
  {
    id = "moonshot", label = "Moonshot / Kimi",
    base = "https://api.moonshot.ai/v1", key = { "MOONSHOT_API_KEY" },
    model = "moonshot-v1-8k", model_env = "MOONSHOT_MODEL",
  },
  {
    id = "ollama", label = "Ollama — модель на этом компьютере, без ключа",
    base = "http://localhost:11434/v1", key = {}, local_ = true,
    model = "llama3.2", model_env = "OLLAMA_MODEL",
  },
  {
    id = "custom", label = "Свой сервис (AI_BASE_URL + AI_API_KEY + AI_MODEL)",
    base_env = "AI_BASE_URL", key = { "AI_API_KEY" }, model_env = "AI_MODEL",
  },
}

function M.find(id)
  for _, p in ipairs(M.providers) do
    if p.id == id then
      return p
    end
  end
  return nil
end

--- Первое непустое значение из переменных ключа: key, имя_переменной.
function M.key_of(p)
  for _, name in ipairs(p.key) do
    local v = vim.env[name]
    if v and v ~= "" then
      return v, name
    end
  end
  return nil, nil
end

--- Провайдер, у которого есть всё для работы (ключ/адрес); для custom — оба.
local function usable(p)
  if p.id == "custom" then
    return (vim.env.AI_BASE_URL or "") ~= "" and M.key_of(p) ~= nil
  end
  if p.local_ then
    return false -- локальные не выбираются автоматически
  end
  return M.key_of(p) ~= nil
end

function M.auto_id()
  for _, p in ipairs(M.providers) do
    if usable(p) then
      return p.id
    end
  end
  return nil
end

--- Текущий провайдер: выбор на сессии → AI_PROVIDER → первый с ключом.
function M.active_id()
  if vim.g.ai_provider and vim.g.ai_provider ~= "" then
    return vim.g.ai_provider
  end
  local env = vim.env.AI_PROVIDER
  if env and env ~= "" then
    return env
  end
  return M.auto_id()
end

--- Проверка и сборка настроек провайдера. Возвращает {id,label,base,key,model,local_}
--- или nil, причина (по-русски, без значения ключа).
function M.resolve(id)
  id = id or M.active_id()
  if not id then
    return nil, 'ни один ИИ не настроен: задай ключ, например set -Ux GROQ_API_KEY "..." (fish)'
  end
  local p = M.find(id)
  if not p then
    return nil, ("неизвестный провайдер «%s» (список: :AiStatus)"):format(id)
  end
  local base = p.base
  if not base then
    base = vim.env[p.base_env or ""]
  end
  if p.endpoint_env and (vim.env[p.endpoint_env] or "") ~= "" then
    -- GEMINI_ENDPOINT обычно = «…/v1beta/models»; OpenAI-совместимый путь — «…/v1beta/openai».
    local root = (vim.env[p.endpoint_env]:gsub("/+$", "")):gsub("/models$", "")
    base = root .. "/openai"
  end
  if not base or base == "" then
    return nil, ("не задан адрес сервиса: переменная %s"):format(p.base_env or "?")
  end
  base = base:gsub("/+$", "")
  local key = nil
  if #p.key > 0 then
    key = M.key_of(p)
    if not key and not p.local_ then
      return nil, ("нет ключа: переменная $%s не задана"):format(p.key[1])
    end
  end
  local model = p.model_env and vim.env[p.model_env] or nil
  if (not model or model == "") and vim.env.AI_PROVIDER == id then
    model = vim.env.AI_MODEL
  end
  if not model or model == "" then
    model = p.model
  end
  if not model or model == "" then
    return nil, ("не задана модель: set -Ux %s \"имя-модели\" (fish)"):format(p.model_env or "AI_MODEL")
  end
  local proxy = p.proxy_env and vim.env[p.proxy_env] or nil
  if not proxy or proxy == "" then proxy = vim.env.AI_PROXY end
  if proxy == "" then proxy = nil end
  local insecure = p.insecure_env and (vim.env[p.insecure_env] or "") ~= "" and vim.env[p.insecure_env] ~= "0"
  return {
    id = id, label = p.label, base = base, key = key, model = model, local_ = p.local_,
    proxy = proxy, insecure = insecure or false,
  }
end

--- Понятный текст ошибки HTTP-ответа (без ключа).
local function http_error(code, body)
  local msg = nil
  local ok, data = pcall(vim.json.decode, body)
  if ok and type(data) == "table" then
    if type(data.error) == "table" and type(data.error.message) == "string" then
      msg = data.error.message
    elseif type(data.error) == "string" then
      msg = data.error
    elseif type(data.message) == "string" then
      msg = data.message
    end
  end
  local hints = {
    [400] = "неверный запрос (модель может не поддерживать JSON-режим)",
    [401] = "ключ не принят — проверь переменную окружения",
    [403] = "доступ запрещён (ключ, регион или права)",
    [404] = "модель или адрес не найдены — проверь имя модели",
    [429] = "лимит запросов — подожди или смени провайдера (:AiProvider)",
  }
  local parts = { "HTTP " .. code }
  if hints[code] then
    parts[#parts + 1] = hints[code]
  elseif code >= 500 then
    parts[#parts + 1] = "сервис ИИ временно недоступен"
  end
  if msg then
    parts[#parts + 1] = msg
  end
  return table.concat(parts, ": ")
end

-- Ни адресов с возможными токенами, ни stderr curl не показываем в сообщениях.
local function network_error(code, id)
  local hints = {
    [5] = "не найден прокси: проверьте AI_PROXY/GEMINI_PROXY",
    [6] = "не удалось разрешить имя сервера (DNS)",
    [7] = "не удалось подключиться к серверу или прокси",
    [28] = "истекло время ожидания; проверьте сеть, VPN и прокси; диагностика: <leader>AN",
    [35] = "ошибка TLS-соединения; проверьте сеть и прокси",
    [60] = "сертификат TLS не принят; проверьте сертификаты и прокси",
  }
  return ("сеть (%s, curl %s): %s"):format(id, tostring(code), hints[code] or "запрос не выполнен; диагностика: <leader>AN")
end

local function request_timeout(value)
  local n = tonumber(value) or tonumber(vim.env.AI_TIMEOUT) or TIMEOUT
  if n < 1 or n > 600 then return TIMEOUT end
  return n
end

-- Параметры с возможными секретами передаём curl через stdin, не через argv.
local function curl_config(key, proxy)
  local lines = {}
  local function quote(value)
    if value:find("[\r\n]") then return nil end
    return value:gsub("\\", "\\\\"):gsub('"', '\\"')
  end
  if proxy then
    local escaped = quote(proxy)
    if not escaped then return nil, "прокси содержит перевод строки" end
    lines[#lines + 1] = 'proxy = "' .. escaped .. '"'
  end
  if key then
    local escaped = quote(key)
    if not escaped then return nil, "ключ содержит перевод строки" end
    lines[#lines + 1] = 'header = "Authorization: Bearer ' .. escaped .. '"'
  end
  return #lines > 0 and table.concat(lines, "\n") .. "\n" or nil
end

-- Только проверка доступности /models без ключа и без кода пользователя.
-- HTTP 401/403/404 означает лишь, что сервер ответил, а не что ИИ работает.
function M.network_check()
  local p, why = M.resolve()
  if not p then return vim.notify("ИИ: " .. why, vim.log.levels.WARN) end
  if vim.fn.executable("curl") == 0 then return vim.notify("ИИ: нет curl", vim.log.levels.ERROR) end
  if p.base:match("^https?://[^/]*@") or p.base:find("[?#]") then
    return vim.notify("ИИ: проверка отменена: адрес содержит учётные данные или параметры", vim.log.levels.WARN)
  end
  local stdin, config_err = curl_config(nil, p.proxy)
  if config_err then return vim.notify("ИИ: " .. config_err, vim.log.levels.WARN) end
  local sink = vim.fn.has("win32") == 1 and "NUL" or "/dev/null"
  local args = { "curl", "-sS", "--max-time", "12", "-o", sink, "-w", "%{http_code}", p.base .. "/models" }
  if stdin then vim.list_extend(args, { "-K", "-" }) end
  if p.insecure then args[#args + 1] = "-k" end
  vim.notify("Проверяю сеть ИИ (" .. p.id .. ") без отправки ключа и кода…", vim.log.levels.INFO)
  local ok = pcall(vim.system, args, { text = true, stdin = stdin }, function(res)
    vim.schedule(function()
      local status = tonumber(vim.trim(res.stdout or ""))
      if res.code ~= 0 then
        return vim.notify("ИИ: " .. network_error(res.code, p.id), vim.log.levels.WARN)
      end
      if not status or status == 0 then
        return vim.notify("ИИ: сервер не вернул HTTP-ответ (" .. p.id .. ")", vim.log.levels.WARN)
      end
      vim.notify(("ИИ: %s ответил HTTP %d. Это только проверка сети, не ключа и модели."):format(p.id, status), vim.log.levels.INFO)
    end)
  end)
  if not ok then vim.notify("ИИ: не удалось запустить curl", vim.log.levels.ERROR) end
end

--- Один запрос chat/completions. cb(text|nil, причина|nil, провайдер|nil).
--- opts: provider (id), json (bool — JSON-режим), temperature, timeout.
function M.chat(messages, opts, cb)
  opts = opts or {}
  local p, why = M.resolve(opts.provider)
  if not p then
    return vim.schedule(function()
      cb(nil, why)
    end)
  end
  local body = {
    model = p.model,
    messages = messages,
    temperature = opts.temperature or 0.2,
  }
  if opts.json then
    body.response_format = { type = "json_object" }
  end
  if vim.fn.executable("curl") == 0 then
    return vim.schedule(function()
      cb(nil, "нет curl")
    end)
  end
  local args = {
    "curl", "-sS", "--max-time", tostring(request_timeout(opts.timeout)),
    "-w", "\n%{http_code}",
    "-X", "POST", p.base .. "/chat/completions",
    "-H", "Content-Type: application/json",
    "-d", vim.json.encode(body),
  }
  if p.insecure then args[#args + 1] = "-k" end
  local stdin, config_err = curl_config(p.key, p.proxy)
  if config_err then return vim.schedule(function() cb(nil, config_err, p) end) end
  if stdin then vim.list_extend(args, { "-K", "-" }) end
  local ok = pcall(vim.system, args, { text = true, stdin = stdin }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        return cb(nil, network_error(res.code, p.id), p)
      end
      local out = res.stdout or ""
      local payload, code_s = out:match("^(.*)\n(%d%d%d)%s*$")
      local code = tonumber(code_s or "")
      if not code then
        return cb(nil, "пустой ответ сервиса", p)
      end
      if code < 200 or code >= 300 then
        return cb(nil, http_error(code, payload or ""), p)
      end
      local ok2, data = pcall(vim.json.decode, payload or "")
      local choice = ok2 and type(data) == "table" and type(data.choices) == "table" and data.choices[1] or nil
      local msg = type(choice) == "table" and type(choice.message) == "table" and choice.message or nil
      local content = msg and msg.content or nil
      if type(content) ~= "string" or content == "" then
        return cb(nil, "пустой ответ сервиса", p)
      end
      cb(content, nil, p)
    end)
  end)
  if not ok then
    vim.schedule(function()
      cb(nil, "не удалось запустить curl", p)
    end)
  end
end

local function strip_fence(s)
  local t = vim.trim(s)
  t = t:gsub("^```[%w]*%s*", "")
  t = t:gsub("%s*```$", "")
  return t
end

--- То же, но ответ — JSON. cb(таблица|nil, причина|nil, провайдер|nil).
function M.chat_json(messages, opts, cb)
  local o = vim.tbl_extend("force", {}, opts or {}, { json = true })
  M.chat(messages, o, function(text, why, p)
    if not text then
      return cb(nil, why, p)
    end
    local ok, data = pcall(vim.json.decode, strip_fence(text))
    if not ok or type(data) ~= "table" then
      return cb(nil, "ответ не в формате JSON", p)
    end
    cb(data, nil, p)
  end)
end

-- ---------------------------------------------------------------------------
-- Интеграции: avante и codecompanion берут те же провайдеры из реестра
-- ---------------------------------------------------------------------------

--- Провайдеры для avante: все OpenAI-совместимые, кроме встроенных gemini/openai/ollama.
--- Наследуются от штатного провайдера avante «openai» (lua/avante/providers/openai.lua).
function M.avante_providers()
  local out = {}
  for _, p in ipairs(M.providers) do
    if p.base and not p.local_ and p.id ~= "gemini" and p.id ~= "openai" then
      out[p.id] = {
        __inherited_from = "openai",
        endpoint = p.base,
        api_key_name = p.key[1],
        model = (p.model_env and vim.env[p.model_env]) or p.model,
        timeout = 30000,
      }
    end
  end
  if (vim.env.AI_BASE_URL or "") ~= "" then
    out.custom = {
      __inherited_from = "openai",
      endpoint = vim.env.AI_BASE_URL,
      api_key_name = "AI_API_KEY",
      model = vim.env.AI_MODEL or "",
      timeout = 30000,
    }
  end
  return out
end

--- Какой провайдер avante выбрать по умолчанию (имя из avante_providers или встроенное).
function M.avante_default()
  local id = M.active_id()
  if id and id ~= "" then
    if id == "gemini" or id == "openai" or id == "ollama" then
      return id
    end
    if M.avante_providers()[id] then
      return id
    end
  end
  return "gemini"
end

--- Имя адаптера codecompanion для текущего провайдера (см. ai.lua).
M.cc_map = {
  groq = "groq", gemini = "gemini", openai = "openai", openrouter = "openrouter",
  mistral = "mistral", deepseek = "deepseek", moonshot = "kimi", ollama = "ollama",
  custom = "custom",
}

function M.cc_adapter()
  local id = M.active_id()
  return (id and M.cc_map[id]) or "kimi"
end

-- ---------------------------------------------------------------------------
-- Интерфейс: выбор провайдера, статус, быстрый вопрос
-- ---------------------------------------------------------------------------

local function status_line(p)
  local ready
  if p.id == "custom" then
    ready = (vim.env.AI_BASE_URL or "") ~= "" and M.key_of(p) ~= nil
    local st = ready and "✓" or "✗"
    return ("%s custom — %s (нужны AI_BASE_URL, AI_API_KEY)"):format(st, p.label)
  end
  if p.local_ then
    return ("· %s — %s (ключ не нужен)"):format(p.id, p.label)
  end
  local _, name = M.key_of(p)
  if name then
    return ("✓ %s — %s (ключ: $%s)"):format(p.id, p.label, name)
  end
  return ("✗ %s — %s (нет $%s)"):format(p.id, p.label, p.key[1])
end

function M.status()
  local lines = { "ИИ-провайдеры (ключи показываются только по имени переменной):" }
  local active = M.active_id()
  lines[#lines + 1] = "Активный: " .. (active or "не выбран — задай ключ")
  for _, p in ipairs(M.providers) do
    lines[#lines + 1] = "  " .. status_line(p)
  end
  lines[#lines + 1] = "Выбрать: <leader>Ap или :AiProvider <id>. Постоянно: set -Ux AI_PROVIDER <id>"
  return table.concat(lines, "\n")
end

function M.pick()
  vim.ui.select(M.providers, {
    prompt = "ИИ-провайдер",
    format_item = function(p)
      return status_line(p)
    end,
  }, function(p)
    if not p then
      return
    end
    vim.g.ai_provider = p.id
    local r, why = M.resolve(p.id)
    if r then
      vim.notify(
        ("ИИ: %s, модель %s. K и :AiAsk — сразу; ещё не загруженные чаты возьмут выбор. Для постоянного выбора задайте AI_PROVIDER")
          :format(r.label, r.model),
        vim.log.levels.INFO
      )
    else
      vim.notify("ИИ: выбран " .. p.id .. ", но " .. why, vim.log.levels.WARN)
    end
  end)
end

--- Окно с текстом (markdown). q / Esc — закрыть.
function M.float(title, text)
  local lines = vim.split(text, "\n", { plain = true })
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local width = math.min(math.max(60, math.floor(vim.o.columns * 0.6)), vim.o.columns - 6)
  local height = math.min(math.max(6, #lines + 2), vim.o.lines - 6)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
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
end

--- Быстрый вопрос в любой ИИ, ответ в окне.
function M.ask(question)
  local r, why = M.resolve()
  if not r then
    vim.notify("ИИ: " .. why, vim.log.levels.WARN)
    return
  end
  vim.notify("ИИ (" .. r.id .. ") думает…", vim.log.levels.INFO)
  M.chat({
    { role = "system", content = "Ты помощник программиста. Отвечай по-русски, по делу, в Markdown." },
    { role = "user", content = question },
  }, {}, function(text, err)
    if not text then
      return vim.notify("ИИ: " .. err, vim.log.levels.ERROR)
    end
    M.float(" 🤖 " .. r.id .. " · " .. r.model .. " ", text)
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("AiProvider", function(o)
    if o.args == "" then
      return M.pick()
    end
    if not M.find(o.args) then
      return vim.notify("ИИ: нет провайдера «" .. o.args .. "» (см. :AiStatus)", vim.log.levels.ERROR)
    end
    vim.g.ai_provider = o.args
    local r, why = M.resolve(o.args)
    vim.notify(r and ("ИИ: " .. r.label .. ", модель " .. r.model) or ("ИИ: " .. why), r and vim.log.levels.INFO or vim.log.levels.WARN)
  end, {
    nargs = "?",
    complete = function()
      local ids = {}
      for _, p in ipairs(M.providers) do
        ids[#ids + 1] = p.id
      end
      return ids
    end,
    desc = "🤖 Выбрать ИИ-провайдера (без аргумента — меню)",
  })
  vim.api.nvim_create_user_command("AiStatus", function()
    M.float(" 🤖 ИИ-провайдеры ", M.status())
  end, { desc = "🤖 Какие ИИ настроены (ключи — только по именам переменных)" })
  vim.api.nvim_create_user_command("AiCheck", M.network_check, { desc = "Проверить сеть ИИ без ключа и кода" })
  vim.api.nvim_create_user_command("AiAsk", function(o)
    if o.args == "" then
      return vim.ui.input({ prompt = "Вопрос ИИ: " }, function(q)
        if q and q ~= "" then
          M.ask(q)
        end
      end)
    end
    M.ask(o.args)
  end, { nargs = "*", desc = "🤖 Вопрос любому ИИ, ответ в окне" })

  vim.keymap.set("n", "<leader>AN", M.network_check, { desc = "🌐 Проверить сеть выбранного ИИ" })
  vim.keymap.set("n", "<leader>Ap", M.pick, { desc = "🤖 Выбрать ИИ-провайдера (Groq, Gemini, OpenAI…)" })
  vim.keymap.set("n", "<leader>Aq", function()
    vim.cmd("AiAsk")
  end, { desc = "🤖 Быстрый вопрос любому ИИ (ответ в окне)" })
end

return M
