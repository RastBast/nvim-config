-- ========================================================================== --
--                              LUALINE                                       --
-- ========================================================================== --
-- ИСПРАВЛЕНО (обе функции падали с "attempt to call a nil value"):
--  1) require("pomo").get_status() — такой функции в pomo.nvim НЕТ.
--     В lua/pomo/init.lua есть setup/start_timer/get_timer/get_latest/
--     get_first_to_finish/... Официальный пример из README pomo.nvim
--     использует pomo.get_first_to_finish().
--  2) pcall(require, "nvim-spotify.status") — отдельного модуля
--     nvim-spotify/status.lua не существует (в репозитории только
--     lua/nvim-spotify.lua), поэтому pcall всегда возвращал false и
--     компонент Spotify не показывал ничего. Статус живёт в поле
--     require("nvim-spotify").status и читается методом :listen().
return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    config = function()
      -- Помодоро: ближайший к завершению таймер
      local function pomo_status()
        local ok, pomo = pcall(require, "pomo")
        if not ok then return "" end
        local timer = pomo.get_first_to_finish()
        if timer == nil then return "" end
        return "󰄉 " .. tostring(timer)
      end

      -- Spotify (нужен внешний бинарник spt / spotify-tui)
      local function spotify_status()
        local ok, spotify = pcall(require, "nvim-spotify")
        if not ok or type(spotify.status) ~= "table" then return "" end
        local text = spotify.status:listen()
        return type(text) == "string" and text or ""
      end

      -- Telegram: непрочитанные из кэша tele (см. lua/config/telegram.lua).
      -- Пустая строка, когда нечего показывать, — статус-бар не пухнет.
      local function telegram_status()
        local ok, tg = pcall(require, "config.telegram")
        if not ok or not tg.component then return "" end
        return tg.component()
      end

      -- Диагноз LSP: какие серверы прикреплены к буферу
      local function lsp_clients()
        local clients = vim.lsp.get_clients({ bufnr = 0 })
        if #clients == 0 then return "" end
        local names = {}
        for _, c in ipairs(clients) do names[#names + 1] = c.name end
        return " " .. table.concat(names, ",")
      end

      require("lualine").setup({
        options = {
          theme = "auto",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          globalstatus = true, -- у нас laststatus = 3
        },
        sections = {
          lualine_c = { { "filename", path = 1 } },
          lualine_x = {
            -- 🎃 тыква-индикатор хэллоуин-оверлея (<leader>uH, lua/config/halloween.lua)
            {
              function() return "🎃👻🦇" end,
              cond = function() return vim.g.halloween_on == 1 end,
              color = { fg = "#ff9500" },
            },
            { pomo_status, color = { fg = "#e0af68" } },
            { spotify_status, color = { fg = "#1DB954" } },
            -- ✈ непрочитанные Telegram (мост к tele); пусто, когда новых нет
            { telegram_status, color = { fg = "#89b4fa" } },
            { lsp_clients, color = { fg = "#82aaff" } },
            "encoding",
            "fileformat",
            "filetype",
          },
          lualine_y = { "progress" },
          lualine_z = { { function() return "ʕ•ᴥ•ʔ I LOVE GO" end, color = { fg = "#00d787" } } },
        },
      })
    end,
  },
}
