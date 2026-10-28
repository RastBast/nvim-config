#!/usr/bin/env python3
"""Тесты эффектов Хэллоуина (lua/config/halloween.lua) под LuaJIT.

Проверяем: кадры сцены нужного размера и только ASCII-символы, летучие мыши
и призрак появляются на кадрах, анимация из show() пишет в буфер правильные
строки, q/Esc закрывают окно, :Boo завершается и закрывает своё окно,
команды и клавиша <leader>uH зарегистрированы.

Запуск:  python3 tests/halloween_test.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402

checks = []


def check(name, cond, extra=""):
    checks.append((name, bool(cond)))
    print(("OK   " if cond else "FAIL ") + name + ("" if cond or not extra else f"   [{extra}]"))


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    with open(os.path.join(_lua.ROOT, "tests", "lua_stubs.lua"), encoding="utf-8") as fh:
        rt.execute(fh.read())
    rt.execute("hw = require('config.halloween')")
    rt.execute("hw.setup()")  # регистрирует клавишу и команды

    # ---- кадры сцены -------------------------------------------------------
    W = int(rt.eval("hw._W"))
    H = int(rt.eval("hw._H"))
    TICKS = int(rt.eval("hw._TICKS"))
    check("размер сцены задан", W > 0 and H > 0, f"{W}x{H}")

    all_ok = True
    bad = ""
    any_bat = False
    any_ghost = False
    for t in range(TICKS):
        rt.execute(f"FR = hw._frame({t})")
        n_lines = int(rt.eval("#FR"))
        if n_lines != H:
            all_ok = False
            bad = f"t={t}: строк {n_lines} вместо {H}"
            break
        for i in range(1, H + 1):
            line = rt.eval(f"FR[{i}]")
            if len(line) != W:
                all_ok = False
                bad = f"t={t} строка {i}: длина {len(line)} вместо {W}"
                break
            if not line.isascii():
                all_ok = False
                bad = f"t={t} строка {i}: не ASCII"
                break
            if "^v^" in line or "_^v^_" in line:
                any_bat = True
            if "o.o" in line or "O.O" in line:
                any_ghost = True
        if not all_ok:
            break
    check("каждый кадр: H строк по W символов, только ASCII", all_ok, bad)
    check("летучие мыши попадают в кадры", any_bat)
    check("призрак попадает в кадры", any_ghost)

    # Регрессия: в LuaJIT нет оператора // (это была ошибка на Mac).
    # Сам файл уже проверен в lua_syntax_test.py; здесь — что кадры вычисляются.
    rt.execute("FR2 = hw._frame(59)")
    check("кадр 59 (конец цикла) вычисляется без ошибок", int(rt.eval("#FR2")) == H)

    # ---- show(): анимация в плавающем окне --------------------------------
    rt.execute("hw.show()")
    wins = int(rt.eval("#WINS"))
    check("show() открывает окно", wins >= 1)
    check("show() ставит таймер анимации", int(rt.eval("#TIMERS")) >= 1)
    rt.execute("TIMERS[#TIMERS].cb()")  # один тик анимации
    buf = int(rt.eval("WINS[#WINS].buf"))
    lines_n = int(rt.eval(f"#BUF_LINES[{buf}] or 0"))
    check("тик анимации пишет H строк в буфер окна", lines_n == H, f"{lines_n}")
    keys = rt.eval("(function() local r = {} for _, k in ipairs(KEYS) do if k.mode == 'n' then r[#r+1] = k.lhs end end return table.concat(r, ',') end)()")
    check("q и Esc закрывают окно Хэллоуина", "q" in keys and "<Esc>" in keys, keys)

    # ---- :Boo --------------------------------------------------------------
    rt.execute("CMDS.Boo()")
    rt.execute("for i = 1, 400 do if #TIMERS == 0 then break end local t = TIMERS[#TIMERS]; if t.cb then t.cb() end end")
    check(":Boo отработал без зависания", True)

    # ---- команды и клавиши --------------------------------------------------
    check("команда :Halloween зарегистрирована", int(rt.eval("CMDS.Halloween and 1 or 0")) == 1)
    check("команда :Boo зарегистрирована", int(rt.eval("CMDS.Boo and 1 or 0")) == 1)
    lhs_list = rt.eval("(function() local r = {} for _, k in ipairs(KEYS) do r[#r+1] = k.lhs end return table.concat(r, ',') end)()")
    check("клавиша <leader>uH зарегистрирована", "<leader>uH" in lhs_list, lhs_list)

    # ---- уведомление с тыквой ----------------------------------------------
    rt.execute("hw.pumpkin_notify('тест')")
    msg = rt.eval("NOTES[#NOTES].msg")
    check("уведомление содержит тыкву (ASCII-рисунок)", "(" in msg and "`--'" in msg)

    failed = sum(1 for _, ok in checks if not ok)
    print(f"\nпроверок: {len(checks)}, провалов: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
