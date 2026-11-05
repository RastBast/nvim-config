#!/usr/bin/env python3
"""Тесты починки PATH (lua/config/env_path.lua) и автопроверки lazy.nvim.

Контекст: на Mac nvim из GUI получает урезанный PATH, и lazy.nvim печатает
«Failed to spawn process git» на каждом плагине. env_path дописывает
стандартные каталоги; если git всё равно нет — одно понятное сообщение.

В заглушках tests/lua_stubs.lua нет vim.split, vim.fn.executable и
vim.fn.isdirectory (они превращаются в пустой прокси). Поэтому здесь они
задаются явно, и проверки опираются на реальные значения.

Запуск:  python3 tests/env_path_test.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402

checks = []


def check(name, cond, extra=""):
    checks.append((name, bool(cond)))
    print(("OK   " if cond else "FAIL ") + name + ("" if cond or not extra else f"   [{extra}]"))


PRELUDE = r'''
vim.split = function(s, sep)
  local out = {}
  for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
  return out
end
EXISTING = {}   -- каталоги, которые «существуют» в тесте
EXEC = {}       -- исполняемые файлы, которые «найдены» в PATH
vim.fn.has = function() return 0 end
vim.fn.stdpath = function() return "/tmp/nvim_tests_state" end
vim.fn.isdirectory = function(d) return EXISTING[d] and 1 or 0 end
vim.fn.executable = function(x) return EXEC[x] and 1 or 0 end
vim.fn.exepath = function(x) return EXEC[x] and ("/x/" .. x) or "" end
vim.uv.fs_stat = function() return nil end
vim.uv.os_uname = function() return { sysname = "Darwin", machine = "arm64" } end
'''


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    with open(os.path.join(_lua.ROOT, "tests", "lua_stubs.lua"), encoding="utf-8") as fh:
        rt.execute(fh.read())
    rt.execute(PRELUDE)
    rt.execute("vim.env.HOME='/Users/test'; vim.env.XDG_STATE_HOME='/custom/state'; ep = require('config.env_path')")

    # ---------------------------------------------------- дописывание PATH ---
    rt.execute("EXISTING = { ['/opt/homebrew/bin'] = true, ['/usr/bin'] = true, ['/bin'] = true }")
    rt.execute("vim.env.PATH = '/usr/bin:/bin'")
    rt.execute("ADDED = ep.setup()")
    check("Homebrew (Apple Silicon) добавлен, если каталог есть",
          rt.eval("ADDED[1]") == "/opt/homebrew/bin", rt.eval("vim.env.PATH"))
    check("у уже имеющихся каталогов не дублируем",
          rt.eval("select(2, vim.env.PATH:gsub('/usr/bin', ''))") == 1)
    check("PATH пользователя остаётся первым (новое — в конец)",
          rt.eval("vim.env.PATH").startswith("/usr/bin:/bin"))

    rt.execute("vim.env.PATH = '/my/tools:/usr/bin'")
    rt.execute("ep.setup()")
    check("свой каталог пользователя стоит впереди",
          rt.eval("vim.env.PATH").startswith("/my/tools:"))

    rt.execute("vim.env.PATH = '/usr/bin'")
    rt.execute("EXISTING = {}")
    rt.execute("ep.setup()")
    check("несуществующие каталоги не добавляются",
          rt.eval("vim.env.PATH") == "/usr/bin")

    rt.execute("""
      EXISTING = { ['/custom/state/nix/profile/bin'] = true, ['/Users/test/.nix-profile/bin'] = true,
                   ['/nix/var/nix/profiles/default/bin'] = true, ['/Users/test/.cargo/bin'] = true }
      vim.env.PATH='/custom/bin'; ep.setup()
    """)
    check("GUI PATH видит существующие профили Nix и cargo, не меняя приоритет пользовательского PATH",
          all(p in rt.eval("vim.env.PATH") for p in ("/custom/state/nix/profile/bin", "/Users/test/.nix-profile/bin",
              "/nix/var/nix/profiles/default/bin", "/Users/test/.cargo/bin"))
          and rt.eval("vim.env.PATH").startswith("/custom/bin:"))

    rt.execute("EXISTING = { ['/opt/homebrew/bin'] = true }")
    rt.execute("vim.env.PATH = '/usr/bin'")
    rt.execute("ep.setup()")
    first = rt.eval("vim.env.PATH")
    rt.execute("ep.setup()")
    check("повторный setup() идемпотентен", rt.eval("vim.env.PATH") == first, first)

    # ---------------------------------------------------- git: есть / нет ---
    rt.execute("NOTES = {}")
    rt.execute("EXEC = { git = true }")
    rt.execute("ep.setup()")
    check("git найден: флаг git_missing = false", rt.eval("ep.git_missing") is False)
    check("git найден: уведомления нет", rt.eval("#NOTES") == 0)

    rt.execute("EXEC = {}")
    rt.execute("NOTES = {}")
    rt.execute("ep.setup()")
    check("git не найден: флаг git_missing = true", rt.eval("ep.git_missing") is True)
    check("git не найден: одно понятное сообщение (ERROR)",
          rt.eval("#NOTES") == 1 and "git не найден" in rt.eval("NOTES[1].msg")
          and rt.eval("NOTES[1].lvl") == 4)
    check("сообщение содержит команду установки",
          "xcode-select --install" in rt.eval("NOTES[1].msg") and "brew install git" in rt.eval("NOTES[1].msg"))
    check("сообщение направляет на :EnvCheck", ":EnvCheck" in rt.eval("NOTES[1].msg"))

    # ------------------------------------------------ :EnvCheck: блок avante ---
    AVDIR = "/tmp/custom-lazy/avante.nvim"
    rt.execute("""
      EXEC = { git = true }; NOTES = {}; EXISTING = {}; AV_READY = false; AV_REV = 'correct'
      vim.fn.has = function(x) return x == 'nvim-0.12' and 1 or 0 end
      package.loaded['config.avante_build'] = {
        TAG = 'v0.4.8', COMMIT = 'correct',
        plugin_dir = function() return '/tmp/custom-lazy/avante.nvim' end,
        lib_file = function(d) return d .. '/lua/avante_templates.so' end,
        check = function() return AV_READY, AV_READY and 'ok' or 'wrong architecture' end,
        revision = function() return AV_REV end,
        revision_error = function() return ':Lazy update avante.nvim' end,
      }
    """)
    rt.execute("ep.check()")
    check(":EnvCheck: плагин avante не установлен — так и пишет",
          "плагин не установлен" in rt.eval("NOTES[#NOTES].msg"), rt.eval("NOTES[#NOTES].msg"))
    check(":EnvCheck: отдельно показаны nil, nix и cargo",
          all(x in rt.eval("NOTES[#NOTES].msg") for x in ("nil:", "nix:", "cargo:", "nil_ls")))
    rt.execute(f"EXISTING = {{ ['{AVDIR}'] = true }}")
    rt.execute("NOTES = {}; ep.check()")
    msg = rt.eval("NOTES[#NOTES].msg")
    check(":EnvCheck: ошибка загрузки и подсказка :AvanteRebuild",
          "библиотеки не готовы" in msg and ":AvanteRebuild" in msg and "wrong architecture" in msg, msg)
    check(":EnvCheck: показывает тег и фактический каталог",
          "avante v0.4.8" in msg and AVDIR in msg and "avante_templates.so" in msg, msg)
    rt.execute("AV_READY = true; NOTES = {}; ep.check()")
    check(":EnvCheck: рабочие библиотеки загружаются",
          "библиотеки загружаются" in rt.eval("NOTES[#NOTES].msg"), rt.eval("NOTES[#NOTES].msg"))
    rt.execute("AV_REV = 'wrong'; NOTES = {}; ep.check()")
    check(":EnvCheck: неправильная версия предлагает Lazy update",
          ":Lazy update avante.nvim" in rt.eval("NOTES[#NOTES].msg"), rt.eval("NOTES[#NOTES].msg"))
    rt.execute("vim.fn.has = function() return 0 end; NOTES = {}; ep.check()")
    check(":EnvCheck: предупреждает о Neovim ниже 0.12",
          "нужен Neovim 0.12+" in rt.eval("NOTES[#NOTES].msg"), rt.eval("NOTES[#NOTES].msg"))

    # ----------------------------------------------- автопроверка lazy.nvim ---
    init = open(os.path.join(_lua.ROOT, "init.lua"), encoding="utf-8").read()
    check("init.lua: автопроверка lazy (checker) выключена",
          "checker = { enabled = false" in init)
    check("init.lua: checker не включён нигде",
          "checker = { enabled = true" not in init)
    check("init.lua: :EnvCheck зарегистрирована", 'nvim_create_user_command("EnvCheck"' in init)
    check("init.lua: lazy ограничен 8 параллельными процессами (concurrency)",
          "concurrency = 8" in init and init.index('require("lazy").setup(') < init.index("concurrency = 8"))
    check("init.lua: env_path подключён первым (до lazy)",
          init.index('require("config.env_path").setup()') < init.index('require("lazy").setup('))

    failed = sum(1 for _, ok in checks if not ok)
    print(f"\nпроверок: {len(checks)}, провалов: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
