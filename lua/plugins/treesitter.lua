return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local status, ts = pcall(require, "nvim-treesitter.configs")
      if not status then return end

      ts.setup({
        ensure_installed = { "sql", "go", "lua", "bash", "javascript", "typescript", "markdown", "markdown_inline" },
        highlight = { 
            enable = true,
            -- Это важно для твоей кастомной раскраски в init.lua
            additional_vim_regex_highlighting = false,
        },
        -- Отключаем встроенные складки Treesitter на корню
        fold = { enable = false }, 
      })
    end,
  },
}

