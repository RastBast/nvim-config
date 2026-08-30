-- ========================================================================== --
--                        DOCKER: ПАНЕЛЬ КОНТЕЙНЕРОВ                          --
-- ========================================================================== --
-- ИСПРАВЛЕНО: у skanehira/docker.vim нет команд :DockerLogs и :DockerKill.
-- Реальный набор (grep по plugin/ репозитория):
--   Docker, DockerContainers, DockerContainerLogs, DockerEvents, DockerImages,
--   DockerImageBuild, DockerImagePull, DockerImageSearch, DockerNetworks,
--   DockerVersion, DockerMonitorStart, DockerMonitorStop, DockerMonitorWindowMove
-- Из-за несуществующих имён в `cmd` lazy.nvim вешал заглушки, которые
-- после загрузки плагина не находили команду и выдавали E492.
return {
  "skanehira/docker.vim",
  cmd = {
    "Docker",
    "DockerContainers",
    "DockerContainerLogs",
    "DockerImages",
    "DockerNetworks",
    "DockerEvents",
  },
  keys = {
    { "<leader>dc", "<cmd>Docker<CR>", desc = "🐳 Docker Dashboard" },
    { "<leader>di", "<cmd>DockerImages<CR>", desc = "🐳 Docker Images" },
    { "<leader>dC", "<cmd>DockerContainers<CR>", desc = "🐳 Docker Containers" },
    { "<leader>dl", "<cmd>DockerContainerLogs<CR>", desc = "🐳 Docker Logs" },
    { "<leader>dn", "<cmd>DockerNetworks<CR>", desc = "🐳 Docker Networks" },
  },
}
