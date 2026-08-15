return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "auto",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
        },
        sections = {
          lualine_x = {
            "encoding",
            {
              function()
                local ok, spotify = pcall(require, "nvim-spotify.status")
                if ok then
                  return spotify.listen() or ""
                end
                return ""
              end,
              color = { fg = "#1DB954" },
            },
            { function() return require("pomo").get_status() end },
            { function() return "ʕ•ᴥ•ʔ I LOVE GO" end },
          },
        },
      })
    end,
  },
}
