-- Мерж-конфликты: выбрать свою / чужую / обе / ничего. Дефолтные буферные
-- маппинги (co, ct, cb, c0) ОТКЛЮЧЕНЫ: они ломают встроенный оператор `c`.
-- Все действия — в <leader>Hgm… (which-key).
return {
  {
    "akinsho/git-conflict.nvim",
    cmd = {
      "GitConflictChooseOurs",
      "GitConflictChooseTheirs",
      "GitConflictChooseBoth",
      "GitConflictChooseNone",
      "GitConflictNextConflict",
      "GitConflictPrevConflict",
      "GitConflictListQf",
    },
    event = "BufReadPre",
    opts = { default_mappings = false, default_commands = true },
  },
}
