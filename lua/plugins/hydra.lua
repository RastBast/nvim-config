-- ========================================================================== --
--                        HYDRA: SUPER MODE                                   --
-- ========================================================================== --
-- ИСПРАВЛЕНО: триггер <leader>h убивал harpoon.nvim.
-- harpoon.lua биндит <leader>ha / <leader>hh / <leader>h1 / <leader>h2,
-- а маппинг ровно на <leader>h срабатывал мгновенно (timeoutlen = 300),
-- поэтому до harpoon дело не доходило никогда.
-- Триггер перенесён на <leader>M (раньше не использовался).
return {
  "nvimtools/hydra.nvim",
  dependencies = { "anuvyklack/keymap-layer.nvim" },
  keys = {
    { "<leader>M", desc = "🦹 Войти в Super Mode" },
  },
  config = function()
    local Hydra = require("hydra")

    -- Стилизация: серый фон, глубокий чёрный текст
    vim.api.nvim_set_hl(0, "HydraHint", { fg = "#000000", bg = "#808080", bold = true })
    vim.api.nvim_set_hl(0, "HydraBorder", { fg = "#808080", bg = "#808080" })

    local super_mode = Hydra({
      name = "SuperMode",
      mode = "n",
      config = {
        color = "pink",
        invoke_on_body = true,
        hint = {
          float_opts = { border = "single" },
          position = "bottom",
        },
        foreign_keys = nil,
      },
      hint = [[
 ^ ^          SUPER MODE (Commands Only)
 ^
 _s_: Save     _f_: Find Files     _g_: Git     _b_: Buffers
 _q_: EXIT
]],
      heads = {
        { "s", ":w<CR>", { desc = "Save" } },
        { "f", ":Telescope find_files<CR>", { desc = "Files" } },
        { "g", ":LazyGit<CR>", { exit = true, desc = "Git" } },
        { "b", ":Telescope buffers<CR>", { desc = "Buffers" } },
        { "q", nil, { exit = true, desc = "Quit" } },
        { "<Esc>", nil, { exit = true, desc = "Quit" } },
      },
    })

    vim.keymap.set("n", "<leader>M", function() super_mode:activate() end, { desc = "🦹 Super Mode" })
  end,
}
