-- ========================================================================== --
--   АРХИТЕКТУРА ПРИЛОЖЕНИЯ C4, КОНТРАКТЫ И ИИ (:Arch*, ОТДЕЛ <leader>C*)     --
-- ========================================================================== --
-- Отдельный раздел через <leader>C («🏗️ Архитектура C4 и связи»):
--   <leader>Cb — C4-доска архитектуры внутри Neovim (:ArchBoard)
--   <leader>Cw — интерактивный веб-холст drag-and-drop в браузере (:ArchWeb)
--   <leader>Cs — умный скан кода, .proto, OpenAPI, SQL (:ArchScan)
--   <leader>Cl — обогащение контрактов из LSP (:ArchLspScan)
--   <leader>Cd — ИИ-генерация / правка схемы (:ArchAiDraft)
--   <leader>Cr — аудит циклов зависимостей и ИИ-ревью (:ArchAiReview)
--   <leader>Cf — показать текущий открытый файл на C4-доске (:ArchFocusFile)
--   <leader>Cp — быстрое меню всех действий архитектуры (:ArchMenu)
--   <leader>Cn — добавить компонент (:ArchAddNode)
--   <leader>Cc — соединить два компонента связью (:ArchConnect)
--   <leader>Cm — экспорт в Mermaid + Markdown (:ArchMermaid)
--   <leader>Cj — открыть docs/architecture.json (:ArchJson)
--   <leader>Cx — остановить локальный сервер веб-холста (:ArchWebStop)
-- Также сохранены зеркала в главном меню (<leader>HC* и <leader>Haa) и <leader>mA*.
local M = {}

local setup_done = false

local function echo_info(msg, hl)
  if vim.api and type(vim.api.nvim_echo) == "function" then
    pcall(vim.api.nvim_echo, { { msg, hl or "MoreMsg" } }, true, {})
  end
end

function M.board()
  require("config.architecture_board").open()
end

function M.web()
  require("config.architecture_server").open()
end

function M.web_stop()
  require("config.architecture_server").stop()
  local msg = "⏹️ Локальный сервер ArchWeb остановлен"
  vim.notify(msg, vim.log.levels.INFO)
  echo_info(msg, "WarningMsg")
end

function M.scan()
  local Model = require("config.architecture_model")
  local Scan = require("config.architecture_scan")
  local root = Model.project_root()
  local paths = Model.default_paths(root)
  local doc = Scan.scan_project(root)
  Model.save_file(paths.json, doc)
  Model.export_mermaid(paths.mermaid, doc, paths.markdown)
  Scan.enrich_from_lsp(doc, root, function(updated, added)
    if added and added > 0 then
      Model.save_file(paths.json, updated)
      Model.export_mermaid(paths.mermaid, updated, paths.markdown)
      pcall(function() require("config.architecture_board").reload_from_disk() end)
    end
  end)
  local msg = ("🔍 Схема обновлена (код + .proto/OpenAPI/SQL): %d узлов, %d связей"):format(#doc.nodes, #doc.edges)
  vim.notify(msg, vim.log.levels.INFO)
  echo_info(msg, "MoreMsg")
  require("config.architecture_board").open(root, "")
end

function M.lsp_scan()
  local Model = require("config.architecture_model")
  local Scan = require("config.architecture_scan")
  local doc, paths = Model.ensure_project_file()
  Scan.enrich_from_lsp(doc, paths.root, function(updated, added, why)
    if why then
      local msg = "LSP-скан архитектуры: " .. why
      vim.notify(msg, vim.log.levels.INFO)
      echo_info(msg, "WarningMsg")
      return
    end
    Model.save_file(paths.json, updated)
    Model.export_mermaid(paths.mermaid, updated, paths.markdown)
    local msg = "🔎 LSP добавил символов в контракты: " .. tostring(added)
    vim.notify(msg, vim.log.levels.INFO)
    echo_info(msg, "MoreMsg")
    pcall(function() require("config.architecture_board").reload_from_disk() end)
  end)
end

function M.ai_draft(cmd_opts)
  local arg = type(cmd_opts) == "table" and cmd_opts.args or cmd_opts
  require("config.architecture_ai").draft(arg)
end

function M.ai_review()
  require("config.architecture_ai").review()
end

function M.export_mermaid()
  local Model = require("config.architecture_model")
  local doc, paths = Model.ensure_project_file()
  local ok, err = Model.export_mermaid(paths.mermaid, doc, paths.markdown)
  if not ok then
    vim.notify("Ошибка экспорта Mermaid: " .. tostring(err), vim.log.levels.ERROR)
    return
  end
  vim.cmd("edit " .. vim.fn.fnameescape(paths.markdown))
  local msg = "📐 Сгенерированы docs/architecture.mmd и docs/architecture.md"
  vim.notify(msg, vim.log.levels.INFO)
  echo_info(msg, "MoreMsg")
end

function M.open_json()
  local Model = require("config.architecture_model")
  local _, paths = Model.ensure_project_file()
  vim.cmd("edit " .. vim.fn.fnameescape(paths.json))
end

--- Найти текущий открытый буфер на C4-доске архитектуры и сфокусироваться на его карточке.
function M.focus_current_file()
  local Model = require("config.architecture_model")
  local Board = require("config.architecture_board")
  local buf_path = (vim.api and type(vim.api.nvim_buf_get_name) == "function" and vim.api.nvim_buf_get_name(0)) or ""
  local doc, paths = Model.ensure_project_file()
  local root = (paths.root or ""):gsub("/+$", "")

  if buf_path == "" then
    Board.open(paths.root, "")
    return
  end

  local function starts_with(s, prefix)
    return type(s) == "string" and type(prefix) == "string" and s:sub(1, #prefix) == prefix
  end

  local norm_buf = buf_path:gsub("\\", "/")
  local rel = norm_buf
  if root ~= "" and starts_with(norm_buf, root .. "/") then
    rel = norm_buf:sub(#root + 2)
  end

  local best_node = nil
  local best_score = -1
  for _, n in ipairs(doc.nodes or {}) do
    local np = type(n.path) == "string" and (n.path:gsub("\\", "/"):gsub("^%./", ""):gsub("/+$", "")) or ""
    if np ~= "" then
      if rel == np or norm_buf == np then
        local score = 1000 + #np
        if score > best_score then
          best_node = n
          best_score = score
        end
      elseif starts_with(rel, np .. "/") then
        local score = #np
        if score > best_score then
          best_node = n
          best_score = score
        end
      end
    end
  end

  if best_node then
    Board.focus_node(best_node.id, paths.root)
    local msg = ("🎯 Файл «%s» → компонент C4 «%s»"):format(rel, best_node.label)
    vim.notify(msg, vim.log.levels.INFO)
    echo_info(msg, "MoreMsg")
  else
    Board.open(paths.root, "")
    local msg = ("🏗️ Файл «%s» ещё не привязан к отдельному узлу — открыт верхний уровень C4 (нажми `s` для скана)"):format(rel)
    vim.notify(msg, vim.log.levels.INFO)
    echo_info(msg, "WarningMsg")
  end
end

function M.add_node()
  local Model = require("config.architecture_model")
  local doc, paths = Model.ensure_project_file()
  vim.ui.select(Model.KINDS, {
    prompt = "Роль компонента:",
    format_item = function(item) return item.icon .. " " .. item.label end,
  }, function(kind_choice)
    if not kind_choice then return end
    vim.ui.input({ prompt = "Название компонента: " }, function(label)
      if not label or vim.trim(label) == "" then return end
      vim.ui.input({ prompt = "Путь к коду в проекте (необязательно): " }, function(path)
        Model.upsert_node(doc, { label = label, kind = kind_choice.id, path = path or "" })
        Model.save_file(paths.json, doc)
        Model.export_mermaid(paths.mermaid, doc, paths.markdown)
        require("config.architecture_board").open(paths.root)
      end)
    end)
  end)
end

function M.connect_nodes()
  local Model = require("config.architecture_model")
  local doc, paths = Model.ensure_project_file()
  if #doc.nodes < 2 then
    vim.notify("В схеме меньше 2 компонентов — сначала добавь узел (:ArchAddNode)", vim.log.levels.WARN)
    return
  end
  vim.ui.select(doc.nodes, {
    prompt = "Источник связи (откуда):",
    format_item = function(n) return Model.kind_meta(n.kind).icon .. " " .. n.label .. " (" .. n.id .. ")" end,
  }, function(src)
    if not src then return end
    local targets = {}
    for _, n in ipairs(doc.nodes) do
      if n.id ~= src.id then targets[#targets + 1] = n end
    end
    vim.ui.select(targets, {
      prompt = "Приёмник связи (куда):",
      format_item = function(n) return Model.kind_meta(n.kind).icon .. " " .. n.label .. " (" .. n.id .. ")" end,
    }, function(dst)
      if not dst then return end
      vim.ui.select(Model.EDGE_KINDS, {
        prompt = "Тип связи:",
        format_item = function(ek) return ek.arrow .. " " .. ek.label end,
      }, function(ek)
        if not ek then return end
        vim.ui.input({ prompt = "Подпись связи (REST, gRPC, SQL, Event): " }, function(lbl)
          Model.add_edge(doc, src.id, dst.id, lbl or "", ek.id)
          Model.save_file(paths.json, doc)
          Model.export_mermaid(paths.mermaid, doc, paths.markdown)
          require("config.architecture_board").open(paths.root)
        end)
      end)
    end)
  end)
end

--- Быстрая интерактивная палитра всех операций архитектуры (<leader>Cp / :ArchMenu).
function M.menu()
  local items = {
    { key = "<leader>Cb", cmd = "ArchBoard",     label = "🏗️ C4-доска архитектуры в Neovim" },
    { key = "<leader>Cf", cmd = "ArchFocusFile", label = "🎯 Найти текущий файл на C4-доске" },
    { key = "<leader>Cw", cmd = "ArchWeb",       label = "🌐 Интерактивный C4-холст в браузере (drag-and-drop)" },
    { key = "<leader>Cs", cmd = "ArchScan",      label = "🔍 Умный скан проекта (код + .proto + SQL + OpenAPI)" },
    { key = "<leader>Cl", cmd = "ArchLspScan",   label = "🔎 Подтянуть контракты и символы из LSP" },
    { key = "<leader>Cd", cmd = "ArchAiDraft",   label = "✨ Сгенерировать / доработать схему через ИИ" },
    { key = "<leader>Cr", cmd = "ArchAiReview",  label = "🧠 Поиск циклов зависимостей и ИИ-ревью архитектуры" },
    { key = "<leader>Cn", cmd = "ArchAddNode",   label = "➕ Добавить компонент / контейнер" },
    { key = "<leader>Cc", cmd = "ArchConnect",   label = "🔗 Соединить два компонента связью" },
    { key = "<leader>Cm", cmd = "ArchMermaid",   label = "📐 Экспортировать в Mermaid + Markdown" },
    { key = "<leader>Cj", cmd = "ArchJson",      label = "📄 Открыть docs/architecture.json" },
    { key = "<leader>Cx", cmd = "ArchWebStop",   label = "⏹️ Остановить веб-сервер ArchWeb" },
  }
  vim.ui.select(items, {
    prompt = "🏗️ Архитектура C4 и связи (<leader>C):",
    format_item = function(it)
      return ("%-12s │ %s  (:%s)"):format(it.key, it.label, it.cmd)
    end,
  }, function(choice)
    if choice and choice.cmd then
      vim.cmd(choice.cmd)
    end
  end)
end

function M.setup()
  if setup_done then
    return
  end
  setup_done = true

  local cmds = {
    { "ArchBoard",     M.board,              { force = true, desc = "🏗️ Открыть C4-доску архитектуры в Neovim" } },
    { "ArchWeb",       M.web,                { force = true, desc = "🌐 Открыть браузерный drag-and-drop C4-холст" } },
    { "ArchWebStop",   M.web_stop,           { force = true, desc = "⏹️ Остановить локальный сервер ArchWeb" } },
    { "ArchScan",      M.scan,               { force = true, desc = "🔍 Умный скан кода, .proto, OpenAPI, SQL и C4-слоёв" } },
    { "ArchLspScan",   M.lsp_scan,           { force = true, desc = "🔎 Подтянуть контракты из активного LSP (workspace/symbol)" } },
    { "ArchAiDraft",   M.ai_draft,           { force = true, nargs = "*", desc = "✨ Сгенерировать или доработать схему через ИИ" } },
    { "ArchAiReview",  M.ai_review,          { force = true, desc = "🧠 Поиск циклов, узких мест и ИИ-ревью архитектуры" } },
    { "ArchFocusFile", M.focus_current_file, { force = true, desc = "🎯 Показать текущий открытый файл на C4-доске" } },
    { "ArchMenu",      M.menu,               { force = true, desc = "🧭 Открыть меню всех команд архитектуры" } },
    { "ArchAddNode",   M.add_node,           { force = true, desc = "➕ Добавить компонент в схему архитектуры" } },
    { "ArchConnect",   M.connect_nodes,      { force = true, desc = "🔗 Соединить два компонента связью" } },
    { "ArchMermaid",   M.export_mermaid,     { force = true, desc = "📐 Экспортировать Mermaid и Markdown документацию" } },
    { "ArchJson",      M.open_json,          { force = true, desc = "📄 Открыть файл architecture.json" } },
  }
  for _, c in ipairs(cmds) do
    vim.api.nvim_create_user_command(c[1], c[2], c[3])
  end

  -- 1) ОТДЕЛЬНЫЙ РАЗДЕЛ ЧЕРЕЗ LEADER: <leader>C («🏗️ Архитектура C4 и связи»)
  -- 2) Зеркало в главном меню: <leader>HC* (и быстрый вход <leader>Haa)
  -- 3) Совместимые алиасы: <leader>mA*
  local actions = {
    { suffix = "b", cmd = "<cmd>ArchBoard<cr>",     desc = "🏗️ C4-доска архитектуры в Neovim (:ArchBoard)" },
    { suffix = "w", cmd = "<cmd>ArchWeb<cr>",       desc = "🌐 Браузерный C4-холст drag-and-drop (:ArchWeb)" },
    { suffix = "s", cmd = "<cmd>ArchScan<cr>",      desc = "🔍 Умный скан: код + .proto + SQL + OpenAPI (:ArchScan)" },
    { suffix = "l", cmd = "<cmd>ArchLspScan<cr>",   desc = "🔎 Обогатить контракты из LSP (:ArchLspScan)" },
    { suffix = "d", cmd = "<cmd>ArchAiDraft<cr>",   desc = "✨ ИИ-генерация / правка схемы (:ArchAiDraft)" },
    { suffix = "r", cmd = "<cmd>ArchAiReview<cr>",  desc = "🧠 Аудит циклов и ИИ-ревью схемы (:ArchAiReview)" },
    { suffix = "f", cmd = "<cmd>ArchFocusFile<cr>", desc = "🎯 Найти текущий файл на C4-доске (:ArchFocusFile)" },
    { suffix = "p", cmd = "<cmd>ArchMenu<cr>",      desc = "🧭 Меню всех действий архитектуры (:ArchMenu)" },
    { suffix = "n", cmd = "<cmd>ArchAddNode<cr>",   desc = "➕ Добавить компонент (:ArchAddNode)" },
    { suffix = "c", cmd = "<cmd>ArchConnect<cr>",   desc = "🔗 Соединить компоненты (:ArchConnect)" },
    { suffix = "m", cmd = "<cmd>ArchMermaid<cr>",   desc = "📐 Экспорт в Mermaid + Markdown (:ArchMermaid)" },
    { suffix = "j", cmd = "<cmd>ArchJson<cr>",      desc = "📄 Открыть architecture.json (:ArchJson)" },
    { suffix = "x", cmd = "<cmd>ArchWebStop<cr>",   desc = "⏹️ Остановить веб-холст (:ArchWebStop)" },
  }

  for _, a in ipairs(actions) do
    vim.keymap.set("n", "<leader>C" .. a.suffix, a.cmd, { desc = a.desc, silent = true })
    vim.keymap.set("n", "<leader>HC" .. a.suffix, a.cmd, { desc = a.desc, silent = true })
    vim.keymap.set("n", "<leader>mA" .. a.suffix, a.cmd, { desc = a.desc, silent = true })
  end

  vim.keymap.set("n", "<leader>Haa", "<cmd>ArchBoard<cr>", { desc = "🏗️ Архитектура C4 и связи (:ArchBoard)", silent = true })
end

return M
