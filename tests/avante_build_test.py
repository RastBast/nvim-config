#!/usr/bin/env python3
"""Тесты сборки avante (lua/config/avante_build.lua) и её подключения в avante.lua.

Что проверяем:
  * выбор архива по платформе (macOS arm64/x86_64, Linux, неизвестная ОС);
  * ссылка на архив закреплённого тега;
  * успех только когда файл библиотеки появился на диске (а не по коду возврата);
  * понятные сообщения: 404, тихий сбой распаковки, нет cargo, ошибка make;
  * тег в avante.lua совпадает с M.TAG; нет старого build.sh.

Внешние команды (curl, tar, make) и файловая система подменяются заглушками,
так что тест не требует сети, macOS и Rust.

Запуск:  python3 tests/avante_build_test.py
"""
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
LIB = DIR .. "/lua/avante_templates.so"

vim.split = function(s, sep)
  local out = {}
  for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
  return out
end
vim.list_slice = function(t, a, b)
  local o = {}
  for i = a, (b or #t) do o[#o + 1] = t[i] end
  return o
end
-- Модель главного цикла: vim.schedule откладывает функцию в очередь,
-- drain() выполняет её, как цикл событий nvim. vim.system вызывает колбэк
-- в fast-контексте (IN_FAST = true), где vim.fn запрещён (E5560).
QUEUE, IN_FAST = {}, false
vim.schedule = function(fn) QUEUE[#QUEUE + 1] = fn end
function drain()
  while #QUEUE > 0 do
    local f = table.remove(QUEUE, 1)
    f()
  end
end
vim.wait = function(_, cond)
  for _ = 1, 100 do
    drain()
    if cond() then return true end
  end
  return cond()
end

EXEC, EXISTS, CALLS, UNAME, HANDLER = {}, {}, {}, nil, nil
vim.fn.has = function() return 0 end
vim.fn.executable = function(x) return EXEC[x] and 1 or 0 end
vim.fn.tempname = function() return "/tmp/fake" end
vim.fn.mkdir = function() return 0 end
vim.fn.isdirectory = function() return 1 end
vim.fn.delete = function(p) CALLS[#CALLS + 1] = "delete " .. p; return 0 end
local FNS = vim.fn
vim.fn = setmetatable({}, {
  __index = function(_, k)
    if IN_FAST then error("E5560: vim.fn." .. tostring(k) .. " вызван в fast-контексте") end
    return FNS[k]
  end,
  __newindex = function(_, k, v) FNS[k] = v end,
})
vim.uv.os_uname = function() return UNAME end
vim.uv.fs_stat = function(p) if EXISTS[p] then return {} end return nil end
vim.system = function(cmd, opts, cb)
  CALLS[#CALLS + 1] = table.concat(cmd, " ")
  if SPAWN_FAIL then error("spawn failed") end
  local r = HANDLER(cmd, opts)
  local prev = IN_FAST
  IN_FAST = true
  cb({ code = r.code or 0, stderr = r.stderr or "", stdout = "" })
  IN_FAST = prev
  return { wait = function() return r end }
end

B = require("config.avante_build")

function SETUP(o)
  CALLS, EXISTS, EXEC = {}, {}, {}
  SPAWN_FAIL = o.spawn_fail
  for _, c in ipairs(o.exec or {}) do EXEC[c] = true end
  UNAME = o.uname
  if o.built then EXISTS[LIB] = true end
  HANDLER = function(cmd)
    local name = cmd[1]
    if name == "curl" then
      return { code = o.curl_code or 0, stderr = o.curl_err or "" }
    elseif name == "tar" then
      if o.tar_produces then EXISTS[LIB] = true end
      return { code = o.tar_code or 0, stderr = o.tar_err or "" }
    elseif name == "make" then
      if o.make_produces then EXISTS[LIB] = true end
      return { code = o.make_code or 0, stderr = o.make_err or "" }
    end
    return { code = 0 }
  end
  RES_OK, RES_MSG = nil, nil
  B.build(DIR, function(ok, msg) RES_OK, RES_MSG = ok, msg end)
  drain()
end
'''

MAC_ARM = 'uname={sysname="Darwin", machine="arm64"}'


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    with open(os.path.join(_lua.ROOT, "tests", "lua_stubs.lua"), encoding="utf-8") as fh:
        rt.execute(fh.read())
    rt.execute(PRELUDE)

    def run(setup_lua):
        rt.execute(setup_lua)

    # ------------------------------------------------------- выбор архива ---
    cases = [
        ("Darwin", "arm64", "avante_lib-darwin-aarch64-luajit.tar.gz"),
        ("Darwin", "x86_64", "avante_lib-darwin-x86_64-luajit.tar.gz"),
        ("Linux", "x86_64", "avante_lib-linux-x86_64-luajit.tar.gz"),
        ("Linux", "aarch64", "avante_lib-linux-aarch64-luajit.tar.gz"),
    ]
    for osn, mach, want in cases:
        got = rt.eval(f"B.artifact('{osn}', '{mach}')")
        check(f"архив для {osn}/{mach}", got == want, str(got))
    check("неизвестная ОС → nil", rt.eval("B.artifact('Windows_NT', 'AMD64')") is None)

    url = rt.eval("B.url('avante_lib-darwin-aarch64-luajit.tar.gz', 'v0.4.8')")
    check("ссылка на релиз закреплённого тега",
          url == "https://github.com/avante-corp/avante.nvim/releases/download/v0.4.8/avante_lib-darwin-aarch64-luajit.tar.gz",
          str(url))

    # ---------------------------------------------------- успешные пути ---
    run(f"SETUP{{ exec={{'curl','tar'}}, {MAC_ARM}, tar_produces=true }}")
    check("Mac arm64: сборка успешна, когда файл появился", rt.eval("RES_OK") is True, str(rt.eval("RES_MSG")))
    check("Mac arm64: первым curl с тегом v0.4.8",
          "releases/download/v0.4.8/avante_lib-darwin-aarch64-luajit.tar.gz" in rt.eval("CALLS[1]"),
          str(rt.eval("CALLS[1]")))
    check("Mac arm64: curl с --fail (404 не сохраняется как архив)",
          str(rt.eval("CALLS[1]")).startswith("curl -fsSL -o "))
    check("Mac arm64: tar распаковывает в lua/ плагина",
          str(rt.eval("CALLS[2]")).startswith("tar -xzf ") and str(rt.eval("CALLS[2]")).endswith("-C /P/avante/lua"),
          str(rt.eval("CALLS[2]")))
    check("Mac arm64: make не запускается, когда готовый архив подошёл",
          rt.eval("#CALLS") == 3 or all("make" not in c for c in [rt.eval(f"CALLS[{i}]") for i in range(1, rt.eval("#CALLS") + 1)]))

    run(f"SETUP{{ built=true, exec={{}}, {MAC_ARM} }}")
    check("уже собрано: без единой команды", rt.eval("RES_OK") is True and rt.eval("#CALLS") == 0)

    run("SETUP{ exec={'curl','tar'}, uname={sysname='Darwin', machine='x86_64'}, tar_produces=true }")
    check("Mac Intel: архив x86_64",
          "darwin-x86_64-luajit" in str(rt.eval("CALLS[1]")), str(rt.eval("CALLS[1]")))

    run("SETUP{ exec={'curl','tar'}, uname={sysname='Linux', machine='x86_64'}, tar_produces=true }")
    check("Linux x86_64: сборка успешна", rt.eval("RES_OK") is True)

    # ------------------------------------------------- отказы и сообщения ---
    run(f"SETUP{{ exec={{'curl','tar'}}, {MAC_ARM}, curl_code=22 }}")
    msg = str(rt.eval("RES_MSG"))
    check("404 / нет архива: сборка не объявлена успешной", rt.eval("RES_OK") is False)
    check("404: сообщение называет тег и «не скачалась»",
          "не скачалась" in msg and "v0.4.8" in msg, msg)
    check("404 без cargo: подсказка про Rust (brew install rust)", "brew install rust" in msg, msg)
    check("404 без cargo: make не вызывался", all("make" not in str(rt.eval(f"CALLS[{i}]")) for i in range(1, rt.eval("#CALLS") + 1)))

    run(f"SETUP{{ exec={{'curl','tar'}}, {MAC_ARM}, tar_produces=false }}")
    msg = str(rt.eval("RES_MSG"))
    check("ТИХИЙ СБОЙ: архив распакован, файла нет → не успех (как «No latest tag» в build.sh)",
          rt.eval("RES_OK") is False, msg)
    check("тихий сбой: сообщение называет отсутствующую библиотеку",
          "avante_templates" in msg, msg)

    run(f"SETUP{{ exec={{'curl','tar','make','cargo'}}, {MAC_ARM}, tar_produces=false, make_produces=true }}")
    check("тихий сбой + cargo: запасной make собирает и это успех",
          rt.eval("RES_OK") is True, str(rt.eval("RES_MSG")))
    check("тихий сбой + cargo: make запущен после распаковки",
          any(str(rt.eval(f"CALLS[{i}]")) == "make" for i in range(1, rt.eval("#CALLS") + 1)))

    run(f"SETUP{{ exec={{'curl','tar','make','cargo'}}, {MAC_ARM}, curl_code=6, make_produces=true }}")
    check("нет сети + cargo: make собирает",
          rt.eval("RES_OK") is True, str(rt.eval("RES_MSG")))

    run(f"SETUP{{ exec={{'curl','tar','make','cargo'}}, {MAC_ARM}, tar_produces=false, make_code=2, make_err='error: linker failed\\nfoo' }}")
    msg = str(rt.eval("RES_MSG"))
    check("make упал: ошибка, код и хвост stderr в сообщении",
          rt.eval("RES_OK") is False and "код 2" in msg and "linker failed" in msg, msg)

    run(f"SETUP{{ exec={{'make','cargo'}}, {MAC_ARM}, make_produces=true }}")
    check("нет curl: сразу make (без попытки скачать)",
          rt.eval("RES_OK") is True and all("curl" not in str(rt.eval(f"CALLS[{i}]")) for i in range(1, rt.eval("#CALLS") + 1)),
          str(rt.eval("RES_MSG")))

    run("SETUP{ exec={'curl','tar','make','cargo'}, uname={sysname='Windows_NT', machine='AMD64'}, make_produces=true }")
    check("неизвестная платформа: make, без curl",
          rt.eval("RES_OK") is True and all("curl" not in str(rt.eval(f"CALLS[{i}]")) for i in range(1, rt.eval("#CALLS") + 1)),
          str(rt.eval("RES_MSG")))

    run(f"SETUP{{ exec={{}}, {MAC_ARM} }}")
    check("ничего нет (ни curl, ни make): понятная ошибка, без падения",
          rt.eval("RES_OK") is False and "brew install rust" in str(rt.eval("RES_MSG")))

    run(f"SETUP{{ exec={{'curl','tar'}}, {MAC_ARM}, spawn_fail=true }}")
    check("ошибка запуска curl: понятный отказ без исключения", rt.eval("RES_OK") is False)

    # -------------------------------------------- синхронная обёртка (lazy) ---
    run(f"SETUP{{ exec={{'curl','tar'}}, {MAC_ARM}, tar_produces=true }}")
    rt.execute("BR_OK, BR_MSG = B.build_blocking(DIR, 1000)")
    check("build_blocking возвращает результат для хука lazy.nvim", rt.eval("BR_OK") is True)

    # ---------------------------------------------------- подключение ---
    av = open(os.path.join(_lua.ROOT, "lua", "plugins", "avante.lua"), encoding="utf-8").read()
    bm = open(os.path.join(_lua.ROOT, "lua", "config", "avante_build.lua"), encoding="utf-8").read()
    m = re.search(r'tag\s*=\s*"(v[\d.]+)"', av)
    spec_tag = m.group(1) if m else None
    m2 = re.search(r'M\.TAG\s*=\s*"(v[\d.]+)"', bm)
    check("avante.lua: тег закреплён (tag = \"v…\")", spec_tag is not None, str(spec_tag))
    check("avante.lua и avante_build.lua: один и тот же тег",
          spec_tag is not None and m2 is not None and spec_tag == m2.group(1), f"{spec_tag} vs {m2 and m2.group(1)}")
    check("avante.lua: version = false (не \"*\")", "version = false" in av and 'version = "*"' not in av)
    check("avante.lua: build использует build_blocking", "build_blocking(plugin.dir)" in av)
    check("avante.lua: build.sh больше не вызывается (только в комментарии)",
          '"./build.sh"' not in av and '"bash"' not in av)
    check("avante.lua: старого голого make в build нет", 'vim.system({ "make" }' not in av)
    check("avante.lua: :AvanteRebuild зарегистрирована",
          'nvim_create_user_command("AvanteRebuild"' in av)
    check("avante.lua: команда AvanteRebuild в ленивом cmd", '"AvanteRebuild"' in av)
    check("avante.lua: проверка библиотеки через B.is_built",
          "B.is_built(plugin_dir())" in av)
    check("avante_build.lua: нет тавтологий (or true)", "or true" not in bm)
    check("avante_build.lua: vim.system вызывается только через sys() (колбэк уходит в главный цикл)",
          bm.count("pcall(vim.system,") == 1 and "vim.schedule(function()" in bm)

    failed = sum(1 for _, ok in checks if not ok)
    print(f"\nпроверок: {len(checks)}, провалов: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
