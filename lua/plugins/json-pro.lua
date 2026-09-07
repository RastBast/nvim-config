-- ========================================================================== --
--                         ИНСТРУМЕНТЫ ДЛЯ JSON                               --
-- ========================================================================== --
-- ИСПРАВЛЕНО: отсюда убран дубль stevearc/aerial.nvim (владелец —
-- lua/plugins/aerial.lua), осталась только работа через jq.
return {
  {
    "gennaro-tedesco/nvim-jqx",
    ft = { "json", "yaml" },
    cmd = { "JqxList", "JqxQuery" },
    config = function()
      -- Показывает структуру/типы данных в JSON (нужен установленный `jq`)
      vim.keymap.set("n", "<leader>jx", "<cmd>JqxList<cr>", { desc = "🔍 Список ключей JSON" })
      vim.keymap.set("n", "<leader>jq", "<cmd>JqxQuery<cr>", { desc = "🔎 jq-запрос по JSON" })
    end,
  },
}
