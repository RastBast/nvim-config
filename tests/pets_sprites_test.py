#!/usr/bin/env python3
"""Тесты спрайтов питомцев (assets/pets).

Структура: assets/pets/<вид>/<окрас>/<действие>/<кадр>.png

Проверяем:
  * все PNG — настоящие PNG (сигнатура) и одного размера;
  * у каждого вида/окраса есть idle, walk, walk_left, run, run_left с кадрами;
  * синий гофер «Харек» (gopher/blue) на месте;
  * лицевая и левая анимации парные: у каждого walk есть walk_left и т.д.;
  * в ассетах нет пустых кадров (файл > 100 байт).

Запуск:  python3 tests/pets_sprites_test.py
"""
import os
import struct
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "pets")
ACTIONS = ["idle", "walk", "walk_left", "run", "run_left"]
PNG_SIG = b"\x89PNG\r\n\x1a\n"

checks = []


def check(name, cond, extra=""):
    checks.append((name, bool(cond)))
    print(("OK   " if cond else "FAIL ") + name + ("" if cond or not extra else f"   [{extra}]"))


def png_size(path):
    with open(path, "rb") as fh:
        head = fh.read(24)
    if head[:8] != PNG_SIG:
        return None
    return struct.unpack(">II", head[16:24])


def main():
    species = sorted(d for d in os.listdir(ROOT) if os.path.isdir(os.path.join(ROOT, d)))
    check("есть виды питомцев", len(species) >= 4, ", ".join(species))
    check("гофер есть", "gopher" in species)

    sizes = set()
    total = 0
    bad_files = []
    missing = []
    for sp in species:
        for color in sorted(os.listdir(os.path.join(ROOT, sp))):
            base = os.path.join(ROOT, sp, color)
            if not os.path.isdir(base):
                continue
            for act in ACTIONS:
                d = os.path.join(base, act)
                if not os.path.isdir(d):
                    missing.append(f"{sp}/{color}/{act}")
                    continue
                pngs = sorted(f for f in os.listdir(d) if f.endswith(".png"))
                if not pngs:
                    missing.append(f"{sp}/{color}/{act} (нет кадров)")
                for f in pngs:
                    p = os.path.join(d, f)
                    total += 1
                    sz = png_size(p)
                    if sz is None or os.path.getsize(p) < 100:
                        bad_files.append(os.path.relpath(p, ROOT))
                    else:
                        sizes.add(sz)

    check("у каждого вида/окраса есть все 5 действий с кадрами", not missing, "; ".join(missing[:5]))
    check("все файлы — настоящие PNG и не пустые", not bad_files, "; ".join(bad_files[:5]))
    check("все кадры одного размера", len(sizes) == 1, str(sizes))
    check("кадров всего > 0", total > 0, str(total))
    check("гофер: синий окрас «Харек» есть", os.path.isdir(os.path.join(ROOT, "gopher", "blue")))

    # Парность: у каждой анимации walk/run есть зеркальная *_left
    unpaired = []
    for sp in species:
        for color in os.listdir(os.path.join(ROOT, sp)):
            base = os.path.join(ROOT, sp, color)
            for a, b in (("walk", "walk_left"), ("run", "run_left")):
                na = len(os.listdir(os.path.join(base, a))) if os.path.isdir(os.path.join(base, a)) else 0
                nb = len(os.listdir(os.path.join(base, b))) if os.path.isdir(os.path.join(base, b)) else 0
                if na != nb:
                    unpaired.append(f"{sp}/{color}: {a}={na} {b}={nb}")
    check("влево/вправо: одинаковое число кадров", not unpaired, "; ".join(unpaired))

    failed = sum(1 for _, ok in checks if not ok)
    print(f"\nкадров: {total}, проверок: {len(checks)}, провалов: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
