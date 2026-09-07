-- ========================================================================== --
--              ОБЩИЙ АСИНХРОННЫЙ ПЕРЕВОД en→ru (Google gtx, curl)            --
-- ========================================================================== --
-- Пользователи: config.hover_ru (подсказки), config.diag_ru (ошибки).
-- С кешем: одинаковые строки переводятся один раз (диагностика при письме
-- шлёт одни и те же сообщения постоянно — не спамим сеть).
-- Любая ошибка (нет curl/сети, кривой JSON) → cb(nil), вызывающий решает,
-- что показать (обычно — оригинал).

local M = { cache = {} }

function M.url_encode(s)
  return (s:gsub("([^%w%-%.%_%~ ])", function(c)
    return string.format("%%%02X", string.byte(c))
  end):gsub(" ", "+"))
end

--- Перевести текст en→ru. cb(string|nil)
function M.translate(text, cb)
  local hit = M.cache[text]
  if hit then
    return cb(hit)
  end
  if vim.fn.executable("curl") == 0 then
    return cb(nil)
  end
  local url = "https://translate.googleapis.com/translate_a/single"
    .. "?client=gtx&sl=en&tl=ru&dt=t&q=" .. M.url_encode(text)
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
      local tr = table.concat(out)
      if tr ~= "" then
        -- простой предохранитель от бесконечного роста кеша
        local n = 0
        for _ in pairs(M.cache) do
          n = n + 1
        end
        if n > 1000 then
          M.cache = {}
        end
        M.cache[text] = tr
      end
      cb(tr ~= "" and tr or nil)
    end)
  end)
end

return M
