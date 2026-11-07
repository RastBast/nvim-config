-- ========================================================================== --
--   УМНЫЙ СКАНЕР АРХИТЕКТУРЫ: КОД + C4-УРОВНИ + .proto + OpenAPI + SQL + LSP --
-- ========================================================================== --
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

local MAX_FILES = 600

local function read_text(path, limit)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local data = f:read(limit or 98304)
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

local function extract_http_routes(src)
  local routes = {}
  -- Go Chi/Gin/Echo/Fiber/net/http: r.Get("/orders", ...), mux.HandleFunc("POST /orders", ...)
  for method, path in src:gmatch('[%.%:]%s*([GgEeTtPpOoSsUuDdLlAaCcHh]+)%s*%(%s*["\'](/[^"\']*)["\']') do
    local m = method:upper()
    if m == "GET" or m == "POST" or m == "PUT" or m == "DELETE" or m == "PATCH" then
      routes[#routes + 1] = m .. " " .. path
    end
  end
  for pattern in src:gmatch('HandleFunc%s*%(%s*["\']([^"\']+)["\']') do
    routes[#routes + 1] = pattern:match("^%u+%s+/") and pattern or ("HTTP " .. pattern)
  end
  -- Python FastAPI / Flask: @router.post("/v1/pay")
  for method, path in src:gmatch('@[%w_]+%.([%a]+)%s*%(%s*["\'](/[^"\']*)["\']') do
    local m = method:upper()
    if m == "GET" or m == "POST" or m == "PUT" or m == "DELETE" or m == "PATCH" then
      routes[#routes + 1] = m .. " " .. path
    end
  end
  return routes
end

local function scan_go(root, doc, code_blobs)
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
  local pkg_files = {}
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
      pkg_files[pkg_rel] = pkg_files[pkg_rel] or {}
      pkg_files[pkg_rel][#pkg_files[pkg_rel] + 1] = rel
      if not pkg_to_id[pkg_rel] then
        local node = Model.upsert_node(doc, {
          id = Model.slug(pkg_rel == "." and "app_main" or pkg_rel),
          label = label,
          kind = kind,
          parent_id = "",
          path = pkg_rel == "." and rel or pkg_rel,
          tech = tech,
          summary = "Go-пакет " .. pkg_rel,
        })
        pkg_to_id[pkg_rel] = node.id
      end
    end
  end

  -- Вложенный C4-уровень (файлы и экспортируемые типы/сервисы внутри пакета)
  for pkg_rel, files in pairs(pkg_files) do
    local parent_id = pkg_to_id[pkg_rel]
    if parent_id and #files > 1 then
      for _, rel in ipairs(files) do
        local fname = rel:match("([^/]+)$") or rel
        Model.upsert_node(doc, {
          id = Model.slug(parent_id .. "_" .. fname:gsub("%.go$", "")),
          label = fname,
          kind = "worker",
          parent_id = parent_id,
          path = rel,
          tech = "Go file",
          summary = "Файл пакета " .. pkg_rel,
        })
      end
    end
  end

  for _, rel in ipairs(go_files) do
    if not rel:match("_test%.go$") then
      local src_pkg = bucket_for_file(rel)
      local from_id = pkg_to_id[src_pkg]
      local text = read_text(root .. "/" .. rel) or ""
      if from_id then
        code_blobs[#code_blobs + 1] = { node_id = from_id, text = text }
        for _, route in ipairs(extract_http_routes(text)) do
          Model.add_contract(doc, from_id, route)
        end
      end
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

  local use_c4_containers = (#lua_files > 10)
  local container_ids = {}
  local mod_to_id = {}
  local file_to_id = {}

  if has_init then
    local entry = Model.upsert_node(doc, {
      id = "init_lua",
      label = "init.lua (Точка входа)",
      kind = "client",
      parent_id = "",
      path = "init.lua",
      tech = "Neovim Entry",
      summary = "Загрузка окружения, команд и lazy.nvim",
    })
    file_to_id["init.lua"] = entry.id
  end

  local group_meta = {
    config  = { label = "lua/config (Ядро и фичи)",   kind = "gateway", tech = "Core Lua" },
    plugins = { label = "lua/plugins (Спеки lazy)",    kind = "service", tech = "lazy.nvim" },
    games   = { label = "lua/games (Встроенные игры)", kind = "worker",  tech = "Lua Games" },
  }

  for _, rel in ipairs(lua_files) do
    local mod = rel:match("^lua/(.+)%.lua$")
    if mod then
      local dotted = mod:gsub("/", ".")
      local top = mod:match("^([^/]+)/") or "misc"
      local parent_id = ""
      if use_c4_containers then
        if not container_ids[top] then
          local gm = group_meta[top] or { label = "lua/" .. top, kind = "service", tech = "Lua group" }
          local cnode = Model.upsert_node(doc, {
            id = Model.slug("c4_lua_" .. top),
            label = gm.label,
            kind = gm.kind,
            parent_id = "",
            path = "lua/" .. top,
            tech = gm.tech,
            summary = "C4-контейнер модулей lua/" .. top,
          })
          container_ids[top] = cnode.id
        end
        parent_id = container_ids[top]
      end

      local kind = (top == "config") and "gateway" or ((top == "plugins") and "worker" or "service")
      local node = Model.upsert_node(doc, {
        id = Model.slug(dotted),
        label = dotted,
        kind = kind,
        parent_id = parent_id,
        path = rel,
        tech = "Lua module",
        summary = "Lua-модуль " .. rel,
      })
      mod_to_id[dotted] = node.id
      file_to_id[rel] = node.id
    end
  end

  for rel, from_id in pairs(file_to_id) do
    local src = read_text(root .. "/" .. rel) or ""
    -- Собираем зарегистрированные команды :UserCmd как контракты модуля
    for cmd_name in src:gmatch('nvim_create_user_command%(%s*["\']([%w_]+)["\']') do
      Model.add_contract(doc, from_id, ":" .. cmd_name)
    end
    for req in src:gmatch('require%s*%(?%s*["\']([%w_./-]+)["\']') do
      local norm = req:gsub("/", ".")
      local to_id = mod_to_id[norm]
      if to_id and to_id ~= from_id then
        Model.add_edge(doc, from_id, to_id, "require", "sync")
      end
    end
    if rel == "init.lua" and src:find('setup%(%s*["\']plugins["\']', 1, false) then
      if container_ids.plugins then
        Model.add_edge(doc, from_id, container_ids.plugins, "lazy.setup", "async")
      else
        for dotted, to_id in pairs(mod_to_id) do
          if dotted:match("^plugins%.") then
            Model.add_edge(doc, from_id, to_id, "lazy.nvim", "async")
          end
        end
      end
    end
  end
  return true
end

local function scan_js_ts(root, doc, code_blobs)
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
        parent_id = "",
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
    if from_id then
      code_blobs[#code_blobs + 1] = { node_id = from_id, text = text }
      for _, route in ipairs(extract_http_routes(text)) do
        Model.add_contract(doc, from_id, route)
      end
    end
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

local function scan_python(root, doc, code_blobs)
  local py_files = walk_files(root, { py = true })
  if #py_files == 0 then
    return false
  end
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
        parent_id = "",
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
    if from_id then
      code_blobs[#code_blobs + 1] = { node_id = from_id, text = text }
      for _, route in ipairs(extract_http_routes(text)) do
        Model.add_contract(doc, from_id, route)
      end
    end
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
    return nil
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
  local primary_db_id = nil
  for _, item in ipairs(infra) do
    if lower:find(item.pat, 1, true) then
      local n = Model.upsert_node(doc, {
        id = item.id,
        label = item.label,
        kind = item.kind,
        parent_id = "",
        path = "docker-compose.yml",
        tech = item.tech,
        summary = "Инфраструктура из docker-compose",
      })
      if item.kind == "db" and not primary_db_id then
        primary_db_id = n.id
      end
    end
  end
  return primary_db_id
end

--- Разбор Protobuf (.proto): gRPC сервисы, RPC-методы, дочерние C4-ручки и связи с кодом.
local function scan_proto(root, doc, code_blobs)
  local proto_files = walk_files(root, { proto = true })
  if #proto_files == 0 then
    return
  end
  for _, rel in ipairs(proto_files) do
    local src = read_text(root .. "/" .. rel) or ""
    local pkg = src:match("package%s+([%w_.]+)%s*;") or ""
    for svc_name, svc_body in src:gmatch("service%s+([%w_]+)%s*(%b{})") do
      local svc_node = Model.upsert_node(doc, {
        id = Model.slug("grpc_" .. svc_name),
        label = svc_name .. " (gRPC)",
        kind = "gateway",
        parent_id = "",
        path = rel,
        tech = pkg ~= "" and ("Protobuf · " .. pkg) or "Protobuf / gRPC",
        summary = "gRPC-контракт из " .. rel,
      })
      local methods = {}
      for rpc_name, req_t, resp_t in svc_body:gmatch("rpc%s+([%w_]+)%s*%(%s*([%w_.]+)%s*%)%s*returns%s*%(%s*([%w_.]+)%s*%)") do
        local sig = ("rpc %s(%s) → %s"):format(rpc_name, req_t, resp_t)
        Model.add_contract(doc, svc_node.id, sig)
        methods[#methods + 1] = rpc_name
        Model.upsert_node(doc, {
          id = Model.slug(svc_node.id .. "_" .. rpc_name),
          label = "rpc " .. rpc_name,
          kind = "service",
          parent_id = svc_node.id,
          path = rel,
          tech = req_t .. " → " .. resp_t,
          summary = "gRPC метод сервиса " .. svc_name,
        })
      end
      -- Связываем модули кода, которые вызывают или реализуют этот gRPC-сервис
      for _, blob in ipairs(code_blobs) do
        if blob.node_id ~= svc_node.id then
          local matched_rpc = nil
          for _, mname in ipairs(methods) do
            if blob.text:find(mname, 1, true) and (blob.text:find(svc_name, 1, true) or blob.text:find("pb%.", 1, false)) then
              matched_rpc = mname
              break
            end
          end
          if matched_rpc or blob.text:find(svc_name .. "Client", 1, true) or blob.text:find(svc_name .. "Server", 1, true) then
            local lbl = matched_rpc and ("gRPC: " .. matched_rpc) or ("gRPC: " .. svc_name)
            Model.add_edge(doc, blob.node_id, svc_node.id, lbl, "sync")
          end
        end
      end
    end
  end
end

--- Разбор OpenAPI / Swagger спецификаций (YAML / JSON).
local function scan_openapi(root, doc)
  local candidates = {
    "openapi.yaml", "openapi.yml", "openapi.json",
    "swagger.yaml", "swagger.yml", "swagger.json",
    "api/openapi.yaml", "api/openapi.yml", "docs/openapi.yaml",
  }
  for _, rel in ipairs(candidates) do
    local raw = read_text(root .. "/" .. rel)
    if raw then
      local gw = Model.upsert_node(doc, {
        id = "openapi_gateway",
        label = "REST API (OpenAPI)",
        kind = "gateway",
        parent_id = "",
        path = rel,
        tech = "OpenAPI / REST",
        summary = "Спецификация API " .. rel,
      })
      -- YAML пути вида `  /v1/orders:` или JSON `"/v1/orders": {`
      for path in raw:gmatch("[\r\n]%s*[\"']?(/[a-zA-Z0-9_/{}-]+)[\"']?%s*:") do
        Model.add_contract(doc, gw.id, "PATH " .. path)
      end
    end
  end
end

--- Разбор SQL-миграций (*.sql): таблицы как C4-дети внутри БД, внешние ключи REFERENCES
--- и автоматические стрелки `SQL: <table>` от сервисов, упоминающих таблицы в запросах!
local function scan_sql(root, doc, primary_db_id, code_blobs)
  local sql_files = walk_files(root, { sql = true })
  if #sql_files == 0 then
    return
  end

  local db_id = primary_db_id
  if not db_id then
    local db_node = Model.upsert_node(doc, {
      id = "sql_database",
      label = "SQL База данных",
      kind = "db",
      parent_id = "",
      path = sql_files[1],
      tech = "SQL Schema",
      summary = "Таблицы и миграции БД",
    })
    db_id = db_node.id
  end

  local table_to_node = {}
  local table_refs = {}

  for _, rel in ipairs(sql_files) do
    local raw = read_text(root .. "/" .. rel) or ""
    local cleaned = raw
      :gsub("%-%-[^\r\n]*", "")
      :gsub("([Tt][Aa][Bb][Ll][Ee])%s+[Ii][Ff]%s+[Nn][Oo][Tt]%s+[Ee][Xx][Ii][Ss][Tt][Ss]%s+", "%1 ")
    for tbl_name, body in cleaned:gmatch("[Cc][Rr][Ee][Aa][Tt][Ee]%s+[Tt][Aa][Bb][Ll][Ee]%s+[\"`%[]?([%w_%.]+)[\"`%]]?%s*(%b())") do
      local short_tbl = tbl_name:match("%.([%w_]+)$") or tbl_name
      Model.add_contract(doc, db_id, "TABLE " .. short_tbl)
      local tnode = Model.upsert_node(doc, {
        id = Model.slug("tbl_" .. short_tbl),
        label = "table " .. short_tbl,
        kind = "db",
        parent_id = db_id,
        path = rel,
        tech = "SQL Table",
        summary = "Таблица из " .. rel,
      })
      table_to_node[short_tbl:lower()] = { id = tnode.id, name = short_tbl }
      for ref_tbl in body:gmatch("[Rr][Ee][Ff][Ee][Rr][Ee][Nn][Cc][Ee][Ss]%s+[\"`%[]?([%w_%.]+)[\"`%]]?") do
        local short_ref = (ref_tbl:match("%.([%w_]+)$") or ref_tbl):lower()
        table_refs[#table_refs + 1] = { from = short_tbl:lower(), to = short_ref }
      end
    end
  end

  -- Связи внешних ключей (FK) между таблицами внутри C4-контейнера БД
  for _, fk in ipairs(table_refs) do
    local src = table_to_node[fk.from]
    local dst = table_to_node[fk.to]
    if src and dst and src.id ~= dst.id then
      Model.add_edge(doc, src.id, dst.id, "FK", "data")
    end
  end

  -- Автоматически связываем сервисы с таблицами, которые они читают/пишут в SQL-запросах!
  for _, blob in ipairs(code_blobs) do
    local lower_code = blob.text:lower()
    for tbl_key, tbl_info in pairs(table_to_node) do
      if lower_code:match("from%s+" .. vim.pesc(tbl_key) .. "[%s%(;\"'`]")
        or lower_code:match("into%s+" .. vim.pesc(tbl_key) .. "[%s%(;\"'`]")
        or lower_code:match("update%s+" .. vim.pesc(tbl_key) .. "%s+")
      then
        Model.add_edge(doc, blob.node_id, tbl_info.id, "SQL: " .. tbl_info.name, "data")
      end
    end
  end
end

function M.scan_project(root)
  local target_root = root or Model.project_root()
  local project_name = vim.fn.fnamemodify(target_root, ":t")
  local doc = {
    version = 2,
    title = "Архитектура " .. (project_name ~= "" and project_name or "проекта"),
    direction = "LR",
    nodes = {},
    edges = {},
  }
  local code_blobs = {}

  scan_go(target_root, doc, code_blobs)
  scan_lua_nvim(target_root, doc)
  scan_js_ts(target_root, doc, code_blobs)
  scan_python(target_root, doc, code_blobs)
  local primary_db_id = scan_compose(target_root, doc)
  scan_proto(target_root, doc, code_blobs)
  scan_openapi(target_root, doc)
  scan_sql(target_root, doc, primary_db_id, code_blobs)

  if #doc.nodes == 0 then
    doc = Model.default_doc(doc.title)
  else
    Model.auto_layout(doc)
  end

  return Model.normalize(doc)
end

--- Живое обогащение контрактов из подключённых LSP-клиентов Neovim (gopls, lua_ls, vtsls, pyright).
function M.enrich_from_lsp(doc, root, on_done)
  if not (vim.lsp and type(vim.lsp.get_clients) == "function") then
    if on_done then on_done(doc, 0, "vim.lsp недоступен") end
    return
  end
  local clients = vim.lsp.get_clients()
  if not clients or #clients == 0 then
    if on_done then on_done(doc, 0, "нет активных LSP-серверов в открытых буферах") end
    return
  end

  local target_root = root or Model.project_root()
  local pending = 0
  local added = 0

  for _, client in ipairs(clients) do
    if type(client.request) == "function" then
      pending = pending + 1
      client:request("workspace/symbol", { query = "" }, function(err, result)
        if not err and type(result) == "table" then
          for _, sym in ipairs(result) do
            local name = type(sym) == "table" and sym.name or nil
            local uri = type(sym) == "table"
              and ((sym.location and sym.location.uri) or sym.uri)
              or nil
            if type(name) == "string" and type(uri) == "string" and vim.uri_to_fname then
              local ok_f, fname = pcall(vim.uri_to_fname, uri)
              if ok_f and type(fname) == "string" and fname:sub(1, #target_root) == target_root then
                local rel = fname:sub(#target_root + 2)
                for _, node in ipairs(doc.nodes or {}) do
                  if node.path and node.path ~= "" and (rel == node.path or rel:sub(1, #node.path + 1) == (node.path .. "/")) then
                    if # (node.contracts or {}) < 15 then
                      Model.add_contract(doc, node.id, "sym " .. name)
                      added = added + 1
                    end
                    break
                  end
                end
              end
            end
          end
        end
        pending = pending - 1
        if pending == 0 and on_done then
          vim.schedule(function() on_done(doc, added, nil) end)
        end
      end, 0)
    end
  end

  if pending == 0 and on_done then
    on_done(doc, 0, "LSP-клиенты не поддержали workspace/symbol")
  end
end

return M
