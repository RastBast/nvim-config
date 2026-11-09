-- ========================================================================== --
--     ЗАЩИТА КАРТЫ РЕПОЗИТОРИЯ И САЙДБАРА AVANTE ОТ БИТОГО КЕША И СБОЕВ      --
-- ========================================================================== --
-- В avante v0.4.8 две связанные ловушки:
--   1. Если `avante_repo_map` не загрузился хотя бы раз, `_build_repo_map`
--      возвращает `nil`, а `Path.repo_map.save` записывает в `*.repo_map.json`
--      строку `null`. На всех следующих запусках `vim.json.decode("null")`
--      возвращает `vim.NIL` (`userdata`), и `next(repo_map)` в `repo_map.lua:112`
--      падает с «bad argument #1 to 'next' (table expected, got userdata)».
--   2. В `ftplugin/AvanteInput.lua` автокоманды `ModeChanged`, `WinEnter` и
--      таймер дебаунса вызывают `sidebar:show_input_hint()` → `calculate_tokens()`
--      → `get_templates_dir()`, который при неготовности `avante_templates`
--      бросает ошибку на каждое нажатие клавиши и смену окна.
local M = {
  invalid_cache_count = 0,
  cleaned_disk_count = 0,
}

local path_repo_wrapped = nil
local repo_map_wrapped = nil
local sidebar_wrapped = nil
local is_ready_cb = function() return false end
local show_status_cb = function() end

--- Проверка, что декодированный JSON — валидный массив элементов `{path, lang, defs}`.
--- Отсекает `vim.NIL` (`userdata`), словари, дырявые массивы и битые записи.
local function valid_map(map)
  if type(map) ~= "table" then
    return false
  end
  local size = #map
  for key, value in pairs(map) do
    if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > size then
      return false
    end
    if type(value) ~= "table"
      or type(value.path) ~= "string"
      or type(value.lang) ~= "string"
      or type(value.defs) ~= "string"
    then
      return false
    end
  end
  for i = 1, size do
    if map[i] == nil then
      return false
    end
  end
  return true
end

M.valid_map = valid_map

--- Удалить уже испорченные файлы `*.repo_map.json` (например, с `null` внутри)
--- из `stdpath("data") .. "/avante"`, чтобы старый сбой больше никогда не всплывал.
function M.clean_disk_cache(data_dir)
  local uv = vim.uv or vim.loop
  if not uv or type(uv.fs_scandir) ~= "function" then
    return 0
  end
  local dir = data_dir or (vim.fn.stdpath("data") .. "/avante")
  local handle = uv.fs_scandir(dir)
  if not handle then
    return 0
  end
  local removed = 0
  while true do
    local name, typ = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if name:sub(-14) == ".repo_map.json" and (typ == nil or typ == "file") then
      local full = dir .. "/" .. name
      local f = io.open(full, "rb")
      if f then
        local raw = f:read("*a")
        f:close()
        local ok, decoded = pcall(vim.json.decode, raw or "")
        if not ok or not valid_map(decoded) then
          pcall(os.remove, full)
          removed = removed + 1
          M.cleaned_disk_count = M.cleaned_disk_count + 1
        end
      end
    end
  end
  return removed
end

--- Безопасная обёртка вокруг `Sidebar:show_input_hint` и `initialize_token_count`:
--- если `avante_templates` по любой причине недоступен, подсказка рисует клавишу
--- отправки без подсчёта токенов и НЕ роняет `ModeChanged` / `WinEnter`.
local function guard_sidebar()
  local ok_sb, Sidebar = pcall(require, "avante.sidebar")
  local ok_path, Path = pcall(require, "avante.path")
  if not ok_sb or type(Sidebar) ~= "table" or sidebar_wrapped == Sidebar then
    return
  end

  if type(Sidebar.initialize_token_count) == "function" then
    local orig_init = Sidebar.initialize_token_count
    Sidebar.initialize_token_count = function(self, ...)
      if ok_path and type(Path.available) == "function" then
        local ok_av, avail = pcall(Path.available)
        if not ok_av or not avail then
          self.token_count = 0
          return
        end
      end
      local ok_call = pcall(orig_init, self, ...)
      if not ok_call and self.token_count == nil then
        self.token_count = 0
      end
    end
  end

  if type(Sidebar.show_input_hint) == "function" then
    local orig_hint = Sidebar.show_input_hint
    Sidebar.show_input_hint = function(self, ...)
      if ok_path and type(Path.available) == "function" then
        local ok_av, avail = pcall(Path.available)
        if not ok_av or not avail then
          pcall(function() self:close_input_hint() end)
          return
        end
      end
      pcall(orig_hint, self, ...)
    end
  end

  sidebar_wrapped = Sidebar
end

--- Установить защиту на `avante.path.repo_map`, `avante.repo_map` и `avante.sidebar`.
function M.install(ready_fn, status_fn)
  if type(ready_fn) == "function" then
    is_ready_cb = ready_fn
  end
  if type(status_fn) == "function" then
    show_status_cb = status_fn
  end

  pcall(M.clean_disk_cache)

  local Path = require("avante.path")
  local RepoMap = require("avante.repo_map")

  if type(Path.repo_map) == "table" and path_repo_wrapped ~= Path.repo_map then
    local orig_load = Path.repo_map.load
    local orig_save = Path.repo_map.save

    if type(orig_load) == "function" then
      Path.repo_map.load = function(...)
        local ok, value = pcall(orig_load, ...)
        if ok and value == nil then
          return nil
        end
        if not ok or not valid_map(value) then
          M.invalid_cache_count = M.invalid_cache_count + 1
          return nil
        end
        return value
      end
    end

    if type(orig_save) == "function" then
      Path.repo_map.save = function(root, ext, value)
        if not valid_map(value) then
          return
        end
        return orig_save(root, ext, value)
      end
    end

    path_repo_wrapped = Path.repo_map
  end

  if type(RepoMap) == "table" and repo_map_wrapped ~= RepoMap then
    local orig_get = RepoMap.get_repo_map
    local orig_internal = RepoMap._get_repo_map
    local orig_show = RepoMap.show

    if type(orig_internal) == "function" then
      RepoMap._get_repo_map = function(...)
        if not is_ready_cb() then
          return {}
        end
        local ok, res = pcall(orig_internal, ...)
        if not ok or type(res) ~= "table" then
          return {}
        end
        return res
      end
    end

    if type(orig_get) == "function" then
      RepoMap.get_repo_map = function(...)
        if not is_ready_cb() then
          return {}
        end
        local ok, res = pcall(orig_get, ...)
        if not ok or type(res) ~= "table" then
          return {}
        end
        return res
      end
    end

    if type(orig_show) == "function" then
      RepoMap.show = function(...)
        if not is_ready_cb() then
          return show_status_cb()
        end
        return orig_show(...)
      end
    end

    repo_map_wrapped = RepoMap
  end

  pcall(guard_sidebar)
end

--- Прогреть и проверить оба нативных модуля внутри самого Avante до `avante.setup()`.
function M.native_ready()
  local Path = require("avante.path")
  local RepoMap = require("avante.repo_map")
  local ok_tpl, avail = pcall(Path.available)
  if not ok_tpl or not avail then
    return false, "avante.path не загрузил avante_templates: " .. tostring(avail)
  end
  local ok_map, lib = pcall(RepoMap._init_repo_map_lib)
  if not ok_map or type(lib) ~= "table" or type(lib.stringify_definitions) ~= "function" then
    return false, "avante.repo_map не загрузил avante_repo_map: " .. tostring(lib)
  end
  return true
end

return M
