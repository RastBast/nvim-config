#!/usr/bin/env python3
"""Регрессия повреждённого кеша avante v0.4.8 и прямых вызовов карты.

Исполняет LuaJIT-код защиты, включая настоящий userdata (аналог vim.NIL),
ошибку JSON-декодера, некорректную форму, повторный setup и native preflight.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    with open(os.path.join(_lua.ROOT, "tests", "lua_stubs.lua"), encoding="utf-8") as fh:
        rt.execute(fh.read())
    rt.execute(r'''
      READY, STATUS, LOADED, SAVES, BUILDS, AVAILABLE, CORE = false, 0, nil, 0, 0, true, true
      PATH = {
        available = function() if AVAILABLE == 'throw' then error('templates broken') end; return AVAILABLE end,
        repo_map = {
          load = function() if LOADED == 'invalid json' then error('invalid JSON') end; return LOADED end,
          save = function(_, _, data) SAVES = SAVES + 1; SAVED = data end,
        },
      }
      REPO = {
        _init_repo_map_lib = function() return CORE and {stringify_definitions=function() end} or nil end,
        _get_repo_map = function()
          local data = PATH.repo_map.load('root', 'lua')
          if not data or next(data) == nil then
            BUILDS = BUILDS + 1
            data = BUILD_RESULT
            PATH.repo_map.save('root', 'lua', data)
          end
          return data
        end,
        get_repo_map = function() return REPO._get_repo_map() or {} end,
        show = function() return REPO.get_repo_map() end,
      }
      package.loaded['avante.path'], package.loaded['avante.repo_map'] = PATH, REPO
      G = require('config.avante_repo_map')
      G.install(function() return READY end, function() STATUS = STATUS + 1 end)
      VALID = { {path='src/a.lua', lang='lua', defs='function x'} }
    ''')
    checks = []

    def check(label, cond):
        checks.append(cond)
        print(("OK   " if cond else "FAIL ") + label)

    rt.execute("REPO.show(); RESULT = REPO.get_repo_map(); INTERNAL = REPO._get_repo_map()")
    check("до готовности прямая команда сообщает статус, построение карты отключено",
          rt.eval("STATUS == 1 and BUILDS == 0 and #RESULT == 0 and #INTERNAL == 0"))
    rt.execute("READY=true; LOADED=io.stdout; BUILD_RESULT=VALID; RESULT=REPO.get_repo_map()")
    check("JSON null (userdata) игнорируется, карта перестраивается без next(userdata)",
          rt.eval("RESULT == VALID and BUILDS == 1 and SAVES == 1 and G.invalid_cache_count == 1"))
    rt.execute("LOADED='invalid json'; RESULT=REPO.get_repo_map()")
    check("синтаксически неверный JSON восстанавливается после перестроения",
          rt.eval("RESULT == VALID and BUILDS == 2 and SAVES == 2 and G.invalid_cache_count == 2"))
    rt.execute("LOADED = {broken='object'}; RESULT=REPO.get_repo_map()")
    check("JSON object вместо массива не доходит до upstream", rt.eval("BUILDS == 3 and RESULT == VALID"))
    rt.execute("LOADED = {{path='a',lang='lua',defs=io.stdout}}; RESULT=REPO.get_repo_map()")
    check("поля записи повреждены: кеш не используется", rt.eval("BUILDS == 4 and RESULT == VALID"))
    rt.execute("LOADED=VALID; RESULT=REPO.get_repo_map()")
    check("корректная карта остаётся нетронутой", rt.eval("BUILDS == 4 and RESULT == VALID"))
    rt.execute("LOADED=nil; BUILD_RESULT=nil; OLD_SAVES=SAVES; RESULT=REPO.get_repo_map()")
    check("ошибка построения не записывает в кеш новый JSON null",
          rt.eval("#RESULT == 0 and SAVES == OLD_SAVES"))
    rt.execute("PATH.repo_map.save('root','lua',io.stdout); PATH.repo_map.save('root','lua',{bad='shape'})")
    check("save отклоняет userdata и произвольные объекты", rt.eval("SAVES == OLD_SAVES"))
    rt.execute("OK = G.native_ready(); AVAILABLE=false; BAD1, MSG1 = G.native_ready(); AVAILABLE=true; CORE=false; BAD2, MSG2 = G.native_ready()")
    check("preflight проверяет обе внутренние библиотеки до setup",
          rt.eval("OK and not BAD1 and not BAD2") and "avante_templates" in rt.eval("MSG1") and "avante_repo_map" in rt.eval("MSG2"))
    rt.execute("""
      READY=false
      G.install(function() return true end, function() STATUS=STATUS+100 end)
      LOADED=VALID; RESULT=REPO.get_repo_map()
    """)
    check("повторный setup обновляет проверку готовности, не наслаивая старые замыкания",
          rt.eval("RESULT == VALID"))
    print(f"\nпроверок: {len(checks)}, провалов: {len(checks) - sum(checks)}")
    return 0 if all(checks) else 1


if __name__ == "__main__":
    sys.exit(main())
