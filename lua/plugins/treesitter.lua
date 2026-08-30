-- ========================================================================== --
--                            TREESITTER                                      --
-- ========================================================================== --
-- ИСПРАВЛЕНО. Старый вариант был мёртвым:
--   local status, ts = pcall(require, "nvim-treesitter.configs")
--   if not status then return end
-- В ветке `main` (текущая по умолчанию) модуля nvim-treesitter.configs
-- БОЛЬШЕ НЕТ — в lua/nvim-treesitter/ лежат: config.lua, init.lua,
-- install.lua, parsers.lua и т.д. pcall молча проглатывал ошибку, и
-- подсветка Treesitter не включалась вообще (поэтому кастомные цвета
-- из init.lua тоже не применялись — групп @keyword/@function не было).
--
-- Ниже — новый API: установка парсеров + vim.treesitter.start() по FileType.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false, -- плагин официально не поддерживает ленивую загрузку
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({
        install_dir = vim.fn.stdpath("data") .. "/site",
      })

      local ensure = {
        "go", "gomod", "gosum", "gowork",
        "lua", "vim", "vimdoc", "query",
        "bash", "json", "json5", "yaml", "toml",
        "javascript", "typescript", "tsx", "css", "html",
        "markdown", "markdown_inline",
        "sql", "dockerfile", "regex", "make", "diff", "gitignore",
      }

      -- Включаем подсветку. vim.treesitter.start() сам определяет язык
      -- по filetype; pcall — потому что парсер может ещё не скачаться.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("UserTreesitterHighlight", { clear = true }),
        callback = function()
          pcall(vim.treesitter.start)
        end,
      })

      -- Ставим парсеры асинхронно (не блокируем запуск Neovim)
      local ok, task = pcall(require("nvim-treesitter").install, ensure)
      if ok and type(task) == "table" and task.await then
        task:await(function()
          -- парсеры приехали — включаем подсветку в текущем буфере
          vim.schedule(function()
            pcall(vim.treesitter.start)
          end)
        end)
      end
    end,
  },
}
