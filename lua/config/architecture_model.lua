-- ========================================================================== --
--     МОДЕЛЬ АРХИТЕКТУРЫ ПРИЛОЖЕНИЯ И СВЯЗЕЙ (architecture.json + Mermaid)   --
-- ========================================================================== --
local M = {}

M.KINDS = {
  { id = "client",   label = "Клиент / UI",        icon = "🖥️", tier = 1 },
  { id = "gateway",  label = "API / Шлюз",         icon = "🚪", tier = 2 },
  { id = "service",  label = "Сервис / Модуль",    icon = "⚙️", tier = 3 },
  { id = "worker",   label = "Воркер / Джоба",     icon = "🔄", tier = 3 },
  { id = "queue",    label = "Очередь / Шина",     icon = "📨", tier = 4 },
  { id = "cache",    label = "Кеш / In-Memory",    icon = "⚡", tier = 4 },
  { id = "db",       label = "База данных",        icon = "🗄️", tier = 4 },
  { id = "external", label = "Внешний API",        icon = "🌐", tier = 4 },
}

M.EDGE_KINDS = {
  { id = "sync",  label = "Синхронный вызов (HTTP / gRPC / require)", arrow = "──▶", mmd = "-->" },
  { id = "async", label = "Асинхронное событие (очередь / pub-sub)",  arrow = "╌╌▶", mmd = "-.->" },
  { id = "data",  label = "Чтение / запись данных (SQL / KV)",        arrow = "══▶", mmd = "==>" },
}

local kind_by_id = {}
for _, item in ipairs(M.KINDS) do
  kind_by_id[item.id] = item
end

local edge_kind_by_id = {}
for _, item in ipairs(M.EDGE_KINDS) do
  edge_kind_by_id[item.id] = item
end

function M.kind_meta(kind)
  return kind_by_id[kind or "service"] or kind_by_id.service
end

function M.edge_meta(kind)
  return edge_kind_by_id[kind or "sync"] or edge_kind_by_id.sync
end

function M.slug(raw)
  local s = tostring(raw or ""):lower()
  s = s:gsub("[^%w_]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if s == "" then
    s = "node"
  end
  if s:match("^%d") then
    s = "n_" .. s
  end
  return s
end

function M.auto_layout(doc)
  if type(doc) ~= "table" or type(doc.nodes) ~= "table" then
    return doc
  end
  local buckets = { [1] = {}, [2] = {}, [3] = {}, [4] = {} }
  for _, node in ipairs(doc.nodes) do
    local tier = M.kind_meta(node.kind).tier or 3
    buckets[tier] = buckets[tier] or {}
    buckets[tier][#buckets[tier] + 1] = node
  end
  local tier_x = { [1] = 80, [2] = 360, [3] = 650, [4] = 960 }
  for tier = 1, 4 do
    local list = buckets[tier] or {}
    for idx, node in ipairs(list) do
      node.x = tier_x[tier]
      node.y = 80 + (idx - 1) * 130
    end
  end
  return doc
end

function M.default_doc(title)
  return {
    version = 1,
    title = (type(title) == "string" and title ~= "") and title or "Архитектура приложения",
    direction = "LR",
    nodes = {
      {
        id = "web_client",
        label = "Клиент (Web / CLI)",
        kind = "client",
        x = 80,
        y = 160,
        path = "",
        tech = "UI / Frontend",
        summary = "Точка входа пользователя",
      },
      {
        id = "api_gateway",
        label = "API / Входной слой",
        kind = "gateway",
        x = 360,
        y = 160,
        path = "",
        tech = "HTTP / gRPC",
        summary = "Маршрутизация, авторизация, валидация",
      },
      {
        id = "core_service",
        label = "Бизнес-логика",
        kind = "service",
        x = 650,
        y = 100,
        path = "",
        tech = "Core Domain",
        summary = "Основные сценарии приложения",
      },
      {
        id = "event_bus",
        label = "Шина событий",
        kind = "queue",
        x = 960,
        y = 80,
        path = "",
        tech = "Queue / Events",
        summary = "Фоновые задачи и интеграции",
      },
      {
        id = "primary_db",
        label = "Основная БД",
        kind = "db",
        x = 960,
        y = 230,
        path = "",
        tech = "PostgreSQL / Storage",
        summary = "Долговременное хранение данных",
      },
    },
    edges = {
      { from = "web_client",   to = "api_gateway",  label = "HTTPS / JSON", kind = "sync" },
      { from = "api_gateway",  to = "core_service", label = "RPC / Call",   kind = "sync" },
      { from = "core_service", to = "primary_db",   label = "SQL",          kind = "data" },
      { from = "core_service", to = "event_bus",    label = "DomainEvent",  kind = "async" },
    },
  }
end

function M.normalize(raw)
  local base = M.default_doc(type(raw) == "table" and raw.title or nil)
  if type(raw) ~= "table" then
    return base
  end
  local dir = tostring(raw.direction or "LR"):upper()
  if dir ~= "LR" and dir ~= "TD" and dir ~= "TB" and dir ~= "RL" then
    dir = "LR"
  end

  local doc = {
    version = 1,
    title = (type(raw.title) == "string" and vim.trim(raw.title) ~= "") and vim.trim(raw.title) or base.title,
    direction = dir,
    nodes = {},
    edges = {},
  }

  local seen_ids = {}
  if type(raw.nodes) == "table" then
    for idx, n in ipairs(raw.nodes) do
      if type(n) == "table" then
        local base_id = M.slug(n.id or n.label or ("node_" .. idx))
        local id = base_id
        local suffix = 2
        while seen_ids[id] do
          id = base_id .. "_" .. suffix
          suffix = suffix + 1
        end
        seen_ids[id] = true
        local kind = kind_by_id[n.kind] and n.kind or "service"
        local tier = M.kind_meta(kind).tier
        doc.nodes[#doc.nodes + 1] = {
          id = id,
          label = (type(n.label) == "string" and vim.trim(n.label) ~= "") and vim.trim(n.label) or id,
          kind = kind,
          x = tonumber(n.x) or (80 + (tier - 1) * 280),
          y = tonumber(n.y) or (80 + ((idx - 1) % 6) * 125),
          path = type(n.path) == "string" and vim.trim(n.path) or "",
          tech = type(n.tech) == "string" and vim.trim(n.tech) or "",
          summary = type(n.summary) == "string" and vim.trim(n.summary) or "",
        }
      end
    end
  end

  local seen_edges = {}
  if type(raw.edges) == "table" then
    for _, e in ipairs(raw.edges) do
      if type(e) == "table" then
        local from = M.slug(e.from or "")
        local to = M.slug(e.to or "")
        if seen_ids[from] and seen_ids[to] and from ~= to then
          local label = type(e.label) == "string" and vim.trim(e.label) or ""
          local ekind = edge_kind_by_id[e.kind] and e.kind or "sync"
          local key = from .. "->" .. to .. ":" .. label .. ":" .. ekind
          if not seen_edges[key] then
            seen_edges[key] = true
            doc.edges[#doc.edges + 1] = {
              from = from,
              to = to,
              label = label,
              kind = ekind,
            }
          end
        end
      end
    end
  end

  return doc
end

function M.find_node(doc, id)
  for idx, node in ipairs(doc.nodes or {}) do
    if node.id == id then
      return node, idx
    end
  end
  return nil, nil
end

function M.upsert_node(doc, spec)
  local id = M.slug(spec.id or spec.label)
  local existing = M.find_node(doc, id)
  local kind = kind_by_id[spec.kind] and spec.kind or (existing and existing.kind) or "service"
  if existing then
    if spec.label and vim.trim(spec.label) ~= "" then existing.label = vim.trim(spec.label) end
    existing.kind = kind
    if spec.x ~= nil then existing.x = tonumber(spec.x) or existing.x end
    if spec.y ~= nil then existing.y = tonumber(spec.y) or existing.y end
    if spec.path ~= nil then existing.path = vim.trim(tostring(spec.path)) end
    if spec.tech ~= nil then existing.tech = vim.trim(tostring(spec.tech)) end
    if spec.summary ~= nil then existing.summary = vim.trim(tostring(spec.summary)) end
    return existing
  end
  local tier = M.kind_meta(kind).tier
  local node = {
    id = id,
    label = (spec.label and vim.trim(spec.label) ~= "") and vim.trim(spec.label) or id,
    kind = kind,
    x = tonumber(spec.x) or (80 + (tier - 1) * 280),
    y = tonumber(spec.y) or (80 + (#doc.nodes % 6) * 125),
    path = spec.path and vim.trim(tostring(spec.path)) or "",
    tech = spec.tech and vim.trim(tostring(spec.tech)) or "",
    summary = spec.summary and vim.trim(tostring(spec.summary)) or "",
  }
  doc.nodes[#doc.nodes + 1] = node
  return node
end

function M.remove_node(doc, id)
  local _, idx = M.find_node(doc, id)
  if not idx then
    return false
  end
  table.remove(doc.nodes, idx)
  local kept = {}
  for _, e in ipairs(doc.edges or {}) do
    if e.from ~= id and e.to ~= id then
      kept[#kept + 1] = e
    end
  end
  doc.edges = kept
  return true
end

function M.add_edge(doc, from, to, label, kind)
  from = M.slug(from)
  to = M.slug(to)
  if from == to or not M.find_node(doc, from) or not M.find_node(doc, to) then
    return false, "оба компонента должны существовать и различаться"
  end
  local clean_label = vim.trim(tostring(label or ""))
  local ekind = edge_kind_by_id[kind] and kind or "sync"
  for _, e in ipairs(doc.edges) do
    if e.from == from and e.to == to and e.label == clean_label then
      e.kind = ekind
      return true
    end
  end
  doc.edges[#doc.edges + 1] = {
    from = from,
    to = to,
    label = clean_label,
    kind = ekind,
  }
  return true
end

function M.remove_edge(doc, index)
  if type(index) ~= "number" or not doc.edges[index] then
    return false
  end
  table.remove(doc.edges, index)
  return true
end

function M.neighbors(doc, node_id)
  local incoming, outgoing = {}, {}
  for idx, e in ipairs(doc.edges or {}) do
    if e.to == node_id then
      incoming[#incoming + 1] = { index = idx, edge = e, peer = M.find_node(doc, e.from) }
    end
    if e.from == node_id then
      outgoing[#outgoing + 1] = { index = idx, edge = e, peer = M.find_node(doc, e.to) }
    end
  end
  return incoming, outgoing
end

local function escape_mermaid(text)
  return tostring(text or "")
    :gsub('"', "'")
    :gsub("[\r\n]+", " ")
    :gsub("[%[%]%(%){}|<>]", " ")
    :gsub("%s+", " ")
end

local function mermaid_shape(node)
  local meta = M.kind_meta(node.kind)
  local title = meta.icon .. " " .. escape_mermaid(node.label)
  if node.tech and node.tech ~= "" then
    title = title .. " · " .. escape_mermaid(node.tech)
  end
  local k = node.kind
  if k == "client" then
    return ('%s(["%s"])'):format(node.id, title)
  elseif k == "gateway" then
    return ('%s{{"%s"}}'):format(node.id, title)
  elseif k == "db" or k == "cache" then
    return ('%s[("%s")]'):format(node.id, title)
  elseif k == "queue" then
    return ('%s>"%s"]'):format(node.id, title)
  elseif k == "external" then
    return ('%s[["%s"]]'):format(node.id, title)
  end
  return ('%s["%s"]'):format(node.id, title)
end

function M.to_mermaid(doc)
  doc = M.normalize(doc)
  local lines = {
    "%% Сгенерировано из architecture.json (" .. doc.title .. ")",
    "flowchart " .. (doc.direction or "LR"),
  }
  for _, node in ipairs(doc.nodes) do
    lines[#lines + 1] = "  " .. mermaid_shape(node)
  end
  if #doc.edges > 0 then
    lines[#lines + 1] = ""
  end
  for _, edge in ipairs(doc.edges) do
    local em = M.edge_meta(edge.kind)
    local lbl = escape_mermaid(edge.label)
    if lbl ~= "" then
      if em.id == "async" then
        lines[#lines + 1] = ('  %s -. "%s" .-> %s'):format(edge.from, lbl, edge.to)
      elseif em.id == "data" then
        lines[#lines + 1] = ('  %s == "%s" ==> %s'):format(edge.from, lbl, edge.to)
      else
        lines[#lines + 1] = ('  %s -- "%s" --> %s'):format(edge.from, lbl, edge.to)
      end
    else
      lines[#lines + 1] = ("  %s %s %s"):format(edge.from, em.mmd, edge.to)
    end
  end

  -- Цветовые классы по ролям компонентов
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  classDef client fill:#1e3a5f,stroke:#60a5fa,color:#f8fafc;"
  lines[#lines + 1] = "  classDef gateway fill:#3b2f63,stroke:#a78bfa,color:#f8fafc;"
  lines[#lines + 1] = "  classDef service fill:#1f3d33,stroke:#34d399,color:#f8fafc;"
  lines[#lines + 1] = "  classDef worker fill:#1f3d33,stroke:#2dd4bf,color:#f8fafc;"
  lines[#lines + 1] = "  classDef queue fill:#4a2c1d,stroke:#fb923c,color:#f8fafc;"
  lines[#lines + 1] = "  classDef cache fill:#4a3718,stroke:#facc15,color:#f8fafc;"
  lines[#lines + 1] = "  classDef db fill:#3f1d2e,stroke:#f472b6,color:#f8fafc;"
  lines[#lines + 1] = "  classDef external fill:#334155,stroke:#94a3b8,color:#f8fafc;"
  for _, node in ipairs(doc.nodes) do
    lines[#lines + 1] = ("  class %s %s;"):format(node.id, node.kind or "service")
  end
  return table.concat(lines, "\n") .. "\n"
end

function M.to_markdown(doc)
  doc = M.normalize(doc)
  local lines = {
    "# 🏗️ " .. doc.title,
    "",
    "## Визуальная диаграмма связей",
    "",
    "```mermaid",
  }
  local mmd = vim.trim(M.to_mermaid(doc))
  for line in (mmd .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end
  lines[#lines + 1] = "```"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "## Каталог компонентов (" .. #doc.nodes .. ")"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "| Компонент | Роль | Технология | Путь в коде | Описание |"
  lines[#lines + 1] = "| --- | --- | --- | --- | --- |"
  for _, n in ipairs(doc.nodes) do
    local km = M.kind_meta(n.kind)
    lines[#lines + 1] = ("| `%s` (%s) | %s %s | %s | %s | %s |"):format(
      n.id,
      n.label,
      km.icon,
      km.label,
      n.tech ~= "" and n.tech or "—",
      n.path ~= "" and ("`" .. n.path .. "`") or "—",
      n.summary ~= "" and n.summary or "—"
    )
  end
  return table.concat(lines, "\n") .. "\n"
end

function M.project_root(bufnr)
  local target = bufnr or 0
  if vim.fs and type(vim.fs.root) == "function" then
    local ok, found = pcall(vim.fs.root, target, { "architecture.json", ".git", "go.mod", "package.json", "pyproject.toml", "Cargo.toml" })
    if ok and type(found) == "string" and found ~= "" then
      return found
    end
  end
  return vim.fn.getcwd()
end

function M.default_paths(root)
  local base = root or M.project_root()
  return {
    root = base,
    json = base .. "/architecture.json",
    mermaid = base .. "/docs/architecture.mmd",
    markdown = base .. "/docs/architecture.md",
  }
end

function M.load_file(path)
  local f = io.open(path, "rb")
  if not f then
    return nil, "файл не найден: " .. tostring(path)
  end
  local content = f:read("*a")
  f:close()
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    return nil, "некорректный JSON в " .. tostring(path)
  end
  return M.normalize(decoded)
end

local function write_text(path, content)
  local dir = vim.fn.fnamemodify(path, ":h")
  if dir and dir ~= "" and vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  local f, err = io.open(path, "wb")
  if not f then
    return false, tostring(err)
  end
  f:write(content)
  f:close()
  return true
end

local function json_escape(str)
  return tostring(str or "")
    :gsub("\\", "\\\\")
    :gsub('"', '\\"')
    :gsub("\n", "\\n")
    :gsub("\r", "\\r")
    :gsub("\t", "\\t")
end

--- Читаемое форматирование JSON (чтобы architecture.json было удобно смотреть в git diff).
function M.encode_pretty(doc)
  doc = M.normalize(doc)
  local out = {
    "{",
    ('  "version": %d,'):format(doc.version or 1),
    ('  "title": "%s",'):format(json_escape(doc.title)),
    ('  "direction": "%s",'):format(json_escape(doc.direction)),
    '  "nodes": [',
  }
  for i, n in ipairs(doc.nodes) do
    local comma = (i < #doc.nodes) and "," or ""
    out[#out + 1] = ("    { \"id\": \"%s\", \"label\": \"%s\", \"kind\": \"%s\", \"x\": %d, \"y\": %d, \"path\": \"%s\", \"tech\": \"%s\", \"summary\": \"%s\" }%s"):format(
      json_escape(n.id),
      json_escape(n.label),
      json_escape(n.kind),
      math.floor(tonumber(n.x) or 0),
      math.floor(tonumber(n.y) or 0),
      json_escape(n.path),
      json_escape(n.tech),
      json_escape(n.summary),
      comma
    )
  end
  out[#out + 1] = "  ],"
  out[#out + 1] = '  "edges": ['
  for i, e in ipairs(doc.edges) do
    local comma = (i < #doc.edges) and "," or ""
    out[#out + 1] = ("    { \"from\": \"%s\", \"to\": \"%s\", \"label\": \"%s\", \"kind\": \"%s\" }%s"):format(
      json_escape(e.from),
      json_escape(e.to),
      json_escape(e.label),
      json_escape(e.kind or "sync"),
      comma
    )
  end
  out[#out + 1] = "  ]"
  out[#out + 1] = "}"
  return table.concat(out, "\n") .. "\n"
end

function M.save_file(path, doc)
  return write_text(path, M.encode_pretty(doc))
end

function M.export_mermaid(mermaid_path, doc, markdown_path)
  local ok1, err1 = write_text(mermaid_path, M.to_mermaid(doc))
  if not ok1 then
    return false, err1
  end
  if markdown_path then
    write_text(markdown_path, M.to_markdown(doc))
  end
  return true
end

function M.ensure_project_file(root)
  local paths = M.default_paths(root)
  local existing = M.load_file(paths.json)
  if existing then
    return existing, paths, false
  end
  local project_name = vim.fn.fnamemodify(paths.root, ":t")
  local created = M.default_doc(project_name ~= "" and ("Архитектура " .. project_name) or nil)
  M.save_file(paths.json, created)
  return created, paths, true
end

return M
