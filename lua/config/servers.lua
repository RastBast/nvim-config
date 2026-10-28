-- ========================================================================== --
--                  ЕДИНЫЙ СПИСОК LSP-СЕРВЕРОВ                                --
-- ========================================================================== --
-- Теперь список собирается из lua/config/languages.lua (≈40 языков).
--   .mason     — что Mason ставит сам (ensure_installed)
--   .all       — что включать через vim.lsp.enable (включая toolchain-серверы)
--   .toolchain — серверы, которым нужен системный тулчейн: Mason их не трогает
local L = require("config.languages")

return {
  mason = L.mason_servers(),
  all = L.servers(),
  toolchain = L.toolchain_servers(),
}
