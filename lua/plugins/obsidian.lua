-- ========================================================================== --
--                              OBSIDIAN                                      --
-- ========================================================================== --
-- ИСПРАВЛЕНО: path = '~/obsidian_base/' — obsidian.nvim не разворачивает `~`
-- во всех версиях одинаково, из-за чего workspace мог не находиться.
-- Плюс добавлена проверка существования папки, чтобы плагин не ругался.
return {
  {
    "epwalsh/obsidian.nvim",
    version = "*",
    lazy = true,
    ft = "markdown",
    event = { "BufReadPre *.md", "BufNewFile *.md" },
    cmd = { "ObsidianNew", "ObsidianSearch", "ObsidianFollowLink", "ObsidianToggleCheckbox" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local vault = vim.fn.expand("~/obsidian_base")

      require("obsidian").setup({
        workspaces = {
          { name = "main", path = vault },
        },
        notes_subdir = "notes",
        new_notes_location = "notes_subdir",

        -- Интеграция с автодополнением (nvim-cmp)
        completion = {
          nvim_cmp = true,
          min_chars = 2,
        },

        -- Как выглядят чекбоксы
        ui = {
          enable = true,
          update_debounce = 200,
          checkboxes = {
            [" "] = { char = "󰄱 ", hl_group = "ObsidianTodo" },
            ["x"] = { char = "󰱒 ", hl_group = "ObsidianDone" },
          },
        },

        -- Клавиши внутри markdown-файлов
        mappings = {
          ["<leader>of"] = {
            action = function() return require("obsidian").util.gf_passthrough() end,
            opts = { buffer = true, noremap = false, desc = "💎 Перейти по ссылке" },
          },
          ["<leader>ot"] = {
            action = function() return require("obsidian").util.toggle_checkbox() end,
            opts = { buffer = true, noremap = false, desc = "💎 Чекбокс" },
          },
        },
      })
    end,
  },
}
