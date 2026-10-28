-- ========================================================================== --
--                          АНИМАЦИИ КОДА (Матрица)                           --
-- ========================================================================== --
-- Единственный владелец eandrju/cellular-automaton.nvim в конфиге
-- (раньше он был ещё и в fidget.lua).
return {
  {
    "eandrju/cellular-automaton.nvim",
    cmd = { "CellularAutomaton", "Matrix", "Flex" },
    keys = {
      { "<leader>fL", "<cmd>CellularAutomaton make_it_rain<CR>", desc = "🚀 Код потёк!" },
    },
    config = function()
      -- :Matrix и :Flex — два коротких алиаса того же эффекта
      vim.api.nvim_create_user_command("Matrix", "CellularAutomaton make_it_rain", {})
      vim.api.nvim_create_user_command("Flex", "CellularAutomaton make_it_rain", {})
    end,
  },
}
