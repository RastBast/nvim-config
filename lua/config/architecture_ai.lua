-- ========================================================================== --
--   ИИ-АРХИТЕКТОР (:ArchAiDraft, :ArchAiReview) ПОВЕРХ config.ai_api         --
-- ========================================================================== --
local Model = require("config.architecture_model")

local M = {}

function M.format_static_audit(doc)
  local stats = Model.analyze_graph(doc)
  local c4_containers = 0
  local total_contracts = 0
  for _, n in ipairs(doc.nodes or {}) do
    if Model.child_count(doc, n.id) > 0 then
      c4_containers = c4_containers + 1
    end
    total_contracts = total_contracts + #(n.contracts or {})
  end

  local lines = {
    "## 📊 Статический анализ графа «" .. (doc.title or "Архитектура") .. "»",
    "",
    ("- **Компонентов:** %d (C4-контейнеров с вложенностью: %d)"):format(#doc.nodes, c4_containers),
    ("- **Связей:** %d · **Контрактов (RPC/HTTP/SQL):** %d"):format(#doc.edges, total_contracts),
    "",
  }

  if #stats.cycles == 0 then
    lines[#lines + 1] = "- ✅ **Циклические зависимости:** не обнаружены"
  else
    lines[#lines + 1] = ("- ⚠️ **Циклические зависимости (%d):**"):format(#stats.cycles)
    for _, cyc in ipairs(stats.cycles) do
      lines[#lines + 1] = "  - `" .. table.concat(cyc, " ──▶ ") .. "`"
    end
  end

  if #stats.layer_warnings == 0 then
    lines[#lines + 1] = "- ✅ **Слои архитектуры:** прямых обходов клиент → БД не найдено"
  else
    lines[#lines + 1] = ("- ⚠️ **Нарушения слоёв (%d):**"):format(#stats.layer_warnings)
    for _, w in ipairs(stats.layer_warnings) do
      lines[#lines + 1] = "  - " .. w
    end
  end

  if #stats.hotspots > 0 then
    lines[#lines + 1] = "- 🔥 **Узлы с наибольшей связностью (Hotspots):**"
    for i = 1, math.min(5, #stats.hotspots) do
      local h = stats.hotspots[i]
      lines[#lines + 1] = ("  - `%s` (%s): входящих %d, исходящих %d"):format(
        h.node.label, h.node.id, h.fan_in, h.fan_out
      )
    end
  end

  if #stats.orphans > 0 then
    local names = {}
    for _, o in ipairs(stats.orphans) do names[#names + 1] = "`" .. o.id .. "`" end
    lines[#lines + 1] = "- 💡 **Изолированные компоненты без связей:** " .. table.concat(names, ", ")
  end

  return table.concat(lines, "\n"), stats
end

local function show_markdown(title, md_text)
  local ok_ai, AI = pcall(require, "config.ai_api")
  if ok_ai and type(AI.float) == "function" and type(vim.api.nvim_list_uis) == "function" and #vim.api.nvim_list_uis() > 0 then
    AI.float(title, md_text)
  else
    pcall(vim.api.nvim_echo, { { md_text, "None" } }, true, {})
  end
end

--- Генерация или модификация схемы architecture.json по текстовому описанию через ИИ.
function M.draft(instruction, root, cb)
  local target_root = root or Model.project_root()

  local function run_with_prompt(text_prompt)
    text_prompt = vim.trim(tostring(text_prompt or ""))
    if text_prompt == "" then
      if cb then cb(nil, "пустой запрос") end
      return
    end
    local ok_ai, AI = pcall(require, "config.ai_api")
    if not ok_ai or type(AI.chat_json) ~= "function" then
      local msg = "Модуль config.ai_api недоступен"
      vim.notify(msg, vim.log.levels.ERROR)
      if cb then cb(nil, msg) end
      return
    end

    local current_doc, paths = Model.ensure_project_file(target_root)
    pcall(vim.api.nvim_echo, { { "✨ ИИ проектирует схему архитектуры…", "MoreMsg" } }, false, {})

    local sys_prompt = table.concat({
      "Ты главный системный архитектор. Верни СТРОГО валидный JSON-объект схемы architecture.json без комментариев.",
      "Формат JSON:",
      '{ "title": "...", "direction": "LR", "nodes": [ { "id": "snake_case", "label": "Название", "kind": "client|gateway|service|worker|queue|cache|db|external", "parent_id": "", "path": "", "tech": "Go / Postgres", "summary": "...", "contracts": ["POST /orders", "rpc CreateOrder"] } ], "edges": [ { "from": "id1", "to": "id2", "label": "gRPC / SQL / Kafka", "kind": "sync|async|data" } ] }',
      "Если уместна иерархия C4 (например модули внутри сервиса или таблицы внутри БД), используй поле parent_id с id родительского контейнера.",
      "Все подписи делай понятными на русском (кроме технических имён и путей).",
    }, "\n")

    local user_prompt = "Задача пользователя:\n" .. text_prompt
      .. "\n\nТекущая схема (используй как базу, если пользователь просит изменить/дополнить её, либо создай новую, если описана новая система):\n"
      .. Model.encode_pretty(current_doc)

    AI.chat_json({
      { role = "system", content = sys_prompt },
      { role = "user", content = user_prompt },
    }, { temperature = 0.2 }, function(data, why, provider)
      if not data or type(data.nodes) ~= "table" or #data.nodes == 0 then
        local err_msg = "ИИ не вернул корректную схему: " .. tostring(why or "пустой список nodes") .. " (проверь :AiStatus / <leader>Ap)"
        vim.notify(err_msg, vim.log.levels.ERROR)
        pcall(vim.api.nvim_echo, { { err_msg, "ErrorMsg" } }, true, {})
        if cb then cb(nil, err_msg, provider) end
        return
      end

      local normalized = Model.normalize(data)
      Model.auto_layout(normalized)
      Model.save_file(paths.json, normalized)
      Model.export_mermaid(paths.mermaid, normalized, paths.markdown)

      local ok_b, Board = pcall(require, "config.architecture_board")
      if ok_b and type(Board.reload_from_disk) == "function" then
        pcall(Board.reload_from_disk)
      end

      local pname = (type(provider) == "table" and provider.name) and provider.name or "AI"
      local done_msg = ("✨ Схема обновлена через %s: %d узлов, %d связей"):format(pname, #normalized.nodes, #normalized.edges)
      vim.notify(done_msg, vim.log.levels.INFO)
      pcall(vim.api.nvim_echo, { { done_msg, "MoreMsg" } }, false, {})
      if cb then
        cb(normalized, nil, provider)
      elseif ok_b and type(Board.open) == "function" and not cb then
        Board.open(target_root)
      end
    end)
  end

  if instruction and vim.trim(tostring(instruction)) ~= "" then
    return run_with_prompt(instruction)
  end
  vim.ui.input({
    prompt = "✨ Опиши архитектуру или доработку схемы для ИИ: ",
  }, function(ans)
    if ans and vim.trim(ans) ~= "" then
      run_with_prompt(ans)
    end
  end)
end

--- Статический аудит циклов/узких мест + глубокое архитектурное ревью через ИИ.
function M.review(root, cb)
  local target_root = root or Model.project_root()
  local doc = Model.ensure_project_file(target_root)
  local static_md = M.format_static_audit(doc)

  local ok_ai, AI = pcall(require, "config.ai_api")
  local provider_cfg = (ok_ai and type(AI.resolve) == "function") and select(1, AI.resolve()) or nil
  if not provider_cfg then
    local fallback = static_md
      .. "\n\n---\n💡 *Для глубокого ИИ-ревью укажи API-ключ провайдера (`<leader>Ap` / `:AiStatus`). Статический поиск циклов и узких мест выше работает полностью офлайн.*"
    if cb then
      cb(fallback, nil, nil)
    else
      show_markdown("🧠 Аудит архитектуры (офлайн)", fallback)
    end
    return
  end

  pcall(vim.api.nvim_echo, { { "🧠 Запускаю статический аудит + ИИ-ревью архитектуры…", "MoreMsg" } }, false, {})
  AI.chat({
    {
      role = "system",
      content = "Ты ведущий системный архитектор. Проанализируй граф архитектуры и результаты статического аудита. Ответь лаконично по-русски в Markdown: 1) Главные риски и узкие места, 2) Как разорвать циклы или улучшить границы сервисов/модулей, 3) Конкретные рекомендации по надёжности и контрактам.",
    },
    {
      role = "user",
      content = static_md .. "\n\nСхема JSON:\n```json\n" .. Model.encode_pretty(doc) .. "```",
    },
  }, { temperature = 0.2 }, function(ai_text, why, provider)
    local pname = (type(provider) == "table" and provider.name) and provider.name or "AI"
    local full_md
    if ai_text and ai_text ~= "" then
      full_md = static_md .. "\n\n---\n## 🤖 Рекомендации ИИ (" .. pname .. ")\n\n" .. ai_text
    else
      full_md = static_md .. "\n\n---\n⚠️ *Ответ ИИ не получен (" .. tostring(why or "ошибка") .. ") — показан офлайн-аудит графа.*"
    end
    if cb then
      cb(full_md, nil, provider)
    else
      show_markdown("🧠 Ревью архитектуры · " .. pname, full_md)
    end
  end)
end

return M
