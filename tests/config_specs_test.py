#!/usr/bin/env python3
"""Тесты спецификаций плагинов, клавиш, Ghostty и документации.

Спецификации загружаются настоящим LuaJIT (тот же код, что у пользователя),
а остальное проверяется по тексту файлов.

Проверяем:
  * markdown: render-markdown, markdown-preview (build — строка, без E117), vim-markdown;
    клавиши <leader>mv / <leader>mV только для markdown;
  * pets: ширина полосы 100%, клавиша <leader>up;
  * spider: умный back на q, b больше не движение;
  * keymaps: b — запись макроса (remap = false);
  * avante: build — функция, готовые библиотеки по тегу и откат на make;
  * Ghostty: нет scrollback-limit-lines, window-save-state = never, fullscreen = non-native;
  * DOCS.md и keydocs содержат новые клавиши и команды.

Запуск:  python3 tests/config_specs_test.py
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


def load_spec(rt, rel):
    """Загрузить Lua-файл, который возвращает таблицу спецификаций, и вернуть её как Lua-таблицу."""
    rt.execute(f"SPEC = dofile(ROOT_PATH .. '/{rel}')")


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    with open(os.path.join(_lua.ROOT, "tests", "lua_stubs.lua"), encoding="utf-8") as fh:
        rt.execute(fh.read())

    # ---------------------------------------------------------- markdown ---
    load_spec(rt, "lua/plugins/markdown.lua")
    rt.execute("""
      function find(name)
        for _, s in ipairs(SPEC) do if s[1] == name then return s end end
      end
    """)
    check("render-markdown.nvim на месте", rt.eval("find('MeanderingProgrammer/render-markdown.nvim') ~= nil"))
    check("vim-markdown на месте", rt.eval("find('preservim/vim-markdown') ~= nil"))
    mp = rt.eval("find('iamcco/markdown-preview.nvim')")
    check("markdown-preview.nvim на месте", mp is not None)
    build = rt.eval("find('iamcco/markdown-preview.nvim').build")
    check("markdown-preview: build — строка (не функция с vim.fn)", isinstance(build, str), type(build).__name__)
    check("markdown-preview: build не вызывает mkdp#util#install (E117)",
          isinstance(build, str) and "mkdp#util" not in build)
    check("markdown-preview: build = cd app && npx --yes yarn install",
          build == "cd app && npx --yes yarn install", str(build))
    keys = rt.eval("""(function()
      local r = {}
      for _, k in ipairs(find('iamcco/markdown-preview.nvim').keys) do
        r[#r + 1] = k[1] .. '|' .. tostring(k.ft)
      end
      return table.concat(r, ',')
    end)()""")
    check("клавиша <leader>mv только для markdown", "<leader>mv|markdown" in keys, keys)
    check("клавиша <leader>mV только для markdown", "<leader>mV|markdown" in keys, keys)
    check("preview: обновление на каждое изменение (refresh_slow = 0 в init)",
          "mkdp_refresh_slow = 0" in read("lua/plugins/markdown.lua"))
    check("preview: только localhost (open_to_the_world = 0)",
          "mkdp_open_to_the_world = 0" in read("lua/plugins/markdown.lua"))

    # ------------------------------------------------------------- pets ---
    load_spec(rt, "lua/plugins/pets.lua")
    rt.execute("PSPEC = SPEC[1]")
    check("pets: popup.width = 100%", rt.eval("PSPEC.opts.popup.width") == "100%")
    check("pets: default_pet = gopher", rt.eval("PSPEC.opts.default_pet") == "gopher")
    check("pets: клавиша <leader>up есть", "<leader>up" in str(rt.eval(
        "(function() local r = {} for _, k in ipairs(PSPEC.keys) do r[#r+1] = k[1] end return table.concat(r, ',') end)()")))

    # ------------------------------------------------------------ spider ---
    load_spec(rt, "lua/plugins/spider.lua")
    rt.execute("SP = SPEC[1].keys")
    lhs = [rt.eval(f"SP[{i}][1]") for i in range(1, int(rt.eval("#SP")) + 1)]
    check("spider: назад (motion 'b') на клавише q", any(
        k == "q" and "motion('b')" in rt.eval(f"SP[{i}][2]") for i, k in enumerate(lhs, 1)))
    check("spider: клавиша b больше не назначена на движение", "b" not in lhs, str(lhs))
    check("spider: w, e, ge остаются", all(x in lhs for x in ("w", "e", "ge")))

    # ----------------------------------------------------------- keymaps ---
    km = read("lua/config/keymaps.lua")
    check("keymaps: b → q (запись макроса), remap = false",
          re.search(r'vim\.keymap\.set\(\s*"n"\s*,\s*"b"\s*,\s*"q"\s*,\s*\{\s*remap\s*=\s*false', km) is not None)

    # ------------------------------------------------------------- avante ---
    av = read("lua/plugins/avante.lua")
    check("avante: build — функция", re.search(r"build\s*=\s*function\(plugin\)", av) is not None)
    check("avante: сборка через config.avante_build", 'require("config.avante_build")' in av)
    bm = read("lua/config/avante_build.lua")
    check("avante_build: запасной make есть", 'vim.system({ "make" }' in bm)
    check("avante_build: готовые библиотеки через curl+tar", '"curl", "-fsSL"' in bm and '"tar", "-xzf"' in bm)
    check("avante: нет старого build = \"make\" по умолчанию", 'or "make",' not in av)

    # ------------------------------------------------------------ Ghostty ---
    gh = [l.strip() for l in read("macos/ghostty/config").split("\n")
          if l.strip() and not l.strip().startswith("#")]
    kv = {}
    for l in gh:
        if "=" in l:
            k, v = l.split("=", 1)
            kv.setdefault(k.strip(), []).append(v.strip())
    check("Ghostty: нет scrollback-limit-lines (ошибка unknown field)", "scrollback-limit-lines" not in kv)
    check("Ghostty: scrollback-limit — число (байты)",
          kv.get("scrollback-limit") and kv["scrollback-limit"][0].isdigit(), str(kv.get("scrollback-limit")))
    check("Ghostty: fullscreen = non-native", kv.get("fullscreen") == ["non-native"], str(kv.get("fullscreen")))
    check("Ghostty: macos-non-native-fullscreen = true",
          kv.get("macos-non-native-fullscreen") == ["true"], str(kv.get("macos-non-native-fullscreen")))
    check("Ghostty: window-save-state = never (стартовый fullscreen не перекрывается)",
          kv.get("window-save-state") == ["never"], str(kv.get("window-save-state")))
    check("Ghostty: window-decoration = none", kv.get("window-decoration") == ["none"])
    REPEATABLE = {"palette", "keybind"}  # Ghostty разрешает повторять эти ключи
    dups = [k for k, v in kv.items() if len(v) > 1 and k not in REPEATABLE]
    check("Ghostty: повторов ключей нет", not dups, str(dups))

    # ------------------------------------------- прыжок flash и окружения ---
    # Баг пункта 5: flash на s + mini.surround на sa/sd/sr… → nvim ждал 2-й символ.
    # Решение: прыжок на gs, окружения остаются на s-префиксе.
    load_spec(rt, "lua/plugins/flash.lua")
    fkeys = rt.eval("(function() local r = {} for _, k in ipairs(SPEC.keys) do r[#r+1] = k[1] end return table.concat(r, ',') end)()")
    check("flash: прыжок на gs", "gs" in str(fkeys), str(fkeys))
    check("flash: клавиши s больше нет (префикс s отдан окружениям)", "s" not in str(fkeys).split(","))
    sur = read("lua/plugins/mini.lua")
    for k in ("sa", "sd", "sf", "sF", "sh", "sr", "sn"):
        check(f"mini.surround: окружение на {k}", f'= "{k}"' in sur)
    check("mini.surround: нет gz-префикса (решение: окружения на s)", "gz" not in sur)

    # ------------------------------------------------------------ markdown ---
    mdsrc = read("lua/plugins/markdown.lua")
    check("markdown: зависимость godlygeek/tabular (для :TableFormat)", "godlygeek/tabular" in mdsrc)
    check("markdown: <leader>mT → :Toc", '"<leader>mT", "<cmd>Toc<cr>"' in mdsrc)
    check("markdown: <leader>mE → :TableFormat", '"<leader>mE", "<cmd>TableFormat<cr>"' in mdsrc)
    check("markdown: чекбоксы видимые (☐/☑), не пустые пробелы",
          "☐" in mdsrc and "☑" in mdsrc and 'icon = "   "' not in mdsrc)

    # -------------------------------------------- live-превью (python3) ---
    init_src = read("init.lua")
    check("init.lua: md_preview.setup() вызывается", 'require("config.md_preview").setup()' in init_src)
    mdp = read("lua/config/md_preview.lua")
    check("md_preview: клавиша <leader>mL", '"<leader>mL"' in mdp)
    check("md_preview: команды :MdPreview / :MdPreviewStop / :MdPreviewStatus",
          all(f'"{c}"' in mdp for c in ("MdPreview", "MdPreviewStop", "MdPreviewStatus")))
    check("md_preview: порт 45771 и только localhost", "PORT = 45771" in mdp and "127.0.0.1" in mdp)
    check("md_preview: клавиша <leader>Im больше не используется", "<leader>Im" not in mdp)

    # ---------------------------------------------------- Halloween / pets ---
    hw = read("lua/config/halloween.lua")
    check("halloween: <leader>uH — оверлей (toggle)", 'vim.keymap.set("n", "<leader>uH", M.toggle' in hw)
    check("halloween: <leader>uHw — окно-анимация", 'vim.keymap.set("n", "<leader>uHw", M.show' in hw)
    check("halloween: палитра терминала не чужая (нет #ff7a00)", "#ff7a00" not in hw)
    lu = read("lua/plugins/lualine.lua")
    check("lualine: индикатор тыквы при halloween_on", "vim.g.halloween_on == 1" in lu)
    pets = read("lua/plugins/pets.lua")
    check("pets: <leader>uP — тыква-питомец", '"<leader>uP", "<cmd>PetsNewCustom pumpkin orange' in pets)
    pc = read("lua/config/pets_custom.lua")
    check("pets_custom: тыква в списке питомцев", "pumpkin = {" in pc)

    # --------------------------------------------------------------- avante ---
    av = read("lua/plugins/avante.lua")
    check("avante: команда :AvanteRebuild", 'nvim_create_user_command("AvanteRebuild"' in av)
    check("avante: авто-сборка при отсутствии библиотек (B.is_built)", "B.is_built(plugin_dir())" in av and "rebuild({ silent = true })" in av)

    # ------------------------------------------------------- lazy-lock / справка ---
    lock = read("lazy-lock.json")
    check("lazy-lock: vim-markdown и tabular зафиксированы",
          '"vim-markdown"' in lock and '"tabular"' in lock)
    kd = read("lua/config/keydocs/g1_editor.lua") + read("lua/config/keydocs/g11_moves.lua") + read("lua/config/keydocs/g12_games_tools.lua")
    for item in ['lhs = "gs"', 'lhs = "sa"', 'lhs = "<leader>uHw"', 'lhs = "<leader>uP"',
                 'lhs = "<leader>mL"', 'lhs = "<leader>mT"', 'lhs = "<leader>mE"']:
        check(f"справка <leader>? содержит {item}", item in kd)

    # ------------------------------------------------------------- DOCS ---
    docs = read("DOCS.md")
    keydocs = read("lua/config/keydocs/g1_editor.lua") + read("lua/config/keydocs/g2_tools.lua")
    for item in ["<leader>uH", "<leader>mv", "<leader>mV", ":Halloween", ":Boo", "`q`", "`b`",
                 "<leader>uHw", "<leader>uP", "<leader>mL", "<leader>mT", "<leader>mE",
                 ":MdPreview", ":AvanteRebuild", "`gs`", "`sa`"]:
        check(f"DOCS.md описывает {item}", item in docs)
    for item in ["<leader>uH", "<leader>mv", "<leader>mV"]:
        check(f"справка <leader>? содержит {item}", item in keydocs)
    check("DOCS.md: нет устаревшего «7 штук»", "7 штук" not in docs and "Меню из 7" not in docs)

    failed = sum(1 for _, ok in checks if not ok)
    print(f"\nпроверок: {len(checks)}, провалов: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
