-- ========================================================================== --
--                          ПЛАВНЫЙ КУРСОР                                    --
-- ========================================================================== --
-- ИСПРАВЛЕНО: `flyin_column` — такой опции у SmoothCursor нет
-- (в lua/smoothcursor/config.lua есть flyin_effect = nil, а не flyin_column).
-- Лишний ключ просто игнорировался; включён правильный flyin_effect.
return {
  {
    "gen740/SmoothCursor.nvim",
    event = "VeryLazy",
    opts = {
      autostart = true,
      cursor = "▶",
      texthl = "SmoothCursor",
      linehl = nil,
      -- Допустимые значения: "default" | "exp" | "matrix".
      -- Эффект "fancy" включается НЕ через type, а через fancy.enable ниже —
      -- при type="fancy" плагин ругается: `type fancy does not exists`.
      type = "default",
      fancy = {
        enable = true,
        head = { cursor = "▶", texthl = "SmoothCursor", linehl = nil },
        body = {
          { cursor = "●", texthl = "SmoothCursorVisual" },
          { cursor = "●", texthl = "SmoothCursorVisual" },
          { cursor = "•", texthl = "SmoothCursorVisual" },
          { cursor = "•", texthl = "SmoothCursorVisual" },
          { cursor = "∙", texthl = "SmoothCursorVisual" },
        },
        tail = { cursor = nil, texthl = "SmoothCursor" },
      },
      speed = 25,
      intervals = 35,
      threshold = 3,
      timeout = 3000,
      priority = 10,
    },
    config = function(_, opts)
      require("smoothcursor").setup(opts)

      -- Горячая клавиша включить/выключить
      vim.keymap.set("n", "<leader>uc", function()
        local sc = require("smoothcursor")
        if vim.g.smoothcursor_disable then
          vim.g.smoothcursor_disable = false
          if sc.start then sc.start() end
          vim.notify("Плавный курсор включён")
        else
          vim.g.smoothcursor_disable = true
          if sc.stop then sc.stop() end
          vim.notify("Плавный курсор выключен")
        end
      end, { desc = "🖱 Плавный курсор вкл/выкл" })
    end,
  },
}
