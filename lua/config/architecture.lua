-- ========================================================================== --
--     АРХИТЕКТУРА ПРИЛОЖЕНИЯ И ВИЗУАЛЬНЫЕ СВЯЗИ (:Arch*, <leader>mA*)        --
-- ========================================================================== --
-- Примечание по клавишам: одиночная <leader>a занята Aerial (структура файла),
-- поэтому все операции архитектуры живут без конфликтов в подменю <leader>mA
-- («Архитектура приложения») и в главном меню <leader>Haa.
local M = {}

local setup_done = false

function M.board()
  require("config.architecture_board").open()
end

function M.web()
  require("config.architecture_server").open()
end

function M.web_stop()
  require("config.architecture_server").stop()
  vim.notify("Локальный сервер ArchWeb остановлен", vim.log.levels.INFO)
end

function M.scan()
  local Model = require("config.architecture_model")
  local Scan = require("config.architecture_scan")
  local root = Model.project_root()
  local paths = Model.default_paths(root)
  local doc = Scan.scan_project(root)
  Model.save_file(paths.json, doc)
  Model.export_mermaid(paths.mermaid, doc, paths.markdown)
  local msg = ("🔍 Схема обновлена по коду: %d компонентов, %d связей"):format(#doc.nodes, #doc.edges)
  vim.notify(msg, vim.log.levels.INFO)
  pcall(vim.api.nvim_echo, { { msg, "MoreMsg" } }, true, {})
  require("config.architecture_board").open(root)
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
  vim.notify("Сгенерированы docs/architecture.mmd и docs/architecture.md", vim.log.levels.INFO)
end

function M.open_json()
  local Model = require("config.architecture_model")
  local _, paths = Model.ensure_project_file()
  vim.cmd("edit " .. vim.fn.fnameescape(paths.json))
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

function M.setup()
  if setup_done then
    return
  end
  setup_done = true

  local cmds = {
    { "ArchBoard",   M.board,          "🏗️ Открыть интерактивную доску архитектуры в Neovim" },
    { "ArchWeb",     M.web,            "🌐 Открыть браузерный drag-and-drop холст архитектуры" },
    { "ArchWebStop", M.web_stop,       "⏹️ Остановить локальный сервер ArchWeb" },
    { "ArchScan",    M.scan,           "🔍 Построить схему архитектуры и связей по коду проекта" },
    { "ArchAddNode", M.add_node,       "➕ Добавить компонент в схему архитектуры" },
    { "ArchConnect", M.connect_nodes,  "🔗 Соединить два компонента связью" },
    { "ArchMermaid", M.export_mermaid, "📐 Экспортировать Mermaid и Markdown документацию архитектуры" },
    { "ArchJson",    M.open_json,      "📄 Открыть файл architecture.json" },
  }
  for _, c in ipairs(cmds) do
    vim.api.nvim_create_user_command(c[1], c[2], { force = true, desc = c[3] })
  end

  local maps = {
    { "<leader>mAb", "<cmd>ArchBoard<cr>",   "🏗️ Доска архитектуры в Neovim" },
    { "<leader>mAw", "<cmd>ArchWeb<cr>",     "🌐 Браузерный холст (drag-and-drop)" },
    { "<leader>mAs", "<cmd>ArchScan<cr>",    "🔍 Авто-скан модулей и связей из кода" },
    { "<leader>mAn", "<cmd>ArchAddNode<cr>", "➕ Добавить компонент" },
    { "<leader>mAc", "<cmd>ArchConnect<cr>", "🔗 Соединить компоненты" },
    { "<leader>mAm", "<cmd>ArchMermaid<cr>", "📐 Экспорт в Mermaid + Markdown" },
    { "<leader>mAj", "<cmd>ArchJson<cr>",    "📄 Открыть architecture.json" },
    { "<leader>mAx", "<cmd>ArchWebStop<cr>", "⏹️ Остановить веб-холст" },
    { "<leader>Haa", "<cmd>ArchBoard<cr>",   "🏗️ Архитектура приложения и связи" },
  }
  for _, m in ipairs(maps) do
    vim.keymap.set("n", m[1], m[2], { desc = m[3], silent = true })
  end
end

return M
