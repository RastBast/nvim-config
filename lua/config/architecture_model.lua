-- ========================================================================== --
--   МОДЕЛЬ АРХИТЕКТУРЫ: C4-ИЕРАРХИЯ, КОНТРАКТЫ, MERMAID И АНАЛИЗ СВЯЗЕЙ     --
-- ========================================================================== --
local M = {}

M.KINDS = {
  { id = "client",   label = "Клиент / UI",        icon = "🖥️", tier = 1 },
  { id = "gateway",  label = "API / Шлюз",         icon = "🚪", tier = 2 },
  { id = "service",  label = "Сервис / Модуль",    icon = "⚙️", tier = 3 },
  { id = "worker",   label = "Воркер / Пакет",     icon = "🔄", tier = 3 },
  { id = "queue",    label = "Очередь / Шина",     icon = "📨", tier = 4 },
  { id = "cache",    label = "Кеш / In-Memory",    icon = "⚡", tier = 4 },
  { id = "db",       label = "База / Таблица",     icon = "🗄️", tier = 4 },
  { id = "external", label = "Внешний API",        icon = "🌐", tier = 4 },
}

M.EDGE_KINDS = {
  { id = "sync",  label = "Синхронный вызов (HTTP / gRPC / require)", arrow = "──▶", mmd = "-->" },
  { id = "async", label = "Асинхронное событие (очередь / pub-sub)",  arrow = "╌╌▶", mmd = "-.->" },
  { id = "data",  label = "Чтение / запись данных (SQL / FK / KV)",   arrow = "══▶", mmd = "==>" },
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

local function clean_contracts(raw_list)
  if type(raw_list) ~= "table" then
    return {}
  end
  local out, seen = {}, {}
  for _, v in ipairs(raw_list) do
    local s = vim.trim(tostring(v or ""))
    if s ~= "" and not seen[s] then
      seen[s] = true
      out[#out + 1] = s
    end
  end
  return out
end

--- Авто-раскладка по архитектурным слоям отдельно для каждого C4-уровня (`parent_id`).
function M.auto_layout(doc, only_scope)
  if type(doc) ~= "table" or type(doc.nodes) ~= "table" then
    return doc
  end
  local scopes = {}
  for _, node in ipairs(doc.nodes) do
    local pid = node.parent_id or ""
    if only_scope == nil or pid == only_scope then
      scopes[pid] = scopes[pid] or { [1] = {}, [2] = {}, [3] = {}, [4] = {} }
      local tier = M.kind_meta(node.kind).tier or 3
      scopes[pid][tier][#scopes[pid][tier] + 1] = node
    end
  end
  local tier_x = { [1] = 80, [2] = 360, [3] = 650, [4] = 960 }
  for _, buckets in pairs(scopes) do
    for tier = 1, 4 do
      local list = buckets[tier] or {}
      for idx, node in ipairs(list) do
        node.x = tier_x[tier]
        node.y = 80 + (idx - 1) * 130
      end
    end
  end
  return doc
end

function M.default_doc(title)
  return {
    version = 2,
    title = (type(title) == "string" and title ~= "") and title or "Архитектура приложения",
    direction = "LR",
    nodes = {
      {
        id = "web_client",
        label = "Клиент (Web / CLI)",
        kind = "client",
        parent_id = "",
        x = 80,
        y = 160,
        path = "",
        tech = "UI / Frontend",
        summary = "Точка входа пользователя",
        contracts = {},
      },
      {
        id = "api_gateway",
        label = "API / Входной слой",
        kind = "gateway",
        parent_id = "",
        x = 360,
        y = 160,
        path = "",
        tech = "HTTP / gRPC",
        summary = "Маршрутизация, авторизация, валидация",
        contracts = { "POST /api/v1/orders", "GET /healthz" },
      },
      {
        id = "core_service",
        label = "Бизнес-логика",
        kind = "service",
        parent_id = "",
        x = 650,
        y = 100,
        path = "",
        tech = "Core Domain",
        summary = "Основные сценарии приложения",
        contracts = { "rpc CreateOrder" },
      },
      {
        id = "event_bus",
        label = "Шина событий",
        kind = "queue",
        parent_id = "",
        x = 960,
        y = 80,
        path = "",
        tech = "Queue / Events",
        summary = "Фоновые задачи и интеграции",
        contracts = { "topic orders.created" },
      },
      {
        id = "primary_db",
        label = "Основная БД",
        kind = "db",
        parent_id = "",
        x = 960,
        y = 230,
        path = "",
        tech = "PostgreSQL / Storage",
        summary = "Долговременное хранение данных",
        contracts = { "TABLE orders", "TABLE users" },
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
    version = 2,
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
        local raw_parent = (type(n.parent_id) == "string" and vim.trim(n.parent_id) ~= "")
          and M.slug(n.parent_id) or ""
        doc.nodes[#doc.nodes + 1] = {
          id = id,
          label = (type(n.label) == "string" and vim.trim(n.label) ~= "") and vim.trim(n.label) or id,
          kind = kind,
          parent_id = raw_parent,
          x = tonumber(n.x) or (80 + (tier - 1) * 280),
          y = tonumber(n.y) or (80 + ((idx - 1) % 6) * 125),
          path = type(n.path) == "string" and vim.trim(n.path) or "",
          tech = type(n.tech) == "string" and vim.trim(n.tech) or "",
          summary = type(n.summary) == "string" and vim.trim(n.summary) or "",
          contracts = clean_contracts(n.contracts),
        }
      end
    end
  end

  -- Очищаем сиротские или циклические parent_id
  local by_id = {}
  for _, n in ipairs(doc.nodes) do by_id[n.id] = n end
  for _, n in ipairs(doc.nodes) do
    if n.parent_id ~= "" and (not by_id[n.parent_id] or n.parent_id == n.id) then
      n.parent_id = ""
    else
      local guard, cur = {}, n.parent_id
      while cur and cur ~= "" do
        if cur == n.id or guard[cur] then
          n.parent_id = ""
          break
        end
        guard[cur] = true
        cur = by_id[cur] and by_id[cur].parent_id or ""
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
    if spec.parent_id ~= nil then
      existing.parent_id = vim.trim(tostring(spec.parent_id)) ~= "" and M.slug(spec.parent_id) or ""
    end
    if spec.x ~= nil then existing.x = tonumber(spec.x) or existing.x end
    if spec.y ~= nil then existing.y = tonumber(spec.y) or existing.y end
    if spec.path ~= nil and vim.trim(tostring(spec.path)) ~= "" then
      existing.path = vim.trim(tostring(spec.path))
    elseif spec.path == "" and existing.path == nil then
      existing.path = ""
    end
    if spec.tech ~= nil and vim.trim(tostring(spec.tech)) ~= "" then
      existing.tech = vim.trim(tostring(spec.tech))
    end
    if spec.summary ~= nil and vim.trim(tostring(spec.summary)) ~= "" then
      existing.summary = vim.trim(tostring(spec.summary))
    end
    if type(spec.contracts) == "table" then
      local merged = clean_contracts(existing.contracts)
      local seen = {}
      for _, c in ipairs(merged) do seen[c] = true end
      for _, c in ipairs(clean_contracts(spec.contracts)) do
        if not seen[c] then
          seen[c] = true
          merged[#merged + 1] = c
        end
      end
      existing.contracts = merged
    end
    return existing
  end
  local tier = M.kind_meta(kind).tier
  local pid = (spec.parent_id and vim.trim(tostring(spec.parent_id)) ~= "") and M.slug(spec.parent_id) or ""
  local node = {
    id = id,
    label = (spec.label and vim.trim(spec.label) ~= "") and vim.trim(spec.label) or id,
    kind = kind,
    parent_id = pid,
    x = tonumber(spec.x) or (80 + (tier - 1) * 280),
    y = tonumber(spec.y) or (80 + (#doc.nodes % 6) * 125),
    path = spec.path and vim.trim(tostring(spec.path)) or "",
    tech = spec.tech and vim.trim(tostring(spec.tech)) or "",
    summary = spec.summary and vim.trim(tostring(spec.summary)) or "",
    contracts = clean_contracts(spec.contracts),
  }
  doc.nodes[#doc.nodes + 1] = node
  return node
end

function M.add_contract(doc, node_id, contract_str)
  local node = M.find_node(doc, node_id)
  if not node then return false end
  local clean = vim.trim(tostring(contract_str or ""))
  if clean == "" then return false end
  node.contracts = node.contracts or {}
  for _, c in ipairs(node.contracts) do
    if c == clean then return true end
  end
  if #node.contracts < 25 then
    node.contracts[#node.contracts + 1] = clean
  end
  return true
end

--- Удалить узел вместе со всеми его вложенными C4-потомками и привязанными связями.
function M.remove_node(doc, id)
  if not M.find_node(doc, id) then
    return false
  end
  local doomed = { [id] = true }
  local changed = true
  while changed do
    changed = false
    for _, n in ipairs(doc.nodes or {}) do
      if n.parent_id and doomed[n.parent_id] and not doomed[n.id] then
        doomed[n.id] = true
        changed = true
      end
    end
  end
  local kept_nodes = {}
  for _, n in ipairs(doc.nodes or {}) do
    if not doomed[n.id] then
      kept_nodes[#kept_nodes + 1] = n
    end
  end
  doc.nodes = kept_nodes

  local kept_edges = {}
  for _, e in ipairs(doc.edges or {}) do
    if not doomed[e.from] and not doomed[e.to] then
      kept_edges[#kept_edges + 1] = e
    end
  end
  doc.edges = kept_edges
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
    if e.from == from and e.to == to and (e.label == clean_label or clean_label == "") then
      if clean_label ~= "" then e.label = clean_label end
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

-- ---------------------------------------------------------------------------
-- Навигация по уровням C4 (Система → Контейнер/Сервис → Модуль/Таблица)
-- ---------------------------------------------------------------------------

function M.children_of(doc, parent_id)
  local target = (type(parent_id) == "string") and parent_id or ""
  local out = {}
  for _, n in ipairs(doc.nodes or {}) do
    if (n.parent_id or "") == target then
      out[#out + 1] = n
    end
  end
  return out
end

function M.child_count(doc, node_id)
  local count = 0
  for _, n in ipairs(doc.nodes or {}) do
    if (n.parent_id or "") == node_id then
      count = count + 1
    end
  end
  return count
end

function M.breadcrumbs(doc, scope_id)
  local trail = { { id = "", label = "🌐 Вся система" } }
  if not scope_id or scope_id == "" then
    return trail
  end
  local stack = {}
  local seen = {}
  local cur = M.find_node(doc, scope_id)
  while cur and not seen[cur.id] do
    seen[cur.id] = true
    table.insert(stack, 1, {
      id = cur.id,
      label = M.kind_meta(cur.kind).icon .. " " .. cur.label,
    })
    cur = (cur.parent_id and cur.parent_id ~= "") and M.find_node(doc, cur.parent_id) or nil
  end
  for _, item in ipairs(stack) do
    trail[#trail + 1] = item
  end
  return trail
end

--- Проекция графа на выбранный C4-уровень (`scope_id`):
--- возвращает дочерние узлы уровня и агрегированные связи между ними
--- (включая связи между их вложенными подмодулями!).
function M.scoped_view(doc, scope_id)
  local scope = (type(scope_id) == "string") and scope_id or ""
  if scope ~= "" and not M.find_node(doc, scope) then
    scope = ""
  end
  local visible = M.children_of(doc, scope)
  local vis_map = {}
  for _, n in ipairs(visible) do
    vis_map[n.id] = n
  end

  local by_id = {}
  for _, n in ipairs(doc.nodes or {}) do
    by_id[n.id] = n
  end

  local function lift_to_visible(id)
    local cur = by_id[id]
    local guard = {}
    while cur and not guard[cur.id] do
      if vis_map[cur.id] then
        return cur.id
      end
      guard[cur.id] = true
      cur = (cur.parent_id and cur.parent_id ~= "") and by_id[cur.parent_id] or nil
    end
    return nil
  end

  local edges = {}
  local edge_index_by_pair = {}
  for real_idx, e in ipairs(doc.edges or {}) do
    local a = lift_to_visible(e.from)
    local b = lift_to_visible(e.to)
    if a and b and a ~= b then
      local key = a .. "->" .. b .. ":" .. (e.kind or "sync")
      local pos = edge_index_by_pair[key]
      if not pos then
        edges[#edges + 1] = {
          from = a,
          to = b,
          label = e.label or "",
          kind = e.kind or "sync",
          real_index = real_idx,
          rolled_up = (a ~= e.from or b ~= e.to),
        }
        edge_index_by_pair[key] = #edges
      else
        local ex = edges[pos]
        if e.label and e.label ~= "" and not ex.label:find(e.label, 1, true) then
          if ex.label == "" then
            ex.label = e.label
          elseif #ex.label < 36 then
            ex.label = ex.label .. ", " .. e.label
          end
        end
      end
    end
  end

  return {
    scope_id = scope,
    breadcrumbs = M.breadcrumbs(doc, scope),
    nodes = visible,
    edges = edges,
  }
end

function M.neighbors_in_view(view, node_id)
  local incoming, outgoing = {}, {}
  local vis_by_id = {}
  for _, n in ipairs(view.nodes or {}) do vis_by_id[n.id] = n end
  for idx, e in ipairs(view.edges or {}) do
    if e.to == node_id then
      incoming[#incoming + 1] = { index = e.real_index or idx, edge = e, peer = vis_by_id[e.from] }
    end
    if e.from == node_id then
      outgoing[#outgoing + 1] = { index = e.real_index or idx, edge = e, peer = vis_by_id[e.to] }
    end
  end
  return incoming, outgoing
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

-- ---------------------------------------------------------------------------
-- Статический аудит графа: циклы, изолированные узлы, узкие места, нарушения слоёв
-- ---------------------------------------------------------------------------

function M.analyze_graph(doc)
  doc = M.normalize(doc)
  local adj = {}
  local fan_in, fan_out = {}, {}
  local by_id = {}
  for _, n in ipairs(doc.nodes) do
    by_id[n.id] = n
    adj[n.id] = {}
    fan_in[n.id] = 0
    fan_out[n.id] = 0
  end
  for _, e in ipairs(doc.edges) do
    if adj[e.from] and by_id[e.to] then
      adj[e.from][#adj[e.from] + 1] = e.to
      fan_out[e.from] = (fan_out[e.from] or 0) + 1
      fan_in[e.to] = (fan_in[e.to] or 0) + 1
    end
  end

  -- Поиск ориентированных циклов (DFS со стеком пути)
  local state = {} -- nil=unvisited, 1=visiting, 2=done
  local stack = {}
  local cycles = {}
  local seen_cycle = {}

  local function dfs(u)
    state[u] = 1
    stack[#stack + 1] = u
    for _, v in ipairs(adj[u] or {}) do
      if state[v] == 1 then
        local cyc = {}
        local recording = false
        for _, item in ipairs(stack) do
          if item == v then recording = true end
          if recording then cyc[#cyc + 1] = item end
        end
        cyc[#cyc + 1] = v
        local sig = table.concat(cyc, " -> ")
        if not seen_cycle[sig] and #cycles < 20 then
          seen_cycle[sig] = true
          cycles[#cycles + 1] = cyc
        end
      elseif not state[v] then
        dfs(v)
      end
    end
    stack[#stack] = nil
    state[u] = 2
  end

  for _, n in ipairs(doc.nodes) do
    if not state[n.id] then
      dfs(n.id)
    end
  end

  -- Изолированные узлы (без связей и без вложенных детей)
  local orphans = {}
  for _, n in ipairs(doc.nodes) do
    if (fan_in[n.id] or 0) == 0 and (fan_out[n.id] or 0) == 0 and M.child_count(doc, n.id) == 0 and (n.parent_id or "") == "" then
      orphans[#orphans + 1] = n
    end
  end

  -- Нарушения слоёв (например, client напрямую ходит в db/cache в обход gateway/service)
  local layer_warnings = {}
  for _, e in ipairs(doc.edges) do
    local src, dst = by_id[e.from], by_id[e.to]
    if src and dst and src.kind == "client" and (dst.kind == "db" or dst.kind == "cache") then
      layer_warnings[#layer_warnings + 1] = ("%s (%s) обращается напрямую к %s (%s) в обход API/сервиса"):format(
        src.label, src.kind, dst.label, dst.kind
      )
    end
  end

  -- Топ нагруженных узлов по числу связей
  local hotspots = {}
  for _, n in ipairs(doc.nodes) do
    local deg = (fan_in[n.id] or 0) + (fan_out[n.id] or 0)
    if deg >= 4 then
      hotspots[#hotspots + 1] = {
        node = n,
        fan_in = fan_in[n.id] or 0,
        fan_out = fan_out[n.id] or 0,
        degree = deg,
      }
    end
  end
  table.sort(hotspots, function(a, b) return a.degree > b.degree end)

  return {
    cycles = cycles,
    orphans = orphans,
    layer_warnings = layer_warnings,
    hotspots = hotspots,
  }
end

-- ---------------------------------------------------------------------------
-- Экспорт в Mermaid (с поддержкой C4 subgraph!) и Markdown
-- ---------------------------------------------------------------------------

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

function M.to_mermaid(doc, scope_id)
  doc = M.normalize(doc)
  local view_nodes, view_edges
  local use_subgraphs = false

  if scope_id ~= nil then
    local v = M.scoped_view(doc, scope_id)
    view_nodes, view_edges = v.nodes, v.edges
  else
    view_nodes, view_edges = doc.nodes, doc.edges
    for _, n in ipairs(doc.nodes) do
      if (n.parent_id or "") ~= "" then
        use_subgraphs = true
        break
      end
    end
  end

  local lines = {
    "%% Сгенерировано из architecture.json (" .. doc.title .. ")",
    "flowchart " .. (doc.direction or "LR"),
  }

  if use_subgraphs then
    local function emit_scope(pid, indent)
      for _, n in ipairs(M.children_of(doc, pid)) do
        local kids = M.children_of(doc, n.id)
        if #kids > 0 then
          local km = M.kind_meta(n.kind)
          lines[#lines + 1] = ('%ssubgraph %s["%s %s"]'):format(indent, n.id, km.icon, escape_mermaid(n.label))
          emit_scope(n.id, indent .. "  ")
          lines[#lines + 1] = indent .. "end"
        else
          lines[#lines + 1] = indent .. mermaid_shape(n)
        end
      end
    end
    emit_scope("", "  ")
  else
    for _, node in ipairs(view_nodes) do
      lines[#lines + 1] = "  " .. mermaid_shape(node)
    end
  end

  if #view_edges > 0 then
    lines[#lines + 1] = ""
  end
  for _, edge in ipairs(view_edges) do
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

  lines[#lines + 1] = ""
  lines[#lines + 1] = "  classDef client fill:#1e3a5f,stroke:#60a5fa,color:#f8fafc;"
  lines[#lines + 1] = "  classDef gateway fill:#3b2f63,stroke:#a78bfa,color:#f8fafc;"
  lines[#lines + 1] = "  classDef service fill:#1f3d33,stroke:#34d399,color:#f8fafc;"
  lines[#lines + 1] = "  classDef worker fill:#1f3d33,stroke:#2dd4bf,color:#f8fafc;"
  lines[#lines + 1] = "  classDef queue fill:#4a2c1d,stroke:#fb923c,color:#f8fafc;"
  lines[#lines + 1] = "  classDef cache fill:#4a3718,stroke:#facc15,color:#f8fafc;"
  lines[#lines + 1] = "  classDef db fill:#3f1d2e,stroke:#f472b6,color:#f8fafc;"
  lines[#lines + 1] = "  classDef external fill:#334155,stroke:#94a3b8,color:#f8fafc;"
  for _, node in ipairs(view_nodes) do
    if not use_subgraphs or M.child_count(doc, node.id) == 0 then
      lines[#lines + 1] = ("  class %s %s;"):format(node.id, node.kind or "service")
    end
  end
  return table.concat(lines, "\n") .. "\n"
end

function M.to_markdown(doc)
  doc = M.normalize(doc)
  local lines = {
    "# 🏗️ " .. doc.title,
    "",
    "## Визуальная диаграмма связей (верхний уровень C4)",
    "",
    "```mermaid",
  }
  local mmd = vim.trim(M.to_mermaid(doc, ""))
  for line in (mmd .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end
  lines[#lines + 1] = "```"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "## Каталог компонентов (" .. #doc.nodes .. ")"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "| Компонент | Роль | Контейнер (C4) | Стек | Путь в коде | Контракты / API |"
  lines[#lines + 1] = "| --- | --- | --- | --- | --- | --- |"
  for _, n in ipairs(doc.nodes) do
    local km = M.kind_meta(n.kind)
    local contracts_str = (n.contracts and #n.contracts > 0) and table.concat(n.contracts, "; ") or "—"
    lines[#lines + 1] = ("| `%s` (%s) | %s %s | %s | %s | %s | %s |"):format(
      n.id,
      n.label,
      km.icon,
      km.label,
      (n.parent_id and n.parent_id ~= "") and ("`" .. n.parent_id .. "`") or "🌐 Система",
      n.tech ~= "" and n.tech or "—",
      n.path ~= "" and ("`" .. n.path .. "`") or "—",
      contracts_str
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

local function encode_str_array(arr)
  if type(arr) ~= "table" or #arr == 0 then
    return "[]"
  end
  local items = {}
  for _, v in ipairs(arr) do
    items[#items + 1] = '"' .. json_escape(v) .. '"'
  end
  return "[" .. table.concat(items, ", ") .. "]"
end

function M.encode_pretty(doc)
  doc = M.normalize(doc)
  local out = {
    "{",
    ('  "version": %d,'):format(doc.version or 2),
    ('  "title": "%s",'):format(json_escape(doc.title)),
    ('  "direction": "%s",'):format(json_escape(doc.direction)),
    '  "nodes": [',
  }
  for i, n in ipairs(doc.nodes) do
    local comma = (i < #doc.nodes) and "," or ""
    out[#out + 1] = ('    { "id": "%s", "label": "%s", "kind": "%s", "parent_id": "%s", "x": %d, "y": %d, "path": "%s", "tech": "%s", "summary": "%s", "contracts": %s }%s'):format(
      json_escape(n.id),
      json_escape(n.label),
      json_escape(n.kind),
      json_escape(n.parent_id or ""),
      math.floor(tonumber(n.x) or 0),
      math.floor(tonumber(n.y) or 0),
      json_escape(n.path),
      json_escape(n.tech),
      json_escape(n.summary),
      encode_str_array(n.contracts),
      comma
    )
  end
  out[#out + 1] = "  ],"
  out[#out + 1] = '  "edges": ['
  for i, e in ipairs(doc.edges) do
    local comma = (i < #doc.edges) and "," or ""
    out[#out + 1] = ('    { "from": "%s", "to": "%s", "label": "%s", "kind": "%s" }%s'):format(
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
  local ok1, err1 = write_text(mermaid_path, M.to_mermaid(doc, ""))
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
