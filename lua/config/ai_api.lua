-- ========================================================================== --
--        ЕДИНЫЙ API ДЛЯ ЛЮБОГО ИИ: Groq, Gemini, OpenAI, OpenRouter, Mistral… --
-- ========================================================================== --
-- Почти все современные сервисы ИИ понимают один и тот же формат запроса —
-- OpenAI chat/completions. Поэтому весь код конфига общается с ИИ через этот
-- модуль: меняется только адрес, ключ и модель, сама логика не меняется.
--
-- КЛЮЧИ — из переменных окружения (fish, постоянно):
--     set -Ux AVANTE_GEMINI_API_KEY "AIza..."   # отдельный прямой ключ Gemini
--     set -Ux GEMINI_API_KEY "AIza..."          # или общий ключ Gemini
--     set -Ux GROQ_API_KEY "gsk_..."
--     set -Ux OPENROUTER_API_KEY "sk-or-..."
-- В файлы конфига и в git ключ никогда не пишется. Значение ключа никогда
-- не печатается (в :AiStatus видно только имя переменной). Для быстрого ввода
-- ключа прямо на текущий сеанс без перезапуска: :AvanteGemini / :AvanteKey (<leader>Ag / <leader>Ak).
--
-- ВЫБОР ПРОВАЙДЕРА (переключает СРАЗУ и открытый чат Avante, и :AiAsk / K):
--   * <leader>Ag или :AvanteGemini     — сразу на прямой Google Gemini;
--   * <leader>Ao или :AvanteOpenRouter — сразу на OpenRouter;
--   * <leader>Ap или :AiProvider <id>  — меню всех провайдеров;
--   * set -Ux AI_PROVIDER gemini       — постоянно.
-- МОДЕЛЬ: <ИМЯ>_MODEL (например GEMINI_MODEL, OPENROUTER_MODEL). Если в переменной
-- случайно прописан русскоязычный шаблон из примера («автор/модель:free»), он
-- автоматически отсекается и заменяется рабочей моделью по умолчанию.
local M = {}

local TIMEOUT = 40 -- секунд на один запрос

-- Запомненные некорректные значения *_MODEL (например «автор/модель:free»), чтобы показать подсказку в :AiStatus.
M.ignored_model_envs = {}

-- Реестр. base — адрес БЕЗ /chat/completions; key — имена переменных с ключом
-- по приоритету; model — модель по умолчанию (меняется переменной model_env).
M.providers = {
  {
    id = "groq", label = "Groq — очень быстрый, есть бесплатный тариф",
    base = "https://api.groq.com/openai/v1", key = { "GROQ_API_KEY" },
    model = "openai/gpt-oss-120b", model_env = "GROQ_MODEL", -- Llama 3.3 выведена Groq 16.08.2026
  },
  {
    id = "gemini", label = "Google Gemini (прямой API-ключ)",
    base = "https://generativelanguage.googleapis.com/v1beta/openai",
    key = { "AVANTE_GEMINI_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY" },
    model = "gemini-3.6-flash", model_env = "GEMINI_MODEL",
    model_names = { "gemini-3.6-flash", "gemini-3.6-pro", "gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash" },
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
    model_names = {
      "openrouter/free",
      "qwen/qwen3-coder:free",
      "deepseek/deepseek-chat-v3-0324:free",
      "google/gemini-2.5-flash",
      "anthropic/claude-sonnet-4",
    },
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

--- Проверка, что строка является настоящим ASCII ID модели, а не шаблоном из доки
--- (например «автор/модель:free», «имя-модели», «...»).
---@param val any
---@return boolean
function M.is_valid_model_id(val)
  if type(val) ~= "string" then
    return false
  end
  local s = vim.trim(val)
  if s == "" then
    return false
  end
  if s:find("[\128-\255]") or s:find("%s") or s:find("[\"'<>]") or s:find("%.%.%.", 1, true) then
    return false
  end
  return true
end

--- Прочитать модель из переменной окружения с защитой от битых/русскоязычных шаблонов.
---@param env_name? string
---@param fallback? string
---@return string|nil
function M.env_model(env_name, fallback)
  local raw = env_name and vim.env[env_name] or nil
  if raw and raw ~= "" then
    if M.is_valid_model_id(raw) then
      M.ignored_model_envs[env_name] = nil
      return vim.trim(raw)
    end
    M.ignored_model_envs[env_name] = raw
  end
  return fallback
end

local function is_placeholder_key(val)
  if type(val) ~= "string" then
    return true
  end
  local s = vim.trim(val)
  if s == "" then
    return true
  end
  if s:find("[\128-\255]") or s == "..." or s == "sk-or-..." or s == "AIza..." then
    return true
  end
  return false
end

function M.find(id)
  for _, p in ipairs(M.providers) do
    if p.id == id then
      return p
    end
  end
  return nil
end

--- Первое непустое валидное значение из переменных ключа: key, имя_переменной.
function M.key_of(p)
  for _, name in ipairs(p.key) do
    local v = vim.env[name]
    if v and v ~= "" and not is_placeholder_key(v) then
      return v, name
    end
  end
  return nil, nil
end

--- Синхронизировать ключ Gemini в окружение процесса C (для встроенного провайдера Avante,
--- который вызывает `os.getenv("AVANTE_GEMINI_API_KEY")` / `os.getenv("GEMINI_API_KEY")` и кеширует ответ).
function M.sync_gemini_env()
  local p = M.find("gemini")
  if not p then
    return nil, nil
  end
  local val, var_name = M.key_of(p)
  if not val then
    return nil, nil
  end
  if is_placeholder_key(vim.env.AVANTE_GEMINI_API_KEY) and is_placeholder_key(vim.env.GEMINI_API_KEY) then
    vim.env.GEMINI_API_KEY = val
    pcall(vim.fn.setenv, "GEMINI_API_KEY", val)
  elseif var_name == "AVANTE_GEMINI_API_KEY" then
    pcall(vim.fn.setenv, "AVANTE_GEMINI_API_KEY", val)
  elseif var_name == "GEMINI_API_KEY" then
    pcall(vim.fn.setenv, "GEMINI_API_KEY", val)
  end
  local env_mod = package.loaded["avante.utils.environment"]
  if type(env_mod) == "table" and type(env_mod.cache) == "table" then
    env_mod.cache = {}
  end
  return val, var_name
end

--- Очистить сохранённый state-файл Avante (`~/.local/state/nvim/avante/config.json`),
--- если туда попала невалидная модель (например `автор/модель:free`).
---@param state_file? string
---@return boolean repaired
function M.sanitize_avante_state_file(state_file)
  local path = state_file or (vim.fn.stdpath("state") .. "/avante/config.json")
  local rf = io.open(path, "r")
  if not rf then
    return false
  end
  local raw = rf:read("*a")
  rf:close()
  if not raw or raw == "" then
    return false
  end
  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" then
    return false
  end

  local dirty = false
  local prov = type(data.last_provider) == "string" and data.last_provider or nil
  local fallback = (prov == "gemini" or prov == "gemini-flash" or prov == "gemini-direct") and M.env_model("GEMINI_MODEL", "gemini-3.6-flash")
    or ((prov == "openrouter" or prov == "openrouter-free") and M.env_model("OPENROUTER_MODEL", "openrouter/free"))
    or nil

  if data.last_model ~= nil and not M.is_valid_model_id(data.last_model) then
    if fallback then
      data.last_model = fallback
      dirty = true
    else
      os.remove(path)
      return true
    end
  end
  if data.provider_model ~= nil and not M.is_valid_model_id(data.provider_model) then
    data.provider_model = fallback or data.last_model
    dirty = true
  end

  if dirty then
    local wf = io.open(path, "w")
    if wf then
      wf:write(vim.json.encode(data))
      wf:close()
    else
      os.remove(path)
    end
    return true
  end
  return false
end

--- Установить API-ключ провайдера на текущий сеанс Neovim (в память процесса, без записи на диск).
---@param provider_id string
---@param raw_key string
---@return boolean, string
function M.set_session_key(provider_id, raw_key)
  local p = M.find(provider_id)
  if not p or not p.key or #p.key == 0 then
    return false, "неизвестный провайдер: " .. tostring(provider_id)
  end
  local clean = vim.trim(tostring(raw_key or ""))
  if is_placeholder_key(clean) or clean:find("[\r\n]") then
    return false, "ключ пустой или содержит недопустимые символы"
  end
  local env_var = p.key[1] -- для gemini это AVANTE_GEMINI_API_KEY (отдельный ключ Gemini!)
  vim.env[env_var] = clean
  pcall(vim.fn.setenv, env_var, clean)
  if provider_id == "gemini" and is_placeholder_key(vim.env.GEMINI_API_KEY) then
    vim.env.GEMINI_API_KEY = clean
    pcall(vim.fn.setenv, "GEMINI_API_KEY", clean)
  end
  local env_mod = package.loaded["avante.utils.environment"]
  if type(env_mod) == "table" and type(env_mod.cache) == "table" then
    env_mod.cache = {}
  end
  return true, env_var
end

--- Переключить провайдера прямо в уже загруженном чате Avante (без перезапуска Neovim).
---@param id string например "gemini", "openrouter", "groq"
---@param opts? { save?: boolean, open_sidebar?: boolean, model?: string }
---@return boolean switched
function M.switch_avante_provider(id, opts)
  opts = opts or {}
  if id == "gemini" or id == "gemini-direct" then
    M.sync_gemini_env()
  end
  local env_mod = package.loaded["avante.utils.environment"]
  if type(env_mod) == "table" and type(env_mod.cache) == "table" then
    env_mod.cache = {}
  end

  local av_cfg = package.loaded["avante.config"]
  local av_api = package.loaded["avante.api"]
  if type(av_cfg) ~= "table" or type(av_api) ~= "table" or type(av_api.switch_provider) ~= "function" then
    return false
  end

  local target = id
  local known = type(av_cfg.providers) == "table" and av_cfg.providers or {}
  if not known[target] then
    return false
  end

  if opts.model and M.is_valid_model_id(opts.model) and type(known[target]) == "table" then
    known[target].model = opts.model
  end

  local suggest_target = (target == "gemini" or target == "gemini-direct") and (known["gemini-flash"] and "gemini-flash" or target) or target
  if type(av_cfg.override) == "function" then
    pcall(av_cfg.override, { auto_suggestions_provider = suggest_target })
  end

  local save_choice = opts.save ~= false
  local ok_sw = pcall(av_api.switch_provider, target, save_choice)
  if ok_sw and opts.open_sidebar then
    local ok_av, av = pcall(require, "avante")
    if ok_av and type(av) == "table" then
      if type(av.is_sidebar_open) == "function" and not av.is_sidebar_open() and type(av.open_sidebar) == "function" then
        pcall(av.open_sidebar, {})
      end
    end
  end
  return ok_sw
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
    return nil, 'ни один ИИ не настроен: задай ключ, например set -Ux GEMINI_API_KEY "..." или GROQ_API_KEY "..." (fish)'
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
      return nil, ("нет ключа: переменная $%s не задана (или нажми <leader>Ak / :AvanteGemini)"):format(p.key[1])
    end
  end
  local model = M.env_model(p.model_env, nil)
  if (not model or model == "") and vim.env.AI_PROVIDER == id then
    model = M.env_model("AI_MODEL", nil)
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
    [400] = "неверный запрос (проверь имя модели через <leader>Am / :AiStatus)",
    [401] = "ключ не принят — проверь переменную окружения",
    [403] = "доступ запрещён (ключ, регион или права)",
    [404] = "модель или адрес не найдены — проверь имя модели",
    [429] = "лимит запросов — подожди или смени провайдера (<leader>Ap / <leader>Ag)",
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
        model = M.env_model(p.model_env, p.model),
        model_names = p.model_names,
        timeout = 30000,
      }
    end
  end
  if (vim.env.AI_BASE_URL or "") ~= "" then
    out.custom = {
      __inherited_from = "openai",
      endpoint = vim.env.AI_BASE_URL,
      api_key_name = "AI_API_KEY",
      model = M.env_model("AI_MODEL", ""),
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
-- Интерфейс: выбор провайдера, ввод ключа на сеанс, статус, быстрый вопрос
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
  local eff_model = M.env_model(p.model_env, p.model) or "?"
  if name then
    return ("✓ %s — %s [модель: %s, ключ: $%s]"):format(p.id, p.label, eff_model, name)
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
  local warned = false
  for env_name, bad_val in pairs(M.ignored_model_envs) do
    if not warned then
      lines[#lines + 1] = ""
      lines[#lines + 1] = "⚠️ Защита от битых шаблонов моделей:"
      warned = true
    end
    lines[#lines + 1] = ("  • $%s = «%s» проигнорировано (заменено рабочей моделью). Очистить в fish: set -Ue %s"):format(
      env_name,
      tostring(bad_val),
      env_name
    )
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Быстрое переключение чата Avante:"
  lines[#lines + 1] = "  • <leader>Ag (:AvanteGemini)     — прямой Google Gemini"
  lines[#lines + 1] = "  • <leader>Ao (:AvanteOpenRouter) — OpenRouter"
  lines[#lines + 1] = "  • <leader>Ap (:AiProvider <id>)  — меню всех провайдеров"
  lines[#lines + 1] = "  • <leader>Am (:AvanteModels)     — смена модели текущего провайдера"
  lines[#lines + 1] = "  • <leader>Ak (:AvanteKey)        — вставить API-ключ на текущий сеанс"
  return table.concat(lines, "\n")
end

local function apply_provider_choice(id, open_sidebar)
  vim.g.ai_provider = id
  local r, why = M.resolve(id)
  if r then
    local switched = M.switch_avante_provider(id, { save = true, open_sidebar = open_sidebar })
    local suffix = switched and " (открытый чат Avante тоже переключён!)" or ""
    vim.notify(("ИИ: %s, модель %s%s"):format(r.label, r.model, suffix), vim.log.levels.INFO)
  else
    vim.notify("ИИ: выбран " .. id .. ", но " .. why, vim.log.levels.WARN)
  end
end

function M.pick()
  vim.ui.select(M.providers, {
    prompt = "🤖 ИИ-провайдер (переключит и чат Avante, и :AiAsk):",
    format_item = function(p)
      return status_line(p)
    end,
  }, function(p)
    if not p then
      return
    end
    -- Если у выбранного провайдера ещё нет ключа, сразу предложим вставить его на сеанс:
    if not p.local_ and p.id ~= "custom" and M.key_of(p) == nil then
      vim.ui.input({
        prompt = ("🔑 Вставьте API-ключ для %s ($%s, только на сеанс): "):format(p.id, p.key[1]),
      }, function(val)
        if val and vim.trim(val) ~= "" then
          local ok_set, err_or_var = M.set_session_key(p.id, val)
          if ok_set then
            apply_provider_choice(p.id, true)
            pcall(vim.api.nvim_echo, {
              { ("✅ Ключ $%s установлен на сеанс, чат переключён на %s. Для сохранения в fish: set -Ux %s \"ваш_ключ\""):format(err_or_var, p.id, err_or_var), "MoreMsg" },
            }, true, {})
            return
          end
        end
        apply_provider_choice(p.id, false)
      end)
      return
    end
    apply_provider_choice(p.id, false)
  end)
end

--- Быстро переключить чат на прямой Google Gemini (или попросить вставить прямой ключ Gemini, если он ещё не задан).
---@param arg? string модель (например "gemini-2.5-pro") или пусто
function M.use_gemini(arg)
  local trimmed = vim.trim(tostring(arg or ""))
  local model_override = trimmed ~= "" and M.is_valid_model_id(trimmed) and trimmed or nil
  local key_val = M.sync_gemini_env()
  if key_val then
    vim.g.ai_provider = "gemini"
    if model_override then
      vim.env.GEMINI_MODEL = model_override
    end
    local ok_lazy, lazy = pcall(require, "lazy")
    if ok_lazy and type(lazy) == "table" and type(lazy.load) == "function" and not package.loaded["avante.api"] then
      pcall(lazy.load, { plugins = { "avante.nvim" } })
    end
    local switched = M.switch_avante_provider("gemini", {
      save = true,
      open_sidebar = true,
      model = model_override,
    })
    local eff_model = M.env_model("GEMINI_MODEL", "gemini-3.6-flash")
    local msg = switched
      and ("✅ Чат Avante переключён на прямой Google Gemini (модель: " .. eff_model .. " · смена модели: <leader>Am)")
      or ("✅ ИИ переключён на прямой Google Gemini (модель: " .. eff_model .. ")")
    vim.notify(msg, vim.log.levels.INFO)
    pcall(vim.api.nvim_echo, { { msg, "MoreMsg" } }, true, {})
    return
  end

  vim.ui.input({
    prompt = "🔑 Вставьте ваш прямой ключ Google Gemini (AIza… — только в память сеанса): ",
  }, function(input_key)
    if not input_key or vim.trim(input_key) == "" then
      return
    end
    local ok_set, var_or_err = M.set_session_key("gemini", input_key)
    if not ok_set then
      vim.notify("Gemini: " .. tostring(var_or_err), vim.log.levels.ERROR)
      return
    end
    M.use_gemini(model_override)
    pcall(vim.api.nvim_echo, {
      { "✅ Прямой ключ Gemini подключён! Чтобы сохранить навсегда в fish: set -Ux AVANTE_GEMINI_API_KEY \"ваш_ключ\"", "MoreMsg" },
    }, true, {})
  end)
end

--- Быстро переключить чат на OpenRouter (с гарантированно валидной моделью).
function M.use_openrouter(arg)
  local trimmed = vim.trim(tostring(arg or ""))
  local model_override = trimmed ~= "" and M.is_valid_model_id(trimmed) and trimmed or nil
  local p = M.find("openrouter")
  if p and M.key_of(p) == nil then
    vim.ui.input({
      prompt = "🔑 Вставьте ключ OpenRouter (sk-or-… — только в память сеанса): ",
    }, function(input_key)
      if not input_key or vim.trim(input_key) == "" then
        return
      end
      local ok_set, var_or_err = M.set_session_key("openrouter", input_key)
      if not ok_set then
        vim.notify("OpenRouter: " .. tostring(var_or_err), vim.log.levels.ERROR)
        return
      end
      M.use_openrouter(model_override)
    end)
    return
  end
  vim.g.ai_provider = "openrouter"
  if model_override then
    vim.env.OPENROUTER_MODEL = model_override
  end
  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy and type(lazy) == "table" and type(lazy.load) == "function" and not package.loaded["avante.api"] then
    pcall(lazy.load, { plugins = { "avante.nvim" } })
  end
  local eff_model = M.env_model("OPENROUTER_MODEL", "openrouter/free")
  local switched = M.switch_avante_provider("openrouter", {
    save = true,
    open_sidebar = true,
    model = eff_model,
  })
  local msg = switched
    and ("✅ Чат Avante переключён на OpenRouter (модель: " .. eff_model .. ")")
    or ("✅ ИИ переключён на OpenRouter (модель: " .. eff_model .. ")")
  vim.notify(msg, vim.log.levels.INFO)
  pcall(vim.api.nvim_echo, { { msg, "MoreMsg" } }, true, {})
end

--- Вставить или обновить API-ключ любого провайдера прямо в сеансе Neovim.
function M.prompt_session_key(provider_id)
  local function ask_key(p)
    vim.ui.input({
      prompt = ("🔑 Новый ключ для %s ($%s, только в память сеанса): "):format(p.id, p.key[1]),
    }, function(val)
      if not val or vim.trim(val) == "" then
        return
      end
      local ok_set, var_or_err = M.set_session_key(p.id, val)
      if not ok_set then
        vim.notify("ИИ: " .. tostring(var_or_err), vim.log.levels.ERROR)
        return
      end
      apply_provider_choice(p.id, true)
      pcall(vim.api.nvim_echo, {
        { ("✅ Ключ $%s обновлён на сеанс. Постоянно в fish: set -Ux %s \"ваш_ключ\""):format(var_or_err, var_or_err), "MoreMsg" },
      }, true, {})
    end)
  end

  if provider_id and provider_id ~= "" then
    local p = M.find(provider_id)
    if not p or p.local_ then
      vim.notify("ИИ: провайдер «" .. tostring(provider_id) .. "» не требует API-ключа", vim.log.levels.WARN)
      return
    end
    return ask_key(p)
  end

  local keyed = {}
  for _, p in ipairs(M.providers) do
    if not p.local_ and p.key and #p.key > 0 then
      keyed[#keyed + 1] = p
    end
  end
  vim.ui.select(keyed, {
    prompt = "🔑 Для какого провайдера задать API-ключ на сеанс?",
    format_item = function(p)
      return status_line(p)
    end,
  }, function(p)
    if p then
      ask_key(p)
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
  M.sync_gemini_env()
  M.sanitize_avante_state_file()

  vim.api.nvim_create_user_command("AiProvider", function(o)
    if o.args == "" then
      return M.pick()
    end
    if not M.find(o.args) then
      return vim.notify("ИИ: нет провайдера «" .. o.args .. "» (см. :AiStatus)", vim.log.levels.ERROR)
    end
    apply_provider_choice(o.args, false)
  end, {
    nargs = "?",
    complete = function()
      local ids = {}
      for _, p in ipairs(M.providers) do
        ids[#ids + 1] = p.id
      end
      return ids
    end,
    desc = "🤖 Выбрать ИИ-провайдера (переключает и чат Avante)",
  })
  vim.api.nvim_create_user_command("AvanteGemini", function(o)
    M.use_gemini(o.args)
  end, {
    nargs = "?",
    complete = function()
      return { "gemini-3.6-flash", "gemini-3.6-pro", "gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash" }
    end,
    desc = "✨ Переключить чат Avante на прямой Google Gemini (или ввести ключ)",
  })
  vim.api.nvim_create_user_command("AvanteOpenRouter", function(o)
    M.use_openrouter(o.args)
  end, {
    nargs = "?",
    complete = function()
      return { "openrouter/free", "qwen/qwen3-coder:free", "deepseek/deepseek-chat-v3-0324:free" }
    end,
    desc = "🌐 Переключить чат Avante на OpenRouter",
  })
  vim.api.nvim_create_user_command("AvanteKey", function(o)
    M.prompt_session_key(o.args)
  end, {
    nargs = "?",
    complete = function()
      local ids = {}
      for _, p in ipairs(M.providers) do
        if not p.local_ and p.key and #p.key > 0 then
          ids[#ids + 1] = p.id
        end
      end
      return ids
    end,
    desc = "🔑 Вставить API-ключ провайдера на текущий сеанс Neovim",
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
  vim.keymap.set("n", "<leader>Ap", M.pick, { desc = "🤖 Выбрать ИИ-провайдера (сразу и для чата Avante)" })
  vim.keymap.set("n", "<leader>Ag", function() M.use_gemini() end, { desc = "✨ Чат Avante → прямой Google Gemini" })
  vim.keymap.set("n", "<leader>Ao", function() M.use_openrouter() end, { desc = "🌐 Чат Avante → OpenRouter" })
  vim.keymap.set("n", "<leader>Ak", function() M.prompt_session_key() end, { desc = "🔑 Задать API-ключ ИИ на сеанс" })
  vim.keymap.set("n", "<leader>Am", function()
    local ok_lazy, lazy = pcall(require, "lazy")
    if ok_lazy and type(lazy) == "table" and type(lazy.load) == "function" and not package.loaded["avante.api"] then
      pcall(lazy.load, { plugins = { "avante.nvim" } })
    end
    if package.loaded["avante.api"] then
      vim.cmd("AvanteModels")
    else
      M.pick()
    end
  end, { desc = "🎛 Выбрать модель в чате Avante (:AvanteModels)" })
  vim.keymap.set("n", "<leader>Aq", function()
    vim.cmd("AiAsk")
  end, { desc = "🤖 Быстрый вопрос любому ИИ (ответ в окне)" })
end

return M
