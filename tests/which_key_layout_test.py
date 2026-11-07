#!/usr/bin/env python3
"""Тесты 3-колоночной панели which-key (<leader> и вложенные отделы) и полного переноса из <leader>H.

Проверяем:
  1. Настройки which-key.lua дают ровно 3 столбика (box_count == 3) для любой ширины
     терминала 80..320 колонок и любой длины подписи (8..140 символов) по точной формуле
     folke/which-key.nvim v3.17.0 (view.lua + layout.lua).
  2. Отдел <leader>H («Главное меню») полностью удалён: ни в lua/, ни в keydocs/ нет ни одной
     привязки <leader>H или <leader>H*.
  3. Все разделы и кнопки из бывшего <leader>H перенесены напрямую под <leader> без конфликтов:
     - <leader>V* (Git, Diffview, мерж-конфликты)
     - <leader>i* (Инфра: K8s, Docker, Kafka)
     - <leader>L* (Плагины и LSP: Lazy, Lazy sync, Mason, LspInfo, ConformInfo, checkhealth)
     - <leader>l* (Утилиты, HUD, Огонёк, RU)
     - <leader>f* (fw, fm, fF), <leader>r* (rf), <leader>d* (da, df, dg, ds, do, de),
       <leader>g* (gs, gf, gj, ge, gF, gu, gI), <leader>A* (Ac, AA, Av, AM, AL),
       <leader>o* (os, on), <leader>t* (tn), <leader>u* (um, uM), <leader>x* (xs, xt),
       <leader>n* (nh), <leader>k* (kc, kl), <leader>y* (ym, yk), <leader>U* (UD).
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402

checks = []


def check(cond, msg, extra=""):
    checks.append((msg, bool(cond)))
    print(("OK   " if cond else "FAIL ") + msg + ("" if cond or not extra else f"   [{extra}]"))


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    with open(os.path.join(_lua.ROOT, "tests", "lua_stubs.lua"), encoding="utf-8") as fh:
        rt.execute(fh.read())

    # 1. Загружаем реальный lua/plugins/which-key.lua в LuaJIT
    rt.execute("WK_SPEC = dofile(ROOT_PATH .. '/lua/plugins/which-key.lua')[1]")
    rt.execute("WK_OPTS = WK_SPEC.opts")

    win_w = float(rt.eval("WK_OPTS.win.width"))
    min_w = float(rt.eval("WK_OPTS.layout.width.min"))
    max_w = float(rt.eval("WK_OPTS.layout.width.max"))
    spacing = int(rt.eval("WK_OPTS.layout.spacing"))

    check(
        0.90 <= win_w <= 1.0 and 0 < min_w < max_w < 0.34,
        "which-key.lua задаёт относительные границы ширины колонки для 3 столбиков",
        f"win.width={win_w}, min={min_w}, max={max_w}, spacing={spacing}",
    )

    # Точная формула Layout.dim + view.lua из folke/which-key.nvim v3.17.0
    rt.execute(
        """
        local function dim(size, parent, rule)
          size = math.abs(size) < 1 and parent * size or size
          size = size < 0 and parent + size or size
          if rule ~= nil then
            if type(rule) == "number" then
              size = dim(rule, parent)
            else
              local mn = rule.min and dim(rule.min, parent) or 0
              local mx = rule.max and dim(rule.max, parent) or parent
              size = math.max(mn, math.min(mx, size))
            end
          end
          return math.floor(math.max(0, math.min(parent, size)) + 0.5)
        end

        BAD_COLS = {}
        for cols = 80, 320 do
          local cw = dim(cols, cols, WK_OPTS.win.width)
          for _, max_row in ipairs({ 8, 16, 28, 44, 64, 92, 140 }) do
            local bw = dim(max_row, cw, WK_OPTS.layout.width)
            local box_count = math.max(math.floor(cw / (bw + WK_OPTS.layout.spacing)), 1)
            if box_count ~= 3 then
              BAD_COLS[#BAD_COLS + 1] = string.format("cols=%d mr=%d -> bc=%d", cols, max_row, box_count)
            end
          end
        end
        """
    )
    bad_cols = int(rt.eval("#BAD_COLS"))
    check(
        bad_cols == 0,
        "формула which-key даёт строго 3 столбика на любых экранах 80..320 и для любых подменю",
        str(rt.eval("BAD_COLS[1] or ''")),
    )

    # 2. Собираем все элементы spec из which-key.lua
    rt.execute(
        """
        SPEC_MAP = {}
        SPEC_GROUPS = {}
        for _, item in ipairs(WK_OPTS.spec) do
          local lhs = item[1]
          SPEC_MAP[lhs] = item
          if item.group then
            SPEC_GROUPS[lhs] = item.group
          end
        end
        """
    )
    check(
        rt.eval("SPEC_MAP['<leader>H']") is None and rt.eval("SPEC_GROUPS['<leader>H']") is None,
        "отдел <leader>H («Главное меню») полностью удалён из which-key.lua",
    )

    # 3. Проверяем отсутствие любых <leader>H или <leader>H* во всём дереве lua/ (включая keydocs/)
    leaked_h = []
    for dirpath, _, filenames in os.walk(os.path.join(_lua.ROOT, "lua")):
        for fn in sorted(filenames):
            if not fn.endswith(".lua"):
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, _lua.ROOT)
            with open(path, encoding="utf-8") as fh:
                for lineno, line in enumerate(fh, 1):
                    s = line.strip()
                    if s.startswith("--"):
                        continue
                    for m in re.finditer(r'["\'](<[lL]eader>H[^"\']*)["\']', line):
                        leaked_h.append(f"{rel}:{lineno}:{m.group(1)}")
    check(not leaked_h, "во всём каталоге lua/ (и справке keydocs/) не осталось ни одной клавиши <leader>H*", ", ".join(leaked_h[:5]))

    # 4. Проверяем наличие всех перенесённых разделов и кнопок напрямую под <leader>
    expected_groups = ["<leader>V", "<leader>Vm", "<leader>i", "<leader>ik", "<leader>id", "<leader>ia",
                       "<leader>L", "<leader>l", "<leader>f", "<leader>d", "<leader>g", "<leader>A", "<leader>C"]
    missing_groups = [g for g in expected_groups if rt.eval(f"SPEC_GROUPS['{g}']") is None]
    check(not missing_groups, "все верхнеуровневые и вложенные разделы зарегистрированы под <leader>", ", ".join(missing_groups))

    expected_wk_keys = [
        # Поиск и файлы
        "<leader>fw", "<leader>fm", "<leader>fF", "<leader>rf",
        # Git + Diffview + мерж-конфликты
        "<leader>Vs", "<leader>Vu", "<leader>Vb", "<leader>Vh", "<leader>Vd", "<leader>Vl", "<leader>Vg",
        "<leader>Vv", "<leader>Vf", "<leader>Vq",
        "<leader>Vmo", "<leader>Vmt", "<leader>Vmb", "<leader>Vm0", "<leader>Vmn", "<leader>Vmp", "<leader>Vml",
        # Go
        "<leader>gs", "<leader>gf", "<leader>gj", "<leader>ge", "<leader>gF", "<leader>gu", "<leader>gI",
        # Инфра K8s / Docker / Kafka
        "<leader>ikk", "<leader>ikp", "<leader>ikc",
        "<leader>idd", "<leader>idp", "<leader>idi",
        "<leader>iak", "<leader>iat", "<leader>iag", "<leader>iab",
        # Отладка и БД
        "<leader>da", "<leader>df", "<leader>dg", "<leader>ds", "<leader>do", "<leader>de",
        # Плагины и LSP
        "<leader>Ll", "<leader>Ls", "<leader>Lu", "<leader>Lm", "<leader>Li", "<leader>Lc", "<leader>Lh",
        # Утилиты / HUD / Огонёк / RU
        "<leader>lh", "<leader>ld", "<leader>li", "<leader>lo", "<leader>lc", "<leader>lk",
        "<leader>lt", "<leader>l2", "<leader>l1", "<leader>lz",
        "<leader>la", "<leader>lA", "<leader>lg", "<leader>lb",
        "<leader>lr", "<leader>lK", "<leader>lD", "<leader>ln", "<leader>le", "<leader>lm",
        # AI / Obsidian / Тесты / Визуал / Trouble / Прочее / Шпаргалки / macOS / TUI
        "<leader>Ac", "<leader>AA", "<leader>Av", "<leader>AM", "<leader>AL",
        "<leader>os", "<leader>on", "<leader>tn", "<leader>um", "<leader>uM",
        "<leader>xs", "<leader>xt", "<leader>nh", "<leader>kc", "<leader>kl",
        "<leader>ym", "<leader>yk", "<leader>UD",
    ]
    missing_keys = [k for k in expected_wk_keys if rt.eval(f"SPEC_MAP['{k}']") is None]
    check(not missing_keys, "все перенесённые из <leader>H кнопки присутствуют напрямую в which-key под <leader>", ", ".join(missing_keys))

    # 5. Проверяем реальную регистрацию в модулях hud.lua, ai.lua и maximizer.lua
    rt.execute("HUD = require('config.hud'); HUD.keymaps()")
    bound_lhs = set(rt.eval("(function() local r = {} for _, k in ipairs(KEYS) do r[#r+1] = k.lhs end return table.concat(r, ',') end)()").split(","))
    check(
        all(k in bound_lhs for k in ("<leader>lh", "<leader>ld", "<leader>li", "<leader>lo", "<leader>lc", "<leader>lk")),
        "hud.lua регистрирует клавиши HUD и огонька напрямую под <leader>l*",
    )

    ai_src = open(os.path.join(_lua.ROOT, "lua", "plugins", "ai.lua"), encoding="utf-8").read()
    check(
        all(k in ai_src for k in ('"<leader>Ac"', '"<leader>AA"', '"<leader>Av"', '"<leader>AM"')),
        "ai.lua привязывает CodeCompanion напрямую к <leader>Ac / AA / Av / AM",
    )

    max_src = open(os.path.join(_lua.ROOT, "lua", "plugins", "maximizer.lua"), encoding="utf-8").read()
    check(
        "'<leader>um'" in max_src and "'<leader>uM'" in max_src,
        "maximizer.lua привязывает разворот окна к <leader>um / <leader>uM",
    )

    # 6. Проверяем справку keydoc.lua: загружается без ошибок и не содержит <leader>H*
    rt.execute(
        """
        KD = require("config.keydoc")
        ENTRIES = KD.entries()
        KD_MAP = {}
        for _, e in ipairs(ENTRIES) do
          KD_MAP[e.lhs] = true
        end
        """
    )
    check(int(rt.eval("#ENTRIES")) >= 380, "справка <leader>? успешно загружает все записи")
    kd_missing = [k for k in ("<leader>Vs", "<leader>Vv", "<leader>Vmo", "<leader>ikk", "<leader>Ll", "<leader>lh", "<leader>Ac", "<leader>gs", "<leader>um") if not rt.eval(f"KD_MAP['{k}'] == true")]
    check(not kd_missing, "справка <leader>? содержит перенесённые прямые клавиши <leader>", ", ".join(kd_missing))

    failed = sum(1 for _, ok in checks if not ok)
    print(f"\nпроверок: {len(checks)}, провалов: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
