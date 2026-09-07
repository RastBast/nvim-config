-- ========================================================================== --
--      УМНЫЙ GO: ФОРМОЧКА STRUCT (как в VSCode) + АВТОЗАПОЛНЕНИЕ ПОЛЕЙ       --
-- ========================================================================== --
-- fill_struct()  — «формочка»: выбираешь struct (красивый пикер через
--                  dressing), вставляется снаркет с ВСЕМИ полями, курсор
--                  прыгает по значениям (<Tab>/<S-Tab>), дефолты —
--                  нулевые значения Go по типу поля.
-- add_fields()   — автодополнение полей: берёт struct под/над курсором
--                  (или пикер) и вставляет поля со значениями.
-- Всё на treesitter-парсере `go` (уже ставится).
local M = {}

-- ---------- нулевые значения Go по типу ----------

function M.zero_for(typ)
  typ = (typ or ""):gsub("%s+", "")
  if typ == "" then
    return nil
  end
  if typ:match("^%*") or typ:match("^%[") or typ:match("^map%[") then
    return "nil"
  end
  if typ == "string" then
    return '""'
  end
  if typ == "bool" then
    return "false"
  end
  if typ:match("^int") or typ:match("^uint") or typ:match("^float")
    or typ:match("^byte$") or typ:match("^rune$") then
    return "0"
  end
  if typ == "error" or typ:match("^interface") or typ:match("^func%(") then
    return "nil"
  end
  return nil -- неизвестный тип → пустой плейсхолдер, заполнит человек
end

-- ---------- treesitter: struct'ы буфера ----------

local function parse_go()
  local parser = vim.treesitter.get_parser(0, "go")
  if not parser then
    return nil
  end
  local tree = parser:parse()[1]
  return tree and tree:root()
end

--- Имена всех struct в текущем буфере.
function M.struct_names()
  local root = parse_go()
  if not root then
    return {}
  end
  local ok, q = pcall(
    vim.treesitter.query.parse,
    "go",
    "(type_declaration (type_spec (type_identifier) @name (struct_type)))"
  )
  if not ok then
    return {}
  end
  local names, seen = {}, {}
  for _, node in q:iter_captures(root, 0) do
    local n = vim.treesitter.get_node_text(node, 0)
    if n ~= "" and not seen[n] then
      seen[n] = true
      names[#names + 1] = n
    end
  end
  return names
end

--- Поля struct'а: { {name=..., type=...}, ... }
function M.fields_of(name)
  local root = parse_go()
  if not root then
    return {}
  end
  local ok, q = pcall(
    vim.treesitter.query.parse,
    "go",
    "(type_declaration (type_spec (type_identifier) @name (struct_type) @body))"
  )
  if not ok then
    return {}
  end
  local fields = {}
  local bodies = {}
  for id, node in q:iter_captures(root, 0) do
    local cap = q.captures[id]
    if cap == "name" then
      bodies[vim.treesitter.get_node_text(node, 0)] = bodies[vim.treesitter.get_node_text(node, 0)] or node:parent()
    end
  end
  -- найдём тело нужного struct'а
  local ok2, q2 = pcall(vim.treesitter.query.parse, "go", "(type_spec (struct_type) @sb)")
  if not ok2 then
    return {}
  end
  local target = nil
  for _, spec in q2:iter_captures(root, 0) do
    local name_node = spec:child(0)
    if name_node and vim.treesitter.get_node_text(name_node, 0) == name then
      target = spec
      break
    end
  end
  if not target then
    return {}
  end
  local ok3, q3 = pcall(vim.treesitter.query.parse, "go", "(field_declaration) @fd")
  if not ok3 then
    return {}
  end
  for _, fd in q3:iter_captures(target, 0) do
    local fname, ftype = nil, {}
    for child in fd:iter_children() do
      if child:named() then
        if child:type() == "field_identifier" and not fname then
          fname = vim.treesitter.get_node_text(child, 0)
        elseif child:type() ~= "field_identifier" then
          ftype[#ftype + 1] = vim.treesitter.get_node_text(child, 0)
        end
      end
    end
    if fname then
      fields[#fields + 1] = { name = fname, type = table.concat(ftype, " ") }
    end
  end
  return fields
end

--- Имя struct'а, ближайшего над курсором (или первый в файле).
function M.nearest_struct()
  local names = M.struct_names()
  if #names == 0 then
    return nil
  end
  local root = parse_go()
  if not root then
    return names[1]
  end
  local cur = vim.api.nvim_win_get_cursor(0)
  local cur_row = cur[1] - 1
  local best, best_row = names[1], -1
  local ok, q = pcall(
    vim.treesitter.query.parse,
    "go",
    "(type_declaration (type_spec (type_identifier) @name (struct_type)))"
  )
  if ok then
    for _, node in q:iter_captures(root, 0) do
      local n = vim.treesitter.get_node_text(node, 0)
      local r = node:start()
      if r <= cur_row and r > best_row then
        best, best_row = n, r
      end
    end
  end
  return best
end

-- ---------- вставка сниппет-тела ----------

local function insert_lsp_snippet(body)
  local ok, ls = pcall(require, "luasnip")
  if ok and ls.lsp_expand then
    ls.lsp_expand(body)
  else
    vim.api.nvim_put(vim.split(body, "\n", { plain = true }), "c", true, true)
  end
end

--- Тело сниппета «формочки» для struct'а: Name{ \n\tField: ${i:zero}, ... }
function M.struct_snippet_body(name)
  local fields = M.fields_of(name)
  if #fields == 0 then
    return nil
  end
  local lines = { name .. " {" }
  for idx, f in ipairs(fields) do
    local zero = M.zero_for(f.type)
    if zero then
      lines[#lines + 1] = ("\t%s: ${%d:%s},"):format(f.name, idx, zero)
    else
      lines[#lines + 1] = ("\t%s: ${%d:},"):format(f.name, idx)
    end
  end
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n")
end

--- Формочка: выбрать struct → вставить сниппет с полями.
function M.fill_struct()
  local names = M.struct_names()
  if #names == 0 then
    vim.notify("В буфере нет struct (нужен treesitter-парсер go)", vim.log.levels.WARN)
    return
  end
  local choose = function(n)
    if not n then
      return
    end
    local body = M.struct_snippet_body(n)
    if body then
      insert_lsp_snippet(body)
    else
      vim.notify("У struct " .. n .. " нет полей", vim.log.levels.WARN)
    end
  end
  if #names == 1 then
    return choose(names[1])
  end
  -- dressing.nvim делает vim.ui.select красивым
  vim.ui.select(names, { prompt = "🧩 Заполнить struct: " }, choose)
end

--- Автодополнение полей struct'а под курсором.
function M.add_fields()
  local name = M.nearest_struct()
  if not name then
    return M.fill_struct()
  end
  local body = M.struct_snippet_body(name)
  if body then
    insert_lsp_snippet(body)
  end
end

return M
