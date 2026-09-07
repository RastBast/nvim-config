-- ========================================================================== --
--          РУССКИЕ ОШИБКИ НА ЛЕТУ (LSP-диагностика при написании кода)       --
-- ========================================================================== --
-- Перехватывает textDocument/publishDiagnostics — сообщения об ошибках,
-- которые LSP шлёт прямо во время набора (gopls для Go, dockerls для
-- Dockerfile, protols для .proto, sqls для SQL, lua_ls и т.д.) — и
-- переводит текст ошибки на русский ДО того, как он попадёт в:
--   * виртуальный текст рядом со строкой,
--   * плавающее окно диагностики (<leader>d),
--   * Trouble / location list / quickfix.
--
-- Код в сообщениях не раздувается: переводится строка сообщения целиком
-- (это проза, не код). Повторные одинаковые сообщения берутся из кеша
-- (ru_util), сеть не спамится.
--
-- Нет сети/curl — молча показываются оригинальные английские ошибки.
-- Команда: :DiagRu on | off | toggle
--
-- Про Redis: для Redis НЕ существует живого LSP-сервера (проверено по
-- реестрам Mason/lspconfig), поэтому ошибки redis-cli в терминале сюда не
-- попадают — это честное ограничение экосистемы, а не конфига.

local RU = require("config.ru_util")

local M = { enabled = true }

function M.setup()
  local orig = vim.lsp.handlers["textDocument/publishDiagnostics"]
  if type(orig) ~= "function" then
    return
  end

  vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, cfg)
    if not M.enabled or err or not result or not result.diagnostics then
      return orig(err, result, ctx, cfg)
    end

    local pending, fired = 0, false
    local function finish()
      if fired then
        return
      end
      fired = true
      orig(nil, result, ctx, cfg)
    end

    for _, d in ipairs(result.diagnostics) do
      if type(d.message) == "string" and d.message:match("%a%a%a") then
        pending = pending + 1
        RU.translate(d.message, function(tr)
          if tr and tr ~= "" then
            d.message = tr
          end
          pending = pending - 1
          if pending == 0 then
            finish()
          end
        end)
      end
    end

    if pending == 0 and not fired then
      return orig(err, result, ctx, cfg)
    end
    -- страховка от медленной сети: через 2.5 с ошибки уходят как есть
    vim.defer_fn(finish, 2500)
  end

  vim.api.nvim_create_user_command("DiagRu", function(o)
    local a = o.args
    if a == "on" then
      M.enabled = true
    elseif a == "off" then
      M.enabled = false
    elseif a == "toggle" then
      M.enabled = not M.enabled
    end
    vim.notify("DiagRu (русские ошибки LSP): " .. (M.enabled and "вкл" or "выкл"), vim.log.levels.INFO)
  end, {
    nargs = "?",
    complete = function()
      return { "on", "off", "toggle" }
    end,
  })
end

return M
