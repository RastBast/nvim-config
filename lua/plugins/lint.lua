-- ========================================================================== --
--                 ЛИНТЕРЫ: nvim-lint (асинхронно, без ошибок)                --
-- ========================================================================== --
-- Линтер запускается, только если его бинарник есть в PATH: иначе тихо пропускаем
-- (без красных сообщений «command not found»). Запуск: при открытии, сохранении,
-- выходе из режима вставки, либо вручную <leader>cl.

-- Запустить линтеры, у которых есть бинарник в PATH (executable у cmd)
local function run_available()
  local lint = require("lint")
  local names = lint.linters_by_ft[vim.bo.filetype]
  if not names then
    return
  end
  local ok = {}
  for _, n in ipairs(names) do
    local l = lint.linters[n]
    if type(l) == "function" then
      l = l()
    end
    local cmd = l and l.cmd
    if type(cmd) == "function" then
      cmd = cmd()
    end
    if cmd and vim.fn.executable(cmd) == 1 then
      ok[#ok + 1] = n
    end
  end
  if #ok > 0 then
    lint.try_lint(ok)
  end
end

return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "InsertLeave" },
    keys = {
      { "<leader>cl", run_available, desc = "🔍 Линтеры для этого файла" },
    },
    config = function()
      require("lint").linters_by_ft = {
        sh = { "shellcheck" },
        bash = { "shellcheck" },
        dockerfile = { "hadolint" },
        python = { "ruff" },
        yaml = { "yamllint" },
        markdown = { "markdownlint-cli2" },
      }

      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("NvimLintRun", { clear = true }),
        callback = run_available,
      })
    end,
  },
}
