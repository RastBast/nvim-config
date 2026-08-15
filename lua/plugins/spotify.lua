return {
  "KadoBOT/nvim-spotify",
  dependencies = { "nvim-telescope/telescope.nvim" },
  build = "make",  -- Требуется для сборки (Go)
  config = function()
    local spotify = require("nvim-spotify")
    spotify.setup({
      status = {
        update_interval = 10000,  -- Интервал обновления статуса (мс)
        format = "%s %t by %a",  -- Формат: станция, трек, артист
      },
    })

    -- Запуск статус-бара (опционально, для lualine или statusline)
    local status = spotify.status
    status:start()

    local opts = { silent = true }

    -- Поиск (Telescope)
    vim.keymap.set("n", "<leader>so", ":Spotify<CR>", vim.tbl_extend("force", opts, { desc = "Spotify Поиск" }))

    -- Выбор устройства
    vim.keymap.set("n", "<leader>sd", ":SpotifyDevices<CR>", vim.tbl_extend("force", opts, { desc = "Spotify Устройства" }))

    -- Управление
    vim.keymap.set("n", "<leader>sp", "<Plug>(SpotifyPause)", vim.tbl_extend("force", opts, { desc = "Spotify Пауза/Плей" }))
    vim.keymap.set("n", "<leader>sn", "<Plug>(SpotifySkip)", vim.tbl_extend("force", opts, { desc = "Spotify Вперед" }))
    vim.keymap.set("n", "<leader>sb", "<Plug>(SpotifyPrev)", vim.tbl_extend("force", opts, { desc = "Spotify Назад" }))
  end,
}
