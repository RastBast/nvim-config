-- ========================================================================== --
--                          GO: ЕДИНСТВЕННЫЙ СПЕК                             --
-- ========================================================================== --
-- ИСПРАВЛЕНО. Раньше ray-x/go.nvim был объявлен ДВАЖДЫ:
--   lua/plugins/go-tools.lua   и   lua/plugins/go-security.lua
-- lazy.nvim склеивает такие спеки в один плагин, а функция config у плагина
-- может быть только одна — выживал последний, поэтому все настройки и
-- клавиши из go-security.lua (GoLint / GoVulncheck) просто терялись.
-- Файл go-security.lua удалён, всё живёт здесь.
--
-- Также удалён lua/plugins/go-utils.lua (olexsmir/gopher.nvim):
--   * его build содержал мусор  `go install ://github.com`
--   * он объявлял те же команды, что и go.nvim (GoIfErr, GoImpl, GoNew),
--     и они перезаписывали друг друга
--   * клавиша <leader>gj вела на :GoDoMock — такой команды нет ни в одном
--     из плагинов. Генерация моков в go.nvim называется :GoMockGen.
return {
  {
    "ray-x/go.nvim",
    dependencies = {
      "ray-x/guihua.lua",
      "nvim-treesitter/nvim-treesitter",
    },
    event = { "CmdlineEnter" },
    ft = { "go", "gomod", "gowork", "gosum" },
    -- Стабы команд: which-key дёргает <cmd>Go* до загрузки плагина —
    -- без cmd = это E492. Все имена сверены с lua/go/commands.lua go.nvim.
    cmd = {
      "GoBuild", "GoTest", "GoTestFunc", "GoTestFile", "GoTestPkg",
      "GoLint", "GoVulnCheck", "GoMockGen", "GoIfErr", "GoImpl",
      "GoAddTag", "GoFillStruct", "GoJson", "GoJson2Struct",
    },
    build = ':lua require("go.install").update_all_sync()',
    config = function()
      require("go").setup({
        lsp_cfg = false, -- LSP настраивается в lua/plugins/lsp-config.lua
        lsp_keymaps = true,
        diagnostic = { hdlr = true, underline = true },
        gofmt = "goimports", -- форматирование с автоимпортом
        test_efm = false,
        trouble = true,
      })

      -- Автоформат Go-файлов при сохранении
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = vim.api.nvim_create_augroup("UserGoFormat", { clear = true }),
        pattern = "*.go",
        callback = function()
          pcall(require("go.format").goimports)
        end,
      })

      -- Быстрые команды (регистр важен: команда называется GoVulnCheck)
      vim.keymap.set("n", "<leader>gv", "<cmd>GoVulnCheck<cr>", { desc = "🛡 Проверить уязвимости" })
      vim.keymap.set("n", "<leader>gl", "<cmd>GoLint<cr>", { desc = "🧹 Линтер" })
      vim.keymap.set("n", "<leader>gt", "<cmd>GoTest<cr>", { desc = "🧪 Тесты пакета" })
      vim.keymap.set("n", "<leader>gb", "<cmd>GoBuild<cr>", { desc = "🔨 Собрать" })
      vim.keymap.set("n", "<leader>gm", "<cmd>GoMockGen<cr>", { desc = "🎭 Сгенерировать мок" })
    end,
  },
}
