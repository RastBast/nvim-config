return {
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("nvim-tree").setup({
        -- Настройки синхронизации дерева с открытым файлом
        update_focused_file = {
          enable = true,
          update_root = true,
        },
        renderer = {
          highlight_opened_files = "all",
          icons = {
            show = {
              file = true,
              folder = true,
              folder_arrow = true,
              git = true,
            },
          },
        },
        view = {
          width = 30,
          side = "left",
        },
        filters = {
          dotfiles = false,
        },
      })

      -- Твоя горячая клавиша
      vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true })
    end,
  },
}

