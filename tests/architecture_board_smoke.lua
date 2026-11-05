-- Настоящий Neovim: интерактивный буфер, HTTP-сервер и локальный сканер.
local root, file, project = vim.env.ARCH_TEST_CONFIG, vim.env.ARCH_BOARD_FILE, vim.env.ARCH_SCAN_ROOT
vim.opt.rtp:prepend(root)
local model = require("config.architecture_model")
local board = require("config.architecture_board")
local server = require("config.architecture_server")
board.setup()
assert(vim.fn.exists(":ArchBoard") == 2 and vim.fn.exists(":ArchScan") == 2, "команды не зарегистрированы")
board.open(file, model.template("layers"))
local first = assert(board.snapshot())
assert(first.modified and #first.model.nodes == 4 and not vim.uv.fs_stat(file), "файл создан на диске без сохранения")
local picture = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert(picture:find("Интерфейс", 1, true) and picture:find("API", 1, true) and picture:find("▶", 1, true), "нет визуальных блоков/стрелок")
vim.api.nvim_feedkeys("q", "x", false)
assert(board.snapshot().modified and not vim.uv.fs_stat(file), "закрытие доски потеряло или записало данные")
board.open()
assert(vim.bo.filetype == "archboard", "доску нельзя повторно открыть")
local before = first.model.nodes[1].x
vim.api.nvim_feedkeys("u", "x", false)
assert(board.snapshot().model.nodes[1].x == before, "отмена стёрла исходную схему")
first = assert(board.snapshot())
vim.api.nvim_feedkeys("l", "x", false)
local moved = assert(board.snapshot())
assert(moved.model.nodes[1].x == before + 1, "клавиатура не переместила блок")
local stale, err = board.apply({op="move", id="N1", x=1, y=1}, first.rev)
assert(not stale and err:find("изменилась", 1, true), "устаревшее действие не отклонено")
vim.api.nvim_feedkeys("u", "x", false)
assert(board.snapshot().model.nodes[1].x == before, "отмена движения не сработала")
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-r>", true, false, true), "x", false)
moved = assert(board.snapshot())
assert(moved.model.nodes[1].x == before + 1, "повтор движения не сработал")
local updated = assert(board.apply({op="add", label="Аутентификация", kind="service", x=8, y=15}, moved.rev))
assert(#updated.model.nodes == 5 and updated.modified and not vim.uv.fs_stat(file), "добавление не сохранило буфер")
assert(board.apply({op="link", from="N1", to="N5", label="OAuth"}, updated.rev))
board.export()
local exported = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert(vim.bo.filetype == "markdown" and exported:find("```mermaid", 1, true) and exported:find("OAuth", 1, true), "экспорт Mermaid не открылся")
board.open()
local existing = file .. ".existing"
local untouched = assert(io.open(existing, "wb")); untouched:write("не трогать\n"); untouched:close()
board.open(existing, model.template("context"))
local check_file = assert(io.open(existing, "rb")); local unchanged = check_file:read("*a"); check_file:close()
assert(unchanged == "не трогать\n" and board.snapshot().file == file, "существующий файл перезаписан или схема заменена")
-- Схема может уже находиться в изменённом буфере, который редактор не создавал.
local prior_path = file .. ".prior"
local on_disk = vim.json.encode(model.template("context"))
local prior_file = assert(io.open(prior_path, "wb")); prior_file:write(on_disk); prior_file:close()
local prior_buf = vim.fn.bufadd(prior_path); vim.fn.bufload(prior_buf)
local prior_model = model.template("context"); prior_model.title = "Не сохранено до открытия"
vim.api.nvim_buf_set_lines(prior_buf, 0, -1, false, {vim.json.encode(prior_model)})
board.open(prior_path)
assert(board.snapshot().modified and board.snapshot().model.title == prior_model.title, "изменённый буфер не сохранён")
local prior_saved, prior_err = board.save()
assert(not prior_saved and prior_err:find("буфер изменён или не совпадает", 1, true), "нет защиты изменённого буфера")
prior_file = assert(io.open(prior_path, "rb")); local after_prior = prior_file:read("*a"); prior_file:close()
assert(after_prior == on_disk, "данные изменённого буфера записаны без подтверждения")
-- Даже немодифицированный, но давно загруженный буфер может отставать от файла.
local stale_path = file .. ".stale"
local stale_file = assert(io.open(stale_path, "wb")); stale_file:write(on_disk); stale_file:close()
local stale_buf = vim.fn.bufadd(stale_path); vim.fn.bufload(stale_buf)
local outside_model = model.template("layers"); outside_model.title = "Другая версия на диске"
local outside_json = vim.json.encode(outside_model)
stale_file = assert(io.open(stale_path, "wb")); stale_file:write(outside_json); stale_file:close()
board.open(stale_path)
assert(board.snapshot().model.title ~= outside_model.title, "тест не создал устаревший буфер")
assert(board.apply({op="rename", id="N1", label="Визуальная правка"}))
local stale_saved, stale_error = board.save()
assert(not stale_saved and stale_error:find("не совпадает с файлом", 1, true), "устаревший буфер перезаписал диск")
stale_file = assert(io.open(stale_path, "rb")); local disk_after = stale_file:read("*a"); stale_file:close()
assert(disk_after == outside_json, "внешняя версия уничтожена")
-- При совпадении чистого буфера и файла безопасное сохранение остаётся доступным.
local matching_path = file .. ".matching"
local matching_file = assert(io.open(matching_path, "wb")); matching_file:write(on_disk .. "\n"); matching_file:close()
local matching_buf = vim.fn.bufadd(matching_path); vim.fn.bufload(matching_buf)
board.open(matching_path)
assert(board.apply({op="rename", id="N1", label="Проверенный буфер"}))
assert(board.save(), "сохранение совпадающего буфера ошибочно заблокировано")
board.open(file)

local url = assert(server.start())
assert(url:match("^http://127%.0%.0%.1:%d+/[%da-f]+/$"), url)
local origin = assert(url:match("^(http://[^/]+)"))
local function curl(args)
  local result
  local cmd = { "curl", "-sS", "--max-time", "5" }
  vim.list_extend(cmd, args)
  vim.system(cmd, { text = true }, function(r) vim.schedule(function() result = r end) end)
  assert(vim.wait(7000, function() return result ~= nil end, 20), "curl timeout")
  assert(result.code == 0, tostring(result.stderr))
  return result.stdout
end
local html = curl({url})
assert(html:find("Архитектура · редактор", 1, true), "редактор не отдаётся")
local remote = vim.json.decode(curl({url .. "state"}))
assert(#remote.model.nodes == 5 and remote.modified, "сервер не видит буфер")
assert(curl({"-o", "/dev/null", "-w", "%{http_code}", "-H", "Host: evil.example", url}) == "403", "Host защита")
assert(curl({"-o", "/dev/null", "-w", "%{http_code}", origin .. "/bad-token/state"}) == "404", "защита токеном")
local payload = vim.json.encode({rev=remote.rev, action={op="move", id="N1", x=10, y=4}})
assert(curl({"-o", "/dev/null", "-w", "%{http_code}", "-X", "POST", "-H", "Origin: http://evil.example", "-H", "Content-Type: application/json", "--data-binary", payload, url .. "action"}) == "403", "Origin защита")
local response = vim.json.decode(curl({"-H", "Origin: " .. origin, "-H", "Content-Type: application/json", "--data-binary", payload, url .. "action"}))
assert(response.model.nodes[1].x == 10 and board.snapshot().model.nodes[1].x == 10, "браузер не обновил Neovim")
assert(curl({"-o", "/dev/null", "-w", "%{http_code}", "-H", "Origin: " .. origin, "-H", "Content-Type: application/json", "--data-binary", payload, url .. "action"}) == "409", "потеря изменений при конфликте")
local save = vim.json.encode({rev=response.rev, action={op="save"}})
local saved = vim.json.decode(curl({"-H", "Origin: " .. origin, "-H", "Content-Type: application/json", "--data-binary", save, url .. "action"}))
assert(saved.modified == false and vim.uv.fs_stat(file), "явное сохранение JSON не работает")
print("OK   Neovim: выбор, движение, схема в буфере и безопасное HTTP API")

if vim.env.ARCH_BOARD_JS_SMOKE == "1" then
  local result
  vim.system({ "node", root .. "/tests/architecture_browser_smoke.js", url }, { text = true }, function(r)
    vim.schedule(function() result = r end)
  end)
  assert(vim.wait(25000, function() return result ~= nil end, 20), "browser smoke timeout")
  print((result.stdout or "") .. (result.stderr or ""))
  assert(result.code == 0 and (result.stdout or ""):find("OK   браузер jsdom", 1, true), "браузерный smoke не прошёл")
end

if vim.env.ARCH_BOARD_REAL_SMOKE == "1" then
  local result
  vim.system({ "node", root .. "/tests/architecture_real_browser_smoke.js", url }, { text = true }, function(r)
    vim.schedule(function() result = r end)
  end)
  assert(vim.wait(60000, function() return result ~= nil end, 20), "реальный браузер: timeout")
  print((result.stdout or "") .. (result.stderr or ""))
  assert(result.code == 0 and (result.stdout or ""):find("OK   реальный Chromium", 1, true), "реальный браузер: smoke не прошёл")
end

-- :ArchSave не перезаписывает файл, который изменился вне Neovim.
local external = assert(io.open(file, "wb")); external:write("данные другого процесса\n"); external:close()
assert(board.apply({op="rename", id="N1", label="проверка конфликта"}))
local wrote, conflict = board.save()
assert(not wrote and conflict:find("изменён вне Neovim", 1, true), "внешнее изменение не распознано")
local f = assert(io.open(file, "rb")); local contents = f:read("*a"); f:close()
assert(contents == "данные другого процесса\n", "перезаписан файл другого процесса")
print("OK   внешнее изменение файла не перезаписано")

local scanner = require("config.architecture_scan")
local result, info
scanner.scan(project, function(m, s) result, info = m, s end)
assert(vim.wait(10000, function() return result or info end, 10), "сканирование зависло")
assert(result, tostring(info))
local labels = {}; for _, n in ipairs(result.nodes) do labels[n.label] = n.id end
local edges = {}; for _, e in ipairs(result.edges) do edges[e.from .. ">" .. e.to] = true end
assert(labels["cmd/server"] and labels["internal/service"] and labels["internal/db"], vim.inspect(labels))
assert(edges[labels["cmd/server"] .. ">" .. labels["internal/service"]], "не найдена связь Go")
assert(edges[labels["internal/service"] .. ">" .. labels["internal/db"]], "не найдена связь Go storage")
assert(labels["web/app"] and labels["web/lib"] and edges[labels["web/app"] .. ">" .. labels["web/lib"]], "не найдена связь JS")
assert(labels["pyapp/api"] and labels["pyapp/store"] and edges[labels["pyapp/api"] .. ">" .. labels["pyapp/store"]], "не найдена связь Python")
assert(not labels["node_modules/ignored"] and not labels["outside"], "обошёл запретные каталоги или симлинк")
assert(info.files == 7 and info.bytes < 8*1024*1024, vim.inspect(info))
local limited, limit_info
scanner.scan(project, function(m, s) limited, limit_info = m, s end, {max_files=3})
assert(vim.wait(10000, function() return limited or limit_info end, 10), "лимитированный сканер завис")
assert(limited and limit_info.files == 3 and limit_info.truncated, "лимит файлов не соблюдён")
local many, many_info
scanner.scan(vim.env.ARCH_SCAN_MANY, function(m, s) many, many_info = m, s end)
assert(vim.wait(10000, function() return many or many_info end, 10), "сканер >20 файлов завис")
assert(many and many_info.files == 45 and #many.nodes == 45 and #many.edges == 44 and not many_info.truncated, vim.inspect(many_info))
local large, large_info
scanner.scan(vim.env.ARCH_SCAN_LARGE, function(m, s) large, large_info = m, s end)
assert(vim.wait(10000, function() return large or large_info end, 10), "сканер большого файла завис")
assert(large and large_info.files == 1 and large_info.truncated, "пропуск большого файла не отмечен")
-- Весь пользовательский путь :ArchScan: каталог, подтверждение, имя, явное сохранение.
local original_buf, scan_file = vim.fn.bufnr(file), file .. ".scan"
local old_input, old_select = vim.ui.input, vim.ui.select
vim.ui.input = function(opts, cb)
  if opts.prompt:find("проанализировать", 1, true) then cb(project)
  elseif opts.prompt:find("Файл схемы", 1, true) then cb(scan_file)
  else error("неожиданный запрос " .. opts.prompt) end
end
vim.ui.select = function(choices, opts, cb)
  assert(opts.prompt:find("Создать новую схему", 1, true), opts.prompt)
  cb(choices[1])
end
vim.cmd("ArchScan")
assert(vim.wait(10000, function()
  local snap = board.snapshot(); return snap and snap.file == scan_file
end, 10), ":ArchScan не открыл созданную схему")
vim.ui.input, vim.ui.select = old_input, old_select
assert(board.snapshot().modified and not vim.uv.fs_stat(scan_file), "сканирование сохранило файл без спроса")
assert(vim.bo[original_buf].modified, "предыдущий изменённый буфер потерян при открытии результата")
assert(board.save() and vim.uv.fs_stat(scan_file), "не удалось явно сохранить результат анализа")
-- :ArchBoardNew и пустой шаблон: пустые массивы должны пережить запись JSON.
local empty_file = file .. ".empty"
old_input, old_select = vim.ui.input, vim.ui.select
vim.ui.select = function(choices, _, cb)
  assert(#choices == 5 and choices[5].id == "empty", "пять шаблонов недоступны")
  cb(choices[5])
end
vim.ui.input = function(_, cb) cb(empty_file) end
vim.cmd("ArchBoardNew")
vim.ui.input, vim.ui.select = old_input, old_select
local empty = assert(board.snapshot())
assert(#empty.model.nodes == 0 and #empty.model.edges == 0 and not vim.uv.fs_stat(empty_file), "пустой шаблон не открылся без записи")
assert(board.apply({op="add", label="Первый блок"}))
assert(board.save(), "пустая схема не сохраняется после добавления")
print("OK   сканер: Go, JS, Python; лимиты и >20 файлов; игнорирование node_modules и симлинков")
server.stop()
vim.cmd("qa!")
