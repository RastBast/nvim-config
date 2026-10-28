#!/usr/bin/env python3
"""Запуск всех тестов конфига одной командой и сводка в конце.

Запуск:
    PYTHONPATH=/путь/к/venv/lib/python3.X/site-packages python3 tests/run_all.py

Нужен пакет lupa (для LuaJIT 2.1): pip install lupa.
Тесты без lupa (pets_sprites_test) запустятся всё равно.
"""
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))

SUITES = [
    ("синтаксис всех .lua (LuaJIT 2.1)", "lua_syntax_test.py"),
    ("логика игр (LuaJIT)", "games_logic.py"),
    ("шахматы: ходы и perft (LuaJIT)", "chess_perft.py"),
    ("шахматы: интерфейс (LuaJIT)", "chess_ui_smoke.py"),
    ("Хэллоуин: кадры, анимация, :Boo", "halloween_test.py"),
    ("markdown live-превью: команды, буфер, python3-сервер", "md_preview_test.py"),
    ("Go PRO: функции, клавиши, сниппеты, ленивые команды", "go_pro_test.py"),
    ("PATH для git и автопроверка lazy", "env_path_test.py"),
    ("avante: сборка библиотек по тегу, откат на make", "avante_build_test.py"),
    ("темы и порядок запуска", "themes_test.py"),
    ("спецификации плагинов, b/q, Ghostty, доки", "config_specs_test.py"),
    ("спрайты питомцев", "pets_sprites_test.py"),
]


def main():
    results = []
    t_all = time.time()
    for title, script in SUITES:
        path = os.path.join(HERE, script)
        t0 = time.time()
        print("=" * 72)
        print(f"▶ {title}  ({script})")
        print("=" * 72)
        proc = subprocess.run([sys.executable, path], capture_output=True, text=True)
        out = proc.stdout + (("\n[stderr]\n" + proc.stderr) if proc.stderr.strip() else "")
        print(out.rstrip())
        dt = time.time() - t0
        results.append((title, script, proc.returncode, dt))
        print(f"→ код выхода {proc.returncode}, {dt:.1f} с\n")

    print("=" * 72)
    print("СВОДКА")
    print("=" * 72)
    failed = 0
    for title, script, code, dt in results:
        status = "PASS" if code == 0 else "FAIL"
        if code != 0:
            failed += 1
        print(f"{status}  {title:<46} {dt:6.1f} с")
    print("-" * 72)
    print(f"наборов: {len(results)}, провалов: {failed}, время: {time.time() - t_all:.1f} с")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
