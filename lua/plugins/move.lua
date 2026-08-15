return {
  {
    'fedepujol/move.nvim',
    config = function()
      local opts = { noremap = true, silent = true }
      vim.keymap.set('n', '<M-j>', ':MoveLine(1)<CR>', opts)
      vim.keymap.set('n', '<M-k>', ':MoveLine(-1)<CR>', opts)
      vim.keymap.set('v', '<M-j>', ':MoveBlock(1)<CR>', opts)
      vim.keymap.set('v', '<M-k>', ':MoveBlock(-1)<CR>', opts)
    end
  }
}