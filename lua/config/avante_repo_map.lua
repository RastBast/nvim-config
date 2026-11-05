-- Совместимость с avante v0.4.8: при ошибке native-модуля upstream записывает
-- nil в *.repo_map.json как JSON null. Позднее json.decode возвращает vim.NIL
-- (userdata), а repo_map.lua вызывает next() и падает на каждом открытии.
local M = { invalid_cache_count = 0 }
local path_module, map_module
local is_ready, show_status

-- Корректная карта — массив записей, именно такой создаёт _build_repo_map.
-- Повреждённый/старый кеш не является пользовательским исходным кодом; его
-- безопасно игнорировать и после успешного сканирования заменить новым кешем.
local function valid_map(map)
  if type(map) ~= "table" then return false end
  local size = #map
  for key, value in pairs(map) do
    if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > size then return false end
    if type(value) ~= "table" or type(value.path) ~= "string"
      or type(value.lang) ~= "string" or type(value.defs) ~= "string" then
      return false
    end
  end
  for i = 1, size do
    if map[i] == nil then return false end
  end
  return true
end

-- Передаём callbacks отдельно: при повторном setup обёртки должны проверять
-- актуальное состояние, а не замыкание от предыдущей настройки плагина.
function M.install(ready, status)
  is_ready, show_status = ready, status
  local Path = require("avante.path")
  local RepoMap = require("avante.repo_map")
  assert(type(Path.repo_map) == "table" and type(Path.repo_map.load) == "function"
    and type(Path.repo_map.save) == "function", "неизвестный интерфейс кеша avante.repo_map")
  assert(type(RepoMap._init_repo_map_lib) == "function" and type(RepoMap._get_repo_map) == "function"
    and type(RepoMap.get_repo_map) == "function" and type(RepoMap.show) == "function",
    "неизвестный интерфейс avante.repo_map")

  if path_module ~= Path.repo_map then
    local load, save = Path.repo_map.load, Path.repo_map.save
    Path.repo_map.load = function(...)
      local ok, value = pcall(load, ...)
      if ok and value == nil then return nil end -- кеша ещё нет
      if not ok or not valid_map(value) then
        M.invalid_cache_count = M.invalid_cache_count + 1
        return nil
      end
      return value
    end
    Path.repo_map.save = function(root, ext, value)
      -- Не сохраняем JSON null после неудачного построения.
      if not valid_map(value) then return end
      return save(root, ext, value)
    end
    path_module = Path.repo_map
  end

  if map_module ~= RepoMap then
    local get_map, get_internal, show = RepoMap.get_repo_map, RepoMap._get_repo_map, RepoMap.show
    RepoMap._get_repo_map = function(...)
      if not is_ready() then return {} end
      return get_internal(...)
    end
    RepoMap.get_repo_map = function(...)
      if not is_ready() then return {} end
      return get_map(...)
    end
    RepoMap.show = function(...)
      if not is_ready() then return show_status() end
      return show(...)
    end
    map_module = RepoMap
  end
end

-- Проверяем внутренние точки входа Avante до setup: они кэшируют модули,
-- так что отсроченные ModeChanged и карта используют уже загруженный комплект.
function M.native_ready()
  local Path, RepoMap = require("avante.path"), require("avante.repo_map")
  local ok, available = pcall(Path.available)
  if not ok or not available then
    return false, "avante.path не загрузил avante_templates: " .. tostring(available)
  end
  local map_ok, lib = pcall(RepoMap._init_repo_map_lib)
  if not map_ok or type(lib) ~= "table" or type(lib.stringify_definitions) ~= "function" then
    return false, "avante.repo_map не загрузил avante_repo_map: " .. tostring(lib)
  end
  return true
end

return M
