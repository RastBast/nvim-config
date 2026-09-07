-- ========================================================================== --
--                        ПОМОДОРО (pomo.nvim)                                --
-- ========================================================================== --
-- ИСПРАВЛЕНО. Команды pomo.nvim называются Timer*, а не Pomo*:
-- в lua/pomo/commands/init.lua создаются TimerStart, TimerStop, TimerRepeat,
-- TimerHide, TimerShow, TimerPause, TimerResume, TimerSession.
-- Из-за `cmd = { "PomoStart", ... }` lazy.nvim вешал заглушки на
-- несуществующие команды, и <leader>pt выдавал "Not an editor command".
return {
  {
    "epwalsh/pomo.nvim",
    lazy = true,
    cmd = { "TimerStart", "TimerStop", "TimerPause", "TimerResume", "TimerShow", "TimerHide", "TimerRepeat", "TimerSession" },
    keys = {
      { "<leader>pt", "<cmd>TimerStart 25m Work<CR>", desc = "⏱️ Запустить таймер (25м)" },
      { "<leader>ps", "<cmd>TimerStop Work<CR>", desc = "⏱️ Остановить таймер" },
      { "<leader>pp", "<cmd>TimerPause Work<CR>", desc = "⏸ Пауза" },
      { "<leader>pr", "<cmd>TimerResume Work<CR>", desc = "▶ Снять с паузы" },
    },
    config = function()
      require("pomo").setup({
        -- Уведомления всплывают через nvim-notify
        notifiers = {
          { name = "Default", opts = { title = "Pomo.nvim" } },
        },
        -- Времена по умолчанию (в секундах)
        update_interval = 1000,
      })
    end,
  },
}
