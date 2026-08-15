return {
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
      require('bufferline').setup({
        options = {
          offsets = {{filetype = 'nvim-tree', text = '📂 File Explorer', text_align = 'left'}},
          separator_style = 'slant',
        }
      })
      vim.keymap.set('n', '<Tab>', '<cmd>BufferLineCycleNext<cr>')
      vim.keymap.set('n', '<S-Tab>', '<cmd>BufferLineCyclePrev<cr>')
    end
  }
}