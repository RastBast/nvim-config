#!/usr/bin/env python3
"""Проверка синтаксиса всех Lua-файлов репозитория под LuaJIT 2.1.

Зачем: Neovim использует LuaJIT, а не Lua 5.3+. Например, оператор `//`
(целочисленное деление) есть в Lua 5.3+, но в LuaJIT это синтаксическая
ошибка: «unexpected symbol near '/'». Такая ошибка прошла бы проверку на
Lua 5.5 и упала бы только у пользователя при старте nvim.

Запуск:  python3 tests/lua_syntax_test.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402

SKIP_DIRS = {".git", "node_modules", "build", "target"}


def lua_files():
    out = []
    for dirpath, dirnames, filenames in os.walk(_lua.ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")]
        for f in filenames:
            if f.endswith(".lua"):
                out.append(os.path.join(dirpath, f))
    return sorted(out)


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    load = rt.eval("function(src, name) return load(src, '@' .. name) end")
    fails = 0
    files = lua_files()
    for path in files:
        rel = os.path.relpath(path, _lua.ROOT)
        with open(path, encoding="utf-8") as fh:
            src = fh.read()
        res = load(src, rel)
        if isinstance(res, tuple):  # (nil, сообщение) — синтаксическая ошибка
            fails += 1
            print("FAIL", rel, "—", res[1])
        else:
            print("OK  ", rel)
    print(f"\nфайлов: {len(files)}, провалов: {fails}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
