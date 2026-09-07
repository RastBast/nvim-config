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

    local opts = { silent = true }
    vim.keymap.set("n", "<leader>so", ":Spotify<CR>", vim.tbl_extend("force", opts, { desc = "🎵 Spotify поиск" }))
    vim.keymap.set("n", "<leader>sd", ":SpotifyDevices<CR>", vim.tbl_extend("force", opts, { desc = "🎵 Spotify устройства" }))
    vim.keymap.set("n", "<leader>sp", "<Plug>(SpotifyPause)", vim.tbl_extend("force", opts, { desc = "🎵 Пауза/Плей" }))
    vim.keymap.set("n", "<leader>sn", "<Plug>(SpotifySkip)", vim.tbl_extend("force", opts, { desc = "🎵 Вперёд" }))
    vim.keymap.set("n", "<leader>sb", "<Plug>(SpotifyPrev)", vim.tbl_extend("force", opts, { desc = "🎵 Назад" }))
  end,
}
