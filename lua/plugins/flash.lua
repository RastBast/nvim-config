return {
  "folke/flash.nvim",
  event = "VeryLazy",
  opts = {},
  keys = {
    -- nowait = true (2026-10-28): БЕЗ него nvim после нажатия s ждал следующий
    -- символ (из-за маппингов mini.surround sa/sd/sf/…) и прыжок/состояние
    -- ломались: после прыжка «пробел не работал, меню команд не появлялось».
    -- С nowait s срабатывает мгновенно, оверлей flash сам перехватывает
    -- символы меток, а после прыжка не остаётся висящих ожиданий — пробел
    -- (<leader>, which-key) работает сразу.
    { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, nowait = true, desc = "Прыжок" },
  },
}
