-- ========================================================================== --
--                   DOCKER: ПОДСВЕТКА DOCKERFILE                             --
-- ========================================================================== --
-- ИСПРАВЛЕНО: skanehira/docker.vim УДАЛЁН — плагин написан только под Vim
-- и в Neovim ВСЕГДА падает с ошибкой:
--   «docker.vim: doesn't support neovim. please use vim that version is
--    8.1.1799 or above»
--
-- Чем заменён:
--   * подсветка Dockerfile / docker-compose — этот файл (ekalinin/Dockerfile.vim);
--   * интерфейс Docker (контейнеры, логи, образы, сети, kill) — lazydocker
--     и docker CLI в плавающем окне toggleterm:
--       <leader>dc — lazydocker (TUI-панель Docker, «маленькое окно»);
--       <leader>dp — docker ps -a;  <leader>di — docker images;
--       <leader>dn — docker network ls.
--     (маппинги живут в lua/plugins/toggleterm.lua)
--   * LSP для Dockerfile (dockerls) уже включён в lua/config/servers.lua.
return {
  { "ekalinin/Dockerfile.vim", ft = { "dockerfile", "docker-compose" } },
}
