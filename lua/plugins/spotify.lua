-- ========================================================================== --
--                          SPOTIFY В РЕДАКТОРЕ                               --
-- ========================================================================== --
-- Команды :Spotify и :SpotifyDevices действительно существуют — они
-- регистрируются через remote-хост в nvim-spotify.vim, но работают только
-- если собран бинарник bin/NvimSpotify (build = "make", нужен Go) и
-- установлен spotify-tui (`spt`).
--
-- ИСПРАВЛЕНО: спека включается только когда `spt` реально есть в системе,
-- иначе при каждом запуске Neovim падали ошибки про отсутствующий хост.
return {
  "KadoBOT/nvim-spotify",
  dependencies = { "nvim-telescope/telescope.nvim" },
  build = "make",
  enabled = vim.fn.executable("spt") == 1, -- нет spt — плагин не грузим
  lazy = true,
  cmd = { "Spotify", "SpotifyDevices" },
  -- Клавиши объявлены в keys, а не в config: config выполняется только ПОСЛЕ
  -- загрузки плагина, и до первого :Spotify <leader>sp/sn/sb не существовали.
  -- Lazy сам подгрузит плагин при нажатии.
  keys = {
    { "<leader>so", ":Spotify<CR>", desc = "🎵 Spotify поиск", silent = true },
    { "<leader>sd", ":SpotifyDevices<CR>", desc = "🎵 Spotify устройства", silent = true },
    { "<leader>sp", "<Plug>(SpotifyPause)", desc = "🎵 Пауза/Плей", silent = true },
    { "<leader>sn", "<Plug>(SpotifySkip)", desc = "🎵 Вперёд", silent = true },
    { "<leader>sb", "<Plug>(SpotifyPrev)", desc = "🎵 Назад", silent = true },
  },
  config = function()
    local spotify = require("nvim-spotify")
    spotify.setup({
      status = {
        update_interval = 10000,          -- интервал обновления статуса (мс)
        format = "%s %t by %a",           -- станция, трек, артист
      },
    })

    -- Запуск опроса статуса (его читает lualine)
    if type(spotify.status) == "table" and spotify.status.start then
      spotify.status:start()
    end

  end,
}
