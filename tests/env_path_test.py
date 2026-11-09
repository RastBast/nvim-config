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
    rt.execute("ep = require('config.env_path')")

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
    AVDIR = "/tmp/nvim_tests_state/lazy/avante.nvim"
    AVLIB = AVDIR + "/lua/avante_templates.so"
    rt.execute("EXEC = { git = true }")
    rt.execute("NOTES = {}")
    rt.execute(f"EXISTING = {{}}")
    rt.execute("ep.check()")
    check(":EnvCheck: плагин avante не установлен — так и пишет",
          "плагин не установлен" in rt.eval("NOTES[#NOTES].msg"), rt.eval("NOTES[#NOTES].msg"))
    rt.execute(f"EXISTING = {{ ['{AVDIR}'] = true }}")
    rt.execute("NOTES = {}")
    rt.execute("ep.check()")
    msg = rt.eval("NOTES[#NOTES].msg")
    check(":EnvCheck: библиотеки нет — подсказка :AvanteRebuild и путь файла",
          "библиотеки НЕТ, выполни :AvanteRebuild" in msg and "avante_templates.so" in msg, msg)
    check(":EnvCheck: показывает закреплённый тег", "avante v0.4.8" in msg, msg)
    rt.execute(f"vim.uv.fs_stat = function(p) if p == '{AVLIB}' then return {{}} end return nil end")
    rt.execute("NOTES = {}")
    rt.execute("ep.check()")
    check(":EnvCheck: библиотека есть — так и пишет",
          "библиотека ЕСТЬ" in rt.eval("NOTES[#NOTES].msg"), rt.eval("NOTES[#NOTES].msg"))

    # ---------------------------------------- зависшие .git/index.lock lazy ---
    import tempfile
    with tempfile.TemporaryDirectory() as lazy_tmp:
        for plug in ("nvim-lspconfig", "nvim-treesitter", "busy-plug"):
            gdir = os.path.join(lazy_tmp, plug, ".git")
            os.makedirs(gdir, exist_ok=True)
            with open(os.path.join(gdir, "index.lock"), "w", encoding="utf-8") as lf:
                lf.write("")

        rt.globals().LAZY_TMP = lazy_tmp
        rt.execute(
            r"""
            EXISTING[LAZY_TMP] = true
            EXISTING[LAZY_TMP .. "/nvim-lspconfig"] = true
            EXISTING[LAZY_TMP .. "/nvim-treesitter"] = true
            EXISTING[LAZY_TMP .. "/busy-plug"] = true
            EXEC = { git = true, ps = true, lsof = true }

            vim.fn.system = function(cmd)
              if cmd[1] == "ps" then
                return "/usr/bin/git git fetch --origin\n"
              elseif cmd[1] == "lsof" then
                -- Имитируем живой процесс git ТОЛЬКО внутри busy-plug:
                return "p1234\nfcwd\nn" .. LAZY_TMP .. "/busy-plug\n"
              end
              return ""
            end
            vim.fn.delete = function(p)
              return os.remove(p) and 0 or -1
            end
            vim.uv.fs_scandir = function(p)
              if p ~= LAZY_TMP then return nil end
              local items = { "nvim-lspconfig", "nvim-treesitter", "busy-plug" }
              local idx = 0
              return { next = function() idx = idx + 1; return items[idx], "directory" end }
            end
            vim.uv.fs_scandir_next = function(h) return h.next() end
            vim.uv.fs_stat = function(p)
              local f = io.open(p, "rb")
              if f then
                f:close()
                return { mtime = { sec = 995 } } -- свежий lock (5 сек назад), проверяем именно ps+lsof!
              end
              return nil
            end

            CLEANED_LOCKS, SKIPPED_LOCKS = ep.clean_lazy_git_locks({
              lazy_root = LAZY_TMP,
              now = 1000,
              max_age_sec = 300,
              quiet = true,
            })
            """
        )
        check("clean_lazy_git_locks удаляет осиротевшие index.lock в nvim-lspconfig и nvim-treesitter",
              rt.eval("#CLEANED_LOCKS") == 2
              and not os.path.exists(os.path.join(lazy_tmp, "nvim-lspconfig", ".git", "index.lock"))
              and not os.path.exists(os.path.join(lazy_tmp, "nvim-treesitter", ".git", "index.lock")))
        check("clean_lazy_git_locks НЕ трогает плагин, в котором прямо сейчас работает живой процесс git",
              rt.eval("#SKIPPED_LOCKS") == 1
              and os.path.exists(os.path.join(lazy_tmp, "busy-plug", ".git", "index.lock")))

        rt.execute("FORCE_CLEANED = ep.clean_lazy_git_locks({ lazy_root = LAZY_TMP, force = true, quiet = true })")
        check(":LazyUnlock! (force=true) снимает оставшийся lock принудительно",
              rt.eval("#FORCE_CLEANED") == 1
              and not os.path.exists(os.path.join(lazy_tmp, "busy-plug", ".git", "index.lock")))

    # ----------------------------------------------- автопроверка lazy.nvim ---
    init = open(os.path.join(_lua.ROOT, "init.lua"), encoding="utf-8").read()
    check("init.lua: автопроверка lazy (checker) выключена",
          "checker = { enabled = false" in init)
    check("init.lua: checker не включён нигде",
          "checker = { enabled = true" not in init)
    check("init.lua: :EnvCheck зарегистрирована", 'nvim_create_user_command("EnvCheck"' in init)
    check("init.lua: :LazyUnlock зарегистрирована", 'nvim_create_user_command("LazyUnlock"' in init)
    check("init.lua: clean_lazy_git_locks вызывается до require('lazy').setup",
          init.index("clean_lazy_git_locks()") < init.index('require("lazy").setup('))
    check("init.lua: lazy ограничен 4 параллельными процессами (concurrency)",
          "concurrency = 4" in init and init.index('require("lazy").setup(') < init.index("concurrency = 4"))
    check("init.lua: env_path подключён первым (до lazy)",
          init.index('require("config.env_path").setup()') < init.index('require("lazy").setup('))

    failed = sum(1 for _, ok in checks if not ok)
    print(f"\nпроверок: {len(checks)}, провалов: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
