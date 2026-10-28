-- Лампочка 💡 в колонке знаков, если для строки есть code action (quick fix).
return {
  {
    "kosayoda/nvim-lightbulb",
    event = "LspAttach",
    opts = {
      autocmd = { enabled = true },
      sign = { enabled = true, text = "💡" },
    },
  },
}
