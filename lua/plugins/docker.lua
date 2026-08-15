-- lua/plugins/docker.lua — DEBUG в Docker контейнерах (DAP + nvim-dap-docker) [web:34]
return {
  "docker/nvim-dap-docker",
  dependencies = {
    "mfussenegger/nvim-dap",
  },
  config = function()
    require("dap-docker").setup({
      -- Хост Docker (Mac: unix sock по умолчанию)
      host = "unix:///var/run/docker.sock",
      -- Фильтр: только running контейнеры
      container_filters = {
        running = true,
      },
    })
  end,
}

