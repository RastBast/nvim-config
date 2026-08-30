-- ========================================================================== --
--                 DAP ДЛЯ DOCKERFILE (docker/nvim-dap-docker)                 --
-- ========================================================================== --
-- ИСПРАВЛЕНО. В setup() передавались `host` и `container_filters` —
-- таких опций у плагина нет: default_config в lua/dap-docker.lua содержит
-- только  docker = { path, builder, standalone }  (+ dap_configurations).
-- Кроме того, плагин НЕ подключается к запущенным контейнерам — он даёт
-- dap-адаптер "dockerfile" для отладки сборки Dockerfile.
return {
  "docker/nvim-dap-docker",
  dependencies = { "mfussenegger/nvim-dap" },
  config = function()
    require("dap-docker").setup({
      docker = {
        path = "docker",      -- бинарник docker из PATH
        builder = nil,        -- nil = дефолтный builder контекста
        standalone = false,   -- использовать docker buildx
      },
      dap_configurations = {
        {
          type = "dockerfile",
          name = "Build (Cache-Only)",
          request = "request",
          args = { "-o", "type=cacheonly" },
        },
      },
    })
  end,
}
