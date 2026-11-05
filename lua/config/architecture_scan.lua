-- Приближённый локальный анализ импортов. Ничего не исполняет и не отправляет
-- в сеть: читает только выбранные исходные файлы после явной команды :ArchScan.
local Model = require("config.architecture_model")
local uv = vim.uv
local M = {}
local running = false
local SKIP = { [".git"] = true, node_modules = true, vendor = true, target = true, build = true, dist = true,
  out = true, coverage = true, __pycache__ = true, [".venv"] = true, [".cache"] = true,
  [".next"] = true, [".idea"] = true, [".terraform"] = true, ["third_party"] = true }
local EXTENSIONS = { go = true, py = true, js = true, jsx = true, ts = true, tsx = true, mjs = true, cjs = true }
local JS_EXTS = { ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs" }

local function say(message, warning)
  vim.api.nvim_echo({ { "Архитектура: " .. message, warning and "WarningMsg" or "None" } }, true, {})
end

local function dirname(path)
  return path:match("^(.*)/[^/]+$") or "."
end

-- Не выходим из выбранного проекта через ../.
local function join_relative(base, relative)
  local parts = {}
  if base ~= "." then for p in base:gmatch("[^/]+") do parts[#parts + 1] = p end end
  for p in relative:gmatch("[^/]+") do
    if p == ".." then
      if #parts == 0 then return nil end
      parts[#parts] = nil
    elseif p ~= "." and p ~= "" then parts[#parts + 1] = p end
  end
  return table.concat(parts, "/")
end

local function read_file(path, max)
  local stat = uv.fs_lstat(path)
  if not stat or stat.type ~= "file" or stat.size > max then return nil end
  local fd = uv.fs_open(path, "r", 0)
  if not fd then return nil end
  local data = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  return data
end

local function module_name(root)
  local data = read_file(root .. "/go.mod", 65536)
  return data and ("\n" .. data):match("\n%s*module%s+([^%s]+)") or nil
end

local function js_target(base, spec, files)
  if spec:sub(1, 1) ~= "." then return nil end
  local path = join_relative(base, spec)
  if not path then return nil end
  if files[path] then return dirname(path) end
  for _, ext in ipairs(JS_EXTS) do
    if files[path .. ext] then return dirname(path .. ext) end
    if files[path .. "/index" .. ext] then return path end
  end
  if path:match("%.js$") then
    local ts = path:gsub("%.js$", ".ts")
    if files[ts] then return dirname(ts) end
  end
end

local function python_target(base, spec, files)
  local dots, rest = spec:match("^(%.*)(.*)$")
  local start = "."
  if #dots > 0 then
    start = base
    for _ = 2, #dots do
      if start == "." then return nil end
      start = dirname(start)
    end
  end
  local rel = join_relative(start, rest:gsub("%.", "/"))
  if not rel then return nil end
  local candidates = { rel .. ".py", rel .. "/__init__.py" }
  if #dots == 0 then
    candidates[#candidates + 1] = "src/" .. rel .. ".py"
    candidates[#candidates + 1] = "src/" .. rel .. "/__init__.py"
  end
  for _, p in ipairs(candidates) do if files[p] then return dirname(p) end end
end

local function dependency_graph(root, collected, stats)
  table.sort(collected, function(a, b) return a.rel < b.rel end)
  local files, dirs = {}, {}
  for _, file in ipairs(collected) do files[file.rel], dirs[dirname(file.rel)] = true, true end
  local go_module, deps, pairs_seen = module_name(root), {}, {}
  local function add(from, to, lang)
    if not to or not dirs[to] or from == to then return end
    local key = from .. "\0" .. to
    if not pairs_seen[key] then pairs_seen[key] = true; deps[#deps + 1] = { from = from, to = to, label = lang } end
  end
  for i, file in ipairs(collected) do
    -- Возвращаем управление интерфейсу и во время разбора содержимого.
    if i % 20 == 0 then coroutine.yield() end
    local remaining = 8 * 1024 * 1024 - stats.bytes
    if remaining <= 0 then stats.truncated = true; break end
    local data = read_file(root .. "/" .. file.rel, math.min(262144, remaining))
    if data then
      stats.bytes = stats.bytes + #data
      local from, in_go = dirname(file.rel), false
      for line in (data .. "\n"):gmatch("(.-)\n") do
        if file.ext == "go" and go_module then
          local is_import = false
          if line:match("^%s*import%s*%(") then in_go = true; is_import = true
          elseif in_go and line:match("^%s*%)") then in_go = false
          elseif in_go or line:match("^%s*import%s+") then is_import = true end
          if is_import then
            local spec = line:match('"([^"]+)"')
            if spec == go_module then add(from, ".", "Go")
            elseif spec and spec:sub(1, #go_module + 1) == go_module .. "/" then add(from, spec:sub(#go_module + 2), "Go") end
          end
        elseif file.ext == "py" then
          local spec = line:match("^%s*from%s+([%w_%.]+)%s+import%s+")
          if spec then add(from, python_target(from, spec, files), "Python") end
          local imports = line:match("^%s*import%s+([^#]+)")
          if imports then
            for part in imports:gmatch("[^,]+") do
              local name = part:match("^%s*([%w_%.]+)")
              if name then add(from, python_target(from, name, files), "Python") end
            end
          end
        else
          for spec in line:gmatch("from%s*['\"]([^'\"]+)['\"]") do add(from, js_target(from, spec, files), "JS/TS") end
          for spec in line:gmatch("require%s*%(%s*['\"]([^'\"]+)['\"]") do add(from, js_target(from, spec, files), "JS/TS") end
          for spec in line:gmatch("import%s*%(%s*['\"]([^'\"]+)['\"]") do add(from, js_target(from, spec, files), "JS/TS") end
          for spec in line:gmatch("import%s*['\"]([^'\"]+)['\"]") do add(from, js_target(from, spec, files), "JS/TS") end
        end
      end
    else
      stats.truncated = true
    end
  end
  table.sort(deps, function(a, b) return a.from == b.from and a.to < b.to or a.from < b.from end)
  local involved, ordered = {}, {}
  for _, dep in ipairs(deps) do involved[dep.from], involved[dep.to] = true, true end
  for d in pairs(involved) do ordered[#ordered + 1] = d end
  table.sort(ordered)
  local others = {}; for d in pairs(dirs) do if not involved[d] then others[#others + 1] = d end end; table.sort(others)
  for _, d in ipairs(others) do ordered[#ordered + 1] = d end
  local base = vim.fn.fnamemodify(root, ":t")
  if base == "" then base = "проект" end
  if #base > 150 then base = vim.fn.strcharpart(base, 0, 30) end
  local model = { version = 1, title = "Зависимости: " .. base, nodes = {}, edges = {} }
  local ids = {}
  for _, dir in ipairs(ordered) do
    if #model.nodes >= Model.MAX_NODES then stats.truncated = true; break end
    if #dir <= 200 and not dir:find("[%z\1-\31\127]") then
      local i = #model.nodes; local id = "N" .. (i + 1)
      ids[dir] = id
      model.nodes[#model.nodes + 1] = { id = id, label = dir, kind = "module", path = dir,
        x = 2 + (i % 4) * 21, y = 2 + math.floor(i / 4) * 5 }
    else stats.truncated = true end
  end
  for _, d in ipairs(deps) do
    if ids[d.from] and ids[d.to] then
      if #model.edges >= Model.MAX_EDGES then stats.truncated = true; break end
      model.edges[#model.edges + 1] = { id = "E" .. (#model.edges + 1), from = ids[d.from], to = ids[d.to], label = d.label }
    end
  end
  stats.nodes, stats.edges = #model.nodes, #model.edges
  local valid, why = Model.validate(model)
  if not valid then return nil, why end
  return model
end

--- Небольшие порции обхода планируются в главном цикле. Лимиты ограничивают
--- чтение больших проектов; пропускаются скрытые каталоги и все симлинки.
function M.scan(root, done, opts)
  opts = opts or {}
  local limit = math.min(opts.max_files or 600, 600)
  local path = uv.fs_realpath(vim.fn.fnamemodify(root, ":p"))
  local stat = path and uv.fs_stat(path)
  if not stat or stat.type ~= "directory" then return done(nil, "каталог не найден") end
  path = path:gsub("/$", "")
  if path == "" then path = "/" end
  local queue, index, found = { { full = path, rel = "" } }, 1, {}
  local stats = { files = 0, bytes = 0, entries = 0, truncated = false }
  local function step()
    local count = 0
    while index <= #queue and count < 20 and #found < limit and stats.entries < 12000 do
      local dir = queue[index]; index, count = index + 1, count + 1
      local req = uv.fs_scandir(dir.full)
      local entries = {}
      if req then
        while true do
          local name, typ = uv.fs_scandir_next(req)
          if not name then break end
          entries[#entries + 1] = { name = name, typ = typ }
          stats.entries = stats.entries + 1
          if stats.entries >= 12000 then stats.truncated = true; break end
        end
      end
      table.sort(entries, function(a, b) return a.name < b.name end)
      for _, entry in ipairs(entries) do
        local rel = dir.rel == "" and entry.name or dir.rel .. "/" .. entry.name
        -- На некоторых ФС scandir не сообщает тип; lstat не следует симлинкам.
        local entry_stat = not entry.typ and uv.fs_lstat(dir.full .. "/" .. entry.name) or nil
        local typ = entry.typ or (entry_stat and entry_stat.type)
        if typ == "directory" and not SKIP[entry.name] and entry.name:sub(1, 1) ~= "." then
          queue[#queue + 1] = { full = dir.full .. "/" .. entry.name, rel = rel }
        elseif typ == "file" then
          local ext = entry.name:match("%.([%w]+)$")
          if ext and EXTENSIONS[ext] and not entry.name:match("%.min%.js$") then
            local fstat = uv.fs_lstat(dir.full .. "/" .. entry.name)
            if fstat and fstat.type == "file" then
              if fstat.size > 262144 then
                stats.truncated = true
              else
                found[#found + 1] = { rel = rel, ext = ext }
                if #found >= limit then stats.truncated = true; break end
              end
            end
          end
        end
      end
    end
    if index <= #queue and #found < limit and stats.entries < 12000 then return vim.schedule(step) end
    stats.files = #found
    -- Парсинг ограничен 600 файлами и 8 МБ; проект не исполняется. Coroutine
    -- также отдаёт управление UI после каждой небольшой порции файлов.
    local worker = coroutine.create(function() return dependency_graph(path, found, stats) end)
    local function resume()
      local ok, model, why = coroutine.resume(worker)
      if not ok then return done(nil, tostring(model)) end
      if coroutine.status(worker) ~= "dead" then return vim.schedule(resume) end
      if not model then return done(nil, why) end
      done(model, stats)
    end
    vim.schedule(resume)
  end
  vim.schedule(step)
end

function M.choose()
  if running then return say("анализ уже выполняется", true) end
  vim.ui.input({ prompt = "Локально проанализировать каталог (код никуда не отправляется): ", default = uv.cwd(), completion = "dir" }, function(root)
    if not root or vim.trim(root) == "" then return end
    running = true
    say("читаю импорты локально; большие и скрытые каталоги пропускаются")
    M.scan(root, function(model, info)
      running = false
      if not model then return say("анализ не удался: " .. tostring(info), true) end
      local summary = ("Файлов: %d, компонентов: %d, связей: %d%s. Создать новую схему?")
        :format(info.files, info.nodes, info.edges, info.truncated and " (достигнут лимит)" or "")
      vim.ui.select({ "Открыть новую схему", "Отмена" }, { prompt = summary }, function(choice)
        if choice == "Открыть новую схему" then require("config.architecture_board").open(nil, model) end
      end)
    end)
  end)
end

return M
