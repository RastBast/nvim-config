#!/usr/bin/env python3
"""Smoke-тест интерфейса шахмат без nvim: заглушка vim.* записывает вызовы,
клавиши нажимаются через сохранённые vim.keymap.set-функции.

Проверяет: выбор режима через vim.ui.select, ход человека (Enter-Enter),
отложенный ход ПК (vim.defer_fn), отмену (u) и превращение пешки.

Запуск:  PYTHONPATH=/path/with/lupa python3 tests/chess_ui_smoke.py
"""
import os
import sys

import lupa

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

PRELUDE = r"""
SEL_Q, DEFER, KEYMAPS, NOTES = {}, {}, {}, {}
local function noop() end
local function store(t) return setmetatable(t, { __index = function(tt, k) local v = {} rawset(tt, k, v) return v end }) end
vim = {
  o = { columns = 120, lines = 40 },
  bo = store({}), wo = store({}),
  log = { levels = { INFO = 2, WARN = 3, ERROR = 4 } },
  fn = setmetatable({}, { __index = function() return function() return "" end end }),
  notify = noop, cmd = noop,
  api = {
    nvim_create_namespace = function() return 1 end,
    nvim_create_buf = function() return 1 end,
    nvim_open_win = function() return 1001 end,
    nvim_win_is_valid = function() return true end,
    nvim_buf_is_valid = function() return true end,
    nvim_buf_set_lines = function(_, _, _, _, lines) NOTES.lines = lines end,
    nvim_buf_clear_namespace = noop,
    nvim_buf_set_extmark = noop,
    nvim_win_close = noop,
    nvim_set_current_win = noop,
    nvim_create_autocmd = noop,
    nvim_set_hl = noop,
    nvim_list_uis = function() return { { width = 120, height = 40 } } end,
  },
  keymap = { set = function(mode, lhs, fn) KEYMAPS[lhs] = fn end },
  ui = { select = function(items, opts, cb)
      local idx = table.remove(SEL_Q, 1)
      if idx == nil then error("нет ответа для vim.ui.select: " .. tostring(opts.prompt)) end
      cb(items[idx])
  end },
  defer_fn = function(fn, ms) table.insert(DEFER, fn) end,
  schedule_wrap = function(fn) return fn end,
  uv = { new_timer = function() return { start = noop, stop = noop, close = noop, is_closing = function() return false end } end },
  schedule = function(fn) fn() end,
}
package.path = ROOT_PATH .. "/lua/?.lua;" .. ROOT_PATH .. "/lua/?/init.lua;" .. package.path
function QUEUE(...)
  for _, v in ipairs({ ... }) do table.insert(SEL_Q, v) end
end
function LEN(t) return #t end
function MKG(board, fen)
  return { st = board.from_fen(fen), mode = "pvp", undo = {}, hist = {}, human = "w" }
end
function FLUSH()
  while #DEFER > 0 do
    local f = table.remove(DEFER, 1)
    f()
  end
end
"""


def main():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.globals().ROOT_PATH = os.path.abspath(ROOT)
    lua.execute(PRELUDE)
    g = lua.globals()
    checks = []

    def check(name, cond, extra=""):
        checks.append((name, bool(cond)))
        print(("OK   " if cond else "FAIL ") + name + (("   [" + str(extra) + "]") if extra and not cond else ""))

    def key(k):
        g.KEYMAPS[k]()

    def queue(*idx):
        g.QUEUE(*idx)

    ui = lua.eval("(require('games.chess.ui'))")
    board = lua.eval("(require('games.chess.board'))")
    S = ui._state

    # 1) режим: против ПК (2), уровень 3 (3), за белых (1)
    queue(2, 3, 1)
    ui.open()
    check("ui: открыто окно", S.h is not None)
    check("ui: режим pc, уровень 3, человек — белые", S.g.mode == "pc" and S.g.level == 3 and S.g.human == "w",
          f"mode={S.g.mode} level={S.g.level} human={S.g.human}")

    # 2) ход e2-e4: курсор стоит на e2 → Enter, k k → e4, Enter
    key("<CR>")
    check("ui: выбрана фигура e2", S.sel == board.sq_of(5, 2))
    key("k")
    key("k")
    key("<CR>")
    check("ui: ход человека сделан (undo=1)", g.LEN(S.g.undo) == 1, str(g.LEN(S.g.undo)))
    check("ui: после хода человека — ход чёрных", S.g.st.turn == "b", S.g.st.turn)

    # 3) ПК отвечает через defer_fn
    g.FLUSH()
    check("ui: ПК ответил (undo=2)", g.LEN(S.g.undo) == 2, str(g.LEN(S.g.undo)))
    check("ui: снова ход белых", S.g.st.turn == "w", S.g.st.turn)
    check("ui: история ходов заполнена", g.LEN(S.g.hist) == 1 and S.g.hist[1].startswith("1. e2-e4"),
          str(S.g.hist[1]))

    # 4) отмена u: против ПК откатываем два полухода
    key("u")
    fen_now = board.to_fen(S.g.st)
    check("ui: u откатывает оба полухода", fen_now == board.START_FEN, fen_now)
    check("ui: после u нет истории", g.LEN(S.g.undo) == 0 and g.LEN(S.g.hist) == 0)

    # 5) превращение пешки: отдельная партия, человек — белые, pvp
    queue(1)  # режим: два игрока
    S.g = None
    key("n")  # новая партия через меню
    S.g = g.MKG(board, "8/P6k/8/8/8/8/8/K7 w - - 0 1")  # пешка a7, белый король a1, чёрный h7
    S.cursor = board.sq_of(1, 7)  # a7
    queue(1)  # в выборе превращения — первый вариант (ферзь)
    key("<CR>")  # выбрать пешку
    key("k")  # курсор на a8
    key("<CR>")  # ход a7-a8 с превращением
    promo_sq = S.g.st.b[board.sq_of(1, 8)]
    check("ui: превращение пешки в ферзя", promo_sq == "Q", promo_sq)

    failures = sum(1 for _, ok in checks if not ok)
    print(f"\nпроверок: {len(checks)}, провалов: {failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
