#!/usr/bin/env python3
"""Тесты live-превью markdown (lua/config/md_preview.lua) под LuaJIT.

Проверяем без nvim и без браузера:
  * команды :MdPreview / :MdPreviewStop / :MdPreviewStatus и клавишу <leader>mL;
  * запуск: python3-сервер на 127.0.0.1:45771, server.py и файл превью в кэше;
  * живое обновление: несохранённый буфер попадает в файл превью (TextChanged);
  * остановка: :MdPreviewStop, повторный <leader>mL, VimLeavePre (без сирот).

Запуск:  python3 tests/md_preview_test.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402

checks = []
STATE_DIR = "/tmp/nvim_tests_state"


def check(name, cond, extra=""):
    checks.append((name, bool(cond)))
    print(("OK   " if cond else "FAIL ") + name + ("" if cond or not extra else f"   [{extra}]"))


# Заглушки, которых нет в общем lua_stubs.lua и которые нужны только превью.
EXTRA_STUBS = r'''
vim.loop = vim.uv
JOBS, JOBSTOPS, DEFERRED = {}, {}, {}
LIVE = { "# Черновик", "" }
vim.fn.executable = function() return 1 end
vim.fn.has = function() return 0 end
vim.fn.mkdir = function() end
vim.fn.fnamemodify = function(p, mod) if mod == ":t" then return (p:match("([^/]+)$") or p) end return p end
vim.fn.bufnr = function() return -1 end
vim.fn.bufadd = function() return 7 end
vim.fn.bufload = function() end
vim.fn.jobstart = function(cmd, opts) JOBS[#JOBS + 1] = { cmd = cmd, opts = opts }; return 42 end
vim.fn.jobstop = function(job) JOBSTOPS[#JOBSTOPS + 1] = job; return 1 end
vim.defer_fn = function(fn) DEFERRED[#DEFERRED + 1] = fn end
vim.api.nvim_get_current_buf = function() return 7 end
vim.api.nvim_buf_get_name = function() return "/home/user/notes.md" end
vim.api.nvim_buf_get_lines = function() return LIVE end
vim.api.nvim_del_augroup_by_id = function() end
'''


def check_live_server(server_py):
    """Запускаем server.py из кэша на свободном порту и делаем HTTP-запросы."""
    import json
    import socket
    import subprocess
    import time
    import urllib.request

    if not os.path.exists(server_py):
        check("сервер: server.py есть для запуска", False)
        return
    with socket.socket() as sk:
        sk.bind(("127.0.0.1", 0))
        port = sk.getsockname()[1]
    md = os.path.join(STATE_DIR, "live.md")
    with open(md, "w", encoding="utf-8") as fh:
        fh.write("# Заголовок\n\nТекст с **жирным** и `кодом`.\n\n- [ ] задача\n- [x] готово\n\n"
                 "| a | b |\n|---|---|\n| 1 | 2 |\n\n```python\nprint(1)\n```\n")
    proc = subprocess.Popen([sys.executable, server_py, md, str(port)],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        body = None
        for _ in range(50):  # до ~5 с на старт
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{port}/view", timeout=1) as r:
                    body = json.loads(r.read().decode("utf-8"))
                break
            except Exception:
                if proc.poll() is not None:
                    break
                time.sleep(0.1)
        check("сервер: поднимается на 127.0.0.1 и отдаёт /view", body is not None,
              proc.stderr.read().decode("utf-8", "replace")[-200:] if proc.poll() is not None else "")
        if body:
            h = body["html"]
            check("сервер: заголовок # → <h1>", "<h1>Заголовок</h1>" in h)
            check("сервер: **жирный** и `код` → <strong>, <code>",
                  "<strong>жирным</strong>" in h and "<code>кодом</code>" in h)
            check("сервер: чекбоксы — отмеченный и неотмеченный",
                  'class="cb done"' in h and 'class="cb "' in h)
            check("сервер: таблица → <table>", "<table>" in h and "<td>1</td>" in h)
            check("сервер: блок кода с языком", 'class="lang-python"' in h and "print(1)" in h)
            # несохранённый текст: меняем файл — revision растёт, текст новый
            with open(md, "w", encoding="utf-8") as fh:
                fh.write("# Новое\n")
            time.sleep(0.05)
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/view", timeout=2) as r:
                body2 = json.loads(r.read().decode("utf-8"))
            check("сервер: изменение файла → новая ревизия и новый HTML",
                  body2["rev"] > body["rev"] and "<h1>Новое</h1>" in body2["html"])
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/", timeout=2) as r:
            page = r.read().decode("utf-8")
        check("сервер: / отдаёт HTML-страницу с опросом /view", "fetch('/view'" in page and "<html" in page)
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    # Каталог кэша (cache_dir делает mkdir, а заглушка mkdir ничего не делает)
    os.makedirs(os.path.join(STATE_DIR, "md_preview"), exist_ok=True)
    with open(os.path.join(_lua.ROOT, "tests", "lua_stubs.lua"), encoding="utf-8") as fh:
        rt.execute(fh.read())
    rt.execute(EXTRA_STUBS)
    rt.execute("md = require('config.md_preview'); md.setup()")

    # ------------------------------------------------ регистрация ---
    check(":MdPreview зарегистрирована", rt.eval("CMDS['MdPreview'] ~= nil"))
    check(":MdPreviewStop зарегистрирована", rt.eval("CMDS['MdPreviewStop'] ~= nil"))
    check(":MdPreviewStatus зарегистрирована", rt.eval("CMDS['MdPreviewStatus'] ~= nil"))
    check("<leader>mL привязана в нормальном режиме",
          rt.eval("(function() for _, k in ipairs(KEYS) do if k.lhs == '<leader>mL' and k.mode == 'n' then return true end end return false end)()"))
    check("VimLeavePre: сервер гасится при выходе",
          rt.eval("(function() for _, a in ipairs(AUTOCMDS) do if a.ev == 'VimLeavePre' then return true end end return false end)()"))

    # ------------------------------------------------ запуск ---
    rt.execute("OK_START = md.start()")
    check("start() возвращает true", rt.eval("OK_START") is True)
    check("сервер запущен через python3", rt.eval("JOBS[1].cmd[1]") == "python3")
    # аргументы: {"python3", server.py, файл превью, порт}
    check("порт сервера 45771", rt.eval("JOBS[1].cmd[4]") == "45771")
    prev_path = rt.eval("JOBS[1].cmd[3]")
    check("аргумент — файл превью в кэше md_preview/preview-<имя>.md",
          prev_path == os.path.join(STATE_DIR, "md_preview", "preview-notes.md.md"), prev_path)
    server_py = os.path.join(STATE_DIR, "md_preview", "server.py")
    check("server.py записан в кэш", os.path.exists(server_py))
    if os.path.exists(server_py):
        src = open(server_py, encoding="utf-8").read()
        check("server.py: ThreadingHTTPServer (без внешних зависимостей)", "ThreadingHTTPServer" in src)
        check("server.py: нет импортов сторонних пакетов",
              all(m not in src for m in ("import markdown", "from markdown", "import requests")))
    check("файл превью записан", os.path.exists(prev_path), prev_path)
    if os.path.exists(prev_path):
        check("файл превью — текст буфера", open(prev_path, encoding="utf-8").read() == "# Черновик\n")
    check("браузер открывается с задержкой (defer_fn)", rt.eval("#DEFERRED") >= 1)

    # ------------------------------------------------ статус ---
    rt.execute("md.status()")
    check(":MdPreviewStatus: сервер жив", "жив" in rt.eval("NOTES[#NOTES].msg"))

    # ------------------------------------------- живое обновление (без :w) ---
    rt.execute("LIVE = { '# Новый текст', 'несохранённый абзац' }")
    # имитация TextChanged: вызываем колбэк автокоманды
    rt.execute("for _, a in ipairs(AUTOCMDS) do if type(a.ev) == 'table' or a.ev == 'TextChanged' then "
               "if a.opts and a.opts.callback then a.opts.callback(); break end end end")
    rt.execute("TIMERS[#TIMERS].cb()")  # debounce 250 мс → экспорт
    if os.path.exists(prev_path):
        content = open(prev_path, encoding="utf-8").read()
        check("несохранённый буфер попал в превью (без :w)",
              content == "# Новый текст\nнесохранённый абзац", repr(content)[:120])
    else:
        check("несохранённый буфер попал в превью (без :w)", False, "файла нет")

    # ------------------------------------------------ остановка ---
    rt.execute("CMDS.MdPreviewStop()")
    check(":MdPreviewStop гасит сервер (jobstop)", rt.eval("#JOBSTOPS") >= 1)
    rt.execute("md.status()")
    check("после остановки статус «не запущен»", "не запущен" in rt.eval("NOTES[#NOTES].msg"))

    # ------------------------------------------- <leader>mL = переключатель ---
    rt.execute("(function() for _, k in ipairs(KEYS) do if k.lhs == '<leader>mL' then k.rhs() end end end)()")
    check("<leader>mL включает превью (второй запуск)", rt.eval("#JOBS") >= 2)
    rt.execute("(function() for _, k in ipairs(KEYS) do if k.lhs == '<leader>mL' then k.rhs() end end end)()")
    check("<leader>mL выключает превью", "выключено" in rt.eval("NOTES[#NOTES].msg"))

    # ------------------------------------------- VimLeavePre гасит сервер ---
    rt.execute("md.start()")
    before = rt.eval("#JOBSTOPS")
    rt.execute("for _, a in ipairs(AUTOCMDS) do if a.ev == 'VimLeavePre' then a.opts.callback() end end")
    check("VimLeavePre: сервер не остаётся сиротой", rt.eval("#JOBSTOPS") > before)

    # ------------------------------------------ сам python3-сервер (живьём) ---
    check_live_server(server_py)

    failed = sum(1 for _, ok in checks if not ok)
    print(f"\nпроверок: {len(checks)}, провалов: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
