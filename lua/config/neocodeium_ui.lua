-- ========================================================================== --
--   МОСТ УПРАВЛЕНИЯ CODEIUM / NEOCODEIUM (GHOST TEXT / INLINE SUGGESTIONS)   --
-- ========================================================================== --
-- По умолчанию ВКЛЮЧЁН (enabled = true).
-- Выключение / включение через хоткей: <leader>AG или <leader>ui (:CodeiumToggle).
-- Авторизация (один раз бесплатно): <leader>AK или :CodeiumAuth (:NeoCodeium auth).
local M = {}

M.enabled = (vim.env.NEOCODEIUM_ENABLED ~= "0")
M.user_toggled = false

local IGNORED_FILETYPES = {
  help = false,
  gitcommit = false,
  gitrebase = false,
  ["."] = false,
  NvimTree = false,
  ["neo-tree"] = false,
  TelescopePrompt = false,
  Avante = false,
  AvanteInput = false,
  AvanteSelectedFiles = false,
  codecompanion = false,
  lazy = false,
  mason = false,
  qf = false,
  trouble = false,
  toggleterm = false,
  alpha = false,
  dashboard = false,
  notify = false,
  noice = false,
  nvimarchboard = false,
  nvimerrorlog = false,
  nvimdiffreview = false,
}

local function echo_msg(msg, hl)
  if vim.api and type(vim.api.nvim_echo) == "function" then
    pcall(vim.api.nvim_echo, { { msg, hl or "MoreMsg" } }, true, {})
  end
end

local function redraw_status()
  pcall(vim.cmd, "redrawstatus")
end

--- Не отправлять файлы с секретами (.env, ключи, сертификаты) в облако.
---@param filepath string
---@return boolean
function M.is_sensitive_file(filepath)
  if type(filepath) ~= "string" or filepath == "" then
    return false
  end
  local base = (filepath:match("([^/\\]+)$") or filepath):lower()
  if base == ".env" or base:match("^%.env%.") or base:match("%.env$") then
    return true
  end
  if base == ".netrc" or base == ".git-credentials" or base:match("^id_rsa") or base:match("^id_ed25519") then
    return true
  end
  if base:match("%.pem$") or base:match("%.key$") or base:match("%.p12$") or base:match("%.pfx$") then
    return true
  end
  if base:find("secret", 1, true) or base:find("credential", 1, true) then
    return true
  end
  return false
end

--- Фильтр буферов для NeoCodeium (возвращает true, если подсказки разрешены).
---@param bufnr integer
---@return boolean
function M.filter_buf(bufnr)
  if not M.enabled then
    return false
  end
  if not vim.api or type(vim.api.nvim_buf_is_valid) ~= "function" or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local bt = vim.bo[bufnr] and vim.bo[bufnr].buftype or ""
  if bt ~= "" then
    return false
  end
  local ft = vim.bo[bufnr] and vim.bo[bufnr].filetype or ""
  if IGNORED_FILETYPES[ft] == false then
    return false
  end
  local name = (type(vim.api.nvim_buf_get_name) == "function" and vim.api.nvim_buf_get_name(bufnr)) or ""
  if M.is_sensitive_file(name) then
    return false
  end
  return true
end

function M.ignored_filetypes()
  return vim.deepcopy and vim.deepcopy(IGNORED_FILETYPES) or IGNORED_FILETYPES
end

local function ensure_loaded()
  if not package.loaded["neocodeium"] then
    pcall(function()
      require("lazy").load({ plugins = { "neocodeium" } })
    end)
  end
  local ok, nc = pcall(require, "neocodeium")
  return ok and type(nc) == "table" and nc or nil
end

function M.visible()
  if not M.enabled then
    return false
  end
  local nc = package.loaded["neocodeium"]
  if type(nc) == "table" and type(nc.visible) == "function" then
    local ok, vis = pcall(nc.visible)
    return ok and vis == true
  end
  return false
end

function M.accept()
  if not M.visible() then
    return false
  end
  local nc = package.loaded["neocodeium"]
  if type(nc) == "table" and type(nc.accept) == "function" then
    pcall(nc.accept)
    return true
  end
  return false
end

function M.accept_word()
  if not M.visible() then
    return false
  end
  local nc = package.loaded["neocodeium"]
  if type(nc) == "table" and type(nc.accept_word) == "function" then
    pcall(nc.accept_word)
    return true
  end
  return false
end

function M.accept_line()
  if not M.visible() then
    return false
  end
  local nc = package.loaded["neocodeium"]
  if type(nc) == "table" and type(nc.accept_line) == "function" then
    pcall(nc.accept_line)
    return true
  end
  return false
end

function M.clear()
  local nc = package.loaded["neocodeium"]
  if type(nc) == "table" and type(nc.clear) == "function" then
    pcall(nc.clear)
    return true
  end
  return false
end

function M.cycle_or_complete(step)
  local nc = ensure_loaded()
  if nc and type(nc.cycle_or_complete) == "function" then
    if vim.fn and type(vim.fn.mode) == "function" and vim.fn.mode() == "n" then
      pcall(vim.cmd, "startinsert")
    end
    pcall(nc.cycle_or_complete, step or 1)
    return true
  end
  echo_msg("⚡ NeoCodeium не установлен — выполни :Lazy sync, затем :CodeiumAuth (<leader>AK)", "WarningMsg")
  return false
end

function M.enable()
  M.enabled = true
  M.user_toggled = true
  ensure_loaded()
  local ok_cmd, cmds = pcall(require, "neocodeium.commands")
  if ok_cmd and type(cmds) == "table" and type(cmds.enable) == "function" then
    pcall(cmds.enable)
  else
    pcall(vim.cmd, "NeoCodeium enable")
  end
  redraw_status()
  local msg = "⚡ Codeium / NeoCodeium (Ghost Text): ВКЛ  [Tab / Alt+L — принять · Alt+W — слово · выкл: <leader>AG]"
  vim.notify(msg, vim.log.levels.INFO)
  echo_msg(msg, "MoreMsg")
end

function M.disable()
  M.enabled = false
  M.user_toggled = true
  M.clear()
  local ok_cmd, cmds = pcall(require, "neocodeium.commands")
  if ok_cmd and type(cmds) == "table" and type(cmds.disable) == "function" then
    pcall(cmds.disable, false)
  elseif package.loaded["neocodeium"] then
    pcall(vim.cmd, "NeoCodeium disable")
  end
  redraw_status()
  local msg = "⚡ Codeium / NeoCodeium (Ghost Text): ВЫКЛ  [включить обратно: <leader>AG или <leader>ui]"
  vim.notify(msg, vim.log.levels.INFO)
  echo_msg(msg, "WarningMsg")
end

function M.toggle()
  if M.enabled then
    M.disable()
  else
    M.enable()
  end
end

function M.auth()
  local nc = ensure_loaded()
  if not nc then
    local msg = "⚡ NeoCodeium ещё не скачан — сначала выполни :Lazy sync, затем :CodeiumAuth"
    vim.notify(msg, vim.log.levels.WARN)
    echo_msg(msg, "WarningMsg")
    return
  end
  pcall(vim.cmd, "NeoCodeium auth")
end

function M.status()
  local nc = package.loaded["neocodeium"]
  local state_txt = M.enabled and "ВКЛЮЧЁН (по умолчанию)" or "ВЫКЛЮЧЕН"
  local srv_txt = "ожидает загрузки (войди в режим вставки или :Lazy sync)"
  if type(nc) == "table" and type(nc.get_status) == "function" then
    local ok, st, srv = pcall(nc.get_status)
    if ok then
      local srv_map = { [0] = "сервер запущен (ON)", [1] = "подключение…", [2] = "сервер остановлен (нужен :CodeiumAuth?)" }
      srv_txt = (srv_map[srv] or tostring(srv)) .. " [status=" .. tostring(st) .. "]"
    end
  end
  local msg = ("⚡ Codeium / NeoCodeium: %s · %s · переключить: <leader>AG / <leader>ui · вход: <leader>AK"):format(state_txt, srv_txt)
  vim.notify(msg, vim.log.levels.INFO)
  echo_msg(msg, M.enabled and "MoreMsg" or "WarningMsg")
end

--- Компонент для Lualine: показывает состояние NeoCodeium и кликом переключает вкл/выкл.
function M.lualine_component()
  if not M.enabled then
    return "⚡ Codeium:off"
  end
  local nc = package.loaded["neocodeium"]
  if type(nc) == "table" and type(nc.get_status) == "function" then
    local ok, st, srv = pcall(nc.get_status)
    if ok then
      if st == 1 or st == 2 then
        return "⚡ Codeium:off"
      end
      if srv == 0 then
        return "⚡ Codeium"
      elseif srv == 1 then
        return "⚡ Codeium…"
      end
    end
  end
  return "⚡ Codeium"
end

local setup_done = false
function M.setup()
  if setup_done then
    return
  end
  setup_done = true

  vim.api.nvim_create_user_command("CodeiumToggle", function() M.toggle() end, {
    force = true,
    desc = "⚡ Вкл/выкл призрачные подсказки Codeium / NeoCodeium",
  })
  vim.api.nvim_create_user_command("CodeiumAuth", function() M.auth() end, {
    force = true,
    desc = "🔑 Авторизация в бесплатном аккаунте Codeium / Windsurf (:NeoCodeium auth)",
  })
  vim.api.nvim_create_user_command("CodeiumStatus", function() M.status() end, {
    force = true,
    desc = "⚡ Показать статус Codeium / NeoCodeium",
  })
  -- Совместимые алиасы :GhostTextToggle / :GhostText
  vim.api.nvim_create_user_command("GhostTextToggle", function() M.toggle() end, {
    force = true,
    desc = "⚡ Вкл/выкл призрачные подсказки Codeium / NeoCodeium",
  })
  vim.api.nvim_create_user_command("GhostText", function(cmd_opts)
    local arg = vim.trim((cmd_opts and cmd_opts.args) or ""):lower()
    if arg == "on" or arg == "enable" or arg == "1" then
      M.enable()
    elseif arg == "off" or arg == "disable" or arg == "0" then
      M.disable()
    elseif arg == "auth" then
      M.auth()
    elseif arg == "status" then
      M.status()
    else
      M.toggle()
    end
  end, {
    force = true,
    nargs = "?",
    complete = function() return { "toggle", "on", "off", "status", "auth" } end,
    desc = "⚡ Управление Codeium / NeoCodeium (Ghost Text): toggle / on / off / status / auth",
  })

  -- Хоткеи вкл/выкл и авторизации (Normal mode)
  vim.keymap.set("n", "<leader>AG", M.toggle, {
    desc = "⚡ Codeium / NeoCodeium (Ghost Text): вкл/выкл (:CodeiumToggle)",
    silent = true,
  })
  vim.keymap.set("n", "<leader>ui", M.toggle, {
    desc = "⚡ Призрачные подсказки Codeium (Ghost Text): вкл/выкл",
    silent = true,
  })
  vim.keymap.set("n", "<leader>AK", M.auth, {
    desc = "🔑 Авторизация Codeium / NeoCodeium (:CodeiumAuth)",
    silent = true,
  })
  vim.keymap.set("n", "<leader>Ai", function() M.cycle_or_complete(1) end, {
    desc = "⚡ Запросить подсказку Codeium вручную",
    silent = true,
  })

  -- Хоткеи в режиме вставки (Insert mode)
  vim.keymap.set("i", "<M-l>", function()
    if M.accept() then return end
    local ok_av, av = pcall(require, "avante")
    if ok_av and type(av.get) == "function" then
      local _, _, sg = av.get()
      if sg and type(sg.is_visible) == "function" and sg:is_visible() then sg:accept() end
    end
  end, { desc = "⚡ Принять подсказку Codeium целиком", silent = true })

  vim.keymap.set("i", "<M-w>", function()
    M.accept_word()
  end, { desc = "⚡ Принять следующее слово из подсказки Codeium", silent = true })

  vim.keymap.set("i", "<C-Right>", function()
    if not M.accept_word() then
      local keys = vim.api.nvim_replace_termcodes("<C-Right>", true, false, true)
      vim.api.nvim_feedkeys(keys, "n", false)
    end
  end, { desc = "⚡ Принять следующее слово из подсказки Codeium", silent = true })

  vim.keymap.set("i", "<M-a>", function()
    M.accept_line()
  end, { desc = "⚡ Принять одну строку из подсказки Codeium", silent = true })

  vim.keymap.set("i", "<M-]>", function()
    M.cycle_or_complete(1)
  end, { desc = "⚡ Следующий вариант подсказки Codeium", silent = true })

  vim.keymap.set("i", "<M-[>", function()
    M.cycle_or_complete(-1)
  end, { desc = "⚡ Предыдущий вариант подсказки Codeium", silent = true })

  vim.keymap.set("i", "<M-g>", function()
    M.cycle_or_complete(1)
  end, { desc = "⚡ Запросить подсказку Codeium вручную", silent = true })

  vim.keymap.set("i", "<C-]>", function()
    if M.visible() then
      M.clear()
      return
    end
    local ok_av, av = pcall(require, "avante")
    if ok_av and type(av.get) == "function" then
      local _, _, sg = av.get()
      if sg and type(sg.dismiss) == "function" then sg:dismiss() end
    end
  end, { desc = "⚡ Скрыть текущую подсказку Codeium", silent = true })
end

return M
