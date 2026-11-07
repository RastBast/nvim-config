-- ========================================================================== --
--     АВТО-СКАНЕР АРХИТЕКТУРЫ И СВЯЗЕЙ ИЗ КОДОВОЙ БАЗЫ ПРОЕКТА               --
-- ========================================================================== --
-- Поддерживает Go, Lua/Neovim, TypeScript/JavaScript, Python + docker-compose.
-- Не требует внешних утилит: читает файлы через стандартный vim.uv / io.open.
local Model = require("config.architecture_model")

local M = {}

local IGNORE_DIRS = {
  [".git"] = true,
  ["node_modules"] = true,
  ["vendor"] = true,
  ["dist"] = true,
  ["build"] = true,
  ["target"] = true,
  [".venv"] = true,
  ["venv"] = true,
  ["__pycache__"] = true,
  [".next"] = true,
  ["out"] = true,
}

local MAX_FILES = 500

local function read_text(path, limit)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local data = f:read(limit or 65536)
  f:close()
  return data
end

local function list_dir(dir)
  local uv = vim.uv or vim.loop
  if not uv or type(uv.fs_scandir) ~= "function" then
    return {}
  end
  local h = uv.fs_scandir(dir)
  if not h then
    return {}
  end
  local items = {}
  while true do
    local name, typ = uv.fs_scandir_next(h)
    if not name then
      break
    end
    items[#items + 1] = { name = name, type = typ }
  end
  table.sort(items, function(a, b) return a.name < b.name end)
  return items
end

local function walk_files(root, exts)
  local found = {}
  local function step(rel)
    if #found >= MAX_FILES then
      return
    end
    local full_dir = rel == "" and root or (root .. "/" .. rel)
    for _, entry in ipairs(list_dir(full_dir)) do
      if #found >= MAX_FILES then
        return
      end
      local child_rel = rel == "" and entry.name or (rel .. "/" .. entry.name)
      local child_full = root .. "/" .. child_rel
      local typ = entry.type
      if not typ and vim.uv and vim.uv.fs_stat then
        local st = vim.uv.fs_stat(child_full)
        typ = st and st.type or nil
      end
      if typ == "directory" then
        if not IGNORE_DIRS[entry.name] and entry.name:sub(1, 1) ~= "." then
          step(child_rel)
        end
      elseif typ == "file" then
        local ext = entry.name:match("%.([%w]+)$")
        if ext and exts[ext:lower()] then
          found[#found + 1] = child_rel
        end
      end
    end
  end
  step("")
  return found
end

local function scan_go(root, doc)
  local gomod = read_text(root .. "/go.mod")
  if not gomod then
    return false
  end
  local mod_name = gomod:match("module%s+([%S]+)")
  if not mod_name then
    return false
  end
  local go_files = walk_files(root, { go = true })
  if #go_files == 0 then
    return false
  end

  local pkg_to_id = {}
  local function bucket_for_file(rel)
    local dir = rel:match("^(.*)/[^/]+$") or "."
    local a, b = dir:match("^([^/]+)/([^/]+)")
    if a == "cmd" and b then
      return "cmd/" .. b, "cmd/" .. b, "gateway", "Go cmd"
    elseif (a == "internal" or a == "pkg") and b then
      return a .. "/" .. b, a .. "/" .. b, "service", "Go package"
    elseif a and a ~= "." then
      return a, a, "service", "Go package"
    end
    return ".", vim.fn.fnamemodify(root, ":t"), "gateway", "Go root"
  end

  for _, rel in ipairs(go_files) do
    if not rel:match("_test%.go$") then
      local pkg_rel, label, kind, tech = bucket_for_file(rel)
      if not pkg_to_id[pkg_rel] then
        local node = Model.upsert_node(doc, {
          id = Model.slug(pkg_rel == "." and "app_main" or pkg_rel),
          label = label,
          kind = kind,
          path = pkg_rel == "." and rel or pkg_rel,
          tech = tech,
          summary = "Авто-найдено из Go-пакета",
        })
        pkg_to_id[pkg_rel] = node.id
      end
    end
  end

  for _, rel in ipairs(go_files) do
    if not rel:match("_test%.go$") then
      local src_pkg = bucket_for_file(rel)
      local from_id = pkg_to_id[src_pkg]
      local text = read_text(root .. "/" .. rel) or ""
      for imp in text:gmatch('"' .. vim.pesc(mod_name) .. '/([^"]+)"') do
        local a, b = imp:match("^([^/]+)/([^/]+)")
        local target_pkg = ((a == "cmd" or a == "internal" or a == "pkg") and b) and (a .. "/" .. b) or (a or imp)
        local to_id = pkg_to_id[target_pkg]
        if from_id and to_id and from_id ~= to_id then
          Model.add_edge(doc, from_id, to_id, "import", "sync")
        end
      end
    end
  end
  return true
end

local function scan_lua_nvim(root, doc)
  local has_init = read_text(root .. "/init.lua") ~= nil
  local lua_files = walk_files(root, { lua = true })
  if not has_init and #lua_files == 0 then
    return false
  end

  local mod_to_id = {}
  local file_to_id = {}

  if has_init then
    local entry = Model.upsert_node(doc, {
      id = "init_lua",
      label = "init.lua (Точка входа)",
      kind = "client",
      path = "init.lua",
      tech = "Neovim Entry",
      summary = "Загрузка окружения, команд и lazy.nvim",
    })
    file_to_id["init.lua"] = entry.id
  end

  for _, rel in ipairs(lua_files) do
    local mod = rel:match("^lua/(.+)%.lua$")
    if mod then
      local dotted = mod:gsub("/", ".")
      local top = mod:match("^([^/]+)/")
      local kind = "service"
      local tech = "Lua module"
      if top == "plugins" then
        kind = "worker"
        tech = "lazy.nvim spec"
      elseif top == "config" then
        kind = "gateway"
        tech = "core config"
      end
      local node = Model.upsert_node(doc, {
        id = Model.slug(dotted),
        label = dotted,
        kind = kind,
        path = rel,
        tech = tech,
        summary = "Lua-модуль " .. rel,
      })
      mod_to_id[dotted] = node.id
      file_to_id[rel] = node.id
    end
  end

  for rel, from_id in pairs(file_to_id) do
    local src = read_text(root .. "/" .. rel) or ""
    for req in src:gmatch('require%s*%(?%s*["\']([%w_./-]+)["\']') do
      local norm = req:gsub("/", ".")
      local to_id = mod_to_id[norm]
      if to_id and to_id ~= from_id then
        Model.add_edge(doc, from_id, to_id, "require", "sync")
      end
    end
    -- В init.lua lazy.setup("plugins") подключает все модули lua/plugins/*.lua
    if rel == "init.lua" and src:find('setup%(%s*["\']plugins["\']', 1, false) then
      for dotted, to_id in pairs(mod_to_id) do
        if dotted:match("^plugins%.") then
          Model.add_edge(doc, from_id, to_id, "lazy.nvim", "async")
        end
      end
    end
  end
  return true
end

local function scan_js_ts(root, doc)
  local files = walk_files(root, { ts = true, tsx = true, js = true, jsx = true, mjs = true })
  if #files == 0 then
    return false
  end

  local group_to_id = {}
  local function group_for(rel)
    local a, b = rel:match("^([^/]+)/([^/]+)/")
    if (a == "apps" or a == "services" or a == "packages") and b then
      local kind = (a == "apps") and "client" or (a == "services" and "service" or "worker")
      return a .. "/" .. b, a .. "/" .. b, kind, "TS/JS workspace"
    end
    local src_sub = rel:match("^src/([^/]+)/")
    if src_sub then
      local kind = (src_sub == "ui" or src_sub == "components" or src_sub == "pages" or src_sub == "app") and "client"
        or ((src_sub == "api" or src_sub == "routes" or src_sub == "controllers") and "gateway" or "service")
      return "src/" .. src_sub, "src/" .. src_sub, kind, "TS/JS module"
    end
    local top = rel:match("^([^/]+)/") or rel
    return top, top, "service", "TS/JS"
  end

  for _, rel in ipairs(files) do
    local grp, label, kind, tech = group_for(rel)
    if not group_to_id[grp] then
      local node = Model.upsert_node(doc, {
        id = Model.slug(grp),
        label = label,
        kind = kind,
        path = grp,
        tech = tech,
        summary = "JS/TS модуль " .. grp,
      })
      group_to_id[grp] = node.id
    end
  end

  for _, rel in ipairs(files) do
    local from_grp = group_for(rel)
    local from_id = group_to_id[from_grp]
    local dir = rel:match("^(.*)/[^/]+$") or ""
    local text = read_text(root .. "/" .. rel) or ""
    for spec in text:gmatch("from%s+[\"']([^\"']+)[\"']") do
      local resolved = nil
      if spec:sub(1, 2) == "@/" then
        resolved = "src/" .. spec:sub(3)
      elseif spec:sub(1, 1) == "." then
        local combined = (dir ~= "" and (dir .. "/" .. spec) or spec)
        local parts = {}
        for seg in combined:gmatch("[^/]+") do
          if seg == ".." then
            table.remove(parts)
          elseif seg ~= "." then
            parts[#parts + 1] = seg
          end
        end
        resolved = table.concat(parts, "/")
      end
      if resolved then
        local to_grp = group_for(resolved .. "/index.ts")
        local to_id = group_to_id[to_grp]
        if from_id and to_id and from_id ~= to_id then
          Model.add_edge(doc, from_id, to_id, "import", "sync")
        end
      end
    end
  end
  return true
end

local function scan_python(root, doc)
  local py_files = walk_files(root, { py = true })
  if #py_files == 0 then
    return false
  end
  -- Если это в основном тестовые скрипты поверх Lua-конфига (tests/*.py), не засоряем карту Lua
  local non_test = {}
  for _, rel in ipairs(py_files) do
    if not rel:match("^tests?/") then
      non_test[#non_test + 1] = rel
    end
  end
  if #non_test == 0 then
    return false
  end

  local pkg_to_id = {}
  local function pkg_for(rel)
    local src_pkg = rel:match("^src/([^/]+)/")
    if src_pkg then return src_pkg, "src/" .. src_pkg end
    local top = rel:match("^([^/]+)/")
    if top then return top, top end
    local stem = rel:match("^([^/]+)%.py$") or rel
    return stem, rel
  end

  for _, rel in ipairs(non_test) do
    local pkg, path_rel = pkg_for(rel)
    if not pkg_to_id[pkg] then
      local node = Model.upsert_node(doc, {
        id = Model.slug("py_" .. pkg),
        label = pkg,
        kind = (pkg == "api" or pkg == "routers" or pkg == "views") and "gateway" or "service",
        path = path_rel,
        tech = "Python",
        summary = "Python-модуль " .. path_rel,
      })
      pkg_to_id[pkg] = node.id
    end
  end

  for _, rel in ipairs(non_test) do
    local from_pkg = pkg_for(rel)
    local from_id = pkg_to_id[from_pkg]
    local text = read_text(root .. "/" .. rel) or ""
    for mod in text:gmatch("from%s+([%w_]+)[%.%s]+import") do
      local to_id = pkg_to_id[mod]
      if from_id and to_id and from_id ~= to_id then
        Model.add_edge(doc, from_id, to_id, "import", "sync")
      end
    end
  end
  return true
end

local function scan_compose(root, doc)
  local compose = read_text(root .. "/docker-compose.yml")
    or read_text(root .. "/docker-compose.yaml")
    or read_text(root .. "/compose.yml")
    or read_text(root .. "/compose.yaml")
  if not compose then
    return
  end
  local infra = {
    { pat = "postgres", id = "postgres_db", label = "PostgreSQL", kind = "db", tech = "Docker / Postgres" },
    { pat = "mysql",    id = "mysql_db",    label = "MySQL",      kind = "db", tech = "Docker / MySQL" },
    { pat = "mongo",    id = "mongodb",     label = "MongoDB",    kind = "db", tech = "Docker / Mongo" },
    { pat = "redis",    id = "redis_cache", label = "Redis",      kind = "cache", tech = "Docker / Redis" },
    { pat = "kafka",    id = "kafka_bus",   label = "Kafka",      kind = "queue", tech = "Docker / Kafka" },
    { pat = "rabbit",   id = "rabbitmq",    label = "RabbitMQ",   kind = "queue", tech = "Docker / RabbitMQ" },
    { pat = "nats",     id = "nats_bus",    label = "NATS",       kind = "queue", tech = "Docker / NATS" },
    { pat = "nginx",    id = "nginx_proxy", label = "Nginx Proxy",kind = "gateway", tech = "Docker / Nginx" },
  }
  local lower = compose:lower()
  for _, item in ipairs(infra) do
    if lower:find(item.pat, 1, true) then
      Model.upsert_node(doc, {
        id = item.id,
        label = item.label,
        kind = item.kind,
        path = "docker-compose.yml",
        tech = item.tech,
        summary = "Найдено в docker-compose",
      })
    end
  end
end

function M.scan_project(root)
  local target_root = root or Model.project_root()
  local project_name = vim.fn.fnamemodify(target_root, ":t")
  local doc = {
    version = 1,
    title = "Архитектура " .. (project_name ~= "" and project_name or "проекта"),
    direction = "LR",
    nodes = {},
    edges = {},
  }

  scan_go(target_root, doc)
  scan_lua_nvim(target_root, doc)
  scan_js_ts(target_root, doc)
  scan_python(target_root, doc)
  scan_compose(target_root, doc)

  if #doc.nodes == 0 then
    doc = Model.default_doc(doc.title)
  else
    Model.auto_layout(doc)
  end

  return Model.normalize(doc)
end

return M
