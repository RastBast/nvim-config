-- Flatten: если вы запустили `nvim` внутри терминала Neovim (toggleterm),
-- файл открывается в ОСНОВНОМ окне Neovim, а не во вложенном. Грузим рано.
return {
  {
    "willothy/flatten.nvim",
    lazy = false,
    priority = 1001,
    opts = { window = { open = "alternate" } },
  },
}
