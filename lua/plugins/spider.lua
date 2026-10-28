-- Умные движения w / e / q (назад = q, бывш. b) / ge: учитывают CamelCase и snake_case (по подсловам).
-- skipInsignificantPunctuation — пропускать «мусорную» пунктуацию (скобки, точки).
return {
  {
    "chrisgrieser/nvim-spider",
    lazy = true,
    opts = { skipInsignificantPunctuation = true },
    keys = {
      { "w", "<cmd>lua require('spider').motion('w')<cr>", mode = { "n", "o", "x" }, desc = "Умное w (подслова)" },
      { "e", "<cmd>lua require('spider').motion('e')<cr>", mode = { "n", "o", "x" }, desc = "Умное e (подслова)" },
      { "q", "<cmd>lua require('spider').motion('b')<cr>", mode = { "n", "o", "x" }, desc = "⬅ Назад к началу слова (подслова)" },
      { "ge", "<cmd>lua require('spider').motion('ge')<cr>", mode = { "n", "o", "x" }, desc = "Умное ge (подслова)" },
    },
  },
}
