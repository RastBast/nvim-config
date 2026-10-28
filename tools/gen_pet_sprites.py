#!/usr/bin/env python3
"""Генератор пиксельных спрайтов для кастомных питомцев (pets.nvim).

Запуск из корня репозитория:   python3 tools/gen_pet_sprites.py
Результат: assets/pets/<вид>/<окрас>/<действие>/<кадр>.png

Формат совпадает с media/ из giusgad/pets.nvim: кадры 128x88 px
(сетка 32x22 пикселя, увеличенная в 4 раза), имена кадров 0.png, 1.png …
Без внешних зависимостей: PNG пишется через zlib.

Питомцы:
  gopher  — синий гофер АНФАС (талисман Go: два глаза, уши, зубы), окрас blue
  nyan    — кот-печенье с радужным хвостом (мем), окрас classic
  toaster — тостер с выскакивающим хлебом (мем), окрас silver
  ghost   — призрак «бу» (мем), окрас white
  pumpkin — фонарь-тыква с вырезанной рожей (хэллоуин), окрас orange
Каждый питомец: idle (2 кадра), walk (4), run (4), walk_left (4), run_left (4).
Левые версии — зеркало правых кадров.
"""
import os
import struct
import zlib

W, H, SCALE = 32, 22, 4
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "pets")

PAL = {
    "B": (0x00, 0xAD, 0xD8, 255),  # Go-синий (тело гофера)
    "D": (0x00, 0x5F, 0x7A, 255),  # тёмно-синий контур
    "L": (0xE6, 0xF9, 0xFF, 255),  # светлое брюшко
    "W": (0xFF, 0xFF, 0xFF, 255),
    "K": (0x10, 0x10, 0x10, 255),
    "P": (0xFF, 0x8F, 0xB8, 255),  # щёки / язык
    "Y": (0xFF, 0xC8, 0x00, 255),  # лапки
    "G": (0xB8, 0xBE, 0xC8, 255),  # серый (кот, тостер)
    "g": (0x6B, 0x72, 0x80, 255),  # тёмно-серый контур
    "T": (0xF2, 0xC4, 0x8D, 255),  # корочка печенья
    "t": (0xB0, 0x7A, 0x3F, 255),  # контур корочки
    "F": (0xFF, 0x7E, 0xB6, 255),  # розовая глазурь
    "S": (0xFF, 0xFF, 0xFF, 255),  # посыпка
    "1": (0xFF, 0x00, 0x00, 255),  # радуга
    "2": (0xFF, 0x99, 0x00, 255),
    "3": (0xFF, 0xFF, 0x00, 255),
    "4": (0x00, 0xE6, 0x00, 255),
    "5": (0x00, 0x99, 0xFF, 255),
    "6": (0x99, 0x00, 0xFF, 255),
    "R": (0xE5, 0x39, 0x35, 255),  # рычаг
    "s": (0xE9, 0xB8, 0x72, 255),  # хлеб
    "h": (0x9C, 0x5B, 0x2B, 255),  # корочка хлеба
    "V": (0xF4, 0xF6, 0xF8, 255),  # призрак
    "v": (0x9A, 0xA0, 0xA6, 255),  # контур призрака
    "O": (0xFF, 0x7A, 0x00, 255),  # тыква (хэллоуин)
    "o": (0xA8, 0x43, 0x00, 255),  # контур и дольки тыквы
    "N": (0x2E, 0x7D, 0x32, 255),  # плодоножка
    "E": (0xFF, 0xE0, 0x66, 255),  # свечение вырезанной рожи (яркое)
}


def canvas():
    return [[None] * W for _ in range(H)]


def put(c, x, y, col):
    if 0 <= x < W and 0 <= y < H:
        c[y][x] = col


def ellipse(c, cx, cy, rx, ry, col):
    for y in range(H):
        for x in range(W):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                put(c, x, y, col)


def rect(c, x0, y0, x1, y1, col):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(c, x, y, col)


def shifted(c, dy):
    if dy == 0:
        return c
    out = canvas()
    for y in range(H):
        for x in range(W):
            if c[y][x] is not None and 0 <= y + dy < H:
                out[y + dy][x] = c[y][x]
    return out


def mirror(c):
    return [list(reversed(row)) for row in c]


# ---------------------------------------------------------------- гофер ----
# ПЕРЕРИСОВАН 2026-10-28: раньше гофер был «в профиль» с одним глазом и
# смахивал на пятно. Теперь — АНСФАС, как официальный талисман Go: круглое
# тело-голова, два больших белых глаза с зрачками, два уха, светлая морда
# с носом и ДВУМЯ передними зубами, руки-обрубки по бокам, ноги снизу.
def gopher(action, i):
    c = canvas()
    bob = 1 if (action in ("walk", "run") and i % 2 == 1) else 0
    # уши: два бугорка на макушке
    ellipse(c, 10, 4, 2.2, 2.0, "D")
    ellipse(c, 10, 4, 1.3, 1.1, "B")
    ellipse(c, 22, 4, 2.2, 2.0, "D")
    ellipse(c, 22, 4, 1.3, 1.1, "B")
    # тело-голова: капсула анфас
    ellipse(c, 16, 12, 9.5, 8.5, "D")
    ellipse(c, 16, 12, 8.5, 7.5, "B")
    # глаза: два больших белка; моргание (idle, кадр 1) — линии
    if action == "idle" and i == 1:
        rect(c, 10, 8, 14, 8, "K")
        rect(c, 18, 8, 22, 8, "K")
    else:
        ellipse(c, 12, 8, 2.6, 2.9, "W")
        ellipse(c, 20, 8, 2.6, 2.9, "W")
        rect(c, 12, 8, 13, 9, "K")  # зрачки смотрят чуть внутрь
        rect(c, 19, 8, 20, 9, "K")
    # щёки
    put(c, 9, 11, "P")
    put(c, 23, 11, "P")
    # морда: светлое пятно, нос и два передних зуба
    ellipse(c, 16, 13, 4.6, 3.2, "L")
    rect(c, 15, 11, 17, 11, "K")  # нос
    rect(c, 14, 13, 15, 15, "W")  # зубы
    rect(c, 17, 13, 18, 15, "W")
    for y in (13, 14, 15):
        put(c, 16, y, "K")        # щель между зубами
    rect(c, 14, 16, 18, 16, "K")  # линия рта под зубами
    # руки-обрубки по бокам
    ellipse(c, 6, 13, 1.9, 2.6, "D")
    ellipse(c, 6, 13, 1.0, 1.7, "B")
    ellipse(c, 26, 13, 1.9, 2.6, "D")
    ellipse(c, 26, 13, 1.0, 1.7, "B")
    # ноги: шаг зависит от кадра
    if action == "idle":
        lx, rx_ = 10, 18
    elif action in ("walk", "walk_left"):
        lx, rx_ = [(9, 18), (11, 16), (12, 15), (11, 16)][i % 4]
    else:  # run
        lx, rx_ = [(6, 21), (11, 16), (15, 10), (11, 16)][i % 4]
    rect(c, lx, 19, lx + 3, 20, "Y")
    rect(c, rx_, 19, rx_ + 3, 20, "Y")
    return shifted(c, -bob)


# ---------------------------------------------------------------- тыква ----
# Хэллоуин-питомец: фонарь-тыква с вырезанной рожей. «Ходьба» — вперевалку
# (подпрыгивает), «бег» — быстрее и с пульсом свечения; свечение моргает
# между кадрами (E яркое / Y приглушённое), от тыква «живая».
def pumpkin(action, i):
    c = canvas()
    lit = "E" if i % 2 == 0 else "Y"
    hop = 0
    if action in ("walk", "walk_left"):
        hop = [0, 1, 0, 1][i % 4]
    elif action in ("run", "run_left"):
        hop = [1, 0, 1, 0][i % 4]
    # плодоножка
    rect(c, 15, 2, 17, 4, "N")
    put(c, 14, 3, "N")
    put(c, 18, 4, "N")
    # тело
    ellipse(c, 16, 13, 10.5, 7.8, "o")
    ellipse(c, 16, 13, 9.5, 6.8, "O")
    # дольки
    for x in (11, 16, 21):
        for y in range(7, 20):
            if c[y][x] == "O":
                put(c, x, y, "o")
    # глаза-треугольники
    for cx in (11, 21):
        put(c, cx, 9, lit)
        rect(c, cx - 1, 10, cx + 1, 10, lit)
        rect(c, cx - 2, 11, cx + 2, 11, lit)
    # нос
    put(c, 16, 11, lit)
    rect(c, 15, 12, 17, 12, lit)
    # зубастая ухмылка
    rect(c, 9, 15, 23, 15, lit)
    for x in (10, 11, 14, 15, 18, 19, 22, 23):
        put(c, x, 16, lit)
    for x in (12, 13, 16, 17, 20, 21):
        put(c, x, 14, lit)
    return shifted(c, -hop)


# ---------------------------------------------------------------- нян ------
def nyan(action, i):
    c = canvas()
    wob = [0, 1, 0, -1][i % 4] if action != "idle" else 0
    # радужный след слева: 6 полос, концы колеблются
    for k, col in enumerate(["1", "2", "3", "4", "5", "6"]):
        y = 7 + k
        x0 = 1 + (wob if k % 2 else -wob)
        rect(c, x0, y, 9, y, col)
    # печенье (тело)
    rect(c, 9, 7, 21, 15, "t")
    rect(c, 10, 8, 20, 14, "T")
    rect(c, 10, 8, 20, 11, "F")  # глазурь
    for sx, sy in [(12, 9), (15, 10), (18, 9), (13, 13), (17, 13)]:
        put(c, sx, sy, "S")
    # голова кота
    ellipse(c, 25, 9, 4.2, 3.8, "g")
    ellipse(c, 25, 9, 3.4, 3.0, "G")
    put(c, 22, 5, "g")  # уши
    put(c, 23, 4, "g")
    put(c, 27, 5, "g")
    put(c, 28, 4, "g")
    put(c, 24, 8, "K")  # глаза
    put(c, 27, 8, "K")
    put(c, 26, 10, "P")  # нос/рот
    # лапки
    legs = [(10, 19), (13, 16), (16, 13), (13, 16)][i % 4] if action != "idle" else (11, 19)
    for x in (legs[0], legs[1]):
        rect(c, x, 16, x + 1, 18, "g")
    if action == "run":
        for x in (legs[0] + 3, legs[1] + 3):
            rect(c, x, 16, x + 1, 18, "g")
    return c


# ---------------------------------------------------------------- тостер ---
def toaster(action, i):
    c = canvas()
    rect(c, 8, 9, 24, 18, "g")
    rect(c, 9, 10, 23, 17, "G")
    rect(c, 10, 9, 22, 9, "K")  # прорези
    # хлеб выскакивает в кадрах pop (idle f1, run/walk чередуем)
    up = (action == "idle" and i == 1) or (action in ("run", "run_left") and i % 2 == 1)
    if up:
        rect(c, 11, 3, 14, 8, "s")
        rect(c, 11, 3, 14, 3, "h")
    rect(c, 13, 12, 13, 13, "K")  # глаза
    rect(c, 19, 12, 19, 13, "K")
    put(c, 14, 15, "K")  # улыбка
    put(c, 15, 16, "K")
    put(c, 16, 16, "K")
    put(c, 17, 16, "K")
    put(c, 18, 15, "K")
    rect(c, 25, 11, 26, 12, "R")  # рычаг
    legs = [(9, 20), (12, 17), (15, 14), (12, 17)][i % 4] if action != "idle" else (10, 20)
    rect(c, legs[0], 19, legs[0] + 2, 20, "g")
    rect(c, legs[1], 19, legs[1] + 2, 20, "g")
    return c


# ---------------------------------------------------------------- призрак --
def ghost(action, i):
    c = canvas()
    dy = [0, -1, 0, 1][i % 4] if action != "idle" else (0 if i == 0 else -1)
    ellipse(c, 16, 9, 8.6, 7.6, "v")
    ellipse(c, 16, 9, 7.6, 6.6, "V")
    rect(c, 8, 9, 24, 15, "v")
    rect(c, 9, 9, 23, 14, "V")
    # волнистый низ: высота зависит от x и кадра
    for x in range(9, 24):
        h = 16 if (x + i) % 4 < 2 else 17
        if action in ("run", "run_left"):
            h = 16 if (x + i * 2) % 4 < 2 else 17
        rect(c, x, 15, x, h, "V")
        put(c, x, h + 1, "v") if h < 17 else None
    # глаза и рот
    rect(c, 12, 8, 13, 10, "K")
    rect(c, 19, 8, 20, 10, "K")
    rect(c, 15, 12, 17, 13, "K")
    return shifted(c, dy)


PETS = {
    "gopher": ("blue", gopher),
    "nyan": ("classic", nyan),
    "toaster": ("silver", toaster),
    "ghost": ("white", ghost),
    "pumpkin": ("orange", pumpkin),
}
ACTIONS = {"idle": 2, "walk": 4, "run": 4}


def png_bytes(pixels):
    """pixels: список строк RGBA-кортежей, размер SCALE*W x SCALE*H."""
    h = len(pixels)
    w = len(pixels[0])
    raw = bytearray()
    for row in pixels:
        raw.append(0)  # фильтр None
        for px in row:
            raw.extend(px)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def to_pixels(c):
    out = []
    for row in c:
        line = []
        for col in row:
            line.extend([PAL[col] if col else (0, 0, 0, 0)] * SCALE)
        for _ in range(SCALE):
            out.append(list(line))
    return [[tuple(p) for p in r] for r in out]


def save(c, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png_bytes(to_pixels(c)))


def main():
    total = 0
    for pet, (style, fn) in PETS.items():
        for action, frames in ACTIONS.items():
            for i in range(frames):
                right = fn(action, i)
                base = os.path.join(ROOT, pet, style)
                save(right, os.path.join(base, action, f"{i}.png"))
                total += 1
                if action != "idle":  # idle не зеркалим: left-версии нужны только для ходьбы и бега
                    save(mirror(right), os.path.join(base, action + "_left", f"{i}.png"))
                    total += 1
    print("written", total, "frames to", os.path.normpath(ROOT))


if __name__ == "__main__":
    main()
