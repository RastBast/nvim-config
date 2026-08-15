return {
  {
    'David-Kunz/treesitter-unit',
    config = function()
      vim.keymap.set('x', 'iu', ':lua require"treesitter-unit".select()<CR>')
      vim.keymap.set('x', 'au', ':lua require"treesitter-unit".select(true)<CR>')
    end
  }
}