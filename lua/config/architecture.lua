-- Небольшой прототип конструктора архитектуры: Mermaid в обычном Markdown.
-- Меню добавляет узлы и стрелки, браузер показывает схему; файлы не сохраняются
-- автоматически и никакой код проекта или данные не отправляются ИИ.
local M = {}

local START = "<!-- nvim-architecture:start -->"
local FINISH = "<!-- nvim-architecture:end -->"
local BLOCK = {
  START,
  "```mermaid",
  "graph LR",
  '  N1["Клиент"]',
  '  N2["API"]',
  '  N3["База данных"]',
  '  N1 -->|"HTTP"| N2',
  '  N2 -->|"SQL"| N3',
  "```",
  FINISH,
}

-- INFO/WARN-уведомления отфильтрованы конфигом, поэтому результаты команды
-- показываем через echo. Ошибки остаются в :messages.
local function say(message, warning)
  vim.api.nvim_echo({ { "Архитектура: " .. message, warning and "WarningMsg" or "None" } }, true, {})
end

local function valid_buffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
    return false, "буфер закрыт; открой схему заново."
  end
  if not vim.bo[buf].modifiable then return false, "буфер нельзя редактировать." end
  return true
end

-- Наша схема ограничена явными маркерами: чужие Mermaid-блоки не трогаем.
-- Меню видит узлы своего простого формата N1["Имя"], но Mermaid можно править
-- вручную. Повторные/сломанные маркеры не пытаемся чинить автоматически.
local function scan(buf)
  local ok, reason = valid_buffer(buf)
  if not ok then return nil, reason end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local start, finish, starts, finishes = nil, nil, 0, 0
  for i, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed == START then start, starts = i, starts + 1 end
    if trimmed == FINISH then finish, finishes = i, finishes + 1 end
  end
  if starts ~= 1 or finishes ~= 1 or start >= finish then
    return nil, "нужен один блок схемы с маркерами. Создай :ArchNew или добавь :ArchInsert."
  end
  if vim.trim(lines[start + 1] or "") ~= "```mermaid"
    or not (lines[start + 2] or ""):match("^%s*graph%s+[A-Z]+%s*$")
    or vim.trim(lines[finish - 1] or "") ~= "```" then
    return nil, "блок схемы повреждён: проверь строки ```mermaid, graph и закрывающую ```."
  end
  local result = { insert_at = finish - 2, nodes = {}, by_id = {}, used = {} }
  for i = start + 3, finish - 2 do
    local line = lines[i]
    if line:match("^%s*```") then return nil, "внутри схемы найдена лишняя закрывающая ``` ." end
    for id in line:gmatch("%f[%w_]N%d+%f[^%w_]") do result.used[id] = true end
    local id, label = line:match('^%s*(N%d+)%s*%["(.-)"%]%s*$')
    if id then
      if result.by_id[id] then return nil, "повторяется идентификатор " .. id .. "." end
      local display = label:gsub("#quot;", '"'):gsub("#124;", "|"):gsub("#60;", "<")
        :gsub("#62;", ">"):gsub("#38;", "&"):gsub("#35;", "#")
      local node = { id = id, label = display }
      result.nodes[#result.nodes + 1] = node
      result.by_id[id] = node
    end
  end
  return result
end

-- Синтаксис Mermaid позволяет кодировать специальные символы через #...;.
-- Это защищает кавычки, подписи стрелок и HTML от поломки диаграммы.
local function encode(text, required)
  text = vim.trim(text or "")
  if required and text == "" then return nil, "название не должно быть пустым." end
  if #text > 512 or text:find("[%z\1-\31\127]") then
    return nil, "используй одну строку без управляющих символов, не длиннее 512 байт."
  end
  return (text:gsub("#", "#35;"):gsub("&", "#38;"):gsub('"', "#quot;")
    :gsub("|", "#124;"):gsub("<", "#60;"):gsub(">", "#62;"))
end

local function insert_lines(buf, at, lines)
  local ok, err = pcall(vim.api.nvim_buf_set_lines, buf, at, at, false, lines)
  if not ok then say("не удалось изменить буфер: " .. tostring(err), true) end
  return ok
end

--- Добавить размеченный блок в конец текущего Markdown, не меняя остальной текст.
function M.insert()
  local buf = vim.api.nvim_get_current_buf()
  local ok, reason = valid_buffer(buf)
  if not ok then return say(reason, true) end
  if vim.bo[buf].filetype ~= "markdown" then return say("открой Markdown-файл (.md).", true) end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed == START or trimmed == FINISH then
      return say("маркеры схемы уже есть; второй блок не добавлен.", true)
    end
  end
  local addition = { "" }
  for _, line in ipairs(BLOCK) do addition[#addition + 1] = line end
  if insert_lines(buf, #lines, addition) then say("схема добавлена в буфер. Сохрани файл через :w.") end
end

--- Новый файл без автоматической записи и без перезаписи существующего файла.
function M.new(path)
  if not path or path == "" then
    return vim.ui.input({ prompt = "Файл архитектуры: ", default = "architecture.md", completion = "file" }, function(value)
      if value and value ~= "" then M.new(value) end
    end)
  end
  path = vim.trim(path)
  if path == "" or path:find("[%z\r\n]") then return say("неверное имя файла.", true) end
  if path:sub(1, 2) == "~/" then path = vim.fn.expand("~") .. path:sub(2) end
  local absolute = vim.fn.fnamemodify(path, ":p")
  local existing_buf
  -- bufnr(path) может трактовать имя как шаблон и сопоставить другой буфер.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == absolute then
      existing_buf = buf
      break
    end
  end
  if existing_buf == vim.api.nvim_get_current_buf() then
    return say("файл или буфер уже открыт без изменений. Для новой схемы используй :ArchInsert.")
  end
  local existing = vim.uv.fs_lstat(absolute) ~= nil or existing_buf ~= nil
  local ok, err = pcall(function() vim.cmd.edit({ args = { absolute } }) end)
  if not ok then return say("не удалось открыть файл: " .. tostring(err), true) end
  if existing then return say("файл или буфер уже существует: открыт без изменений. Для новой схемы используй :ArchInsert.") end
  local buf = vim.api.nvim_get_current_buf()
  local can_edit, reason = valid_buffer(buf)
  if not can_edit then return say(reason, true) end
  if vim.bo[buf].filetype ~= "markdown" then vim.bo[buf].filetype = "markdown" end
  -- Страховка от автокоманд открытия и FileType, которые могли менять буфер.
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if vim.bo[buf].modified or #lines ~= 1 or lines[1] ~= "" then
    return say("новый буфер уже содержит изменения; ничего не перезаписано.", true)
  end
  local template = { "# Архитектура приложения", "" }
  for _, line in ipairs(BLOCK) do template[#template + 1] = line end
  local written, write_err = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, template)
  if not written then return say("не удалось создать черновик: " .. tostring(write_err), true) end
  say("создан черновик. Сохрани через :w; превью — :ArchPreview.")
end

--- Добавить компонент по имени, идентификатор присваивается автоматически.
function M.add_node()
  local buf = vim.api.nvim_get_current_buf()
  local diagram, reason = scan(buf)
  if not diagram then return say(reason, true) end
  vim.ui.input({ prompt = "Название компонента: " }, function(label)
    if label == nil then return end
    local text, err = encode(label, true)
    if not text then return say(err, true) end
    -- Буфер мог измениться, пока был открыт ввод.
    local current, scan_err = scan(buf)
    if not current then return say(scan_err, true) end
    local n = 1
    while current.used["N" .. n] do n = n + 1 end
    if insert_lines(buf, current.insert_at, { ('  N%d["%s"]'):format(n, text) }) then
      say("компонент добавлен; сохрани через :w.")
    end
  end)
end

--- Выбрать начало, конец и необязательную подпись направленной связи.
function M.add_link()
  local buf = vim.api.nvim_get_current_buf()
  local diagram, reason = scan(buf)
  if not diagram then return say(reason, true) end
  if #diagram.nodes == 0 then return say("сначала добавь компонент через :ArchNode.", true) end
  local function display(node) return node.label .. " (" .. node.id .. ")" end
  vim.ui.select(diagram.nodes, { prompt = "Связь: откуда?", format_item = display }, function(source)
    if not source then return end
    local current, scan_err = scan(buf)
    if not current or not current.by_id[source.id] or current.by_id[source.id].label ~= source.label then
      return say(scan_err or "исходный компонент изменился или удалён; выбери связь заново.", true)
    end
    vim.ui.select(current.nodes, { prompt = "Связь: куда?", format_item = display }, function(target)
      if not target then return end
      vim.ui.input({ prompt = "Подпись связи (Enter — без подписи): " }, function(label)
        if label == nil then return end
        local text, err = encode(label, false)
        if not text then return say(err, true) end
        local latest, latest_err = scan(buf)
        if not latest then return say(latest_err, true) end
        if not latest.by_id[source.id] or not latest.by_id[target.id]
          or latest.by_id[source.id].label ~= source.label or latest.by_id[target.id].label ~= target.label then
          return say("один из компонентов изменился или удалён; выбери связь заново.", true)
        end
        local arrow = text == "" and " --> " or (' -->|"' .. text .. '"| ')
        if insert_lines(buf, latest.insert_at, { "  " .. source.id .. arrow .. target.id }) then
          say("связь добавлена; сохрани через :w.")
        end
      end)
    end)
  end)
end

--- Графическое превью даёт уже используемый markdown-preview.nvim, не MdPreview.
function M.preview()
  if vim.bo.filetype ~= "markdown" then return say("открой Markdown-файл со схемой.", true) end
  local ok, err = pcall(function() vim.cmd.MarkdownPreview() end)
  if not ok then
    say("не удалось открыть MarkdownPreview: " .. tostring(err)
      .. "\nНужны Node.js/npm и собранный markdown-preview.nvim: :Lazy build markdown-preview.nvim.", true)
  end
end

function M.menu()
  local choices = {
    { name = "Создать файл схемы", run = M.new },
    { name = "Добавить схему в текущий Markdown", run = M.insert },
    { name = "Добавить компонент", run = M.add_node },
    { name = "Соединить компоненты", run = M.add_link },
    { name = "Открыть визуальное превью", run = M.preview },
  }
  vim.ui.select(choices, { prompt = "Архитектура приложения", format_item = function(item) return item.name end }, function(item)
    if item then item.run() end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("ArchMenu", M.menu, { desc = "Меню схемы архитектуры" })
  vim.api.nvim_create_user_command("ArchNew", function(o) M.new(o.fargs[1]) end, { nargs = "?", complete = "file", desc = "Создать Markdown-схему архитектуры" })
  vim.api.nvim_create_user_command("ArchInsert", M.insert, { desc = "Добавить схему в текущий Markdown" })
  vim.api.nvim_create_user_command("ArchNode", M.add_node, { desc = "Добавить компонент архитектуры" })
  vim.api.nvim_create_user_command("ArchLink", M.add_link, { desc = "Соединить компоненты" })
  vim.api.nvim_create_user_command("ArchPreview", M.preview, { desc = "Открыть схему в браузере" })
  vim.keymap.set("n", "<leader>mA", M.menu, { desc = "📐 Архитектура приложения" })
end

return M
