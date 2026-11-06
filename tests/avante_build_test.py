#!/usr/bin/env python3
"""Проверка сборки avante: версия, рабочие нативные модули и восстановление.

ФС и внешние процессы подменены: тестируются также ошибки загрузчика, принудительная
пересборка, безопасная замена и параллельные запросы. Реальный dlopen проверяется
отдельно в avante_native_test.py. Запуск: PYTHONPATH=... python3 tests/avante_build_test.py
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402

checks = []


def check(name, cond, extra=""):
    checks.append((name, bool(cond)))
    print(("OK   " if cond else "FAIL ") + name + ("" if cond or not extra else f"   [{extra}]"))


PRELUDE = r'''
DIR = "/P/avante"
STAGE = DIR .. "/lua/.avante-build-12345678901234567890"
NAMES = {"avante_templates", "avante_tokenizers", "avante_repo_map", "avante_html2md"}
EXPECTED = {
  avante_templates = {"initialize", "render"},
  avante_tokenizers = {"from_pretrained", "encode"},
  avante_repo_map = {"stringify_definitions"},
  avante_html2md = {"fetch_md", "html2md"},
}
vim.split = function(s, sep)
  local out = {}
  for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
  return out
end
vim.list_slice = function(t, a, b)
  local o = {}; for i = a, (b or #t) do o[#o + 1] = t[i] end; return o
end
QUEUE, IN_FAST = {}, false
vim.schedule = function(fn) QUEUE[#QUEUE + 1] = fn end
function drain()
  local n = 0
  while #QUEUE > 0 do
    n = n + 1; if n > 300 then error("очередь не опустела") end
    table.remove(QUEUE, 1)()
  end
end
vim.wait = function(_, cond)
  for _ = 1, 100 do drain(); if cond() then return true end end
  return cond()
end
EXEC, FILES, VERSIONS, GENERATION, CALLS, RENAMES, UNAME, O = {}, {}, {}, 0, {}, {}, nil, {}
vim.fn.has = function() return 0 end
vim.fn.executable = function(x) return EXEC[x] and 1 or 0 end
vim.fn.tempname = function() return "/tmp/nvim-unique/1" end
vim.fn.sha256 = function() return "12345678901234567890abcdef" end
vim.fn.mkdir = function(path)
  if O.mkdir_error or (O.stage_error and path:find('.avante-build-', 1, true)) then error('permission denied') end
  if O.mkdir_zero then return 0 end
  return 1
end
vim.fn.delete = function(p, flags)
  CALLS[#CALLS + 1] = "delete " .. p .. " " .. tostring(flags)
  for name in pairs(FILES) do if name:sub(1, #p + 1) == p .. "/" then FILES[name] = nil end end
  return 0
end
local FNS = vim.fn
vim.fn = setmetatable({}, {
  __index = function(_, k)
    if IN_FAST then error("E5560: vim.fn." .. tostring(k) .. " в fast-контексте") end
    return FNS[k]
  end,
  __newindex = function(_, k, v) FNS[k] = v end,
})
vim.uv.os_uname = function() return UNAME end
vim.uv.fs_stat = function(p) if FILES[p] then return { type = "file", ino = VERSIONS[p], size = 1, mtime = {sec=VERSIONS[p], nsec=0} } end return nil end
vim.uv.fs_copyfile = function(from, to)
  if O.copy_fail then return nil, "copy failed" end
  if not FILES[from] then return nil, "missing source" end
  FILES[to], VERSIONS[to] = FILES[from], VERSIONS[from]
  CALLS[#CALLS + 1] = "copy " .. from .. " " .. to
  return true
end
vim.uv.fs_rename = function(from, to)
  RENAMES[#RENAMES + 1] = {from, to}
  if O.rename_fail then return nil, "permission denied" end
  if not FILES[from] then return nil, "missing source" end
  FILES[to], FILES[from] = FILES[from], nil
  VERSIONS[to], VERSIONS[from] = VERSIONS[from], nil
  return true
end
package.loadlib = function(path, symbol)
  local name = path:match("/(avante_[%w_]+)%.so$")
  local state = FILES[path]
  if state == "bad" then return nil, "wrong architecture" end
  if not state or not name or symbol ~= "luaopen_" .. name then return nil, "missing symbol" end
  return function()
    if state == "throws" then error("broken library initializer") end
    local result = {}
    for _, export in ipairs(EXPECTED[name]) do result[export] = function() end end
    if state == "api" then result[EXPECTED[name][1]] = nil end
    return result
  end
end
local function make_files(base, kind, missing)
  GENERATION = GENERATION + 1
  for _, name in ipairs(NAMES) do
    if name ~= missing then
      local path = base .. "/" .. name .. ".so"
      FILES[path], VERSIONS[path] = kind or "valid", GENERATION
    end
  end
end
vim.system = function(cmd, opts, cb)
  CALLS[#CALLS + 1] = table.concat(cmd, " ")
  local name = cmd[1]
  local r
  if name == "git" then
    r = { code = O.git_code or 0, stdout = (O.revision or B.COMMIT) .. "\n", stderr = O.git_error or "" }
    return { wait = function() return r end }
  elseif name == "curl" then
    r = { code = O.curl_code or 0, stderr = O.curl_err or "", stdout = "" }
  elseif name == "tar" then
    if O.tar_produces then make_files(STAGE, O.tar_kind, O.tar_missing) end
    r = { code = O.tar_code or 0, stderr = O.tar_err or "", stdout = "" }
  elseif name == "make" then
    if O.make_produces then make_files(DIR .. "/lua", O.make_kind, O.make_missing) end
    r = { code = O.make_code or 0, stderr = O.make_err or "", stdout = O.make_out or "" }
  else
    error("unexpected process " .. name)
  end
  local prev = IN_FAST; IN_FAST = true; cb(r); IN_FAST = prev
  return { wait = function() return r end }
end
B = require("config.avante_build")

function RESET(o)
  O, CALLS, FILES, VERSIONS, GENERATION, EXEC, RENAMES, QUEUE = o, {}, {}, {}, 0, {}, {}, {}
  for _, c in ipairs(o.exec or {}) do EXEC[c] = true end
  UNAME = o.uname or {sysname="Darwin", machine="arm64"}
  if o.built then make_files(DIR .. "/lua", o.built_kind, o.missing) end
  RES_OK, RES_MSG = nil, nil
end
function SETUP(o)
  RESET(o)
  B.build(DIR, function(ok, msg) RES_OK, RES_MSG = ok, msg end, {force = o.force, source = o.source})
  drain()
end
function count_command(name)
  local n = 0
  for _, call in ipairs(CALLS) do if call:match("^" .. name .. " ") or call == name then n = n + 1 end end
  return n
end
function find_command(name)
  for _, call in ipairs(CALLS) do if call:match("^" .. name .. " ") or call == name then return call end end
  return ""
end
'''


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    with open(os.path.join(_lua.ROOT, "tests", "lua_stubs.lua"), encoding="utf-8") as fh:
        rt.execute(fh.read())
    rt.execute(PRELUDE)

    def run(s):
        rt.execute(s)

    cases = [
        ("Darwin", "arm64", "avante_lib-darwin-aarch64-luajit.tar.gz"),
        ("Darwin", "x86_64", "avante_lib-darwin-x86_64-luajit.tar.gz"),
        ("Linux", "x86_64", "avante_lib-linux-x86_64-luajit.tar.gz"),
        ("Linux", "aarch64", "avante_lib-linux-aarch64-luajit.tar.gz"),
    ]
    for osn, mach, want in cases:
        got = rt.eval(f"B.artifact('{osn}', '{mach}')")
        check(f"архив {osn}/{mach}", got == want, str(got))
    check("неизвестная ОС → nil", rt.eval("B.artifact('Windows_NT', 'AMD64')") is None)
    url = rt.eval("B.url('avante_lib-darwin-aarch64-luajit.tar.gz')")
    check("ссылка на закреплённый релиз", url.endswith("/v0.4.8/avante_lib-darwin-aarch64-luajit.tar.gz"), url)

    # Наличие файла недостаточно: должен загрузиться каждый модуль и его API.
    run("RESET{built=true, exec={'git'}}")
    check("четыре рабочие библиотеки признаны готовыми", rt.eval("B.is_built(DIR)") is True)
    run("RESET{built=true, built_kind='bad', exec={'git'}}")
    check("файлы есть, но неподходящая архитектура → не готовы",
          rt.eval("B.is_built(DIR)") is False and "wrong architecture" in rt.eval("select(2, B.check(DIR))"))
    run("RESET{built=true, built_kind='api', exec={'git'}}")
    check("неверный API библиотеки → не готовы",
          rt.eval("B.is_built(DIR)") is False and "нет функции" in rt.eval("select(2, B.check(DIR))"))
    run("RESET{built=true, exec={'git'}, missing='avante_repo_map'}")
    check("частичный комплект библиотек не считается готовым", rt.eval("B.is_built(DIR)") is False)
    run("RESET{built=true, built_kind='throws', exec={'git'}}")
    check("ошибка инициализатора ловится", "broken library initializer" in rt.eval("select(2, B.check(DIR))"))

    run("SETUP{exec={'git','curl','tar'}, tar_produces=true}")
    check("Mac arm64: успех после загрузки и проверки", rt.eval("RES_OK") is True, str(rt.eval("RES_MSG")))
    check("архив скачивается по тегу и с таймаутом",
          "v0.4.8/avante_lib-darwin-aarch64-luajit.tar.gz" in rt.eval("find_command('curl')")
          and "--max-time 180" in rt.eval("find_command('curl')"))
    check("распаковка не поверх используемых библиотек",
          rt.eval("find_command('tar')").endswith("-C " + rt.eval("STAGE")))
    check("все четыре файла заменяются через rename", rt.eval("#RENAMES") == 4)
    check("временный каталог очищен", rt.eval("count_command('delete')") == 1)
    check("make при успешном архиве не запущен", rt.eval("count_command('make')") == 0)

    run("SETUP{built=true, exec={'git'}}")
    check("уже исправно: загрузки нет", rt.eval("RES_OK") is True and rt.eval("count_command('curl')") == 0)
    run("SETUP{built=true, exec={'git','curl','tar'}, tar_produces=true, force=true}")
    check("принудительная сборка не пропускается при существующем файле",
          rt.eval("RES_OK") is True and rt.eval("count_command('curl')") == 1 and rt.eval("#RENAMES") == 4)
    run("SETUP{built=true, built_kind='bad', exec={'git','curl','tar'}, tar_produces=true}")
    check("повреждённые библиотеки реально заменяются", rt.eval("RES_OK") is True and rt.eval("#RENAMES") == 4)

    run("SETUP{exec={'git','curl','tar'}, revision='deadbeef'}")
    check("другой checkout: не скачивать несовместимые бинарники",
          rt.eval("RES_OK") is False and rt.eval("count_command('curl')") == 0
          and ":Lazy update avante.nvim" in rt.eval("RES_MSG"))
    run("SETUP{exec={'curl','tar'}, tar_produces=true}")
    check("нет git: понятная причина, бинарники не скачиваются без проверки версии",
          rt.eval("RES_OK") is False and "git не найден" in rt.eval("RES_MSG") and rt.eval("count_command('curl')") == 0)
    run("SETUP{exec={'git','curl','tar'}, git_code=128, git_error='not a git repository'}")
    check("ошибка чтения HEAD не маскируется", rt.eval("RES_OK") is False and "not a git repository" in rt.eval("RES_MSG"))

    run("SETUP{exec={'git','curl','tar'}, curl_code=22, curl_err='HTTP 404'}")
    msg = rt.eval("RES_MSG")
    check("ошибка скачивания: причина curl и подсказка про Rust",
          rt.eval("RES_OK") is False and "HTTP 404" in msg and "brew install rust" in msg, msg)
    run("SETUP{exec={'git','curl','tar'}, tar_produces=true, tar_missing='avante_templates'}")
    check("частичный архив не объявляется успешным",
          rt.eval("RES_OK") is False and "avante_templates" in rt.eval("RES_MSG") and rt.eval("#RENAMES") == 0)
    run("SETUP{exec={'git','curl','tar'}, tar_produces=true, tar_kind='bad'}")
    check("нерабочий архив не заменяет имеющиеся библиотеки",
          rt.eval("RES_OK") is False and "wrong architecture" in rt.eval("RES_MSG") and rt.eval("#RENAMES") == 0)
    run("SETUP{exec={'git','curl','tar'}, tar_produces=true, rename_fail=true}")
    check("ошибка замены содержит причину и не объявляется успехом",
          rt.eval("RES_OK") is False and "permission denied" in rt.eval("RES_MSG"))
    run("SETUP{exec={'git','curl','tar'}, mkdir_error=true}")
    check("ошибка создания каталога завершает сборку, а не оставляет её висеть",
          rt.eval("RES_OK") is False and "permission denied" in rt.eval("RES_MSG"))
    run("SETUP{exec={'git','curl','tar'}, mkdir_zero=true}")
    check("неуспех mkdir с кодом 0 тоже показывается", rt.eval("RES_OK") is False and "создать каталог" in rt.eval("RES_MSG"))
    run("SETUP{exec={'git','curl','tar'}, stage_error=true}")
    check("ошибка staging-каталога явно показана", rt.eval("RES_OK") is False and "permission denied" in rt.eval("RES_MSG"))
    run("SETUP{exec={'git','curl','tar','make','cargo'}, curl_code=6, make_produces=true}")
    check("нет сети + cargo: запасной make работает", rt.eval("RES_OK") is True and rt.eval("count_command('make')") == 1)
    run("SETUP{exec={'git','curl','tar','make','cargo'}, tar_produces=false, make_code=2, make_err='linker failed'}")
    check("ошибка make: сохраняется и причина fallback, и stderr",
          rt.eval("RES_OK") is False and "linker failed" in rt.eval("RES_MSG") and "Архив" in rt.eval("RES_MSG"))
    run("SETUP{exec={'git','make','cargo'}, make_produces=true}")
    check("нет curl: сразу make", rt.eval("RES_OK") is True and rt.eval("count_command('curl')") == 0)
    run("SETUP{exec={'git','curl','tar','make','cargo'}, source=true, force=true, make_produces=true}")
    check("source=true использует make, а не скачивание другого тега",
          rt.eval("RES_OK") is True and rt.eval("count_command('make')") == 1 and rt.eval("count_command('curl')") == 0)
    check("результат make проверяется в отдельном каталоге, без кэша загруженных библиотек",
          rt.eval("count_command('copy')") == 4)
    run("SETUP{built=true, force=true, exec={'git','make','cargo'}, make_produces=false}")
    check("make с кодом 0 не маскирует старые библиотеки, если ничего не пересобрал",
          rt.eval("RES_OK") is False and "make не обновил" in rt.eval("RES_MSG"))
    run("SETUP{built=true, force=true, exec={'git','make','cargo'}, make_produces=true, make_kind='bad'}")
    check("испорченный результат make не принимается из-за кэшированной старой библиотеки",
          rt.eval("RES_OK") is False and "wrong architecture" in rt.eval("RES_MSG"))
    run("SETUP{exec={'git','make','cargo'}, make_produces=true, copy_fail=true}")
    check("ошибка проверки копии make не скрывается", rt.eval("RES_OK") is False and "copy failed" in rt.eval("RES_MSG"))

    run("""
      RESET{exec={'git','curl','tar'}, tar_produces=true}
      RESULTS = {}
      B.build(DIR, function(ok) RESULTS[#RESULTS+1] = ok end)
      B.build(DIR, function(ok) RESULTS[#RESULTS+1] = ok end, {force=true})
      drain()
    """)
    check("одновременные запросы используют одну сборку и оба завершаются",
          rt.eval("count_command('curl')") == 1 and rt.eval("#RESULTS") == 2
          and rt.eval("RESULTS[1] and RESULTS[2]") is True)
    run("RESET{exec={'git','curl','tar'}, tar_produces=true}; BR_OK, BR_MSG = B.build_blocking(DIR, 1000)")
    check("build_blocking возвращает результат lazy.nvim", rt.eval("BR_OK") is True, str(rt.eval("BR_MSG")))

    # Проверка обычного require отдельно от прямого dlopen.
    run("""
      RESET{built=true, exec={'git'}}
      for _, name in ipairs(NAMES) do
        package.loaded[name] = nil
        package.preload[name] = function()
          local module = {}
          for _, export in ipairs(EXPECTED[name]) do module[export] = function() end end
          return module
        end
      end
      REQ_OK, REQ_MSG = B.runtime_check(DIR)
    """)
    check("runtime_check проверяет настоящий require", rt.eval("REQ_OK") is True)
    run("""
      package.loaded.avante_templates = nil
      package.preload.avante_templates = function() error('runtime path problem') end
      REQ_OK, REQ_MSG = B.runtime_check(DIR)
    """)
    check("ошибка require не скрывается наличием файла", rt.eval("REQ_OK") is False and "runtime path problem" in rt.eval("REQ_MSG"))
    run("""
      package.loaded.avante_templates = nil
      package.preload.avante_templates = function() return {initialize=function() end, render=function() end} end
      package.loaded.avante_repo_map = nil
      package.preload.avante_repo_map = function() error('repo map search failed') end
      REQ_OK, REQ_MSG = B.runtime_check(DIR)
    """)
    check("файлы есть, но require avante_repo_map упал: плагин не готов",
          rt.eval("REQ_OK") is False and "avante_repo_map" in rt.eval("REQ_MSG") and "repo map search failed" in rt.eval("REQ_MSG"))
    check("ошибка require не оставляет sentinel LuaJIT в package.loaded", rt.eval("package.loaded.avante_repo_map == nil"))
    run("""
      -- Ошибка могла возникнуть до нашего запуска, в другом компоненте.
      pcall(require, 'avante_repo_map')
      package.preload.avante_repo_map = function() return {stringify_definitions=function() end} end
      REQ_OK, REQ_MSG = B.runtime_check(DIR)
    """)
    check("устаревший sentinel после чужой ошибки удаляется и require восстанавливается", rt.eval("REQ_OK") is True)
    run("""
      package.loaded.avante_repo_map = nil
      package.preload.avante_repo_map = function() return {} end
      REQ_OK, REQ_MSG = B.runtime_check(DIR)
    """)
    check("require avante_repo_map с неверным API не принимается",
          rt.eval("REQ_OK") is False and "stringify_definitions" in rt.eval("REQ_MSG"))
    run("""
      package.loaded.avante_repo_map = nil
      package.preload.avante_repo_map = function() return {stringify_definitions=function() end} end
      package.loaded.avante_templates = nil
      RESETS = {}
      vim.loader = {reset=function(path) RESETS[#RESETS+1] = 'nvim:' .. path end}
      package.loaded['lazy.core.cache'] = {reset=function(path) RESETS[#RESETS+1] = 'lazy:' .. path end}
      package.preload.avante_templates = function()
        assert(#RESETS == 2, 'stale module index')
        return {initialize=function() end, render=function() end}
      end
      REQ_OK = B.runtime_check(DIR)
    """)
    check("перед require сбрасываются индексы lazy и vim.loader только для каталога плагина",
          rt.eval("REQ_OK") is True and rt.eval("RESETS[1]") == "lazy:/P/avante" and rt.eval("RESETS[2]") == "nvim:/P/avante")

    av = open(os.path.join(_lua.ROOT, "lua", "plugins", "avante.lua"), encoding="utf-8").read()
    bm = open(os.path.join(_lua.ROOT, "lua", "config", "avante_build.lua"), encoding="utf-8").read()
    lock = json.load(open(os.path.join(_lua.ROOT, "lazy-lock.json"), encoding="utf-8"))
    spec_tag = re.search(r'tag\s*=\s*"(v[\d.]+)"', av)
    check("tag, модуль сборки и lock указывают одну версию",
          spec_tag is not None and spec_tag.group(1) == rt.eval("B.TAG")
          and lock["avante.nvim"]["commit"] == rt.eval("B.COMMIT"))
    check("build hook принудительно обновляет бинарники", "build_blocking(plugin.dir)" in av and "{ force = true }" in bm)
    bootstrap = open(os.path.join(_lua.ROOT, "lua", "config", "avante_commands.lua"), encoding="utf-8").read()
    check("runtime подключён; команды принадлежат конфигу, а не lazy",
          'require("config.avante_runtime").setup(plugin, opts)' in av
          and '"AvanteRebuild"' not in av and '"AvanteStatus"' not in av
          and '"AvanteRebuild"' in bootstrap and '"AvanteStatus"' in bootstrap)
    check("avante v0.4.8 не загружается на nvim < 0.12", 'vim.fn.has("nvim-0.12") == 1' in av)

    failed = sum(1 for _, ok in checks if not ok)
    print(f"\nпроверок: {len(checks)}, провалов: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
