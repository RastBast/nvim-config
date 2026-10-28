#!/usr/bin/env python3
"""Тесты тем (lua/config/themes.lua) и порядка запуска (init.lua).

Проверяем:
  * список M.order совпадает с набором тем и без повторов;
  * «Новая», «Старая» и Halloween применяют фон #000000 и дерево файлов (nvim-tree);
  * пять оригинальных схем НЕ переопределяют фон (у них нет apply);
  * в themes.lua и init.lua нет VimEnter-костыля;
  * themes.setup() вызывается в init.lua ПОСЛЕ lazy.setup; страховка catppuccin/habamax
    живёт ВНУТРИ setup() после применения сохранённой темы (без мерцания на старте).

Запуск:  python3 tests/themes_test.py
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


def read(rel):
    with open(os.path.join(_lua.ROOT, rel), encoding="utf-8") as fh:
        return fh.read()


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    with open(os.path.join(_lua.ROOT, "tests", "lua_stubs.lua"), encoding="utf-8") as fh:
        rt.execute(fh.read())
    rt.execute("T = require('config.themes')")

    rt.execute("""
      local keys = {}
      for k in pairs(T.themes) do keys[#keys + 1] = k end
      table.sort(keys)
      TKEYS = keys
    """)
    keys = [rt.eval(f"TKEYS[{i}]") for i in range(1, int(rt.eval("#TKEYS")) + 1)]
    order = [rt.eval(f"T.order[{i}]") for i in range(1, int(rt.eval("#T.order")) + 1)]

    check("в M.order нет повторов", len(order) == len(set(order)), str(order))
    check("M.order содержит все темы и только их", sorted(order) == sorted(keys),
          f"order={sorted(order)} themes={sorted(keys)}")
    check("8 тем (новая, старая, 5 оригиналов, halloween)", len(order) == 8, str(len(order)))
    check("halloween в списке", "halloween" in order)

    # Фон #000000 у «Новой», «Старой» и Halloween
    for name in ("new", "classic", "halloween"):
        rt.execute(f"HL = {{}}; T.apply('{name}')")
        ok_normal = rt.eval("HL.Normal and HL.Normal.bg") == "#000000"
        ok_tree = rt.eval("HL.NvimTreeNormal and HL.NvimTreeNormal.bg") == "#000000"
        check(f"{name}: Normal и дерево файлов — фон #000000", ok_normal and ok_tree)

    # Пять оригинальных схем: без своего apply (фон и цвета — от плагина)
    originals = ["tokyonight", "gruvbox", "kanagawa", "rosepine", "carbonfox"]
    for name in originals:
        has_apply = rt.eval(f"T.themes['{name}'].apply ~= nil")
        check(f"{name}: оригинал, без переопределения фона", not has_apply)

    # Halloween: акцентные цвета из палитры пользователя
    rt.execute("HL = {}; T.apply('halloween')")
    check("halloween: ключевые слова оранжевые #ff9500", rt.eval("HL['@keyword'].fg") == "#ff9500")
    check("halloween: строки жёлтые #fffb00", rt.eval("HL['@string'].fg") == "#fffb00")
    check("halloween: переменные зелёные #2bff00", rt.eval("HL['@variable'].fg") == "#2bff00")

    # Регрессия: VimEnter-костыля больше нет
    def code_only(src):
        return "\n".join(l for l in src.split("\n") if not l.strip().startswith("--"))
    check("themes.lua: в коде нет VimEnter (комментарии не считаются)",
          "VimEnter" not in code_only(read("lua/config/themes.lua")))
    init = read("init.lua")
    check("init.lua: в коде нет VimEnter", "VimEnter" not in code_only(init))

    # Порядок в init.lua: lazy.setup → страховка colorscheme → themes.setup
    i_lazy = init.find('require("lazy").setup(')
    i_themes = init.find('require("config.themes").setup()')
    check("init.lua: lazy.setup найден", i_lazy > 0)
    check("init.lua: themes.setup вызывается после lazy.setup", i_themes > i_lazy > 0,
          f"lazy={i_lazy} themes={i_themes}")
    # Мерцание: до themes.setup в init.lua НЕЛЬЗЯ ставить другую схему
    code_init = code_only(init)
    pre = code_init[:code_init.find('require("config.themes").setup()')]
    # Ищем именно ВЫЗОВ смены схемы (а не опцию install.colorscheme у lazy)
    calls = ("vim.cmd.colorscheme", 'vim.cmd("colorscheme', "vim.cmd('colorscheme")
    check("init.lua: до themes.setup нет вызова colorscheme (нет мерцания)",
          not any(c in pre for c in calls))

    # Страховка внутри themes.setup: сначала сохранённая тема, потом catppuccin/habamax
    th = code_only(read("lua/config/themes.lua"))
    i_set = th.find("pcall(M.set, M.current")
    i_fb = th.find('pcall(vim.cmd.colorscheme, "catppuccin-mocha")')
    i_fn = th.find("function M.setup()")
    check("themes.lua: сохранённая тема ставится в setup()", i_fn > 0 and i_set > i_fn)
    check("themes.lua: страховка catppuccin/habamax идёт ПОСЛЕ попытки темы",
          i_fb > i_set > 0, f"set={i_set} fallback={i_fb}")

    # Полные схемы: priority = 1000 (как просил пользователь)
    cs = read("lua/plugins/colorscheme.lua")
    full = [l for l in cs.split("\n") if 'lazy = true' in l and "name =" in l]
    check("полные схемы: у каждой priority = 1000", full and all("priority = 1000" in l for l in full),
          f"{len(full)} строк")

    failed = sum(1 for _, ok in checks if not ok)
    print(f"\nпроверок: {len(checks)}, провалов: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
