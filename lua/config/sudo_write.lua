-- :SudoWrite — сохранить файл, которому нужны права root (например /etc/hosts).
-- Пароль sudo спрашивает терминал (sudo читает с /dev/tty), поэтому работает в nvim в терминале.
-- Клавиша: <leader>qW.
local M = {}

function M.write()
  local path = vim.fn.expand("%:p")
  if path == "" or vim.bo.buftype ~= "" then
    vim.notify("SudoWrite: нужен обычный файл на диске", vim.log.levels.WARN)
    return
  end
  -- тихо пишем буфер через sudo tee; вывод tee глушим
  vim.cmd("silent write !sudo tee " .. vim.fn.fnameescape(path) .. " >/dev/null")
  if vim.v.shell_error ~= 0 then
    vim.notify("SudoWrite: не удалось записать (код " .. vim.v.shell_error .. ")", vim.log.levels.ERROR)
    return
  end
  -- перечитываем файл с диска, чтобы буфер совпал с записанным
  vim.cmd("silent edit!")
  vim.notify("💾 Записано с sudo: " .. vim.fn.fnamemodify(path, ":t"), vim.log.levels.INFO)
end

function M.setup()
  vim.api.nvim_create_user_command("SudoWrite", function()
    M.write()
  end, { desc = "Записать файл через sudo" })
  vim.keymap.set("n", "<leader>qW", function()
    M.write()
  end, { desc = "💾 Записать файл через sudo" })
end

return M
