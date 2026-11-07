-- ========================================================================== --
--   СКРЫТИЕ РАЗМЫШЛЕНИЙ ИИ (THINKING / REASONING) — ТОЛЬКО ЧИСТЫЙ ОТВЕТ      --
-- ========================================================================== --
-- По умолчанию размышления ИИ СКРЫТЫ (M.show_thinking = false):
--   • Вырезаются блоки <think>...</think>, <thinking>...</thinking>,
--     <thought>...</thought>, <reasoning>...</reasoning>, ◁think▷...◁/think▷
--     (включая ещё не закрытый блок во время потоковой генерации).
--   • В чате Avante скрываются блоки «🤔 Thought content:», части ответа
--     Google Gemini с флагом `thought = true`, `reasoning_content` от
--     OpenRouter / DeepSeek / Qwen / Groq и отключается инструмент `think`.
--   • В CodeCompanion выключается `display.chat.show_reasoning`.
--   • Переключатель на случай сложной отладки:
--       <leader>Ah  или  :AiThinkingToggle  (:AiThinking on|off|status)
local M = {}

M.show_thinking = (vim.env.AI_SHOW_THINKING == "1")

local hooks_installed = {
  render = false,
  openai = false,
  gemini = false,
}
local setup_done = false

local function echo_msg(msg, hl)
  if vim.api and type(vim.api.nvim_echo) == "function" then
    pcall(vim.api.nvim_echo, { { msg, hl or "MoreMsg" } }, true, {})
  end
end

---@return boolean
function M.is_enabled()
  return M.show_thinking == true
end

-- Пары открывающих/закрывающих тегов размышлений разных семейств моделей
local THINK_TAGS = {
  { open = "<think>", close = "</think>" },
  { open = "<thinking>", close = "</thinking>" },
  { open = "<thought>", close = "</thought>" },
  { open = "<reasoning>", close = "</reasoning>" },
  { open = "◁think▷", close = "◁/think▷" },
}

local function remove_tag_blocks(s, open_tag, close_tag)
  local lower_open = open_tag:lower()
  local lower_close = close_tag:lower()
  local guard = 0
  while guard < 64 do
    guard = guard + 1
    local ls = s:lower()
    local i1, j1 = ls:find(lower_open, 1, true)
    if not i1 then
      break
    end
    local i2, j2 = ls:find(lower_close, j1 + 1, true)
    if i2 then
      local before = s:sub(1, i1 - 1)
      local after = s:sub(j2 + 1):gsub("^\r?\n", "")
      s = before .. after
    else
      -- Потоковый ответ: открывающий <think> уже пришёл, а закрывающий </think> ещё нет —
      -- скрываем незавершённый хвост размышлений, чтобы он не мелькал в чате!
      s = s:sub(1, i1 - 1)
      break
    end
  end
  return s
end

--- Вырезать все виды блоков размышлений из текста ИИ, оставив только чистый ответ.
---@param text any
---@return string
function M.strip(text)
  if type(text) ~= "string" or text == "" then
    return type(text) == "string" and text or ""
  end
  local s = text
  for _, pair in ipairs(THINK_TAGS) do
    s = remove_tag_blocks(s, pair.open, pair.close)
  end
  -- На случай сиротского закрывающего тега (некоторые модели на OpenRouter шлют мыслепоток без открывающего <think>, но с </think>)
  for _, close_tag in ipairs({ "</think>", "</thinking>", "</thought>", "</reasoning>", "◁/think▷" }) do
    local idx, end_idx = s:lower():find(close_tag:lower(), 1, true)
    if idx and end_idx then
      s = s:sub(end_idx + 1)
    end
  end
  s = s:gsub("^[\r\n%s]+", "")
  return s
end

--- Подключить перехватчики к загруженным модулям avante.nvim (безопасно вызывать многократно).
function M.install_avante_hooks()
  -- 1. Рендер истории чата Avante (убирает «🤔 Thought content:» и <think> при отрисовке)
  local ok_r, Render = pcall(require, "avante.history.render")
  if ok_r and type(Render) == "table" and not hooks_installed.render then
    hooks_installed.render = true
    local orig_msg_to_lines = Render.message_to_lines
    if type(orig_msg_to_lines) == "function" then
      Render.message_to_lines = function(message, messages, expanded)
        if M.show_thinking or type(message) ~= "table" then
          return orig_msg_to_lines(message, messages, expanded)
        end
        local shallow = setmetatable({}, { __index = message })
        if type(message.displayed_content) == "string" then
          shallow.displayed_content = M.strip(message.displayed_content)
        end
        local inner = message.message
        if type(inner) == "table" then
          local content = inner.content
          if type(content) == "string" then
            shallow.message = vim.tbl_extend("force", inner, { content = M.strip(content) })
          elseif type(content) == "table" then
            local filtered = {}
            for _, item in ipairs(content) do
              if type(item) == "string" then
                local clean = M.strip(item)
                if clean ~= "" then filtered[#filtered + 1] = clean end
              elseif type(item) == "table" then
                if item.type == "thinking" or item.type == "redacted_thinking" or item.type == "reasoning" then
                  -- пропускаем блок размышлений целиком
                elseif item.type == "text" and type(item.text) == "string" then
                  local clean = M.strip(item.text)
                  if clean ~= "" then
                    filtered[#filtered + 1] = vim.tbl_extend("force", item, { text = clean })
                  end
                else
                  filtered[#filtered + 1] = item
                end
              end
            end
            shallow.message = vim.tbl_extend("force", inner, { content = filtered })
          end
        end
        return orig_msg_to_lines(shallow, messages, expanded)
      end
    end
  end

  -- 2. OpenAI-совместимые провайдеры Avante (OpenRouter, Groq, DeepSeek, Kimi, Mistral, OpenAI)
  local ok_p, Providers = pcall(require, "avante.providers")
  local openai = ok_p and type(Providers) == "table" and Providers.openai or package.loaded["avante.providers.openai"]
  if type(openai) == "table" and not hooks_installed.openai then
    hooks_installed.openai = true
    local orig_add_thinking = openai.add_thinking_message
    if type(orig_add_thinking) == "function" then
      openai.add_thinking_message = function(self_obj, ctx, text, state, opts)
        if not M.show_thinking then
          return
        end
        return orig_add_thinking(self_obj, ctx, text, state, opts)
      end
    end
    local orig_add_reasoning = openai.add_reasoning_message
    if type(orig_add_reasoning) == "function" then
      openai.add_reasoning_message = function(self_obj, ctx, reasoning_item, opts)
        if not M.show_thinking then
          return
        end
        return orig_add_reasoning(self_obj, ctx, reasoning_item, opts)
      end
    end
    local orig_add_text = openai.add_text_message
    if type(orig_add_text) == "function" then
      openai.add_text_message = function(self_obj, ctx, text, state, opts)
        if M.show_thinking then
          return orig_add_text(self_obj, ctx, text, state, opts)
        end
        ctx._raw_stream_text = (ctx._raw_stream_text or "") .. tostring(text or "")
        local cleaned_total = M.strip(ctx._raw_stream_text)
        local prev_clean = ctx._prev_clean_len or 0
        if state ~= "generating" then
          ctx._raw_stream_text = nil
          ctx._prev_clean_len = nil
        end
        if #cleaned_total <= prev_clean then
          if state ~= "generating" and prev_clean > 0 then
            return orig_add_text(self_obj, ctx, "", state, opts)
          end
          return
        end
        local delta = cleaned_total:sub(prev_clean + 1)
        if state == "generating" then
          ctx._prev_clean_len = #cleaned_total
        end
        return orig_add_text(self_obj, ctx, delta, state, opts)
      end
    end
  end

  -- 3. Провайдер Google Gemini в Avante (фильтруем части с `part.thought == true`)
  local gemini = ok_p and type(Providers) == "table" and Providers.gemini or package.loaded["avante.providers.gemini"]
  if type(gemini) == "table" and not hooks_installed.gemini then
    hooks_installed.gemini = true
    local orig_gemini_parse = gemini.parse_response
    if type(orig_gemini_parse) == "function" then
      gemini.parse_response = function(self_obj, ctx, data_stream, event_state, opts)
        if not M.show_thinking and type(data_stream) == "string" and data_stream:find('"thought"', 1, true) then
          local ok_j, jsn = pcall(vim.json.decode, data_stream)
          if ok_j and type(jsn) == "table" and type(jsn.candidates) == "table" and jsn.candidates[1] then
            local cand = jsn.candidates[1]
            if type(cand.content) == "table" and type(cand.content.parts) == "table" then
              local kept = {}
              for _, part in ipairs(cand.content.parts) do
                if type(part) ~= "table" or part.thought ~= true then
                  kept[#kept + 1] = part
                end
              end
              cand.content.parts = kept
              if #kept == 0 and not cand.finishReason then
                return
              end
              local ok_enc, reencoded = pcall(vim.json.encode, jsn)
              if ok_enc and type(reencoded) == "string" then
                data_stream = reencoded
              end
            end
          end
        end
        return orig_gemini_parse(self_obj, ctx, data_stream, event_state, opts)
      end
    end
  end
end

local function sync_chat_uis()
  -- CodeCompanion (если уже загружен)
  local cc_cfg = package.loaded["codecompanion.config"]
  if type(cc_cfg) == "table" and type(cc_cfg.display) == "table" and type(cc_cfg.display.chat) == "table" then
    cc_cfg.display.chat.show_reasoning = M.show_thinking
  end
  -- Перерисовать открытый сайдбар Avante на лету
  local av_api = package.loaded["avante.api"]
  if type(av_api) == "table" and type(av_api.refresh) == "function" then
    local ok_av, av = pcall(require, "avante")
    if ok_av and type(av) == "table" and type(av.is_sidebar_open) == "function" and av.is_sidebar_open() then
      pcall(av_api.refresh)
    end
  end
end

function M.set(flag)
  M.show_thinking = (flag == true)
  M.install_avante_hooks()
  sync_chat_uis()
  if M.show_thinking then
    local msg = "🧠 Размышления ИИ: ПОКАЗАНЫ (для отладки · скрыть обратно: <leader>Ah)"
    vim.notify(msg, vim.log.levels.INFO)
    echo_msg(msg, "WarningMsg")
  else
    local msg = "✨ Размышления ИИ: СКРЫТЫ (только чистый ответ · включить: <leader>Ah)"
    vim.notify(msg, vim.log.levels.INFO)
    echo_msg(msg, "MoreMsg")
  end
end

function M.toggle()
  M.set(not M.show_thinking)
end

function M.status()
  local msg = M.show_thinking
    and "🧠 Размышления ИИ сейчас ПОКАЗАНЫ (<leader>Ah — скрыть)"
    or "✨ Размышления ИИ сейчас СКРЫТЫ по умолчанию — остаётся только чистый ответ (<leader>Ah — переключить)"
  vim.notify(msg, vim.log.levels.INFO)
  echo_msg(msg, "MoreMsg")
end

function M.setup()
  if setup_done then
    return
  end
  setup_done = true

  vim.api.nvim_create_user_command("AiThinkingToggle", function() M.toggle() end, {
    force = true,
    desc = "🧠 Показать/скрыть размышления ИИ в чатах (по умолчанию скрыты)",
  })
  vim.api.nvim_create_user_command("AiThinking", function(cmd_opts)
    local arg = vim.trim((cmd_opts and cmd_opts.args) or ""):lower()
    if arg == "on" or arg == "show" or arg == "1" then
      M.set(true)
    elseif arg == "off" or arg == "hide" or arg == "0" then
      M.set(false)
    elseif arg == "status" then
      M.status()
    else
      M.toggle()
    end
  end, {
    force = true,
    nargs = "?",
    complete = function() return { "toggle", "off", "on", "status" } end,
    desc = "🧠 Управление показом размышлений ИИ: toggle / off / on / status",
  })

  vim.keymap.set("n", "<leader>Ah", M.toggle, {
    desc = "🧠 Размышления ИИ: скрыть/показать (по умолчанию скрыты)",
    silent = true,
  })
end

return M
