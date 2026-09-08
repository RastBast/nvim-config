-- ========================================================================== --
--                             TELESCOPE                                      --
-- ========================================================================== --
-- ИСПРАВЛЕНО:
--  1) tag = '0.1.8' — жёсткая привязка к старому тегу, из-за которой
--     плагин не обновлялся и отставал от plenary. Убрано.
--  2) cwd = "~/Documents/ObsidianVault" — telescope НЕ разворачивает `~`.
--     Теперь путь разворачивается через vim.fn.expand() и проверяется.
--  3) Добавлены буферы/справка/документы, которые уже были в which-key
--     и на дашборде alpha, но не имели маппингов.
return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "Telescope",
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "📂 Найти файл" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "🔎 Поиск по содержимому" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "🗂 Буферы" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "🕑 Недавние файлы" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "❓ Поиск по справке" },
      { "<leader>fd", "<cmd>Telescope diagnostics<cr>", desc = "⚠️ Диагностика проекта" },
      { "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "⌨️ Все горячие клавиши" },
      { "<leader>fc", "<cmd>Telescope commands<cr>", desc = "🧰 Все команды" },
      { "<leader>fn", function()
        -- Путь к хранилищу Obsidian: раскрываем ~ и проверяем, что папка есть
        local vault = vim.fn.expand("~/obsidian_base")
        if vim.fn.isdirectory(vault) ~= 1 then
          vim.notify("Хранилище Obsidian не найдено: " .. vault, vim.log.levels.WARN)
          return
        end
        require("telescope.builtin").find_files({ cwd = vault, prompt_title = "Obsidian" })
      end, desc = "💎 Поиск в Obsidian" },
    },
    opts = {
      defaults = {
        prompt_prefix = " 🔎 ",
        selection_caret = "  ",
        layout_config = { horizontal = { preview_width = 0.55 } },
        file_ignore_patterns = { "node_modules/", "%.git/", "go%.sum" },
      },
      pickers = {
        find_files = { hidden = true },
      },
    },
  },
}
