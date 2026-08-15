-- lua/plugins/docker-cli.lua
return {
  "skanehira/docker.vim", -- Именно этот плагин дает команды :Docker...
  cmd = { 
    "Docker", 
    "DockerContainers", 
    "DockerImages", 
    "DockerLogs", 
    "DockerKill" 
  },
  keys = {
    { "<leader>dc", "<cmd>Docker<CR>", desc = "Docker Dashboard" },
    { "<leader>di", "<cmd>DockerImages<CR>", desc = "Docker Images" },
    { "<leader>dC", "<cmd>DockerContainers<CR>", desc = "Docker Containers" },
    { "<leader>dl", "<cmd>DockerLogs<CR>", desc = "Docker Logs" },
  },
  config = function()
    -- Здесь можно добавить настройки, если нужно
    vim.g.docker_terminal_position = 'top'
  end
}

