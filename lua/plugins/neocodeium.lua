-- ========================================================================== --
--   CODEIUM / NEOCODEIUM — INLINE SUGGESTIONS / GHOST TEXT                   --
-- ========================================================================== --
-- Быстрые бесплатные встроенные серые автоподсказки кода (Ghost Text) на базе
-- monkoose/neocodeium (облегчённый нативный клиент Codeium / Windsurf на Lua):
--   • По умолчанию ВКЛЮЧЕНЫ при старте Neovim!
--   • Выключение / включение по хоткею: <leader>AG или <leader>ui (:CodeiumToggle)
--   • Первичная бесплатная авторизация (1 раз): <leader>AK или :CodeiumAuth (:NeoCodeium auth)
--   • Принять целиком: <Tab> или <M-l> · одно слово: <M-w> / <C-Right> · строку: <M-a>
--   • Листать варианты: <M-]> / <M-[> · скрыть: <C-]>
return {
  {
    "monkoose/neocodeium",
    event = "VeryLazy",
    cmd = { "NeoCodeium" },
    opts = function()
      local ui = require("config.neocodeium_ui")
      return {
        enabled = ui.enabled,
        manual = false,
        show_label = true,
        debounce = true,
        silent = true,
        disable_in_special_buftypes = true,
        filetypes = ui.ignored_filetypes(),
        filter = function(bufnr)
          return ui.filter_buf(bufnr)
        end,
      }
    end,
    config = function(_, opts)
      require("neocodeium").setup(opts)
    end,
  },
}
