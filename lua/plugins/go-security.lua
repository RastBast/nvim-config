return {
  {
    'ray-x/go.nvim', -- Мы его обновляем, добавляя Govulncheck
    config = function()
      require('go').setup({
        lsp_cfg = false,
        diagnostic = { hdlr = true, underline = true },
      })
      -- Быстрые команды
      vim.keymap.set('n', '<leader>gv', '<cmd>GoVulncheck<cr>', { desc = '🛡 Проверить уязвимости' })
      vim.keymap.set('n', '<leader>gl', '<cmd>GoLint<cr>', { desc = '🧹 Линтер' })
    end
  }
}