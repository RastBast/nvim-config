-- Умные движения w / e / b / ge: учитывают CamelCase и snake_case (по подсловам).
-- skipInsignificantPunctuation — пропускать «мусорную» пунктуацию (скобки, точки).
return {
  {
    "chrisgrieser/nvim-spider",
    lazy = true,
    opts = { skipInsignificantPunctuation = true },
    keys = {
      { "w", "<cmd>lua require('spider').motion('w')<cr>", mode = { "n", "o", "x" }, desc = "Умное w (подслова)" },
      { "e", "<cmd>lua require('spider').motion('e')<cr>", mode = { "n", "o", "x" }, desc = "Умное e (подслова)" },
      -- ПРЫЖОК К НАЧАЛУ ПРЕДЫДУЩЕГО СЛОВА — по просьбе пользователя перенесён
      -- с b на q (2026-10-28). Родное b вернулось в vim (обычный назад-слово),
      -- запись макросов уехала на Q (см. lua/config/keymaps.lua).
      { "q", "<cmd>lua require('spider').motion('b')<cr>", mode = { "n", "o", "x" }, desc = "Умное назад-слово (было b)" },
      { "ge", "<cmd>lua require('spider').motion('ge')<cr>", mode = { "n", "o", "x" }, desc = "Умное ge (подслова)" },
    },
  },
}
