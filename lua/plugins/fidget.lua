return {
  {
    'j-hui/fidget.nvim',
    opts = {
      progress = {
        display = {
          spinnner = { ' ⊚ ', ' ⊚ ', ' ⊚ ', ' ⊚ ' }, -- можно заменить на фазы движения
        },
      },
      notification = {
        window = { winblend = 0 },
      },
    },
    config = function(_, opts)
      require('fidget').setup(opts)
      -- Рофл: при вводе команды :Flex наш Гофер на заставке будет 'танцевать'
      vim.api.nvim_create_user_command('Flex', function()
        require('cellular-automaton').make_it_rain()
      end, {})
    end,
  },
  {
    'eandrju/cellular-automaton.nvim', -- плагин для анимации кода
    config = function()
      vim.keymap.set('n', '<leader>fL', '<cmd>CellularAutomaton make_it_rain<CR>', { desc = '🚀 Код потек!' })
    end
  }
}