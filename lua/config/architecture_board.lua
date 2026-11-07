-- ========================================================================== --
--   ИНТЕРАКТИВНАЯ C4-ДОСКА АРХИТЕКТУРЫ ВНУТРИ NEOVIM (:ArchBoard)            --
-- ========================================================================== --
local Model = require("config.architecture_model")
local Scan = require("config.architecture_scan")

local M = {}

local state = {
  win = nil,
  buf = nil,
  root = nil,
  paths = nil,
  doc = nil,
  scope_id = "",
  selected_idx = 1,
}

local ns_id = nil

local function pad_display(str, width)
  local w = vim.fn.strdisplaywidth(str)
  if w >= width then
    return vim.fn.strcharpart(str, 0, math.max(1, width - 1)) .. "…"
  end
  return str .. string.rep(" ", width - w)
end

local function close_board()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  state.win = nil
end

local function save_and_refresh()
  if state.paths and state.doc then
    Model.save_file(state.paths.json, state.doc)
    Model.export_mermaid(state.paths.mermaid, state.doc, state.paths.markdown)
  end
  M.refresh()
end

local function current_view()
  return Model.scoped_view(state.doc, state.scope_id)
end

local function render_lines(doc)
  local view = Model.scoped_view(doc, state.scope_id)
  state.scope_id = view.scope_id
  local nodes = view.nodes or {}
  if state.selected_idx < 1 then state.selected_idx = 1 end
  if state.selected_idx > #nodes then state.selected_idx = math.max(1, #nodes) end
  local sel_idx = state.selected_idx
  local active = nodes[sel_idx]

  local incoming_set, outgoing_set = {}, {}
  local incoming_list, outgoing_list = {}, {}
  if active then
    incoming_list, outgoing_list = Model.neighbors_in_view(view, active.id)
    for _, item in ipairs(incoming_list) do
      incoming_set[item.edge.from] = item.edge
    end
    for _, item in ipairs(outgoing_list) do
      outgoing_set[item.edge.to] = item.edge
    end
  end

  local crumbs = {}
  for _, c in ipairs(view.breadcrumbs or {}) do
    crumbs[#crumbs + 1] = c.label
  end

  local tiers = { [1] = {}, [2] = {}, [3] = {}, [4] = {} }
  for idx, n in ipairs(nodes) do
    local t = Model.kind_meta(n.kind).tier or 3
    tiers[t][#tiers[t] + 1] = { idx = idx, node = n }
  end

  local col_w = 25
  local headers = {
    pad_display("1. Клиенты / Точки входа", col_w),
    pad_display("2. Шлюзы / Ядро / gRPC", col_w),
    pad_display("3. Сервисы / Модули", col_w),
    pad_display("4. Данные / Шины / Таблицы", col_w),
  }

  local lines = {
    "🏗️  " .. (doc.title or "Архитектура приложения")
      .. ("   [на уровне: %d · всего в схеме: %d узлов, %d связей]"):format(#nodes, #(doc.nodes or {}), #(doc.edges or {})),
    "🧭 Уровень C4: " .. table.concat(crumbs, "  ›  ") .. "    (l/zi внутрь ⊞ · h/BS/zo наверх)",
    "Клавиши: j/k выбор · Enter к коду · l/h C4-зум · a +узел · c +связь · s скан · S LSP · g ИИ-схема · R ИИ-ревью · w Web · m Mermaid · q выход",
    string.rep("═", 108),
    table.concat(headers, " │ "),
    string.rep("─", col_w) .. "─┼─" .. string.rep("─", col_w) .. "─┼─" .. string.rep("─", col_w) .. "─┼─" .. string.rep("─", col_w),
  }

  local max_rows = 1
  for t = 1, 4 do
    if #tiers[t] > max_rows then
      max_rows = #tiers[t]
    end
  end
  max_rows = math.min(max_rows, 12)

  for r = 1, max_rows do
    local row_cells = {}
    for t = 1, 4 do
      local slot = tiers[t][r]
      if not slot then
        row_cells[t] = string.rep(" ", col_w)
      else
        local km = Model.kind_meta(slot.node.kind)
        local kids = Model.child_count(doc, slot.node.id)
        local badge = " "
        if active and slot.node.id == active.id then
          badge = "▶"
        elseif incoming_set[slot.node.id] then
          badge = "◀"
        elseif outgoing_set[slot.node.id] then
          badge = "→"
        end
        local c4_tag = kids > 0 and (" ⊞" .. kids) or ""
        local text = ("%s[%s %s%s]"):format(badge, km.icon, slot.node.label, c4_tag)
        row_cells[t] = pad_display(text, col_w)
      end
    end
    lines[#lines + 1] = table.concat(row_cells, " │ ")
  end
  for t = 1, 4 do
    if #tiers[t] > max_rows then
      lines[#lines + 1] = ("  … ещё %d элемент(ов) в слое %d (полный список ниже и в :ArchWeb)"):format(#tiers[t] - max_rows, t)
    end
  end

  lines[#lines + 1] = string.rep("═", 108)

  if active then
    local km = Model.kind_meta(active.kind)
    local kids = Model.child_count(doc, active.id)
    local zoom_hint = kids > 0 and (" · ⊞ вложенных узлов: " .. kids .. " (нажми `l` для входа)") or ""
    lines[#lines + 1] = ("🎯 Выбран [%d/%d]: %s %s  (`%s`)%s"):format(
      sel_idx, #nodes, km.icon, active.label, active.id, zoom_hint
    )
    lines[#lines + 1] = ("   Роль: %s   · Стек: %s   · Путь: %s"):format(
      km.label,
      active.tech ~= "" and active.tech or "—",
      active.path ~= "" and active.path or "(не задан — нажми `p`)"
    )
    if active.summary ~= "" then
      lines[#lines + 1] = "   Описание: " .. active.summary
    end
    if active.contracts and #active.contracts > 0 then
      lines[#lines + 1] = "   📜 Контракты / API: " .. table.concat(active.contracts, "  ·  ")
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = ("   Входящие связи на этом уровне (%d):"):format(#incoming_list)
    if #incoming_list == 0 then
      lines[#lines + 1] = "     · нет входящих стрелок"
    else
      for _, it in ipairs(incoming_list) do
        local em = Model.edge_meta(it.edge.kind)
        local from_lbl = it.peer and it.peer.label or it.edge.from
        local tag = it.edge.label ~= "" and (" [" .. it.edge.label .. "]") or ""
        local rollup = it.edge.rolled_up and " (агрег. C4)" or ""
        lines[#lines + 1] = ("     ◀── %s (%s)%s  {%s}%s"):format(from_lbl, it.edge.from, tag, em.id, rollup)
      end
    end

    lines[#lines + 1] = ("   Исходящие связи на этом уровне (%d):"):format(#outgoing_list)
    if #outgoing_list == 0 then
      lines[#lines + 1] = "     · нет исходящих стрелок (нажми `c`, чтобы соединить)"
    else
      for _, it in ipairs(outgoing_list) do
        local em = Model.edge_meta(it.edge.kind)
        local to_lbl = it.peer and it.peer.label or it.edge.to
        local tag = it.edge.label ~= "" and (" [" .. it.edge.label .. "]") or ""
        local rollup = it.edge.rolled_up and " (агрег. C4)" or ""
        lines[#lines + 1] = ("     %s %s (%s)%s  {%s}%s"):format(em.arrow, to_lbl, it.edge.to, tag, em.id, rollup)
      end
    end
  else
    lines[#lines + 1] = "На этом C4-уровне пока нет компонентов. Нажми `a` для добавления или `h`/`BS` чтобы вернуться выше."
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "📋 Компоненты текущего уровня (j/k выбор · l внутрь ⊞ · h наверх · Enter к коду):"
  for idx, n in ipairs(nodes) do
    local km = Model.kind_meta(n.kind)
    local kids = Model.child_count(doc, n.id)
    local mark = (idx == sel_idx) and " ▶ " or "   "
    local c4 = kids > 0 and (" [⊞" .. kids .. "]") or ""
    local p = (n.path and n.path ~= "") and ("  → " .. n.path) or ""
    lines[#lines + 1] = ("%s%2d. %s %-28s [%s]%s%s"):format(mark, idx, km.icon, n.label, n.id, c4, p)
  end

  return lines
end

function M.refresh()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) or not state.doc then
    return
  end
  local lines = render_lines(state.doc)
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false

  if not ns_id and vim.api.nvim_create_namespace then
    ns_id = vim.api.nvim_create_namespace("UserArchBoard")
  end
  if ns_id and vim.api.nvim_buf_clear_namespace then
    vim.api.nvim_buf_clear_namespace(state.buf, ns_id, 0, -1)
    pcall(vim.api.nvim_buf_add_highlight, state.buf, ns_id, "Title", 0, 0, -1)
    pcall(vim.api.nvim_buf_add_highlight, state.buf, ns_id, "Directory", 1, 0, -1)
    pcall(vim.api.nvim_buf_add_highlight, state.buf, ns_id, "Comment", 2, 0, -1)
    for i, line in ipairs(lines) do
      if line:match("^ ▶ ") or line:match("^🎯") then
        pcall(vim.api.nvim_buf_add_highlight, state.buf, ns_id, "Visual", i - 1, 0, -1)
      end
    end
  end
end

function M.reload_from_disk()
  if state.paths then
    local loaded = Model.load_file(state.paths.json)
    if loaded then
      state.doc = loaded
      M.refresh()
    end
  end
end

local function active_node()
  local view = current_view()
  return view.nodes[state.selected_idx], view
end

local function zoom_in_c4()
  local active = active_node()
  if not active then return end
  local kids = Model.child_count(state.doc, active.id)
  if kids == 0 then
    vim.notify("У «" .. active.label .. "» пока нет вложенных C4-элементов (можно войти принудительно через `zi` и нажать `a`).", vim.log.levels.INFO)
    return
  end
  state.scope_id = active.id
  state.selected_idx = 1
  M.refresh()
end

local function zoom_in_force()
  local active = active_node()
  if not active then return end
  state.scope_id = active.id
  state.selected_idx = 1
  M.refresh()
end

local function zoom_out_c4()
  if not state.scope_id or state.scope_id == "" then
    return
  end
  local prev_scope = state.scope_id
  local cur_container = Model.find_node(state.doc, prev_scope)
  state.scope_id = (cur_container and cur_container.parent_id) or ""
  local view = current_view()
  state.selected_idx = 1
  for idx, n in ipairs(view.nodes) do
    if n.id == prev_scope then
      state.selected_idx = idx
      break
    end
  end
  M.refresh()
end

local function jump_to_selected_code()
  local active = active_node()
  if not active then return end
  if not active.path or active.path == "" then
    vim.notify("У компонента «" .. active.label .. "» не задан путь в коде. Нажми `p`, чтобы привязать файл/папку.", vim.log.levels.INFO)
    return
  end
  local target = active.path
  if target:sub(1, 1) ~= "/" then
    target = (state.root or Model.project_root()) .. "/" .. target
  end
  if vim.fn.filereadable(target) == 1 or vim.fn.isdirectory(target) == 1 then
    close_board()
    vim.cmd("edit " .. vim.fn.fnameescape(target))
  else
    vim.notify("Путь не найден на диске: " .. target, vim.log.levels.WARN)
  end
end

local function prompt_add_node()
  vim.ui.select(Model.KINDS, {
    prompt = "Роль нового компонента (на текущем C4-уровне):",
    format_item = function(item) return item.icon .. " " .. item.label .. " (" .. item.id .. ")" end,
  }, function(kind_choice)
    if not kind_choice then return end
    vim.ui.input({ prompt = "Название компонента: " }, function(label)
      if not label or vim.trim(label) == "" then return end
      vim.ui.input({ prompt = "Путь к коду в проекте (необязательно): " }, function(path)
        vim.ui.input({ prompt = "Технология / стек (необязательно): " }, function(tech)
          Model.upsert_node(state.doc, {
            label = label,
            kind = kind_choice.id,
            parent_id = state.scope_id or "",
            path = path or "",
            tech = tech or "",
          })
          local view = current_view()
          state.selected_idx = #view.nodes
          save_and_refresh()
        end)
      end)
    end)
  end)
end

local function prompt_edit_node()
  local active = active_node()
  if not active then return end
  vim.ui.input({ prompt = "Новое название: ", default = active.label }, function(label)
    if not label or vim.trim(label) == "" then return end
    vim.ui.input({ prompt = "Технология / стек: ", default = active.tech or "" }, function(tech)
      vim.ui.input({ prompt = "Краткое описание: ", default = active.summary or "" }, function(summary)
        active.label = vim.trim(label)
        active.tech = vim.trim(tech or "")
        active.summary = vim.trim(summary or "")
        save_and_refresh()
      end)
    end)
  end)
end

local function prompt_bind_path()
  local active = active_node()
  if not active then return end
  vim.ui.input({
    prompt = "Путь к файлу или папке компонента «" .. active.label .. "»: ",
    default = active.path or "",
  }, function(path)
    if path == nil then return end
    active.path = vim.trim(path)
    save_and_refresh()
  end)
end

local function prompt_connect_from_selected()
  local active, view = active_node()
  if not active then return end
  local candidates = {}
  for _, n in ipairs(view.nodes) do
    if n.id ~= active.id then
      candidates[#candidates + 1] = n
    end
  end
  if #candidates == 0 then
    vim.notify("На этом C4-уровне меньше 2 компонентов — добавь ещё один (`a`).", vim.log.levels.INFO)
    return
  end
  vim.ui.select(candidates, {
    prompt = "Куда направить связь от «" .. active.label .. "»:",
    format_item = function(n)
      return Model.kind_meta(n.kind).icon .. " " .. n.label .. " (" .. n.id .. ")"
    end,
  }, function(target)
    if not target then return end
    vim.ui.select(Model.EDGE_KINDS, {
      prompt = "Тип связи:",
      format_item = function(ek) return ek.arrow .. " " .. ek.label end,
    }, function(ek)
      if not ek then return end
      vim.ui.input({ prompt = "Подпись протокола/события (REST, gRPC, SQL, Kafka): " }, function(lbl)
        Model.add_edge(state.doc, active.id, target.id, lbl or "", ek.id)
        save_and_refresh()
      end)
    end)
  end)
end

local function prompt_remove_edge()
  local active = active_node()
  if not active then return end
  local related = {}
  for idx, e in ipairs(state.doc.edges or {}) do
    if e.from == active.id or e.to == active.id then
      related[#related + 1] = { index = idx, edge = e }
    end
  end
  if #related == 0 then
    vim.notify("У выбранного компонента нет прямых связей (если связь агрегирована C4 — нажми `l` чтобы войти внутрь).", vim.log.levels.INFO)
    return
  end
  vim.ui.select(related, {
    prompt = "Удалить связь:",
    format_item = function(item)
      local em = Model.edge_meta(item.edge.kind)
      local lbl = item.edge.label ~= "" and (" [" .. item.edge.label .. "]") or ""
      return ("%s %s %s%s"):format(item.edge.from, em.arrow, item.edge.to, lbl)
    end,
  }, function(choice)
    if not choice then return end
    Model.remove_edge(state.doc, choice.index)
    save_and_refresh()
  end)
end

local function bind_keys(buf)
  local opts = { buffer = buf, nowait = true, silent = true }
  local function step(delta)
    local view = current_view()
    local count = #view.nodes
    if count == 0 then return end
    state.selected_idx = ((state.selected_idx - 1 + delta) % count) + 1
    M.refresh()
  end

  vim.keymap.set("n", "q", close_board, opts)
  vim.keymap.set("n", "<Esc>", close_board, opts)
  vim.keymap.set("n", "<Tab>", function() step(1) end, opts)
  vim.keymap.set("n", "<S-Tab>", function() step(-1) end, opts)
  vim.keymap.set("n", "j", function() step(1) end, opts)
  vim.keymap.set("n", "k", function() step(-1) end, opts)
  vim.keymap.set("n", "l", zoom_in_c4, opts)
  vim.keymap.set("n", "<Right>", zoom_in_c4, opts)
  vim.keymap.set("n", "zi", zoom_in_force, opts)
  vim.keymap.set("n", "h", zoom_out_c4, opts)
  vim.keymap.set("n", "<Left>", zoom_out_c4, opts)
  vim.keymap.set("n", "<BS>", zoom_out_c4, opts)
  vim.keymap.set("n", "zo", zoom_out_c4, opts)
  vim.keymap.set("n", "<CR>", jump_to_selected_code, opts)
  vim.keymap.set("n", "gf", jump_to_selected_code, opts)
  vim.keymap.set("n", "a", prompt_add_node, opts)
  vim.keymap.set("n", "e", prompt_edit_node, opts)
  vim.keymap.set("n", "p", prompt_bind_path, opts)
  vim.keymap.set("n", "c", prompt_connect_from_selected, opts)
  vim.keymap.set("n", "x", prompt_remove_edge, opts)
  vim.keymap.set("n", "d", function()
    local active = active_node()
    if not active then return end
    Model.remove_node(state.doc, active.id)
    local view = current_view()
    if state.selected_idx > #view.nodes then
      state.selected_idx = math.max(1, #view.nodes)
    end
    save_and_refresh()
  end, opts)
  vim.keymap.set("n", "=", function()
    Model.auto_layout(state.doc, state.scope_id)
    save_and_refresh()
  end, opts)

  local function nudge(dx, dy)
    local active = active_node()
    if not active then return end
    active.x = (tonumber(active.x) or 0) + dx
    active.y = (tonumber(active.y) or 0) + dy
    save_and_refresh()
  end
  vim.keymap.set("n", "H", function() nudge(-40, 0) end, opts)
  vim.keymap.set("n", "L", function() nudge(40, 0) end, opts)
  vim.keymap.set("n", "K", function() nudge(0, -30) end, opts)
  vim.keymap.set("n", "J", function() nudge(0, 30) end, opts)

  vim.keymap.set("n", "s", function()
    state.doc = Scan.scan_project(state.root)
    state.scope_id = ""
    state.selected_idx = 1
    save_and_refresh()
    Scan.enrich_from_lsp(state.doc, state.root, function(updated, added)
      if added and added > 0 then
        state.doc = updated
        save_and_refresh()
      end
    end)
    vim.notify(("Архитектура просканирована: %d узлов, %d связей"):format(#state.doc.nodes, #state.doc.edges), vim.log.levels.INFO)
  end, opts)

  vim.keymap.set("n", "S", function()
    Scan.enrich_from_lsp(state.doc, state.root, function(updated, added, why)
      if why then
        vim.notify("LSP-скан: " .. why, vim.log.levels.INFO)
        return
      end
      state.doc = updated
      save_and_refresh()
      vim.notify("LSP добавил символов в контракты: " .. tostring(added), vim.log.levels.INFO)
    end)
  end, opts)

  vim.keymap.set("n", "g", function()
    require("config.architecture_ai").draft(nil, state.root)
  end, opts)

  vim.keymap.set("n", "R", function()
    require("config.architecture_ai").review(state.root)
  end, opts)

  vim.keymap.set("n", "m", function()
    Model.export_mermaid(state.paths.mermaid, state.doc, state.paths.markdown)
    close_board()
    vim.cmd("edit " .. vim.fn.fnameescape(state.paths.markdown))
  end, opts)

  vim.keymap.set("n", "w", function()
    local ok_srv, Server = pcall(require, "config.architecture_server")
    if ok_srv and type(Server.open) == "function" then
      Server.open(state.root)
    end
  end, opts)

  vim.keymap.set("n", "r", M.reload_from_disk, opts)
end

function M.set_scope(scope_id)
  state.scope_id = scope_id or ""
  state.selected_idx = 1
  M.refresh()
end

--- Открыть доску архитектуры и сфокусироваться на конкретном компоненте `node_id`
--- (автоматически переходя внутрь его родительского C4-контейнера, если он вложенный).
function M.focus_node(node_id, root)
  M.open(root)
  if not state.doc or not node_id or node_id == "" then
    return false
  end
  local target = Model.find_node(state.doc, node_id)
  if not target then
    return false
  end
  state.scope_id = target.parent_id or ""
  local view = Model.scoped_view(state.doc, state.scope_id)
  for idx, n in ipairs(view.nodes or {}) do
    if n.id == target.id then
      state.selected_idx = idx
      break
    end
  end
  M.refresh()
  return true
end

function M.open(root, scope_id)
  state.root = root or Model.project_root()
  if scope_id ~= nil then
    state.scope_id = scope_id
  end
  local doc, paths = Model.ensure_project_file(state.root)
  state.doc = doc
  state.paths = paths

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].buftype = "nofile"
    vim.bo[state.buf].bufhidden = "wipe"
    vim.bo[state.buf].swapfile = false
    vim.bo[state.buf].filetype = "nvimarchboard"
    bind_keys(state.buf)
  end

  local has_ui = type(vim.api.nvim_list_uis) == "function" and #vim.api.nvim_list_uis() > 0
  if has_ui and type(vim.api.nvim_open_win) == "function" then
    local cols = (vim.o and vim.o.columns and vim.o.columns > 40) and vim.o.columns or 120
    local rows = (vim.o and vim.o.lines and vim.o.lines > 16) and vim.o.lines or 36
    local width = math.min(math.max(96, math.floor(cols * 0.92)), math.max(40, cols - 4))
    local height = math.min(math.max(22, math.floor(rows * 0.86)), math.max(12, rows - 4))
    local cfg = {
      relative = "editor",
      width = width,
      height = height,
      row = math.max(0, math.floor((rows - height) / 2)),
      col = math.max(0, math.floor((cols - width) / 2)),
      style = "minimal",
      border = "rounded",
      title = " 🏗️ Визуальная архитектура C4 и связи (:ArchBoard) ",
      title_pos = "center",
    }
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      pcall(vim.api.nvim_win_set_config, state.win, cfg)
      vim.api.nvim_set_current_win(state.win)
    else
      state.win = vim.api.nvim_open_win(state.buf, true, cfg)
    end
    vim.wo[state.win].wrap = false
    vim.wo[state.win].cursorline = true
  else
    if not (state.win and vim.api.nvim_win_is_valid(state.win)) then
      vim.cmd("botright new")
      state.win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(state.win, state.buf)
    end
  end

  M.refresh()
end

return M
