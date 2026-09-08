-- ========================================================================== --
--              ОБЩИЙ АСИНХРОННЫЙ ПЕРЕВОД en→ru (Google gtx, curl)            --
-- ========================================================================== --
-- Пользователи: hover_ru (подсказки), diag_ru (ошибки LSP), notify_ru
-- (уведомления/вывод сборок), completions (окно документации cmp).
--
-- КЕШ: в памяти + файл stdpath("cache")/ru_cache.json — перевод переживает
-- перезапуск Neovim. Повторная ошибка/подсказка отдаётся СРАЗУ по-русски
-- (translate_cached), первый раз греет кеш асинхронно.
-- Любая ошибка (нет curl/сети, кривой JSON) → cb(nil); вызывающий показывает
-- оригинал — ничего не падает и не блокируется.

local M = { cache = {} }

local function cache_file()
  local ok, dir = pcall(vim.fn.stdpath, "cache")
  if not ok or type(dir) ~= "string" then
    dir = "/tmp"
  end
  return dir .. "/ru_cache.json"
end

-- подгружаем кеш прошлого сеанса
do
  local f = io.open(cache_file(), "r")
  if f then
    local raw = f:read("*a")
    f:close()
    local ok, data = pcall(vim.json.decode, raw)
    if ok and type(data) == "table" then
      for k, v in pairs(data) do
        if type(k) == "string" and type(v) == "string" then
          M.cache[k] = v
        end
      end
    end
  end
end

local save_scheduled = false
local function persist()
  if save_scheduled then
    return
  end
  save_scheduled = true
  vim.defer_fn(function()
    save_scheduled = false
    local ok, raw = pcall(vim.json.encode, M.cache)
    if ok then
      local f = io.open(cache_file(), "w")
      if f then
        f:write(raw)
        f:close()
      end
    end
  end, 2000)
end

function M.url_encode(s)
  return (s:gsub("([^%w%-%.%_%~ ])", function(c)
    return string.format("%%%02X", string.byte(c))
  end):gsub(" ", "+"))
end

--- Синхронно: перевод из кеша или nil (ещё не переводилось).
function M.translate_cached(text)
  return M.cache[text]
end

-- ---------- разборы ответов разных переводчиков ----------

--- Google gtx: [[["перевод","original",...],...],...]
local function parse_gtx(stdout)
  local ok, data = pcall(vim.json.decode, stdout)
  if not ok or type(data) ~= "table" or type(data[1]) ~= "table" then
    return nil
  end
  local out = {}
  for _, item in ipairs(data[1]) do
    if type(item) == "table" and type(item[1]) == "string" then
      out[#out + 1] = item[1]
    end
  end
  local joined = table.concat(out)
  return joined ~= "" and joined or nil
end

--- MyMemory: {"responseData":{"translatedText":"..."},"responseStatus":200}
--- ВАЖНО: при переполнении лимита или слишком длинной строке сервис отдаёт
--- responseStatus 403/400, а в translatedText — текст ошибки
--- («QUERY LENGTH LIMIT EXCEEDED»). Без проверки статуса этот текст
--- уезжал бы пользователю вместо перевода.
local function parse_mymemory(stdout)
  local ok, data = pcall(vim.json.decode, stdout)
  if not ok or type(data) ~= "table" then
    return nil
  end
  if data.responseStatus ~= 200 then
    return nil
  end
  local rd = data.responseData
  if type(rd) == "table" and type(rd.translatedText) == "string" and rd.translatedText ~= "" then
    return rd.translatedText
  end
  return nil
end

--- Список переводчиков по порядку: первые два — Google (быстрые, но из РФ
--- без VPN недоступны), третий — MyMemory (не Google, работает и там).
--- Каждый элемент: { url = <префикс, дальше припишется текст>, parse = fn }.
M.endpoints = {
  {
    name = "google (translate.googleapis.com)",
    url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=ru&dt=t&q=",
    parse = parse_gtx,
  },
  {
    name = "google (translate.google.com)",
    url = "https://translate.google.com/translate_a/single?client=gtx&sl=en&tl=ru&dt=t&q=",
    parse = parse_gtx,
  },
  {
    -- Не Google: спасает, когда googleapis.com заблокирован провайдером.
    -- Бесплатный, с дневным лимитом и ограничением на длину строки (~500
    -- символов) — для ошибок LSP и коротких подсказок хватает.
    name = "MyMemory (api.mymemory.translated.net)",
    url = "https://api.mymemory.translated.net/get?langpair=en%7Cru&q=",
    parse = parse_mymemory,
  },
}

--- Асинхронный перевод en→ru, результат в кеш. cb(string|nil)
function M.translate(text, cb)
  local hit = M.cache[text]
  if hit then
    return cb(hit)
  end
  if vim.fn.executable("curl") == 0 then
    return cb(nil)
  end
  local function try(i)
    local ep = M.endpoints[i]
    if not ep then
      return cb(nil)
    end
    local url = ep.url .. M.url_encode(text)
    vim.system({ "curl", "-sS", "--max-time", "4", url }, { text = true }, function(res)
      vim.schedule(function()
        local tr = nil
        if res.code == 0 and ep.parse then
          tr = ep.parse(res.stdout)
        end
        if tr then
          local n = 0
          for _ in pairs(M.cache) do
            n = n + 1
          end
          if n > 2000 then
            M.cache = {}
          end
          M.cache[text] = tr
          persist()
          return cb(tr)
        end
        try(i + 1) -- этот переводчик недоступен — пробуем следующий
      end)
    end)
  end
  try(1)
end

--- Диагностика: :RuCheck — какой переводчик реально отвечает.
--- Без неё «перевод не работает» не отличить от «Google заблокирован».
function M.check()
  local lines = {}
  local pending = #M.endpoints
  local sample = "undefined reference"
  for i, ep in ipairs(M.endpoints) do
    local url = ep.url .. M.url_encode(sample)
    vim.system({ "curl", "-sS", "--max-time", "6", url }, { text = true }, function(res)
      local status
      if res.code ~= 0 then
        status = "недоступен (curl exit " .. tostring(res.code) .. ")"
      else
        local tr = ep.parse and ep.parse(res.stdout) or nil
        status = tr and ("работает → «" .. tr .. "»") or "отвечает, но разбор не удался"
      end
      vim.schedule(function()
        lines[i] = ("%d. %-42s %s"):format(i, ep.name, status)
        pending = pending - 1
        if pending == 0 then
          vim.notify(
            "Перевод en→ru, тест строки «" .. sample .. "»:\n" .. table.concat(lines, "\n"),
            vim.log.levels.INFO,
            { title = "Проверка переводчика" }
          )
        end
      end)
    end)
  end
end

-- ---------- markdown: код не переводим ----------

--- Разбить markdown на куски {code=bool, text=...}: fenced-блоки — code=true.
function M.split_md(md)
  local parts, buf, in_fence = {}, {}, false
  local function flush()
    if #buf > 0 then
      table.insert(parts, { code = in_fence, text = table.concat(buf, "\n") })
      buf = {}
    end
  end
  for line in (md .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^%s*```") then
      flush()
      table.insert(parts, { code = true, text = line })
      in_fence = not in_fence
    else
      table.insert(buf, line)
    end
  end
  flush()
  return parts
end


-- Спрятать inline `код` под маркеры @@N@@ и вернуть обратно.
function M.protect_inline(text)
  local stash = {}
  local masked = text:gsub("`[^`\n]+`", function(c)
    table.insert(stash, c)
    return "@@" .. #stash .. "@@"
  end)
  return masked, stash
end

function M.restore_inline(text, stash)
  return (text:gsub("@@(%d+)@@", function(n)
    return stash[tonumber(n)] or ""
  end))
end

return M
