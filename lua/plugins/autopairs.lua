-- ========================================================================== --
--                        АВТОПАРЫ СКОБОК (autopairs)                         --
-- ========================================================================== --
-- ИСПРАВЛЕНО: добавлена зависимость от nvim-cmp. Раньше внутри config
-- делался require('cmp'), а сам cmp подгружался по событию InsertEnter —
-- порядок загрузки не гарантирован, и интеграция с автодополнением
-- (автодобавление скобок у функций) могла не подключиться.
--
-- Также удалён lua/plugins/insx.lua: hrsh7th/nvim-insx с пресетом
-- `standard` сам добавляет автопары ()[]{}"", то есть дублировал
-- autopairs и давал двойные скобки при наборе.
return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    dependencies = { "hrsh7th/nvim-cmp" },
    config = function()
      require("nvim-autopairs").setup({
        check_ts = true, -- учитывать контекст Treesitter
        ts_config = {
          lua = { "string" },        -- не добавлять пары внутри строк lua
          javascript = { "template_string" },
          go = { "string" },
        },
        fast_wrap = { map = "<M-e>" },
      })

      -- Интеграция с автодополнением: скобки добавляются при выборе функции
      local ok, cmp_autopairs = pcall(require, "nvim-autopairs.completion.cmp")
      if ok then
        require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
      end
    end,
  },
}
