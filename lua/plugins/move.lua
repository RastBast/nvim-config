-- ========================================================================== --
--                       ПЕРЕНОС СТРОК (move.nvim)                            --
-- ========================================================================== --
-- ИСПРАВЛЕНО: <M-j>/<M-k> раньше объявлялись ТРИЖДЫ —
--   init.lua (перенос строк), lua/config/keymaps.lua (ресайз окна)
--   и здесь. Последний маппинг перетирал остальные, поэтому часть
--   сочетаний вела себя непредсказуемо.
-- Теперь <M-j>/<M-k> — только перенос строк (этот файл),
-- ресайз по высоте переехал на <C-Up>/<C-Down> в config/keymaps.lua.
return {
  {
    "fedepujol/move.nvim",
    -- Реальные команды move.nvim (lua/move/commands.lua):
    -- MoveLine, MoveBlock, MoveWord, MoveHChar, MoveHBlock
    cmd = { "MoveLine", "MoveBlock", "MoveWord", "MoveHChar", "MoveHBlock" },
    config = function()
      require("move").setup({})

      local opts = { noremap = true, silent = true }
      vim.keymap.set("n", "<M-j>", ":MoveLine(1)<CR>", vim.tbl_extend("force", opts, { desc = "⬇ Строку вниз" }))
      vim.keymap.set("n", "<M-k>", ":MoveLine(-1)<CR>", vim.tbl_extend("force", opts, { desc = "⬆ Строку вверх" }))
      vim.keymap.set("v", "<M-j>", ":MoveBlock(1)<CR>", vim.tbl_extend("force", opts, { desc = "⬇ Блок вниз" }))
      vim.keymap.set("v", "<M-k>", ":MoveBlock(-1)<CR>", vim.tbl_extend("force", opts, { desc = "⬆ Блок вверх" }))
      -- Горизонтальное перемещение (раньше не использовалось)
      vim.keymap.set("n", "<M-H>", ":MoveWord(-1)<CR>", vim.tbl_extend("force", opts, { desc = "⬅ Слово влево" }))
      vim.keymap.set("n", "<M-L>", ":MoveWord(1)<CR>", vim.tbl_extend("force", opts, { desc = "➡ Слово вправо" }))
      vim.keymap.set("v", "<M-H>", ":MoveHBlock(-1)<CR>", vim.tbl_extend("force", opts, { desc = "⬅ Блок влево" }))
      vim.keymap.set("v", "<M-L>", ":MoveHBlock(1)<CR>", vim.tbl_extend("force", opts, { desc = "➡ Блок вправо" }))
    end,
  },
}
