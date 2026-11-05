#!/usr/bin/env python3
"""Два действия Noice: фильтр ошибок, последние десять и доступность истории."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    with open(os.path.join(_lua.ROOT, "tests", "lua_stubs.lua"), encoding="utf-8") as fh:
        rt.execute(fh.read())
    rt.execute(r'''
      NOTES, COMMANDS, QUEUE, HISTORY = {}, {}, {}, {}
      vim.schedule = function(fn) QUEUE[#QUEUE+1] = fn end
      function drain() while #QUEUE > 0 do table.remove(QUEUE, 1)() end end
      vim.fn.exists = function() return 2 end
      vim.cmd = function(cmd) COMMANDS[#COMMANDS+1] = cmd end
      RUNNING = true
      package.loaded['noice'] = {setup=function(opts) OPTIONS=opts end}
      package.loaded['noice.config'] = {is_running=function() return RUNNING end}
      package.loaded['noice.message.manager'] = {
        get = function(filter, opts)
          FILTER, FILTER_OPTIONS = filter, opts
          return HISTORY
        end,
      }
      SPEC = dofile(ROOT_PATH .. '/lua/plugins/noice.lua')[1]
      SPEC.config()
      E = require('config.error_history')
    ''')
    checks = []

    def check(label, cond):
        checks.append(bool(cond))
        print(("OK   " if cond else "FAIL ") + label)

    check("две разные клавиши доступны в группе x",
          rt.eval("SPEC.keys[1][1] == '<leader>xe' and SPEC.keys[2][1] == '<leader>xl'"))
    check("последние 10: только ошибки, последние по времени, а не первые",
          rt.eval("OPTIONS.commands.errors10.filter.error and OPTIONS.commands.errors10.filter_opts.count == 10 and not OPTIONS.commands.errors10.filter_opts.reverse"))
    check("журнал: те же ошибки без ограничения количества",
          rt.eval("OPTIONS.commands.errorlog.filter.error and OPTIONS.commands.errorlog.filter_opts == nil"))
    rt.execute("SPEC.keys[1][2](); drain()")
    check("пустой журнал объясняет, что ошибок нет, без пустого окна",
          rt.eval("#COMMANDS == 0 and #NOTES == 1") and "ошибок нет" in rt.eval("NOTES[1].msg"))
    rt.execute("NOTES={}; HISTORY={{id=1}}; SPEC.keys[1][2](); SPEC.keys[2][2](); drain()")
    check("клавиши вызывают различные команды Noice",
          rt.eval("COMMANDS[1] == 'Noice errors10' and COMMANDS[2] == 'Noice errorlog'"))
    check("проверка пустоты учитывает всю историю Noice только с уровнем error",
          rt.eval("FILTER.error and FILTER_OPTIONS.history and FILTER_OPTIONS.sort and FILTER_OPTIONS.count == 1"))
    rt.execute("NOTES={}; COMMANDS={}; RUNNING=false; E.last(); drain()")
    check("отключённый Noice предлагает :messages вместо исключения",
          rt.eval("#COMMANDS == 0") and ":messages" in rt.eval("NOTES[1].msg"))
    rt.execute("RUNNING=true; NOTES={}; package.loaded['noice.message.manager']={}; E.log(); drain()")
    check("несовместимый API журнала обрабатывается безопасно", ":messages" in rt.eval("NOTES[1].msg"))
    rt.execute("""
      NOTES={}; package.loaded['noice.message.manager']={get=function() error('broken') end}
      E.log(); drain()
    """)
    check("ошибка чтения журнала не роняет редактор", ":messages" in rt.eval("NOTES[1].msg"))
    docs = open(os.path.join(_lua.ROOT, "DOCS.md"), encoding="utf-8").read()
    keys = open(os.path.join(_lua.ROOT, "lua", "config", "keydocs", "g6_missing.lua"), encoding="utf-8").read()
    which = open(os.path.join(_lua.ROOT, "lua", "plugins", "which-key.lua"), encoding="utf-8").read()
    check("обе клавиши видны в which-key, справке и документации",
          all(key in text for key in ("<leader>xe", "<leader>xl") for text in (docs, keys, which)))
    check("документация различает сеансовую историю, ранние сообщения и диагностику LSP",
          all(text in docs for text in ("только в памяти текущего сеанса", "Ранние ошибки до запуска Noice",
                                       "не** история сбоев Neovim", ":MasonLog")))
    print(f"\nпроверок: {len(checks)}, провалов: {len(checks) - sum(checks)}")
    return 0 if all(checks) else 1


if __name__ == "__main__":
    sys.exit(main())
