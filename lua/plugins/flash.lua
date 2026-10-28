return {
  "folke/flash.nvim",
  event = "VeryLazy",
  opts = {},
  keys = {
    -- Прыжок переехал с `s` на `gs`: mini.surround использует префикс s
    -- (sa / sd / sr / sf / sh / sn), и `s` заставляло nvim ждать второй символ
    -- → после прыжка «пробел не работал, меню which-key не появлялось» (баг пункта 5).
    { "gs", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Прыжок (flash)" },
  },
}
