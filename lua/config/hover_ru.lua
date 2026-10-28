-- ========================================================================== --
--        РУССКИЙ В LSP-ПОДСКАЗКАХ (K) — перевод БЕЗ трогания кода            --
-- ========================================================================== --
-- Что переводится: описательный текст подсказки «что делает функция» (K).
-- Что НЕ переводится (остаётся как есть): fenced-блоки ```…``` (сигнатуры,
-- примеры) и inline `код` внутри прозы (на время перевода — маркер @@N@@).
--
-- КАК РАБОТАЕТ (исправлено):
--   Раньше перехват был на vim.lsp.handlers["textDocument/hover"], но K в
--   Neovim 0.12 идёт через vim.lsp.buf.hover → vim.lsp.util.open_floating_preview
--   и обработчик в обход не вызывается — перевода не было вовсе.
--   Теперь перехват стоит на open_floating_preview с focus_id = "textDocument/hover":
--     * перевод уже в кеше (диск) → подсказка сразу открывается по-русски;
--     * кеша нет → окно открывается сразу на английском, а когда перевод
--       готов — текст в окне заменяется (если окно ещё открыто).
--   Повторная подсказка тех же фраз — мгновенно по-русски (кеш на диске).
--
-- Команды:  :HoverRu on | off | toggle
-- Окно автодополнения (nvim-cmp) НЕ переводится — осознанно (запрос на каждый пункт).

local M = { enabled = true }

local RU = require("config.ru_util")

local function build_text(parts)
  local out = {}
  for _, p in ipairs(parts) do
    out[#out + 1] = p.text
  end
  return table.concat(out, "\n")
end

-- Перевести куски подсказки. on_done(lines) вызывается один раз, когда все куски
-- обработаны (сразу — если всё в кеше). Возвращает true, если всё уже было в кеше.
local function translate_parts(parts, on_done)
  local jobs = {}
  for _, p in ipairs(parts) do
    if not p.code and p.text:match("%a%a%a") then
      jobs[#jobs + 1] = p
    end
  end
  if #jobs == 0 then
    on_done(false)
    return
  end

  local pending = #jobs
  local changed = false
  local function one_done()
    pending = pending - 1
    if pending == 0 then
      on_done(changed)
    end
  end

  for _, p in ipairs(jobs) do
    local masked, stash = RU.protect_inline(p.text)
    RU.translate(masked, function(tr)
      if tr then
        local ok_ph = true
        for i = 1, #stash do
          if not tr:find("@@" .. i .. "@@", 1, true) then
            ok_ph = false
            break
          end
        end
        if ok_ph then
          p.text = RU.restore_inline(tr, stash)
          changed = true
        end
      end
      one_done()
    end)
  end
end

-- Заменить содержимое уже открытого окна подсказки переводом
local function swap_window_text(bufnr, winnr, text)
  if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
    return
  end
  if not (winnr and vim.api.nvim_win_is_valid(winnr)) then
    return
  end
  local lines = vim.split(text, "\n", { plain = true })
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
  -- Подгоняем размер окна под новый текст (грубо, но достаточно)
  local width = 0
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  pcall(vim.api.nvim_win_set_config, winnr, {
    width = math.min(math.max(width + 2, 20), 100),
    height = math.min(#lines, 30),
  })
end

function M.setup()
  local ok, util = pcall(require, "vim.lsp.util")
  if not ok or type(util.open_floating_preview) ~= "function" then
    return
  end

  local orig = util.open_floating_preview

  util.open_floating_preview = function(contents, format, opts)
    -- Переводим только подсказки K (focus_id = hover) и только markdown-строки
    if not M.enabled or type(contents) ~= "table" or not (opts and opts.focus_id == "textDocument/hover") then
      return orig(contents, format, opts)
    end

    local md = table.concat(contents, "\n")
    if md == "" then
      return orig(contents, format, opts)
    end

    local parts = RU.split_md(md)

    -- Все куски уже в кеше? Тогда открываем сразу по-русски.
    local bufnr, winnr
    local opened = false
    local function open_original()
      if not opened then
        opened = true
        bufnr, winnr = orig(contents, format, opts)
      end
    end

    translate_parts(parts, function(changed)
      if not changed then
        open_original()
        return
      end
      local text = build_text(parts)
      if not opened then
        -- Перевод пришёл раньше открытия окна (всё из кеша) — открываем уже переведённым
        opened = true
        bufnr, winnr = orig(vim.split(text, "\n", { plain = true }), format, opts)
      else
        swap_window_text(bufnr, winnr, text)
      end
    end)

    -- Если перевод не пришёл синхронно — окно открываем сейчас, на английском
    if not opened then
      open_original()
    end
    return bufnr, winnr
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
    vim.notify("HoverRu (перевод подсказок K): " .. (M.enabled and "вкл" or "выкл"), vim.log.levels.INFO)
  end, {
    nargs = "?",
    complete = function()
      return { "on", "off", "toggle" }
    end,
  })
end

return M
