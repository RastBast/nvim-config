-- ========================================================================== --
--                         НОВОЕ: mini.surround + mini.ai                     --
-- ========================================================================== --
-- Удобные текстовые объекты и работа с окружениями (скобки, кавычки, теги):
--   gzaiw "  — обернуть слово в кавычки     gzd" — удалить кавычки
--   vi(  /  va"  /  vit — выделение внутри/вокруг скобок, кавычек, тегов
--   gzr (  — заменить скобки
-- Обе библиотеки — чистая Lua от echasnovski/mini.*, без внешних зависимостей.
--
-- ПРЕФИКС gz ВМЕСТО s (2026-10-28): раньше окружения жили на sa/sd/sf/…, и
-- простое s (flash-прыжок) заставляло nvim ждать второй символ: прыжок
-- запаздывал, а комбинации вроде sf уводили в surround — после этого
-- «проваливался» пробел и меню which-key. Теперь s целиком принадлежит flash
-- (с nowait), а окружения — префиксу gz.
return {
  {
    "nvim-mini/mini.surround",
    version = false,
    event = { "BufReadPost", "InsertEnter" },
    opts = {
      mappings = {
        add = "gza",       -- добавить окружение (visual или gzaiw ")
        delete = "gzd",    -- удалить окружение
        find = "gzf",      -- найти окружение справа
        find_left = "gzF", -- найти окружение слева
        highlight = "gzh", -- подсветить окружение
        replace = "gzr",   -- заменить окружение
        update_n_lines = "gzn",
      },
      n_lines = 20,
      search_method = "cover",
    },
  },
  {
    "nvim-mini/mini.ai",
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
