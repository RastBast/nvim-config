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
    if i > #M.endpoints then
      return cb(nil)
    end
    local url = M.endpoints[i] .. M.url_encode(text)
    vim.system({ "curl", "-sS", "--max-time", "4", url }, { text = true }, function(res)
      vim.schedule(function()
        local tr = nil
        if res.code == 0 then
          local ok, data = pcall(vim.json.decode, res.stdout)
          if ok and type(data) == "table" and type(data[1]) == "table" then
            local out = {}
            for _, item in ipairs(data[1]) do
              if type(item) == "table" and type(item[1]) == "string" then
                out[#out + 1] = item[1]
              end
            end
            local joined = table.concat(out)
            if joined ~= "" then
              tr = joined
            end
          end
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
        try(i + 1) -- первый эндпоинт недоступен — пробуем запасной
      end)
    end)
  end
  try(1)
end

M.endpoints = {
  "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=ru&dt=t&q=",
  "https://translate.google.com/translate_a/single?client=gtx&sl=en&tl=ru&dt=t&q=",
}

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
