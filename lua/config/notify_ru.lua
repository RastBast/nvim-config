-- ========================================================================== --
--     РУССКИЕ УВЕДОМЛЕНИЯ: вывод сборок/линтов (go.nvim и прочие плагины)    --
-- ========================================================================== --
-- Перехватывает vim.notify. Покрывает то, что НЕ является LSP-диагностикой:
--   * «build exited with code: 1 … package X is not in std …» после <leader>HGb,
--   * вывод GoLint, SnipRun, прочих плагинов, пишущих в notify.
--
-- Работает через кеш ru_util (файл stdpath("cache")/ru_cache.json):
--   * сообщение уже переводилось (в т.ч. в прошлый сеанс) — сразу по-русски;
--   * первый раз — показывается оригинал, перевод уходит в кеш фоном,
--     следующий показ этого же сообщения — русский.
-- LSP-диагностику (ошибки при наборе) переводит diag_ru, подсказки — hover_ru.
-- Команда: :NotifyRu on | off | toggle

local RU = require("config.ru_util")

local M = { enabled = true }

function M.setup()
  local orig = vim.notify
  if type(orig) ~= "function" then
    return
  end

  vim.notify = function(msg, level, opts)
    if not M.enabled or type(msg) ~= "string" or not msg:match("%a%a%a") then
      return orig(msg, level, opts)
    end
    local tr = RU.translate_cached(msg)
    if tr then
      return orig(tr, level, opts)
    end
    -- первый раз: оригинал + греем кеш
    RU.translate(msg, function() end)
    return orig(msg, level, opts)
  end

  vim.api.nvim_create_user_command("NotifyRu", function(o)
    local a = o.args
    if a == "on" then
      M.enabled = true
    elseif a == "off" then
      M.enabled = false
    elseif a == "toggle" then
      M.enabled = not M.enabled
    end
    vim.notify("NotifyRu (русские уведомления): " .. (M.enabled and "вкл" or "выкл"), vim.log.levels.INFO)
  end, {
    nargs = "?",
    complete = function()
      return { "on", "off", "toggle" }
    end,
  })
end

return M
