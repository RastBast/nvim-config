#!/usr/bin/env python3
"""Проверка генератора ходов шахмат (lua/games/chess/board.lua) по эталонным perft.

Запуск:  PYTHONPATH=/path/with/lupa python3 tests/chess_perft.py [--deep]
Нужен пакет lupa (pip install lupa). Без --deep быстрый набор (до глубины 3),
--deep добавляет глубину 4 для стартовой позиции и Kiwipete.

Эталонные значения — из Chess Programming Wiki (Perft Results).
"""
import os
import sys
import time

import lupa

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# (название, FEN, [(глубина, ожидаемо), ...], тяжёлый?)
CASES = [
    ("start", "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
     [(1, 20), (2, 400), (3, 8902), (4, 197281)], False),
    ("kiwipete", "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
     [(1, 48), (2, 2039), (3, 97862)], False),
    ("pos3 (ep, pins)", "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
     [(1, 14), (2, 191), (3, 2812), (4, 43238)], False),
    ("pos4 (promo, castle)", "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
     [(1, 6), (2, 264), (3, 9467)], False),
    ("pos5", "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
     [(1, 44), (2, 1486), (3, 62379)], False),
]


def make_lua():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        'package.path = "%s/lua/?.lua;%s/lua/?/init.lua;" .. package.path'
        % (ROOT, ROOT)
    )
    return lua


def main():
    deep = "--deep" in sys.argv
    lua = make_lua()
    board = lua.eval("(require('games.chess.board'))")
    failures = 0
    checks = 0
    for name, fen, expects, heavy in CASES:
        for depth, want in expects:
            if depth >= 4 and not deep and name != "start":
                continue
            if heavy and not deep:
                continue
            st = board.from_fen(fen)
            t0 = time.time()
            got = board.perft(st, depth)
            dt = time.time() - t0
            checks += 1
            ok = got == want
            failures += 0 if ok else 1
            print(f"{'OK  ' if ok else 'FAIL'} {name:22s} depth {depth}: {got} (ожидалось {want})  {dt:.2f}s")

    # Круговой тест make/unmake: FEN не меняется после перебора
    st = board.from_fen(CASES[1][1])
    before = board.to_fen(st)
    board.perft(st, 2)
    after = board.to_fen(st)
    checks += 1
    if before != after:
        failures += 1
        print("FAIL make/unmake: позиция не восстановлена")
    else:
        print("OK   make/unmake восстанавливает позицию")

    # Мат и пат
    mate = board.from_fen("7k/6Q1/6K1/8/8/8/8/8 b - - 0 1")  # мат: Qg7
    stale = board.from_fen("7k/5Q2/5K2/8/8/8/8/8 b - - 0 1")  # пат
    for label, st, want in [("мат", mate, "mate"), ("пат", stale, "stalemate")]:
        checks += 1
        res = board.status(st)
        got = res[0] if isinstance(res, tuple) else res  # (статус, победитель)
        if got == want:
            print(f"OK   статус: {label} → {got}")
        else:
            failures += 1
            print(f"FAIL статус: {label}: {got} (ожидалось {want})")

    print(f"\nпроверок: {checks}, провалов: {failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
