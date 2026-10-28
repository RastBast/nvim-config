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
    -- КЛЮЧ DeepL из окружения (2026-10-28): translate.nvim читает его только
    -- из vim.g.deepl_api_auth_key (lua/translate/preset/command/deepl.lua:11).
    -- Положил ключ в переменную окружения — перевод подхватился сам:
    --   fish: set -Ux DEEPL_AUTH_KEY "…:fx"   bash/zsh: export DEEPL_AUTH_KEY=…
    if (vim.env.DEEPL_AUTH_KEY or "") ~= "" then
      vim.g.deepl_api_auth_key = vim.env.DEEPL_AUTH_KEY
    end
    local has_deepl = (vim.g.deepl_api_auth_key or "") ~= ""
    require("translate").setup({
      default = {
        -- С ключом DeepL — он (работает из РФ без VPN); без ключа — google
        -- (бесплатный, но из РФ без VPN может не отвечать).
        command = has_deepl and "deepl_free" or "google",
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
