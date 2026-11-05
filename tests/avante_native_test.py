#!/usr/bin/env python3
"""Smoke-тест реального LuaJIT dlopen/require без Neovim и без сети.

На Linux компилирует маленький совместимый C-модуль, проверяет реальные .so,
повреждённый файл и обычный require; нативные бинарники Avante не подменяются в
репозитории. На других ОС или без C-компилятора тест явно пропускается.
"""
import ctypes
import os
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402

C_MODULE = r'''
typedef struct lua_State lua_State;
typedef int (*lua_CFunction)(lua_State *);
extern void lua_createtable(lua_State *, int, int);
extern void lua_pushcclosure(lua_State *, lua_CFunction, int);
extern void lua_setfield(lua_State *, int, const char *);
extern const char *lua_pushstring(lua_State *, const char *);
static int nop(lua_State *L) { (void)L; return 0; }
static int text(lua_State *L) { lua_pushstring(L, "test prompt"); return 1; }
static int tokens(lua_State *L) { lua_createtable(L, 0, 0); return 1; }
static void field(lua_State *L, const char *name, lua_CFunction fn) {
  lua_pushcclosure(L, fn, 0); lua_setfield(L, -2, name);
}
static int make_module(lua_State *L) {
  lua_createtable(L, 0, 7);
  field(L, "initialize", nop); field(L, "render", text);
  field(L, "from_pretrained", nop); field(L, "encode", tokens);
  field(L, "stringify_definitions", text); field(L, "fetch_md", text); field(L, "html2md", text);
  return 1;
}
int luaopen_avante_templates(lua_State *L) { return make_module(L); }
int luaopen_avante_tokenizers(lua_State *L) { return make_module(L); }
int luaopen_avante_repo_map(lua_State *L) { return make_module(L); }
int luaopen_avante_html2md(lua_State *L) { return make_module(L); }
'''


def main():
    if not sys.platform.startswith("linux") or not shutil.which("cc"):
        print("SKIP: реальный тест dlopen требует Linux и C-компилятор")
        return 0
    import lupa.luajit21  # noqa: PLC0415

    # В nvim символы LuaJIT экспортирует исполняемый файл. Python грузит lupa
    # локально, поэтому делаем их глобальными для тестового C-модуля.
    ctypes.CDLL(lupa.luajit21.__file__, mode=ctypes.RTLD_GLOBAL)
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    with open(os.path.join(_lua.ROOT, "tests", "lua_stubs.lua"), encoding="utf-8") as fh:
        rt.execute(fh.read())
    rt.globals().file_exists = os.path.isfile
    rt.execute("""
      vim.fn.has = function() return 0 end
      vim.uv.fs_stat = function(path) if file_exists(path) then return {type='file'} end end
      B = require('config.avante_build')
    """)

    with tempfile.TemporaryDirectory(prefix="avante-native-") as tmp:
        c_file = os.path.join(tmp, "fixture.c")
        lib_file = os.path.join(tmp, "fixture.so")
        with open(c_file, "w", encoding="utf-8") as fh:
            fh.write(C_MODULE)
        subprocess.run(["cc", "-shared", "-fPIC", "-o", lib_file, c_file], check=True, capture_output=True, text=True)
        good = os.path.join(tmp, "good")
        bad = os.path.join(tmp, "bad")
        os.makedirs(os.path.join(good, "lua"))
        os.makedirs(os.path.join(bad, "lua"))
        names = ("templates", "tokenizers", "repo_map", "html2md")
        for name in names:
            shutil.copyfile(lib_file, os.path.join(good, "lua", "avante_" + name + ".so"))
        with open(os.path.join(bad, "lua", "avante_templates.so"), "wb") as fh:
            fh.write(b"not a real shared object")
        rt.globals().GOOD_DIR = good
        rt.globals().BAD_DIR = bad
        rt.execute("""
          BAD_OK, BAD_MSG = B.check(BAD_DIR)
          GOOD_OK, GOOD_MSG = B.check(GOOD_DIR)
          package.cpath = GOOD_DIR .. '/lua/?.so;' .. package.cpath
          REQUIRE_OK, REQUIRE_MSG = B.runtime_check(GOOD_DIR)
        """)
        tests = [
            ("повреждённый существующий .so отклоняется dlopen", not rt.eval("BAD_OK") and "не удалось загрузить" in rt.eval("BAD_MSG")),
            ("четыре реальные библиотеки проходят dlopen и проверку API", rt.eval("GOOD_OK")),
            ("runtime_check действительно вызывает LuaJIT require", rt.eval("REQUIRE_OK")),
        ]
        for name, ok in tests:
            print(("OK   " if ok else "FAIL ") + name)
        return 1 if not all(ok for _, ok in tests) else 0


if __name__ == "__main__":
    sys.exit(main())
