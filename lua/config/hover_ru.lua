-- ========================================================================== --
--        РУССКИЙ В LSP-ПОДСКАЗКАХ (hover) — перевод БЕЗ трогания кода        --
-- ========================================================================== --
-- Перехватывает textDocument/hover — подсказку «что делает функция»
-- (клавиша K / авто-hover) — и переводит описательный текст en → ru.
--
-- НЕ переводится (код остаётся как есть):
--   * fenced-блоки ```...```  (сигнатура функции, примеры);
--   * inline `код` внутри прозы — на время перевода заменяется маркером
--     @@N@@ и восстанавливается после.
--
-- Перевод: свободный эндпоинт Google (client=gtx), асинхронно через curl.
-- Если сети/curl нет или ответ кривой — молча показывается оригинальная
-- подсказка: ничего не падает и не блокируется (таймаут-фолбэк 1.2 с).
--
-- Команды:  :HoverRu on | off | toggle
-- Работает с любым LSP: gopls (Go), lua_ls, ts_ls и т.д.
-- Окно документации автодополнения (nvim-cmp) НЕ переводится — это осознанное
-- ограничение (иначе запрос на каждый пункт списка).

local M = { enabled = true }

-- ---------- утилиты ----------

local function url_encode(s)
  return (s:gsub("([^%w%-%.%_%~ ])", function(c)
    return string.format("%%%02X", string.byte(c))
  end):gsub(" ", "+"))
end

-- Разбить markdown на куски {code=bool, text=...}: fenced-блоки — code=true.
local function split_md(md)
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
local function protect_inline(text)
  local stash = {}
  local masked = text:gsub("`[^`\n]+`", function(c)
    table.insert(stash, c)
    return "@@" .. #stash .. "@@"
  end)
  return masked, stash
end

local function restore_inline(text, stash)
  return (text:gsub("@@(%d+)@@", function(n)
    return stash[tonumber(n)] or ""
  end))
end

-- Асинхронный перевод en→ru (Google gtx). cb(nil) при любой ошибке.
local function translate(text, cb)
  if vim.fn.executable("curl") == 0 then
    return cb(nil)
  end
  local url = "https://translate.googleapis.com/translate_a/single"
    .. "?client=gtx&sl=en&tl=ru&dt=t&q=" .. url_encode(text)
  vim.system({ "curl", "-sS", "--max-time", "4", url }, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        return cb(nil)
      end
      local ok, data = pcall(vim.json.decode, res.stdout)
      if not ok or type(data) ~= "table" or type(data[1]) ~= "table" then
        return cb(nil)
      end
      local out = {}
      for _, item in ipairs(data[1]) do
        if type(item) == "table" and type(item[1]) == "string" then
          out[#out + 1] = item[1]
        end
      end
      cb(table.concat(out))
    end)
  end)
end

-- ---------- перехват hover ----------

function M.setup()
  local orig = vim.lsp.handlers["textDocument/hover"]
  if type(orig) ~= "function" then
    return
  end

  vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, cfg)
    if not M.enabled or err or not result or not result.contents then
      return orig(err, result, ctx, cfg)
    end

    local mc = result.contents
    local md
    if type(mc) == "string" then
      md = mc
    elseif type(mc) == "table" and type(mc.value) == "string" then
      md = mc.value
    elseif vim.islist(mc) then
      md = table.concat(mc, "\n")
    end
    if not md or md == "" then
      return orig(err, result, ctx, cfg)
    end

    local parts = split_md(md)
    local pending, fired = 0, false

    local function finish()
      if fired then
        return
      end
      fired = true
      local out = {}
      for _, p in ipairs(parts) do
        out[#out + 1] = p.text
      end
      local r2 = vim.deepcopy(result)
      if type(r2.contents) == "string" then
        r2.contents = table.concat(out, "\n")
      elseif type(r2.contents) == "table" and r2.contents.value then
        r2.contents.value = table.concat(out, "\n")
      end
      orig(nil, r2, ctx, cfg)
    end

    for _, p in ipairs(parts) do
      if not p.code and p.text:match("%a%a%a") then
        local masked, stash = protect_inline(p.text)
        pending = pending + 1
        translate(masked, function(tr)
          if tr then
            local ok_ph = true
            for i = 1, #stash do
              if not tr:find("@@" .. i .. "@@", 1, true) then
                ok_ph = false
                break
              end
            end
            if ok_ph then
              p.text = restore_inline(tr, stash)
            end
          end
          pending = pending - 1
          if pending == 0 then
            finish()
          end
        end)
      end
    end

    if pending == 0 and not fired then
      -- нечего переводить (или всё код) — сразу оригинал
      return orig(err, result, ctx, cfg)
    end
    -- страховка: сеть медленная → через 1.2 с показываем как есть
    vim.defer_fn(finish, 1200)
  end

  vim.api.nvim_create_user_command("HoverRu", function(o)
    local a = o.args
    if a == "on" then
      M.enabled = true
    elseif a == "off" then
      M.enabled = false
    elseif a == "toggle" then
      M.enabled = not M.enabled
    end
    vim.notify("HoverRu (перевод подсказок LSP): " .. (M.enabled and "вкл" or "выкл"), vim.log.levels.INFO)
  end, {
    nargs = "?",
    complete = function()
      return { "on", "off", "toggle" }
    end,
  })
end

return M
