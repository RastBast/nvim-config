#!/usr/bin/env python3
"""Тесты логики игр: змейка, тетрис, 2048 (lua/games/*.lua). Без окна nvim.

Запуск:  PYTHONPATH=/path/with/lupa python3 tests/games_logic.py
Окно (games.float) не нужно: модули логики его не вызывают, а stub vim.* достаточен.
"""
import os
import sys

import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lupa  # noqa: F401 (проверка наличия; рантайм — в _lua)

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

STUB = r"""
vim = vim or {}
vim.api = setmetatable({ nvim_create_namespace = function() return 1 end },
  { __index = function() return function() end end })
vim.uv = vim.uv or {}
vim.keymap = vim.keymap or { set = function() end }
"""


def lua_runtime():
    import _lua
    lua, _kind = _lua.runtime()
    print('Lua runtime:', _kind)
    lua.execute('package.path = "%s/lua/?.lua;%s/lua/?/init.lua;" .. package.path' % (ROOT, ROOT))
    lua.execute(STUB)
    return lua


def main():
    lua = lua_runtime()
    lua.execute("function LEN(t) return #t end")
    lua.execute("function ROW(t, r) local o = {} for i = 1, #t[r] do o[i] = t[r][i] end return o end")
    LEN = lua.globals().LEN
    ROW = lua.globals().ROW

    checks = []

    def check(name, cond, extra=""):
        checks.append((name, bool(cond)))
        mark = "OK  " if cond else "FAIL"
        print(f"{mark} {name}" + (f"   [{extra}]" if extra and not cond else ""))

    def row_list(t, r):
        return [t[r][i] for i in range(1, len(t[r]) + 1)]

    # ------------------------------------------------------------ змейка --
    snake = lua.eval("(require('games.snake'))")
    s = snake.new(lambda n: 1, 10, 10)
    check("snake: стартовая длина 3", LEN(s.body) == 3, str(LEN(s.body)))
    s.food = lua.eval("{x = 6, y = 6}")  # еда прямо впереди головы (5,6)
    alive = snake.step(s)
    check("snake: шаг на еду — жива, счёт 1", alive is True and s.score == 1, f"alive={alive} score={s.score}")
    check("snake: после еды длина 4", LEN(s.body) == 4, str(LEN(s.body)))

    s.nd = lua.eval("{x = 1, y = 0}")
    snake.turn(s, -1, 0)  # разворот на 180°
    check("snake: разворот 180° запрещён", s.nd.x == 1 and s.nd.y == 0)

    wall = snake.new(lambda n: 1, 4, 4)
    wall.body = lua.eval("{{x = 4, y = 2}, {x = 3, y = 2}, {x = 2, y = 2}}")
    wall.dir = lua.eval("{x = 1, y = 0}")
    wall.nd = lua.eval("{x = 1, y = 0}")
    wall.food = lua.eval("{x = 1, y = 1}")
    check("snake: стена убивает", snake.step(wall) is False and wall.alive is False)

    self_hit = snake.new(lambda n: 1, 10, 10)
    self_hit.body = lua.eval("{{x = 3, y = 3}, {x = 3, y = 4}, {x = 2, y = 4}, {x = 2, y = 3}, {x = 2, y = 2}}")
    self_hit.dir = lua.eval("{x = -1, y = 0}")
    self_hit.nd = lua.eval("{x = -1, y = 0}")
    self_hit.food = lua.eval("{x = 9, y = 9}")
    check("snake: столкновение с телом убивает", snake.step(self_hit) is False)

    # голова (1,2) → (1,3): клетка (1,3) — хвост, он уйдёт, ход разрешён
    tail = snake.new(lambda n: 1, 10, 10)
    tail.body = lua.eval("{{x = 1, y = 2}, {x = 2, y = 2}, {x = 2, y = 3}, {x = 1, y = 3}}")
    tail.dir = lua.eval("{x = 0, y = 1}")
    tail.nd = lua.eval("{x = 0, y = 1}")
    tail.food = lua.eval("{x = 9, y = 9}")
    check("snake: в клетку хвоста можно (хвост уходит)", snake.step(tail) is True)

    # ----------------------------------------------------------- тетрис --
    tet = lua.eval("(require('games.tetris'))")
    I = lua.eval("{{0,0,0,0},{1,1,1,1},{0,0,0,0},{0,0,0,0}}")
    m = I
    for _ in range(4):
        m = tet.rotate(m)
    same = all(m[i][j] == I[i][j] for i in range(1, 5) for j in range(1, 5))
    check("tetris: 4 поворота возвращают фигуру", same)
    rI = tet.rotate(I)
    vertical = sum(rI[i][3] for i in range(1, 5)) == 4  # I становится вертикальной
    check("tetris: I после поворота вертикальна", vertical)

    g = tet.new(lambda n: 1)
    H, W = tet.H, tet.W
    for x in range(1, W + 1):
        g.board[H][x] = 1 if x != 10 else 0  # нижний ряд: дыра в столбце 10
    g.cur = {"kind": 1, "m": lua.eval("{{0,1,0,0},{0,1,0,0},{0,1,0,0},{0,1,0,0}}"), "x": 9, "y": 0}
    for _ in range(H + 4):
        tet.tick(g)
        if g.lines > 0:
            break
    check("tetris: заполненная линия очищается", g.lines == 1, f"lines={g.lines}")
    check("tetris: за одну линию 100 очков на уровне 1", g.score == 100, f"score={g.score}")

    # зона появления заблокирована: новая фигура не помещается → конец игры
    g_over = tet.new(lambda n: 1)
    g_over.board[1][5] = 1
    g_over.next = 2
    tet.spawn(g_over)
    check("tetris: занятая зона появления — конец игры", g_over.over is True)

    # ------------------------------------------------------------- 2048 --
    g2 = lua.eval("(require('games.game2048'))")
    line, gained, _ = g2.slide_line(lua.eval("{2, 2, 2, 2}"))
    check("2048: {2,2,2,2} → {4,4,0,0}", [line[i] for i in range(1, 5)] == [4, 4, 0, 0])
    check("2048: слияние даёт 8 очков", gained == 8, str(gained))
    line2, _, _ = g2.slide_line(lua.eval("{4, 4, 8, 0}"))
    check("2048: {4,4,8,0} → {8,8,0,0} (одно слияние за ход)", [line2[i] for i in range(1, 5)] == [8, 8, 0, 0])
    line3, _, _ = g2.slide_line(lua.eval("{2, 0, 2, 4}"))
    check("2048: {2,0,2,4} → {4,4,0,0}", [line3[i] for i in range(1, 5)] == [4, 4, 0, 0])
    _, _, changed = g2.slide_line(lua.eval("{2, 4, 8, 16}"))
    check("2048: линия без слияний и сдвигов не меняется", changed is False)

    b = lua.eval("{{2,0,0,0},{0,0,0,0},{0,0,0,0},{0,0,0,0}}")
    nb, _, moved = g2.move(b, "right")
    check("2048: сдвиг вправо переносит плитку в правый край", nb[1][4] == 2 and nb[1][1] == 0 and moved is True)
    _, _, moved2 = g2.move(nb, "right")
    check("2048: повторный сдвиг без эффекта", moved2 is False)
    nb_up, _, moved_up = g2.move(nb, "up")
    check("2048: сдвиг вверх у верхнего края без эффекта", moved_up is False and nb_up[1][4] == 2)

    fresh = g2.new(lambda n: 1)
    tiles = sum(1 for r in range(1, 5) for x in range(1, 5) if fresh.board[r][x] != 0)
    check("2048: старт — две плитки", tiles == 2, str(tiles))

    deadlock = lua.eval("{{2,4,2,4},{4,2,4,2},{2,4,2,4},{4,2,4,2}}")
    check("2048: тупик определяется", g2.can_move(deadlock) is False)
    free = lua.eval("{{2,4,2,4},{4,2,4,2},{2,4,2,4},{4,2,4,4}}")
    check("2048: есть слияние — ход возможен", g2.can_move(free) is True)

    failures = sum(1 for _, ok in checks if not ok)
    print(f"\nпроверок: {len(checks)}, провалов: {failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
