return {
  "nvimtools/hydra.nvim",
  dependencies = { "anuvyklack/keymap-layer.nvim" },
  config = function()
    local Hydra = require("hydra")

    -- Стилизация: Серый фон, Глубокий черный текст
    vim.api.nvim_set_hl(0, "HydraHint", { fg = "#000000", bg = "#808080", bold = true })
    vim.api.nvim_set_hl(0, "HydraBorder", { fg = "#808080", bg = "#808080" })

    local super_mode = Hydra({
      name = "SuperMode",
      config = {
        color = "pink",
        invoke_on_body = true,
        hint = {
          float_opts = { border = "single" },
          position = "bottom",
        },
        foreign_keys = nil,
      },
      -- Исправлено: убрали Esc из подчеркиваний, чтобы парсер не ругался
      hint = [[
 ^ ^          SUPER MODE (Commands Only)
 ^
 _s_: Save     _f_: Find Files     _g_: Git     _b_: Buffers
 _q_: EXIT
]],
      heads = {
        { "s", ":w<CR>", { desc = "Save" } },
        { "f", ":Telescope find_files<CR>", { desc = "Files" } },
        { "g", ":LazyGit<CR>", { exit = true } },
        { "b", ":Telescope buffers<CR>", { desc = "Buffers" } },

        -- Выход (Esc работает тихо, q отображается в подсказке)
        { "q", nil, { exit = true, desc = "Quit" } },
        { "<Esc>", nil, { exit = true } },
      },
    })

    vim.keymap.set("n", "<leader>h", function()
      super_mode:activate()
    end, { desc = "Enter Super Mode" })
  end,
}