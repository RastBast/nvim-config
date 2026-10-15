-- ========================================================================== --
--                         НОВОЕ: mini.surround + mini.ai                     --
-- ========================================================================== --
-- Удобные текстовые объекты и работа с окружениями (скобки, кавычки, теги):
--   saiw "  — обернуть слово в кавычки      sd" — удалить кавычки
--   vi(  /  va"  /  vit — выделение внутри/вокруг скобок, кавычек, тегов
--   sr( [  — заменить скобки
-- Обе библиотеки — чистая Lua от echasnovski/mini.*, без внешних зависимостей.
return {
  {
    "echasnovski/mini.surround",
    version = false,
    event = { "BufReadPost", "InsertEnter" },
    opts = {
      mappings = {
        add = "sa",       -- добавить окружение (visual или saiw ")
        delete = "sd",    -- удалить окружение
        find = "sf",      -- найти окружение справа
        find_left = "sF", -- найти окружение слева
        highlight = "sh", -- подсветить окружение
        replace = "sr",   -- заменить окружение
        update_n_lines = "sn",
      },
      n_lines = 20,
      search_method = "cover",
    },
  },
  {
    "echasnovski/mini.ai",
    version = false,
    event = { "BufReadPost", "InsertEnter" },
    -- opts — функция: gen_spec нужен mini.ai, а его модуль доступен только
    -- после загрузки плагина. Раньше `f` был обёрткой, которая возвращала
    -- функцию-спек вместо спека → vif/vaf ломались.
    opts = function()
      local ai = require("mini.ai")
      return {
        n_lines = 50,
        custom_textobjects = {
          -- f — функция (по Treesitter): af / if
          f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
        },
      }
    end,
  },
}
