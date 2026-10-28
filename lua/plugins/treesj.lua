-- Разбить/собрать конструкцию (список, аргументы, объект) одной клавишей.
-- Дефолтные клавиши <space>m/j/s отключены — свои в which-key (<leader>c…).
return {
  {
    "Wansmer/treesj",
    cmd = { "TSJToggle", "TSJSplit", "TSJJoin" },
    opts = { use_default_keymaps = false, max_join_length = 150 },
  },
}
