-- ========================================================================== --
--   ОТПРАВКА ФАЙЛА ИИ В ФОРМАТЕ .TXT  +  ПРОСМОТР ИЗМЕНЕНИЙ КАК В GIT        --
-- ========================================================================== --
-- Решает сразу две практические задачи:
--   1) Не все ИИ-провайдеры принимают редкие/специфичные расширения ЯП
--      (.wgsl, .templ, .move, .proto, .zig, .sql и т.д.). Модуль конвертирует
--      текущий буфер в чистый текстовый файл `<имя>.txt` и умеет:
--        • <leader>AF (:AiFileTxt)     — отправить текущий файл как .txt,
--          получить изменённый целый файл от ИИ и сразу открыть git-diff;
--        • <leader>AT (:AvanteFileTxt) — прикрепить текущий файл как .txt
--          прямо в открытый боковой чат Avante (вместо исходного расширения).
--   2) Когда ИИ присылает изменённый код целого файла (из :AiFileTxt или прямо
--      в чате Avante / CodeCompanion — клавиша <leader>AD / :AiDiffLast):
--        • открывается наглядный цветной Unified Git Diff (+ зелёные / - красные
--          строки, как в `git diff`), где:
--            Enter / a   — применить весь файл целиком (откатывается через `u`);
--            y / Space   — применить только текущий ханк под курсором;
--            n / p       — переход по ханкам изменений;
--            Tab / d     — переключить в двухоконный side-by-side `vimdiff`;
--            q / Esc     — закрыть без изменений.
local M = {}

local NS_NAME = "ai_git_diff_viewer"
local ns_id = nil
local setup_done = false

M.txt_to_source = {}   -- txt_path -> { bufnr, orig_path }
M.source_to_txt = {}   -- bufnr -> txt_path
M.last_target_buf = nil
M.last_ai_code = nil   -- { bufnr, new_lines, source_label }

local active_review = nil -- состояние открытого окна git-diff

local function ensure_ns()
  if not ns_id and vim.api and type(vim.api.nvim_create_namespace) == "function" then
    ns_id = vim.api.nvim_create_namespace(NS_NAME)
  end
  return ns_id
end

local function echo_msg(msg, hl)
  if vim.api and type(vim.api.nvim_echo) == "function" then
    pcall(vim.api.nvim_echo, { { msg, hl or "MoreMsg" } }, true, {})
  end
end

local function split_lines(s)
  if type(s) ~= "string" then
    return {}
  end
  s = s:gsub("\r\n", "\n"):gsub("\n$", "")
  if s == "" then
    return {}
  end
  local out = {}
  local start = 1
  while true do
    local i, j = s:find("\n", start, true)
    if not i then
      out[#out + 1] = s:sub(start)
      break
    end
    out[#out + 1] = s:sub(start, i - 1)
    start = j + 1
  end
  return out
end

--- Найти подходящий открытый буфер кода (даже если курсор сейчас стоит в чате Avante или NvimTree).
---@return integer|nil bufnr
function M.find_code_buf()
  local cur = vim.api.nvim_get_current_buf()
  local function is_code_buf(b)
    if not b or not vim.api.nvim_buf_is_valid(b) then
      return false
    end
    local bt = vim.bo[b] and vim.bo[b].buftype or ""
    if bt ~= "" then
      return false
    end
    if vim.bo[b] and vim.bo[b].modifiable == false then
      return false
    end
    local ft = vim.bo[b] and vim.bo[b].filetype or ""
    if ft == "NvimTree" or ft == "neo-tree" or ft:match("^Avante") or ft == "codecompanion" or ft == "nvimdiffreview" then
      return false
    end
    return true
  end

  if is_code_buf(cur) then
    M.last_target_buf = cur
    return cur
  end
  if is_code_buf(M.last_target_buf) then
    return M.last_target_buf
  end
  if type(vim.api.nvim_list_wins) == "function" then
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      local b = vim.api.nvim_win_get_buf(w)
      if is_code_buf(b) then
        M.last_target_buf = b
        return b
      end
    end
  end
  return nil
end

--- Сформировать безопасное имя `<имя>.txt` без исходного расширения ЯП.
---@param orig_path string
---@param bufnr integer
---@return string txt_filename
function M.make_txt_filename(orig_path, bufnr)
  local base = (type(orig_path) == "string" and orig_path ~= "")
    and (orig_path:match("([^/\\]+)$") or orig_path)
    or ("buffer_" .. tostring(bufnr))
  -- Заменяем точки и спецсимволы на `_`, чтобы расширение гарантированно было ТОЛЬКО `.txt`
  local stem = base:gsub("[^%w_%-]", "_"):gsub("_+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if stem == "" then
    stem = "code_buffer"
  end
  -- Если уже заканчивалось на _txt, не дублируем
  stem = stem:gsub("_[tT][xX][tT]$", "")
  return stem .. ".txt"
end

--- Сохранить актуальную `.txt`-копию буфера `bufnr` на диск и вернуть `{ txt_path, txt_name, orig_path, lines }`.
---@param bufnr? integer
---@return table|nil info, string|nil err
function M.export_buffer_as_txt(bufnr)
  local b = bufnr or M.find_code_buf()
  if not b then
    return nil, "не найден открытый редактируемый буфер с кодом"
  end
  local orig_path = (type(vim.api.nvim_buf_get_name) == "function" and vim.api.nvim_buf_get_name(b)) or ""
  local ok_nc, nc_ui = pcall(require, "config.neocodeium_ui")
  if ok_nc and type(nc_ui.is_sensitive_file) == "function" and nc_ui.is_sensitive_file(orig_path) then
    return nil, "отправка заблокирована: файл похож на секретный (.env / ключ / сертификат)"
  end

  local lines = vim.api.nvim_buf_get_lines(b, 0, -1, false)
  local txt_name = M.make_txt_filename(orig_path, b)
  local cache_root = (vim.fn and type(vim.fn.stdpath) == "function" and vim.fn.stdpath("cache")) or "/tmp"
  local dir = cache_root .. "/ai_txt"
  if vim.fn and type(vim.fn.mkdir) == "function" then
    pcall(vim.fn.mkdir, dir, "p")
  end
  local txt_path = dir .. "/" .. txt_name

  local wf = io.open(txt_path, "w")
  if not wf then
    return nil, "не удалось записать временный .txt файл: " .. txt_path
  end
  wf:write(table.concat(lines, "\n"))
  wf:close()

  M.txt_to_source[txt_path] = { bufnr = b, orig_path = orig_path }
  M.source_to_txt[b] = txt_path
  M.last_target_buf = b

  return {
    bufnr = b,
    orig_path = orig_path,
    txt_name = txt_name,
    txt_path = txt_path,
    lines = lines,
  }, nil
end

--- Извлечь чистый код файла из ответа ИИ (срезая размышления <think> и markdown-обёртки ```...```).
---@param raw string
---@return string[]|nil lines
function M.extract_code_lines(raw)
  if type(raw) ~= "string" or vim.trim(raw) == "" then
    return nil
  end
  local s = raw
  local ok_th, th = pcall(require, "config.ai_thinking")
  if ok_th and type(th) == "table" and type(th.strip) == "function" then
    s = th.strip(s)
  end
  s = s:gsub("\r\n", "\n")

  -- Ищем самый крупный fenced-блок ```...``` в ответе (ИИ часто кладёт туда полный файл)
  local best_block = nil
  local pos = 1
  while true do
    local b1, e1 = s:find("```[^\n]*\n", pos)
    if not b1 then
      break
    end
    local b2, e2 = s:find("\n```", e1 + 1, true)
    if not b2 then
      -- если закрывающий ``` в самом конце без перевода строки
      local tail = s:sub(e1 + 1):gsub("```%s*$", "")
      if not best_block or #tail > #best_block then
        best_block = tail
      end
      break
    end
    local candidate = s:sub(e1 + 1, b2 - 1)
    if not best_block or #candidate > #best_block then
      best_block = candidate
    end
    pos = e2 + 1
  end

  local chosen = best_block or vim.trim(s)
  if chosen == "" then
    return nil
  end
  return split_lines(chosen)
end

-- ========================================================================== --
--   АЛГОРИТМ DIFF И ПОСТРОЕНИЕ ХАНКОВ (КАК В GIT DIFF)                       --
-- ========================================================================== --

--- Запасной чистый Lua-алгоритм поиска изменяемых диапазонов (LCS/hunk indices),
--- если встроенный `vim.text.diff` недоступен (например в тестовом раннере lupa).
---@param old_lines string[]
---@param new_lines string[]
---@return integer[][] hunks_indices { {start_a, count_a, start_b, count_b}, ... }
local function fallback_diff_indices(old_lines, new_lines)
  local n, m = #old_lines, #new_lines
  -- Быстрое отсечение одинакового префикса и суффикса
  local p = 0
  while p < n and p < m and old_lines[p + 1] == new_lines[p + 1] do
    p = p + 1
  end
  local s_old, s_new = n, m
  while s_old > p and s_new > p and old_lines[s_old] == new_lines[s_new] do
    s_old = s_old - 1
    s_new = s_new - 1
  end
  if p == s_old and p == s_new then
    return {}
  end

  local sub_n = s_old - p
  local sub_m = s_new - p
  -- Для очень больших файлов без vim.text.diff отдаём единый блок изменений
  if sub_n * sub_m > 400000 then
    return { { p + 1, sub_n, p + 1, sub_m } }
  end

  local dp = {}
  for i = 0, sub_n do
    dp[i] = {}
    for j = 0, sub_m do
      dp[i][j] = 0
    end
  end
  for i = sub_n - 1, 0, -1 do
    for j = sub_m - 1, 0, -1 do
      if old_lines[p + i + 1] == new_lines[p + j + 1] then
        dp[i][j] = 1 + dp[i + 1][j + 1]
      else
        local a, b = dp[i + 1][j], dp[i][j + 1]
        dp[i][j] = a >= b and a or b
      end
    end
  end

  -- Восстанавливаем операции: "=" | "-" | "+"
  local ops = {}
  local i, j = 0, 0
  while i < sub_n and j < sub_m do
    if old_lines[p + i + 1] == new_lines[p + j + 1] then
      ops[#ops + 1] = { op = "=", a = p + i + 1, b = p + j + 1 }
      i = i + 1
      j = j + 1
    elseif dp[i + 1][j] >= dp[i][j + 1] then
      ops[#ops + 1] = { op = "-", a = p + i + 1, b = p + j + 1 }
      i = i + 1
    else
      ops[#ops + 1] = { op = "+", a = p + i + 1, b = p + j + 1 }
      j = j + 1
    end
  end
  while i < sub_n do
    ops[#ops + 1] = { op = "-", a = p + i + 1, b = p + j + 1 }
    i = i + 1
  end
  while j < sub_m do
    ops[#ops + 1] = { op = "+", a = p + i + 1, b = p + j + 1 }
    j = j + 1
  end

  local raw_ranges = {}
  local idx = 1
  while idx <= #ops do
    if ops[idx].op == "=" then
      idx = idx + 1
    else
      local start_a = ops[idx].a
      local start_b = ops[idx].b
      local cnt_a, cnt_b = 0, 0
      while idx <= #ops and ops[idx].op ~= "=" do
        if ops[idx].op == "-" then
          if cnt_a == 0 then start_a = ops[idx].a end
          cnt_a = cnt_a + 1
        elseif ops[idx].op == "+" then
          if cnt_b == 0 then start_b = ops[idx].b end
          cnt_b = cnt_b + 1
        end
        idx = idx + 1
      end
      if cnt_a == 0 then start_a = start_a - 1 end
      if cnt_b == 0 then start_b = start_b - 1 end
      raw_ranges[#raw_ranges + 1] = { start_a, cnt_a, start_b, cnt_b }
    end
  end
  return raw_ranges
end

local function compute_raw_ranges(old_lines, new_lines)
  if vim.text and type(vim.text.diff) == "function" then
    local old_s = table.concat(old_lines, "\n") .. "\n"
    local new_s = table.concat(new_lines, "\n") .. "\n"
    local ok, indices = pcall(vim.text.diff, old_s, new_s, {
      result_type = "indices",
      algorithm = "histogram",
    })
    if ok and type(indices) == "table" then
      return indices
    end
  end
  return fallback_diff_indices(old_lines, new_lines)
end

--- Построить список git-ханков с контекстом и статистикой `+added / -removed`.
---@param old_lines string[]
---@param new_lines string[]
---@param ctx_len? integer
---@return table diff_report { hunks = {...}, added = integer, removed = integer }
function M.build_git_diff(old_lines, new_lines, ctx_len)
  ctx_len = ctx_len or 3
  local ranges = compute_raw_ranges(old_lines, new_lines)
  if #ranges == 0 then
    return { hunks = {}, added = 0, removed = 0 }
  end

  -- Склеиваем близкие изменения в единые git-ханки с контекстом ctx_len строк
  local groups = {}
  for _, r in ipairs(ranges) do
    local sa, ca, sb, cb = r[1], r[2], r[3], r[4]
    local a_first = ca > 0 and sa or (sa + 1)
    local a_last = ca > 0 and (sa + ca - 1) or sa
    local prev = groups[#groups]
    if prev and (a_first - prev.a_last) <= (ctx_len * 2 + 1) then
      prev.edits[#prev.edits + 1] = r
      prev.a_last = a_last
    else
      groups[#groups + 1] = {
        a_first = a_first,
        a_last = a_last,
        edits = { r },
      }
    end
  end

  local total_added, total_removed = 0, 0
  local hunks = {}

  for h_idx, grp in ipairs(groups) do
    local first_edit = grp.edits[1]
    local last_edit = grp.edits[#grp.edits]

    local first_old = first_edit[2] > 0 and first_edit[1] or (first_edit[1] + 1)
    local last_old = last_edit[2] > 0 and (last_edit[1] + last_edit[2] - 1) or last_edit[1]
    local ctx_start_a = math.max(1, first_edit[2] > 0 and (first_old - ctx_len) or (first_edit[1] - ctx_len + 1))
    local ctx_end_a = math.min(#old_lines, last_old + ctx_len)

    -- Точный диапазон замены без контекста (для точечного применения одного ханка!)
    local replace_start_a = first_edit[2] > 0 and first_edit[1] or (first_edit[1] + 1)
    local replace_end_a = last_edit[2] > 0 and (last_edit[1] + last_edit[2] - 1) or last_edit[1]

    local first_new = first_edit[4] > 0 and first_edit[3] or (first_edit[3] + 1)
    local last_new = last_edit[4] > 0 and (last_edit[3] + last_edit[4] - 1) or last_edit[3]

    -- Собираем новые строки для диапазона [replace_start_a .. replace_end_a]
    local repl_lines = {}
    local rows = {}

    local cur_a = ctx_start_a
    local delta_b = (first_edit[4] > 0 and first_edit[3] or (first_edit[3] + 1))
      - (first_edit[2] > 0 and first_edit[1] or (first_edit[1] + 1))
    local cur_b = cur_a + delta_b

    for _, ed in ipairs(grp.edits) do
      local sa, ca, sb, cb = ed[1], ed[2], ed[3], ed[4]
      local ed_a_before = ca > 0 and (sa - 1) or sa
      while cur_a <= ed_a_before and cur_a <= #old_lines do
        rows[#rows + 1] = { kind = "ctx", old_no = cur_a, new_no = cur_b, text = old_lines[cur_a] }
        if cur_a >= replace_start_a and cur_a <= replace_end_a then
          repl_lines[#repl_lines + 1] = old_lines[cur_a]
        end
        cur_a = cur_a + 1
        cur_b = cur_b + 1
      end
      for k = 0, ca - 1 do
        local line_a = sa + k
        rows[#rows + 1] = { kind = "del", old_no = line_a, new_no = nil, text = old_lines[line_a] or "" }
        total_removed = total_removed + 1
      end
      cur_a = (ca > 0) and (sa + ca) or (sa + 1)

      for k = 0, cb - 1 do
        local line_b = sb + k
        local txt = new_lines[line_b] or ""
        rows[#rows + 1] = { kind = "add", old_no = nil, new_no = line_b, text = txt }
        repl_lines[#repl_lines + 1] = txt
        total_added = total_added + 1
      end
      cur_b = (cb > 0) and (sb + cb) or (sb + 1)
    end

    while cur_a <= ctx_end_a and cur_a <= #old_lines do
      rows[#rows + 1] = { kind = "ctx", old_no = cur_a, new_no = cur_b, text = old_lines[cur_a] }
      cur_a = cur_a + 1
      cur_b = cur_b + 1
    end

    local old_cnt = math.max(0, ctx_end_a - ctx_start_a + 1)
    local new_cnt = math.max(0, last_new - first_new + 1 + (ctx_start_a < first_old and (first_old - ctx_start_a) or 0) + (ctx_end_a > last_old and (ctx_end_a - last_old) or 0))
    local header = ("@@ -%d,%d +%d,%d @@  [ханк #%d/%d]"):format(
      ctx_start_a, old_cnt, math.max(1, ctx_start_a + delta_b), new_cnt, h_idx, #groups
    )

    hunks[#hunks + 1] = {
      index = h_idx,
      header = header,
      rows = rows,
      replace_start_a = replace_start_a, -- 1-based включительно
      replace_end_a = replace_end_a,     -- 1-based включительно (может быть < replace_start_a при чистой вставке)
      replacement = repl_lines,
    }
  end

  return {
    hunks = hunks,
    added = total_added,
    removed = total_removed,
  }
end

--- Применить один выбранный ханк `hunk` к массиву строк `old_lines` и вернуть новый массив строк.
---@param old_lines string[]
---@param hunk table
---@return string[]
function M.apply_single_hunk_to_lines(old_lines, hunk)
  local out = {}
  local s_a = hunk.replace_start_a
  local e_a = hunk.replace_end_a
  for i = 1, math.min(#old_lines, s_a - 1) do
    out[#out + 1] = old_lines[i]
  end
  for _, rl in ipairs(hunk.replacement or {}) do
    out[#out + 1] = rl
  end
  for i = math.max(1, e_a + 1), #old_lines do
    out[#out + 1] = old_lines[i]
  end
  return out
end

-- ========================================================================== --
--   ИНТЕРАКТИВНЫЙ ПРОСМОТРЩИК ИЗМЕНЕНИЙ (UNIFIED GIT DIFF + VIMDIFF SPLIT)   --
-- ========================================================================== --

local function close_review_float()
  if active_review and active_review.win and vim.api.nvim_win_is_valid(active_review.win) then
    pcall(vim.api.nvim_win_close, active_review.win, true)
  end
  if active_review then
    active_review.win = nil
  end
end

local function focus_buf_window(target_buf)
  if type(vim.api.nvim_list_wins) == "function" then
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == target_buf then
        pcall(vim.api.nvim_set_current_win, w)
        return w
      end
    end
  end
  return nil
end

--- Открыть двухоконный режим `vimdiff` бок-о-бок (слева ваш файл, справа версия ИИ).
function M.open_side_by_side_diff(target_buf, new_lines, title)
  close_review_float()
  if not vim.api.nvim_buf_is_valid(target_buf) then
    return
  end
  focus_buf_window(target_buf)
  if vim.api.nvim_get_current_buf() ~= target_buf then
    pcall(vim.cmd, "buffer " .. tostring(target_buf))
  end

  local ft = vim.bo[target_buf] and vim.bo[target_buf].filetype or ""
  local orig_name = vim.api.nvim_buf_get_name(target_buf)
  local short = orig_name ~= "" and (orig_name:match("([^/\\]+)$") or orig_name) or "buffer"

  pcall(vim.cmd, "diffthis")
  local left_win = vim.api.nvim_get_current_win()

  pcall(vim.cmd, "rightbelow vsplit")
  local right_win = vim.api.nvim_get_current_win()
  local ai_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(right_win, ai_buf)
  pcall(vim.api.nvim_buf_set_name, ai_buf, "🤖 ИИ: " .. short .. " [" .. tostring(ai_buf) .. "]")
  vim.bo[ai_buf].buftype = "acwrite"
  vim.bo[ai_buf].bufhidden = "wipe"
  vim.bo[ai_buf].swapfile = false
  vim.bo[ai_buf].filetype = ft
  vim.api.nvim_buf_set_lines(ai_buf, 0, -1, false, new_lines)
  vim.bo[ai_buf].modified = false
  pcall(vim.cmd, "diffthis")

  local function close_split_diff()
    if vim.api.nvim_win_is_valid(right_win) then
      pcall(vim.api.nvim_win_close, right_win, true)
    end
    if vim.api.nvim_win_is_valid(left_win) then
      pcall(vim.api.nvim_set_current_win, left_win)
      pcall(vim.cmd, "diffoff")
    end
  end

  local function accept_all_from_split()
    local latest_ai = vim.api.nvim_buf_is_valid(ai_buf)
      and vim.api.nvim_buf_get_lines(ai_buf, 0, -1, false)
      or new_lines
    close_split_diff()
    if vim.api.nvim_buf_is_valid(target_buf) then
      vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, latest_ai)
      local msg = "✅ Изменения ИИ применены к " .. short .. " (откат: `u`)"
      vim.notify(msg, vim.log.levels.INFO)
      echo_msg(msg, "MoreMsg")
    end
  end

  local map_opts = { buffer = ai_buf, silent = true, nowait = true }
  vim.keymap.set("n", "q", close_split_diff, map_opts)
  vim.keymap.set("n", "<CR>", accept_all_from_split, map_opts)
  vim.keymap.set("n", "<leader>Ay", accept_all_from_split, map_opts)
  vim.keymap.set("n", "<Tab>", function()
    local latest_ai = vim.api.nvim_buf_get_lines(ai_buf, 0, -1, false)
    close_split_diff()
    M.open_git_diff(target_buf, latest_ai, { title = title })
  end, map_opts)

  local msg = "🪟 Режим vimdiff бок-о-бок: Enter / <leader>Ay — принять весь файл · do/dp — перенос кусков · Tab — единый git diff · q — закрыть"
  echo_msg(msg, "MoreMsg")
end

--- Открыть цветное плавающее окно Unified Git Diff (+ / -) с управлением ханками и переключением в vimdiff.
---@param target_buf integer
---@param new_lines string[]
---@param opts? { title?: string }
---@return boolean opened
function M.open_git_diff(target_buf, new_lines, opts)
  opts = opts or {}
  if not target_buf or not vim.api.nvim_buf_is_valid(target_buf) then
    echo_msg("⚠️ Целевой буфер кода больше не открыт", "WarningMsg")
    return false
  end

  local old_lines = vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)
  local report = M.build_git_diff(old_lines, new_lines, 3)
  if #report.hunks == 0 then
    local msg = "ℹ️ Код от ИИ полностью совпадает с текущим содержимым буфера (изменений нет)"
    vim.notify(msg, vim.log.levels.INFO)
    echo_msg(msg, "MoreMsg")
    return false
  end

  close_review_float()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "nvimdiffreview"

  local orig_name = vim.api.nvim_buf_get_name(target_buf)
  local short = orig_name ~= "" and (orig_name:match("([^/\\]+)$") or orig_name) or ("буфер #" .. tostring(target_buf))
  local title = opts.title or short

  active_review = {
    buf = buf,
    win = nil,
    target_buf = target_buf,
    new_lines = new_lines,
    title = title,
    short = short,
    hunk_header_rows = {},
    row_to_hunk = {},
    report = report,
  }

  local function render_diff_buf()
    local cur_old = vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)
    local rep = M.build_git_diff(cur_old, active_review.new_lines, 3)
    active_review.report = rep
    active_review.hunk_header_rows = {}
    active_review.row_to_hunk = {}

    if #rep.hunks == 0 then
      close_review_float()
      focus_buf_window(target_buf)
      local done_msg = "✅ Все изменения от ИИ применены к " .. short .. "!"
      vim.notify(done_msg, vim.log.levels.INFO)
      echo_msg(done_msg, "MoreMsg")
      return false
    end

    local lines = {
      ("🔀 Изменения ИИ (как в git): %s    [+%d добавлено  /  -%d удалено  ·  ханков: %d]"):format(
        title, rep.added, rep.removed, #rep.hunks
      ),
      "Клавиши: Enter / a — применить ВЕСЬ файл · y / Space — применить ЭТОТ ханк · n / p — след./пред. ханк · Tab / d — 2 окна (vimdiff) · q — отмена",
      string.rep("═", 104),
    }
    local hls = {
      { row = 0, hl = "Title" },
      { row = 1, hl = "Comment" },
      { row = 2, hl = "FloatBorder" },
    }

    for _, h in ipairs(rep.hunks) do
      lines[#lines + 1] = ""
      lines[#lines + 1] = h.header
      local hdr_line_1based = #lines
      active_review.hunk_header_rows[#active_review.hunk_header_rows + 1] = hdr_line_1based
      active_review.row_to_hunk[hdr_line_1based] = h
      hls[#hls + 1] = { row = hdr_line_1based - 1, hl = "DiffChange" }

      for _, r in ipairs(h.rows) do
        local old_s = r.old_no and ("%4d"):format(r.old_no) or "    "
        local new_s = r.new_no and ("%4d"):format(r.new_no) or "    "
        local sign = r.kind == "add" and "+" or (r.kind == "del" and "-" or " ")
        lines[#lines + 1] = ("%s %s │ %s %s"):format(old_s, new_s, sign, r.text)
        local lnum = #lines
        active_review.row_to_hunk[lnum] = h
        if r.kind == "add" then
          hls[#hls + 1] = { row = lnum - 1, hl = "DiffAdd" }
        elseif r.kind == "del" then
          hls[#hls + 1] = { row = lnum - 1, hl = "DiffDelete" }
        else
          hls[#hls + 1] = { row = lnum - 1, hl = "Comment" }
        end
      end
    end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    local id = ensure_ns()
    if id and type(vim.api.nvim_buf_clear_namespace) == "function" then
      pcall(vim.api.nvim_buf_clear_namespace, buf, id, 0, -1)
      for _, item in ipairs(hls) do
        if type(vim.api.nvim_buf_add_highlight) == "function" then
          pcall(vim.api.nvim_buf_add_highlight, buf, id, item.hl, item.row, 0, -1)
        end
      end
    end
    return true
  end

  if not render_diff_buf() then
    return false
  end

  local has_ui = type(vim.api.nvim_list_uis) == "function" and #vim.api.nvim_list_uis() > 0
  if has_ui and type(vim.api.nvim_open_win) == "function" then
    local cols = (vim.o and vim.o.columns and vim.o.columns > 40) and vim.o.columns or 120
    local rows = (vim.o and vim.o.lines and vim.o.lines > 16) and vim.o.lines or 36
    local width = math.min(math.max(92, math.floor(cols * 0.88)), math.max(40, cols - 4))
    local height = math.min(math.max(20, math.floor(rows * 0.82)), math.max(12, rows - 4))
    active_review.win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = math.max(0, math.floor((rows - height) / 2)),
      col = math.max(0, math.floor((cols - width) / 2)),
      style = "minimal",
      border = "rounded",
      title = " 🔀 Git-Diff изменений от ИИ (" .. short .. ") ",
      title_pos = "center",
    })
    vim.wo[active_review.win].wrap = false
    vim.wo[active_review.win].cursorline = true
  else
    pcall(vim.cmd, "botright new")
    active_review.win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(active_review.win, buf)
  end

  if active_review.hunk_header_rows[1] then
    pcall(vim.api.nvim_win_set_cursor, active_review.win, { active_review.hunk_header_rows[1], 0 })
  end

  local function current_hunk()
    local cur = vim.api.nvim_win_get_cursor(active_review.win or 0)
    local row = cur[1]
    if active_review.row_to_hunk[row] then
      return active_review.row_to_hunk[row]
    end
    return active_review.report and active_review.report.hunks[1] or nil
  end

  local function jump_hunk(delta)
    local hdrs = active_review.hunk_header_rows or {}
    if #hdrs == 0 then return end
    local cur_row = vim.api.nvim_win_get_cursor(active_review.win or 0)[1]
    local chosen = hdrs[1]
    if delta > 0 then
      chosen = hdrs[1]
      for _, r in ipairs(hdrs) do
        if r > cur_row then chosen = r; break end
      end
    else
      chosen = hdrs[#hdrs]
      for i = #hdrs, 1, -1 do
        if hdrs[i] < cur_row then chosen = hdrs[i]; break end
      end
    end
    pcall(vim.api.nvim_win_set_cursor, active_review.win or 0, { chosen, 0 })
  end

  local function accept_whole_file()
    local final_lines = active_review.new_lines
    close_review_float()
    if vim.api.nvim_buf_is_valid(target_buf) then
      vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, final_lines)
      focus_buf_window(target_buf)
      -- Синхронизируем .txt зеркало, если оно было прикреплено
      if M.source_to_txt[target_buf] then
        pcall(M.export_buffer_as_txt, target_buf)
      end
      local msg = ("✅ Применён весь файл от ИИ → %s (+%d / -%d, откат: `u`)"):format(
        short, report.added, report.removed
      )
      vim.notify(msg, vim.log.levels.INFO)
      echo_msg(msg, "MoreMsg")
    end
  end

  local function accept_current_hunk()
    local h = current_hunk()
    if not h or not vim.api.nvim_buf_is_valid(target_buf) then
      return
    end
    local cur_old = vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)
    local updated = M.apply_single_hunk_to_lines(cur_old, h)
    vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, updated)
    if M.source_to_txt[target_buf] then
      pcall(M.export_buffer_as_txt, target_buf)
    end
    render_diff_buf()
  end

  local map_opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set("n", "q", close_review_float, map_opts)
  vim.keymap.set("n", "<Esc>", close_review_float, map_opts)
  vim.keymap.set("n", "<CR>", accept_whole_file, map_opts)
  vim.keymap.set("n", "a", accept_whole_file, map_opts)
  vim.keymap.set("n", "y", accept_current_hunk, map_opts)
  vim.keymap.set("n", "<Space>", accept_current_hunk, map_opts)
  vim.keymap.set("n", "n", function() jump_hunk(1) end, map_opts)
  vim.keymap.set("n", "]c", function() jump_hunk(1) end, map_opts)
  vim.keymap.set("n", "p", function() jump_hunk(-1) end, map_opts)
  vim.keymap.set("n", "[c", function() jump_hunk(-1) end, map_opts)
  vim.keymap.set("n", "<Tab>", function()
    M.open_side_by_side_diff(target_buf, active_review.new_lines, title)
  end, map_opts)
  vim.keymap.set("n", "d", function()
    M.open_side_by_side_diff(target_buf, active_review.new_lines, title)
  end, map_opts)

  return true
end

-- ========================================================================== --
--   СЦЕНАРИЙ 1: ОТПРАВИТЬ ТЕКУЩИЙ ФАЙЛ КАК .TXT → ИИ → GIT-DIFF (<leader>AF) --
-- ========================================================================== --

---@param instruction? string
function M.send_txt_and_diff(instruction)
  local info, err = M.export_buffer_as_txt()
  if not info then
    local msg = "⚠️ " .. tostring(err)
    vim.notify(msg, vim.log.levels.WARN)
    echo_msg(msg, "WarningMsg")
    return
  end

  local function run_with_prompt(task)
    task = vim.trim(tostring(task or ""))
    if task == "" then
      return
    end
    local plain_payload = table.concat({
      "=== ATTACHED PLAIN TEXT FILE (.txt) ===",
      "TXT_FILENAME: " .. info.txt_name,
      "CONTENT_START",
      table.concat(info.lines, "\n"),
      "CONTENT_END",
    }, "\n")

    local messages = {
      {
        role = "system",
        content = table.concat({
          "You receive the user's source code serialized strictly as a plain .txt file so file extensions never cause issues.",
          "Apply the user's requested changes and output ONLY the COMPLETE updated file inside a single code block (```text ... ```).",
          "STRICT RULES:",
          "1. Output ONLY the final updated file — NO thinking, NO <think> tags, NO explanations before or after.",
          "2. NEVER omit unchanged parts with comments like '// ... rest of code' — return the FULL file from first line to last line so git diff works accurately.",
        }, "\n"),
      },
      {
        role = "user",
        content = plain_payload .. "\n\nИнструкция: " .. task,
      },
    }

    local wait_msg = ("📤 Файл отправлен ИИ как «%s» (%d строк)… ждём изменённую версию для git-diff"):format(
      info.txt_name, #info.lines
    )
    echo_msg(wait_msg, "MoreMsg")

    local AI = require("config.ai_api")
    AI.chat(messages, {
      temperature = 0.15,
      timeout = 90,
    }, function(reply, chat_err, prov)
      if chat_err or not reply then
        local emsg = "❌ Ошибка ИИ при обработке " .. info.txt_name .. ": " .. tostring(chat_err or "пустой ответ")
        vim.notify(emsg, vim.log.levels.ERROR)
        echo_msg(emsg, "ErrorMsg")
        return
      end
      local new_lines = M.extract_code_lines(reply)
      if not new_lines or #new_lines == 0 then
        local emsg = "⚠️ ИИ не вернул код файла для сравнения"
        vim.notify(emsg, vim.log.levels.WARN)
        echo_msg(emsg, "WarningMsg")
        return
      end
      local prov_id = (type(prov) == "table" and prov.id) or "ai"
      M.last_ai_code = {
        bufnr = info.bufnr,
        new_lines = new_lines,
        source_label = info.txt_name .. " ← " .. prov_id,
      }
      M.open_git_diff(info.bufnr, new_lines, {
        title = info.txt_name .. " (" .. prov_id .. ")",
      })
    end)
  end

  if type(instruction) == "string" and vim.trim(instruction) ~= "" then
    run_with_prompt(instruction)
  else
    vim.ui.input({
      prompt = ("📄 [%s] Что изменить в файле? "):format(info.txt_name),
    }, function(ans)
      if ans and vim.trim(ans) ~= "" then
        run_with_prompt(ans)
      end
    end)
  end
end

-- ========================================================================== --
--   СЦЕНАРИЙ 2: ПРИКРЕПИТЬ ТЕКУЩИЙ ФАЙЛ КАК .TXT В ЧАТ AVANTE (<leader>AT)   --
-- ========================================================================== --

---@param question? string
function M.attach_txt_to_avante(question)
  local info, err = M.export_buffer_as_txt()
  if not info then
    local msg = "⚠️ " .. tostring(err)
    vim.notify(msg, vim.log.levels.WARN)
    echo_msg(msg, "WarningMsg")
    return nil
  end

  pcall(function()
    if not package.loaded["avante"] then
      require("lazy").load({ plugins = { "avante.nvim" } })
    end
  end)

  local ok_av, av = pcall(require, "avante")
  if not ok_av or type(av) ~= "table" then
    local msg = "📄 Сформирован " .. info.txt_path .. " (Avante недоступен — используй <leader>AF для прямой правки с git-diff)"
    echo_msg(msg, "WarningMsg")
    return info.txt_path
  end

  if type(av.is_sidebar_open) == "function" and not av.is_sidebar_open() and type(av.open_sidebar) == "function" then
    pcall(av.open_sidebar, {})
  end

  local sidebar = type(av.get) == "function" and av.get() or nil
  if type(sidebar) == "table" and type(sidebar.file_selector) == "table" then
    local fs = sidebar.file_selector
    -- Убираем исходный файл с «незнакомым» расширением, сохраняя обработчики событий UI!
    if info.orig_path ~= "" and type(fs.remove_selected_file) == "function" then
      pcall(fs.remove_selected_file, fs, info.orig_path)
    elseif type(fs.selected_filepaths) == "table" then
      for i = #fs.selected_filepaths, 1, -1 do
        if fs.selected_filepaths[i] == info.orig_path then
          table.remove(fs.selected_filepaths, i)
        end
      end
    end
    if type(fs.add_selected_file) == "function" then
      pcall(fs.add_selected_file, fs, info.txt_path)
    end
  end

  local q = type(question) == "string" and vim.trim(question) or ""
  if q ~= "" then
    local ok_api, av_api = pcall(require, "avante.api")
    if ok_api and type(av_api) == "table" and type(av_api.ask) == "function" then
      pcall(av_api.ask, {
        question = q .. "\n(Файл передан в формате plain .txt: `" .. info.txt_name .. "`. Если меняешь файл целиком — верни его полный код в одном блоке ```.)",
      })
    end
  else
    local msg = ("📄 Файл прикреплён в чат Avante как «%s»! Когда ИИ пришлёт изменённый код файла — нажми <leader>AD для git-diff"):format(
      info.txt_name
    )
    vim.notify(msg, vim.log.levels.INFO)
    echo_msg(msg, "MoreMsg")
  end
  return info.txt_path
end

-- ========================================================================== --
--   ИЗВЛЕЧЬ ПОСЛЕДНИЙ КОД ФАЙЛА ИЗ ЧАТА ИИ И ПОКАЗАТЬ GIT-DIFF (<leader>AD)  --
-- ========================================================================== --

local function extract_latest_avante_reply()
  local ok_av, av = pcall(require, "avante")
  if not ok_av or type(av) ~= "table" or type(av.get) ~= "function" then
    return nil
  end
  local sidebar = av.get()
  if type(sidebar) ~= "table" or type(sidebar.chat_history) ~= "table" then
    return nil
  end
  local msgs = sidebar.chat_history.messages
  if type(msgs) ~= "table" then
    local ok_h, History = pcall(require, "avante.history")
    if ok_h and type(History.get_history_messages) == "function" then
      local ok_m, res = pcall(History.get_history_messages, sidebar.chat_history)
      if ok_m and type(res) == "table" then
        msgs = res
      end
    end
  end
  if type(msgs) ~= "table" then
    return nil
  end

  -- Собираем текст последнего ответа ассистента (может состоять из нескольких чанков одного turn_id)
  local chunks = {}
  local target_turn = nil
  for i = #msgs, 1, -1 do
    local m = msgs[i]
    local inner = type(m) == "table" and (m.message or m) or nil
    if type(inner) == "table" and inner.role == "assistant" then
      if not target_turn and m.turn_id then
        target_turn = m.turn_id
      end
      if target_turn and m.turn_id and m.turn_id ~= target_turn and #chunks > 0 then
        break
      end
      local c = inner.content
      if type(c) == "string" and c ~= "" then
        table.insert(chunks, 1, c)
      elseif type(c) == "table" then
        for j = #c, 1, -1 do
          local item = c[j]
          if type(item) == "string" then
            table.insert(chunks, 1, item)
          elseif type(item) == "table" and item.type == "text" and type(item.text) == "string" then
            table.insert(chunks, 1, item.text)
          end
        end
      end
      if not target_turn and #chunks > 0 then
        break
      end
    end
  end
  if #chunks == 0 then
    return nil
  end
  return table.concat(chunks, "\n")
end

local function extract_latest_codecompanion_reply()
  if type(vim.api.nvim_list_bufs) ~= "function" then
    return nil
  end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and (vim.bo[b] and vim.bo[b].filetype == "codecompanion") then
      local lines = vim.api.nvim_buf_get_lines(b, 0, -1, false)
      local full = table.concat(lines, "\n")
      if full:find("```", 1, true) then
        return full
      end
    end
  end
  return nil
end

--- Показать цветной git-diff между текущим буфером кода и последним файлом, присланным ИИ.
function M.diff_last_ai_reply()
  local target_buf = M.find_code_buf()
  if not target_buf then
    echo_msg("⚠️ Не найден открытый буфер с кодом для сравнения", "WarningMsg")
    return false
  end

  -- 1. Пробуем последний ответ в чате Avante
  local av_reply = extract_latest_avante_reply()
  if av_reply then
    local lines = M.extract_code_lines(av_reply)
    if lines and #lines > 0 then
      return M.open_git_diff(target_buf, lines, { title = "чат Avante" })
    end
  end

  -- 2. Пробуем открытый буфер чата CodeCompanion
  local cc_reply = extract_latest_codecompanion_reply()
  if cc_reply then
    local lines = M.extract_code_lines(cc_reply)
    if lines and #lines > 0 then
      return M.open_git_diff(target_buf, lines, { title = "чат CodeCompanion" })
    end
  end

  -- 3. Пробуем результат последнего :AiFileTxt (<leader>AF)
  if M.last_ai_code and type(M.last_ai_code.new_lines) == "table" and #M.last_ai_code.new_lines > 0 then
    return M.open_git_diff(target_buf, M.last_ai_code.new_lines, {
      title = M.last_ai_code.source_label or "последний ответ ИИ",
    })
  end

  echo_msg("ℹ️ В чате пока нет блока кода от ИИ — сначала отправь файл через <leader>AF или <leader>AT", "WarningMsg")
  return false
end

function M.setup()
  if setup_done then
    return
  end
  setup_done = true
  ensure_ns()

  if vim.api and type(vim.api.nvim_create_augroup) == "function" then
    local grp = vim.api.nvim_create_augroup("AiFileTxtBridge", { clear = true })
    vim.api.nvim_create_autocmd("BufEnter", {
      group = grp,
      callback = function(ev)
        local b = ev and ev.buf
        if b and vim.api.nvim_buf_is_valid(b) then
          local bt = vim.bo[b] and vim.bo[b].buftype or ""
          local ft = vim.bo[b] and vim.bo[b].filetype or ""
          if bt == "" and ft ~= "NvimTree" and ft ~= "neo-tree" and not ft:match("^Avante") and ft ~= "codecompanion" then
            M.last_target_buf = b
          end
        end
      end,
    })
    -- Авто-обновление .txt зеркала при сохранении исходного файла
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = grp,
      callback = function(ev)
        local b = ev and ev.buf
        if b and M.source_to_txt[b] then
          pcall(M.export_buffer_as_txt, b)
        end
      end,
    })
  end

  vim.api.nvim_create_user_command("AiFileTxt", function(cmd_opts)
    M.send_txt_and_diff(cmd_opts and cmd_opts.args or nil)
  end, {
    force = true,
    nargs = "*",
    desc = "📄 Отправить текущий файл ИИ в формате .txt и открыть git-diff изменений",
  })

  vim.api.nvim_create_user_command("AvanteFileTxt", function(cmd_opts)
    M.attach_txt_to_avante(cmd_opts and cmd_opts.args or nil)
  end, {
    force = true,
    nargs = "*",
    desc = "📄 Прикрепить текущий файл как .txt в боковой чат Avante",
  })

  vim.api.nvim_create_user_command("AiDiffLast", function()
    M.diff_last_ai_reply()
  end, {
    force = true,
    desc = "🔀 Показать изменения целого файла из последнего ответа ИИ как в git",
  })

  vim.keymap.set("n", "<leader>AF", function() M.send_txt_and_diff() end, {
    desc = "📄 Файл → .txt → ИИ → изменения как в git (:AiFileTxt)",
    silent = true,
  })
  vim.keymap.set("n", "<leader>AT", function() M.attach_txt_to_avante() end, {
    desc = "📄 Прикрепить текущий файл как .txt в чат Avante (:AvanteFileTxt)",
    silent = true,
  })
  vim.keymap.set("n", "<leader>AD", function() M.diff_last_ai_reply() end, {
    desc = "🔀 Показать изменения файла от ИИ как в git (:AiDiffLast)",
    silent = true,
  })
end

return M
