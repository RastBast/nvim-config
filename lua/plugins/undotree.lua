-- История правок (дерево undo): <leader>v. Нужен undofile (init.lua) — он уже включён,
-- поэтому история переживает перезапуск nvim.
return {
  {
    "mbbill/undotree",
    cmd = { "UndotreeToggle", "UndotreeShow", "UndotreeFocus" },
    keys = {
      { "<leader>v", "<cmd>UndotreeToggle<cr>", desc = "⏪ История правок (undotree)" },
    },
  },
}
