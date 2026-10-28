#!/usr/bin/env python3
"""Тесты Хэллоуина (lua/config/halloween.lua) под LuaJIT.

Два режима:
  * ОВЕРЛЕЙ (<leader>uH, :Halloween [on|off]) — мыши поверх редактора, тема
    halloween, флаг vim.g.halloween_on, палитра терминала, сохранение состояния;
  * ОКНО-АНИМАЦИЯ (<leader>uHw, :HalloweenWin) — кадры сцены, q/Esc закрывают.
Плюс :Boo, уведомление с тыквой и регистрация команд/клавиш.

Запуск:  python3 tests/halloween_test.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402

checks = []
STATE_DIR = "/tmp/nvim_tests_state"


def check(name, cond, extra=""):
    checks.append((name, bool(cond)))
    print(("OK   " if cond else "FAIL ") + name + ("" if cond or not extra else f"   [{extra}]"))


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    os.makedirs(STATE_DIR, exist_ok=True)
    state_file = os.path.join(STATE_DIR, "halloween.txt")
    if os.path.exists(state_file):
        os.remove(state_file)
    with open(os.path.join(_lua.ROOT, "tests", "lua_stubs.lua"), encoding="utf-8") as fh:
        rt.execute(fh.read())
    rt.execute("hw = require('config.halloween'); T = require('config.themes')")
    rt.execute("hw.setup()")  # регистрирует клавиши и команды

    # ---------------------------------------------------------- окно-кадры ---
    W = int(rt.eval("hw._W"))
    H = int(rt.eval("hw._H"))
    TICKS = int(rt.eval("hw._TICKS"))
    check("размер сцены задан", W > 0 and H > 0, f"{W}x{H}")

    all_ok, bad, any_bat, any_ghost = True, "", False, False
    for t in range(TICKS):
        rt.execute(f"FR = hw._frame({t})")
        if int(rt.eval("#FR")) != H:
            all_ok, bad = False, f"t={t}: строк {int(rt.eval('#FR'))} вместо {H}"
            break
        for i in range(1, H + 1):
            line = rt.eval(f"FR[{i}]")
            if len(line) != W or not line.isascii():
                all_ok, bad = False, f"t={t} строка {i}: длина {len(line)}"
                break
            any_bat = any_bat or ("^v^" in line)
            any_ghost = any_ghost or ("o.o" in line or "O.O" in line)
        if not all_ok:
            break
    check("каждый кадр окна: H строк по W символов, только ASCII", all_ok, bad)
    check("летучие мыши попадают в кадры окна", any_bat)
    check("призрак попадает в кадры окна", any_ghost)
    rt.execute("FR2 = hw._frame(59)")
    check("кадр 59 (конец цикла) вычисляется без ошибок", int(rt.eval("#FR2")) == H)

    # ------------------------------------------------------- окно: команды ---
    rt.execute("hw.show()")
    check("<leader>uHw открывает окно-анимацию (show)", int(rt.eval("#WINS")) >= 1)
    rt.execute("TIMERS[#TIMERS].cb()")
    buf = int(rt.eval("WINS[#WINS].buf"))
    check("тик окна пишет H строк в буфер", int(rt.eval(f"#BUF_LINES[{buf}] or 0")) == H)
    keys_n = rt.eval("(function() local r = {} for _, k in ipairs(KEYS) do if k.mode == 'n' then r[#r+1] = k.lhs end end return table.concat(r, ',') end)()")
    check("q и Esc закрывают окно-анимацию", "q" in keys_n and "<Esc>" in keys_n, keys_n)
    rt.execute("CMDS.HalloweenWin()")
    check(":HalloweenWin зарегистрирована и открывает окно", int(rt.eval("#WINS")) >= 2)

    # ------------------------------------------------- клавиши и команды ---
    def bound_to(lhs_key, fn_name):
        return rt.eval(
            f"(function() for _, k in ipairs(KEYS) do if k.lhs == '{lhs_key}' then "
            f"return k.rhs == hw.{fn_name} end end return false end)()")

    check("<leader>uH — переключение оверлея (hw.toggle)", bound_to("<leader>uH", "toggle"))
    check("<leader>uHw — окно-анимация (hw.show)", bound_to("<leader>uHw", "show"))
    check("команды :Halloween, :HalloweenWin, :Boo зарегистрированы",
          all(rt.eval(f"CMDS['{c}'] ~= nil") for c in ("Halloween", "HalloweenWin", "Boo")))

    # ------------------------------------------------------ оверлей: вкл/выкл ---
    check("по умолчанию оверлей выключен", not rt.eval("hw.is_on()"))
    check("vim.g.halloween_on = 0 на старте", int(rt.eval("vim.g.halloween_on")) == 0)

    rt.execute("CMDS.Halloween({ args = 'on' })")
    check(":Halloween on включает оверлей", rt.eval("hw.is_on()"))
    check("оверлей: vim.g.halloween_on = 1 (для lualine)", int(rt.eval("vim.g.halloween_on")) == 1)
    check("оверлей: тема halloween применена", rt.eval("T.current") == "halloween")
    check("оверлей: окно мышей открыто с zindex = 60 (поверх редактора)",
          rt.eval("(function() for _, w in ipairs(WINS) do if w.cfg and w.cfg.zindex == 60 then return true end end return false end)()"))
    check("оверлей: палитра терминала = ghostty (terminal_color_1 = #ff0000)",
          rt.eval("vim.g.terminal_color_1") == "#ff0000")
    check("оверлей: файл состояния = on", open(state_file, encoding="utf-8").read().strip() == "on")

    # Тик оверлея: в буфере мышей ровно одна строка (глифы — из заглушки nr2char)
    rt.execute("OVL_WIN = (function() for _, w in ipairs(WINS) do if w.cfg and w.cfg.zindex == 60 then return w end end end)()")
    rt.execute("OVL_BUF = OVL_WIN.buf")
    rt.execute("OVL_TIMER = TIMERS[#TIMERS]; OVL_TIMER.cb()")
    check("тик оверлея пишет одну строку мышей в буфер",
          int(rt.eval("#BUF_LINES[OVL_BUF] or 0")) == 1)

    rt.execute("CMDS.Halloween({ args = 'off' })")
    check(":Halloween off выключает оверлей", not rt.eval("hw.is_on()"))
    check("выкл: vim.g.halloween_on = 0", int(rt.eval("vim.g.halloween_on")) == 0)
    check("выкл: палитра терминала возвращена", rt.eval("vim.g.terminal_color_1") is None)
    check("выкл: файл состояния = off", open(state_file, encoding="utf-8").read().strip() == "off")

    rt.execute("hw.toggle()")
    check("<leader>uH (toggle) включает", rt.eval("hw.is_on()"))
    rt.execute("hw.toggle()")
    check("<leader>uH (toggle) выключает", not rt.eval("hw.is_on()"))

    # ------------------------------------------- сохранение через перезапуск ---
    with open(state_file, "w", encoding="utf-8") as fh:
        fh.write("on\n")
    rt.execute("hw.setup()")
    check("после перезапуска оверлей поднимается по файлу состояния", rt.eval("hw.is_on()"))
    check("после перезапуска halloween_on = 1", int(rt.eval("vim.g.halloween_on")) == 1)
    rt.execute("hw.off()")

    # ----------------------------------------------------------- :Boo ---
    rt.execute("CMDS.Boo()")
    rt.execute("for i = 1, 400 do local t = TIMERS[#TIMERS]; if t and t.cb then t.cb() end end")
    check(":Boo отработал без зависания", True)

    # ------------------------------------------------------ тыква-уведомление ---
    rt.execute("hw.pumpkin_notify('тест')")
    msg = rt.eval("NOTES[#NOTES].msg")
    check("уведомление содержит тыкву (ASCII-рисунок)", "(" in msg and "`--'" in msg)

    failed = sum(1 for _, ok in checks if not ok)
    print(f"\nпроверок: {len(checks)}, провалов: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
