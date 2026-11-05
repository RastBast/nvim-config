-- Общая модель графа для терминального и браузерного редактора.
-- Сохранение выполняет Neovim; этот модуль не читает файлы и не отправляет данные.
local M = {}

M.MAX_NODES, M.MAX_EDGES = 50, 160
M.MAX_X, M.MAX_Y = 72, 70
M.WIDTH, M.BOX_WIDTH, M.BOX_HEIGHT = 90, 16, 3
M.kinds = { actor = true, service = true, storage = true, queue = true, external = true, module = true }

local function text(value, limit, empty)
  if type(value) ~= "string" or #value > limit or value:find("[%z\1-\31\127]") then return nil end
  value = vim.trim(value)
  if not empty and value == "" then return nil end
  return value
end

local function integer(value, max)
  return type(value) == "number" and value == math.floor(value) and value >= 0 and value <= max
end

local function is_list(value)
  return type(value) == "table" and vim.islist(value)
end

local function by_id(items, id)
  for i, item in ipairs(items) do if item.id == id then return item, i end end
end

local function next_id(items, prefix)
  local used = {}
  for _, item in ipairs(items) do used[item.id] = true end
  local n = 1
  while used[prefix .. n] do n = n + 1 end
  return prefix .. n
end

-- Первое свободное место с небольшим зазором. На нестандартно расставленной
-- схеме проверяем и остальные клетки, а не накладываем новый блок на старый.
function M.free_position(model)
  local function clear(x, y, gap)
    for _, node in ipairs(model.nodes) do
      if x < node.x + M.BOX_WIDTH + gap and x + M.BOX_WIDTH + gap > node.x
        and y < node.y + M.BOX_HEIGHT + gap and y + M.BOX_HEIGHT + gap > node.y then return false end
    end
    return true
  end
  for y = 2, M.MAX_Y, 5 do
    for x = 2, M.MAX_X, 21 do if clear(x, y, 1) then return x, y end end
  end
  for y = 0, M.MAX_Y do
    for x = 0, M.MAX_X do if clear(x, y, 0) then return x, y end end
  end
end

--- Проверить данные до отображения или изменения; неизвестные поля сохраняются.
function M.validate(model)
  if type(model) ~= "table" or model.version ~= 1 or not text(model.title, 200) then
    return false, "нужен JSON схемы версии 1 с непустым title"
  end
  if not is_list(model.nodes) or #model.nodes > M.MAX_NODES then return false, "неверный список компонентов" end
  if not is_list(model.edges) or #model.edges > M.MAX_EDGES then return false, "неверный список связей" end
  local nodes, edges = {}, {}
  for _, node in ipairs(model.nodes) do
    if type(node) ~= "table" or type(node.id) ~= "string" or not node.id:match("^N%d+$") or nodes[node.id]
      or not text(node.label, 200) or not M.kinds[node.kind]
      or not integer(node.x, M.MAX_X) or not integer(node.y, M.MAX_Y)
      or (node.path ~= nil and not text(node.path, 1024, true)) then
      return false, "неверный компонент или повторяющийся ID"
    end
    nodes[node.id] = true
  end
  for _, edge in ipairs(model.edges) do
    if type(edge) ~= "table" or type(edge.id) ~= "string" or not edge.id:match("^E%d+$") or edges[edge.id]
      or not nodes[edge.from] or not nodes[edge.to] or edge.from == edge.to
      or (edge.label ~= nil and not text(edge.label, 200, true)) then
      return false, "неверная связь или повторяющийся ID"
    end
    edges[edge.id] = true
  end
  return true
end

local function point(x, y, label, kind, id)
  return { id = id, label = label, kind = kind, x = x, y = y }
end

local function edge(from, to, label, id)
  return { id = id, from = from, to = to, label = label }
end

M.template_names = {
  { id = "context", name = "Контекст: пользователь → приложение → внешняя система" },
  { id = "layers", name = "Слои: интерфейс → API → логика → база данных" },
  { id = "microservices", name = "Микросервисы: gateway → сервисы → очередь / база" },
  { id = "flow", name = "Поток данных: источник → обработка → хранилище" },
  { id = "empty", name = "Пустая схема" },
}

function M.template(id)
  if id == "empty" then return { version = 1, title = "Новая архитектура", nodes = {}, edges = {} } end
  if id == "layers" then
    return { version = 1, title = "Слои приложения", nodes = {
      point(2, 5, "Интерфейс", "actor", "N1"), point(23, 5, "API", "service", "N2"),
      point(44, 5, "Бизнес-логика", "service", "N3"), point(65, 5, "База данных", "storage", "N4"),
    }, edges = { edge("N1", "N2", "HTTP", "E1"), edge("N2", "N3", "", "E2"), edge("N3", "N4", "SQL", "E3") } }
  elseif id == "microservices" then
    return { version = 1, title = "Микросервисы", nodes = {
      point(2, 9, "Gateway", "service", "N1"), point(25, 3, "Сервис заказов", "service", "N2"),
      point(25, 15, "Сервис оплаты", "service", "N3"), point(52, 3, "Очередь", "queue", "N4"),
      point(52, 15, "База данных", "storage", "N5"),
    }, edges = { edge("N1", "N2", "", "E1"), edge("N1", "N3", "", "E2"),
      edge("N2", "N4", "события", "E3"), edge("N3", "N5", "", "E4") } }
  elseif id == "flow" then
    return { version = 1, title = "Поток данных", nodes = {
      point(4, 7, "Источник", "external", "N1"), point(29, 7, "Обработка", "service", "N2"),
      point(54, 7, "Хранилище", "storage", "N3"),
    }, edges = { edge("N1", "N2", "данные", "E1"), edge("N2", "N3", "результат", "E2") } }
  end
  return { version = 1, title = "Контекст приложения", nodes = {
    point(4, 7, "Пользователь", "actor", "N1"), point(29, 7, "Приложение", "service", "N2"),
    point(54, 7, "Внешняя система", "external", "N3"),
  }, edges = { edge("N1", "N2", "запрос", "E1"), edge("N2", "N3", "API", "E2") } }
end

--- Возвращает изменённую копию, не трогая исходную модель при ошибке.
function M.apply(original, action)
  local ok, err = M.validate(original)
  if not ok then return nil, err end
  if type(action) ~= "table" or type(action.op) ~= "string" then return nil, "неверное действие" end
  local model = vim.deepcopy(original)
  local op = action.op
  if op == "add" then
    local label, kind = text(action.label, 200), action.kind or "service"
    if not label or not M.kinds[kind] then return nil, "укажи название и допустимый тип компонента" end
    if #model.nodes >= M.MAX_NODES then return nil, "достигнут лимит компонентов" end
    local x, y = action.x, action.y
    if x == nil and y == nil then
      x, y = M.free_position(model)
      if not x then return nil, "на холсте нет свободного места для блока" end
    else
      x, y = x or 2, y or 2
    end
    if not integer(x, M.MAX_X) or not integer(y, M.MAX_Y) then return nil, "неверные координаты" end
    local id = next_id(model.nodes, "N")
    model.nodes[#model.nodes + 1] = { id = id, label = label, kind = kind, x = x, y = y }
    return model, id
  elseif op == "move" then
    local node = by_id(model.nodes, action.id)
    if not node or not integer(action.x, M.MAX_X) or not integer(action.y, M.MAX_Y) then return nil, "компонент или координаты не найдены" end
    node.x, node.y = action.x, action.y
  elseif op == "rename" then
    local node, label = by_id(model.nodes, action.id), text(action.label, 200)
    if not node or not label then return nil, "компонент не найден или название пустое" end
    node.label = label
  elseif op == "kind" then
    local node = by_id(model.nodes, action.id)
    if not node or not M.kinds[action.kind] then return nil, "неверный тип компонента" end
    node.kind = action.kind
  elseif op == "delete" then
    local _, index = by_id(model.nodes, action.id)
    if not index then return nil, "компонент не найден" end
    table.remove(model.nodes, index)
    local rest = {}
    for _, e in ipairs(model.edges) do if e.from ~= action.id and e.to ~= action.id then rest[#rest + 1] = e end end
    model.edges = rest
  elseif op == "link" then
    local label = text(action.label or "", 200, true)
    if not by_id(model.nodes, action.from) or not by_id(model.nodes, action.to) or action.from == action.to or not label then
      return nil, "выбери два разных компонента и корректную подпись"
    end
    if #model.edges >= M.MAX_EDGES then return nil, "достигнут лимит связей" end
    local id = next_id(model.edges, "E")
    model.edges[#model.edges + 1] = { id = id, from = action.from, to = action.to, label = label }
    return model, id
  elseif op == "unlink" then
    local _, index = by_id(model.edges, action.id)
    if not index then return nil, "связь не найдена" end
    table.remove(model.edges, index)
  elseif op == "layout" then
    for i, node in ipairs(model.nodes) do
      local n = i - 1
      node.x, node.y = 2 + (n % 4) * 21, 2 + math.floor(n / 4) * 5
    end
  else
    return nil, "неизвестное действие"
  end
  return model
end

local function escaped(s)
  return (s:gsub("#", "#35;"):gsub("&", "#38;"):gsub('"', "#quot;")
    :gsub("|", "#124;"):gsub("<", "#60;"):gsub(">", "#62;"))
end

function M.mermaid(model)
  local ok, err = M.validate(model)
  if not ok then return nil, err end
  local lines = { "# " .. model.title, "", "```mermaid", "graph LR" }
  for _, n in ipairs(model.nodes) do lines[#lines + 1] = ('  %s["%s"]'):format(n.id, escaped(n.label)) end
  for _, e in ipairs(model.edges) do
    local label = e.label or ""
    local arrow = label == "" and " --> " or (' -->|"' .. escaped(label) .. '"| ')
    lines[#lines + 1] = "  " .. e.from .. arrow .. e.to
  end
  lines[#lines + 1] = "```"
  return lines
end

return M
