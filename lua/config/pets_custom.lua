-- Кастомные питомцы для giusgad/pets.nvim: гофер, нян-кот, тостер, призрак, тыква.
--
-- Что делает модуль:
--   1. install_media(): симлинки assets/pets/<вид> → <lazy>/pets.nvim/media/<вид>,
--      чтобы плагин увидел наши спрайты (он читает media/ при загрузке).
--   2. register(): package.preload["pets.pets.<вид>"] — описания поведения
--      (next_actions, movements), которые плагин ждёт от require("pets.pets.<вид>").
--   3. patch_listdir(): плагин читает кадры через vim.fs.dir без сортировки,
--      поэтому кадры анимации могут идти в случайном порядке. Подменяем
--      utils.listdir на версию с натуральной сортировкой (0,1,2…,10).
--   4. menu(): выбор питомца из списка (вид · окрас) и ввод имени.
--
-- Спрайты генерирует tools/gen_pet_sprites.py (128x88, кадры 0.png, 1.png…).

local M = {}

-- Корень репозитория: .../lua/config/pets_custom.lua → ...
local this = debug.getinfo(1, "S").source:sub(2)
local repo = this:match("^(.*)/lua/config/pets_custom%.lua$") or vim.fn.stdpath("config")
M.assets_dir = repo .. "/assets/pets"

M.custom = {
  gopher = { label = "Гофер (Go)", default_name = "Харек", style = "blue" },
  nyan = { label = "Нян-кот (мем)", default_name = "Нян", style = "classic" },
  toaster = { label = "Тостер (мем)", default_name = "Тостер", style = "silver" },
  ghost = { label = "Призрак «бу» (мем)", default_name = "Бу", style = "white" },
  pumpkin = { label = "Тыква (хэллоуин)", default_name = "Тыква", style = "orange" },
}

local function plugin_media_dir()
  return vim.fn.stdpath("data") .. "/lazy/pets.nvim/media"
end

-- ---------------------------------------------------------------- media ---
function M.install_media()
  local media = plugin_media_dir()
  if vim.fn.isdirectory(media) == 0 then
    return 0 -- плагин ещё не установлен; вызовем снова из config
  end
  local linked = 0
  for name, _ in pairs(M.custom) do
    local src = M.assets_dir .. "/" .. name
    local dst = media .. "/" .. name
    if vim.uv.fs_lstat(dst) == nil and vim.fn.isdirectory(src) == 1 then
      local ok = vim.uv.fs_symlink(src, dst, { dir = true })
      if ok then
        linked = linked + 1
      end
    end
  end
  return linked
end

-- ------------------------------------------------------------- behaviour ---
local NEXT = {
  idle = { "idle", "walk", "walk_left", "run" },
  walk = { "walk", "idle", "run", "walk_left" },
  walk_left = { "walk_left", "idle", "run_left" },
  run = { "run", "walk", "idle", "run_left" },
  run_left = { "run_left", "walk_left", "idle", "run" },
}

local function behaviour()
  return {
    next_actions = vim.deepcopy(NEXT),
    idle_actions = { "idle" },
    first_action = "idle",
    movements = {
      right = { normal = { "walk" }, fast = { "run" } },
      left = { normal = { "walk_left" }, fast = { "run_left" } },
    },
  }
end

function M.register()
  for name, _ in pairs(M.custom) do
    package.preload["pets.pets." .. name] = function()
      return behaviour()
    end
  end
end

-- ---------------------------------------------------------------- listdir ---
local function natural_less(a, b)
  local na, nb = tonumber(a:match("^(%d+)")), tonumber(b:match("^(%d+)"))
  if na and nb and na ~= nb then
    return na < nb
  end
  return a < b
end

function M.patch_listdir()
  local utils = require("pets.utils")
  if utils._sorted_listdir then
    return
  end
  utils.listdir = function(path)
    local sol = {}
    for name, _ in vim.fs.dir(path) do
      table.insert(sol, name)
    end
    table.sort(sol, natural_less)
    return sol
  end
  utils._sorted_listdir = true
end

-- -------------------------------------------------------------------- menu ---
local function clean_name(s)
  s = (s or ""):gsub("%s+", "_"):gsub('[|"\\]', "")
  return s
end

function M.menu()
  local utils = require("pets.utils")
  local entries = {}
  for pet, styles in pairs(utils.available_pets) do
    for _, style in ipairs(styles) do
      table.insert(entries, { pet = pet, style = style })
    end
  end
  table.sort(entries, function(a, b)
    if a.pet ~= b.pet then
      return a.pet < b.pet
    end
    return a.style < b.style
  end)
  if #entries == 0 then
    vim.notify("Питомцы не найдены: проверьте установку pets.nvim", vim.log.levels.WARN)
    return
  end
  vim.ui.select(entries, {
    prompt = "🐾 Выберите питомца",
    format_item = function(e)
      local custom = M.custom[e.pet]
      local label = custom and custom.label or e.pet
      return label .. "  ·  " .. e.style
    end,
  }, function(choice)
    if not choice then
      return
    end
    local custom = M.custom[choice.pet]
    local default = custom and custom.default_name or "pet"
    vim.ui.input({ prompt = "Имя питомца: ", default = default }, function(name)
      name = clean_name(name)
      if name == "" then
        name = default
      end
      vim.cmd(("PetsNewCustom %s %s %s"):format(choice.pet, choice.style, name))
    end)
  end)
end

-- Вызывается из config плагина: порядок важен — медиа и listdir до require("pets").
function M.setup()
  M.install_media()
  M.register()
  M.patch_listdir()
end

-- Регистрация типов при require модуля (до загрузки плагина): только preload.
M.register()

return M
