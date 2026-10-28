"""Общий хелпер тестов: Lua-рантайм на LuaJIT 2.1 (как в Neovim).

Нужен пакет lupa (pip install lupa): в нём есть сборка LuaJIT 2.1
(lupa.luajit21). Если её нет — падаем обратно на системную Lua (лучше,
чем ничего, но проверка совместимости с LuaJIT тогда не выполняется).
"""
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def runtime():
    try:
        from lupa.luajit21 import LuaRuntime  # LuaJIT 2.1 — тот же язык, что в Neovim
        kind = "luajit21"
    except ImportError:
        from lupa import LuaRuntime
        kind = "system-lua (LuaJIT не найден — проверка совместимости неполная)"
    rt = LuaRuntime(unpack_returned_tuples=True)
    rt.globals().ROOT_PATH = ROOT
    return rt, kind


def ensure_path():
    if os.path.dirname(os.path.abspath(__file__)) not in sys.path:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
