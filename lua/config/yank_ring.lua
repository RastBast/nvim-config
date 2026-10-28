-- ========================================================================== --
--              КОЛЬЦО БУФЕРА ОБМЕНА: 9 последних yank в регистрах "1…"9       --
-- ========================================================================== --
-- Как пользоваться:
--   yy / yiw / y…        — копирование кладёт текст и в "1; прежние сдвигаются в "2…"9
--   "1p  "2p  …  "9p     — вставить 1-й … 9-й из последних скопированных
--   p                    — обычная вставка (последнее копирование)
--   <leader>yr           — список всех 9 со превью, выбрать Enter-ом
--
-- Важно (поведение Vim): регистры "1…"9 Vim ТАКЖЕ заполняет при многострочных
-- удалениях (d). Поэтому удаления тоже сдвигают кольцо — это штатное поведение Vim.
-- Копирование в именованный регистр ("ay) кольцо не трогает.
--
-- Системная история macOS (9 пунктов) — отдельно: Maccy, см. macos/README.md.
-- Neovim с `clipboard=unnamedplus` и так пишет в системный буфер.

local M = {}

M.SIZE = 9

-- Сдвинуть кольцо и положить новое значение в "1
---@param lines string[]
---@param regtype string  "v" | "V" | "\22"
function M.push(lines, regtype)
  for i = M.SIZE, 2, -1 do
    local info = vim.fn.getreginfo(tostring(i - 1))
    if info and info.regcontents and #info.regcontents > 0 then
      vim.fn.setreg(tostring(i), info.regcontents, info.regtype)
    else
      vim.fn.setreg(tostring(i), {}, "v")
    end
  end
  vim.fn.setreg("1", lines, regtype)
end

-- Список всех непустых пунктов для выбора
---@return {idx:integer, text:string, info:table}[]
function M.entries()
  local out = {}
  for i = 1, M.SIZE do
    local info = vim.fn.getreginfo(tostring(i))
    if info and info.regcontents and #info.regcontents > 0 then
      local text = table.concat(info.regcontents, "\n")
      out[#out + 1] = { idx = i, text = text, info = info }
    end
  end
  return out
end

-- Открыть выбор (vim.ui.select) и вставить выбранный пункт
function M.pick()
  local items = M.entries()
  if #items == 0 then
    vim.notify("Кольцо буфера пусто: сначала что-нибудь скопируйте (yy, yiw…)", vim.log.levels.INFO)
    return
  end
  vim.ui.select(items, {
    prompt = "Буфер обмена (1–9):",
    format_item = function(it)
      local preview = it.text:gsub("\n", "⏎"):sub(1, 90)
      return ("\"%d  %s"):format(it.idx, preview)
    end,
  }, function(choice)
    if not choice then
      return
    end
    -- Вставляем через обычный "p" из нужного регистра
    vim.fn.setreg('"', choice.info.regcontents, choice.info.regtype)
    vim.cmd('normal! ""p')
  end)
end

function M.setup()
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("YankRing", { clear = true }),
    callback = function()
      local ev = vim.v.event
      -- Только обычное копирование (y), без явного регистра ("ay и т.п.)
      if ev.operator ~= "y" then
        return
      end
      if ev.regname ~= "" and ev.regname ~= '"' then
        return
      end
      if not ev.regcontents or #ev.regcontents == 0 then
        return
      end
      M.push(ev.regcontents, ev.regtype)
    end,
  })

  vim.keymap.set("n", "<leader>yr", M.pick, { desc = "📋 Кольцо буфера обмена (1–9)" })
end

return M
