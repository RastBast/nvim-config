-- ========================================================================== --
--                           ПЕРЕВОДЧИК                                       --
-- ========================================================================== --
-- ИСПРАВЛЕНО: ключ `output_option` в translate.nvim НЕ СУЩЕСТВУЕТ
-- (в lua/translate/config.lua есть M.config = { default, parse_before,
-- command, parse_after, output, preset }), а у пресета split нет поля `size`
-- и `position` принимает только "top"/"bottom".
-- Поэтому вся секция молча игнорировалась и перевод открывался
-- в дефолтном плавающем окне сверху.
return {
  "uga-rosa/translate.nvim",
  cmd = { "Translate" },
  keys = {
    { "<leader>tt", ":Translate ru<CR>", desc = "🌐 Перевести слово (ru)", mode = "n" },
    { "<leader>tt", ":Translate ru<CR>", desc = "🌐 Перевести выделение (ru)", mode = "v" },
    { "<leader>te", ":Translate en<CR>", desc = "🌐 Перевести на английский", mode = { "n", "v" } },
  },
  config = function()
    require("translate").setup({
      default = {
        command = "google",
        output = "split", -- вместо плавающего окна — сплит
      },
      preset = {
        output = {
          split = {
            position = "bottom", -- "top" | "bottom"
            min_size = 10,       -- минимум 10 строк
            max_size = 0.4,      -- не больше 40% экрана
            append = false,      -- заменять предыдущий перевод
          },
        },
      },
    })
  end,
}
