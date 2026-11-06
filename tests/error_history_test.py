#!/usr/bin/env python3
"""Два независимых действия, фильтр Noice и запасное окно :messages."""
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
      GENERAL = {{content=function() return 'early Noice message\nnative error in history' end}}
      vim.v = { errmsg = 'E999: last native error' }
      vim.schedule = function(fn) QUEUE[#QUEUE+1] = fn end
      function drain() while #QUEUE > 0 do table.remove(QUEUE, 1)() end end
      vim.fn.exists = function() return 2 end
      vim.api.nvim_get_current_buf = function() return 1 end
      vim.api.nvim_exec2 = function(cmd)
        MESSAGES_CMD = cmd
        return {output = 'old message\nnative error in history'}
      end
      vim.split = function(s)
        local lines = {}
        for line in (s .. '\n'):gmatch('(.-)\n') do lines[#lines+1] = line end
        return lines
      end
      vim.list_extend = function(a, b) for _, value in ipairs(b) do a[#a+1] = value end end
      vim.cmd = function(cmd)
        if cmd:match('^Noice ') and FAIL_VIEW then error('synthetic view failure') end
        COMMANDS[#COMMANDS+1] = cmd
      end
      RUNNING = true
      package.loaded['noice'] = {setup=function(opts) OPTIONS=opts end}
      package.loaded['noice.config'] = {is_running=function() return RUNNING end}
      package.loaded['noice.message.manager'] = {
        get = function(filter, opts)
          if not filter then GENERAL_OPTIONS = opts; return GENERAL end
          FILTER, FILTER_OPTIONS = filter, opts
          return HISTORY
        end,
      }
      SPEC = dofile(ROOT_PATH .. '/lua/plugins/noice.lua')[1]
      SPEC.config()
      E = require('config.error_history')
      E.setup()
      function map(lhs)
        for _, entry in ipairs(KEYS) do if entry.lhs == lhs then return entry end end
      end
      function fallback_text() return table.concat(BUF_LINES[1] or {}, '\n') end
    ''')
    checks = []

    def check(label, cond):
        checks.append(bool(cond))
        print(("OK   " if cond else "FAIL ") + label)

    check("команды и клавиши существуют независимо от lazy-спецификации Noice",
          rt.eval("CMDS.ErrorLast10 ~= nil and CMDS.ErrorLog ~= nil and SPEC.keys == nil"))
    check("действия зарегистрированы в обеих группах",
          rt.eval("map('<leader>xe').rhs == '<cmd>ErrorLast10<cr>' and map('<leader>Hxe').rhs == '<cmd>ErrorLast10<cr>' and map('<leader>xl').rhs == '<cmd>ErrorLog<cr>' and map('<leader>Hxg').rhs == '<cmd>ErrorLog<cr>'"))
    check("последние 10: только ошибки, последние по времени, а не первые",
          rt.eval("OPTIONS.commands.errors10.filter.error and OPTIONS.commands.errors10.filter_opts.count == 10 and not OPTIONS.commands.errors10.filter_opts.reverse"))
    check("журнал: те же ошибки без ограничения количества",
          rt.eval("OPTIONS.commands.errorlog.filter.error and OPTIONS.commands.errorlog.filter_opts == nil"))
    rt.execute("CMDS.ErrorLast10(); drain()")
    check("пустой Noice открывает общую историю и последнюю ошибку, не вызывая :messages",
          rt.eval("MESSAGES_CMD == nil and GENERAL_OPTIONS.count == 10") and all(s in rt.eval("fallback_text()") for s in
              ("Noice нет ошибок", "E999: last native error", "native error in history", "могут быть и другие сообщения")))
    rt.execute("COMMANDS={}; HISTORY={{id=1}}; CMDS.ErrorLast10(); CMDS.ErrorLog(); drain()")
    check("команды вызывают различные представления Noice",
          rt.eval("COMMANDS[1] == 'Noice errors10' and COMMANDS[2] == 'Noice errorlog'"))
    check("проверка пустоты учитывает всю историю Noice только с уровнем error",
          rt.eval("FILTER.error and FILTER_OPTIONS.history and FILTER_OPTIONS.sort and FILTER_OPTIONS.count == 1"))
    rt.execute("COMMANDS={}; RUNNING=false; CMDS.ErrorLog(); drain()")
    check("отключённый Noice открывает всю встроенную историю",
          rt.eval("MESSAGES_CMD == 'messages' and COMMANDS[1] == 'botright new'") and "Noice не запущен" in rt.eval("fallback_text()"))
    rt.execute("RUNNING=true; package.loaded['noice.message.manager']={}; E.log(); drain()")
    check("несовместимый API истории предлагает :messages вручную", "История Noice недоступна" in rt.eval("fallback_text()") and "Открой :messages" in rt.eval("fallback_text()"))
    rt.execute("package.loaded['noice.message.manager']={get=function() error('broken') end}; E.log(); drain()")
    check("ошибка чтения истории не роняет редактор", "Не удалось прочитать" in rt.eval("fallback_text()"))
    rt.execute("package.loaded['noice.message.manager']={get=function() return {{}} end}; FAIL_VIEW=true; E.log(); drain()")
    check("ошибка отображения Noice открывает запасное окно", "Не удалось открыть Noice" in rt.eval("fallback_text()"))
    rt.execute("package.loaded.noice=nil; package.loaded['noice.config']=nil; package.preload.noice=function() error('missing') end; E.last()")
    check("отсутствующий Noice открывает последние 10 сообщений",
          rt.eval("MESSAGES_CMD == '10messages'") and "Noice недоступен" in rt.eval("fallback_text()"))
    rt.execute("vim.v.errmsg='E999: first line\\nsecond line'; E.last()")
    check("многострочный v:errmsg разбивается на строки буфера",
          rt.eval("(function() for _, line in ipairs(BUF_LINES[1]) do if line:find('\\n', 1, true) then return false end end return true end)()")
          and "second line" in rt.eval("fallback_text()"))
    docs = open(os.path.join(_lua.ROOT, "DOCS.md"), encoding="utf-8").read()
    keys = open(os.path.join(_lua.ROOT, "lua", "config", "keydocs", "g6_missing.lua"), encoding="utf-8").read()
    which = open(os.path.join(_lua.ROOT, "lua", "plugins", "which-key.lua"), encoding="utf-8").read()
    check("все четыре клавиши видны в which-key, справке и документации",
          all(key in text for key in ("<leader>xe", "<leader>xl", "<leader>Hxe", "<leader>Hxg") for text in (docs, keys, which)))
    check("документация различает сеансовую историю, ранние сообщения и диагностику LSP",
          all(text in docs for text in ("только в памяти текущего сеанса", "Ранние ошибки до запуска Noice",
                                       "не** история сбоев Neovim", ":MasonLog", "последние 10 **сообщений**")))
    print(f"\nпроверок: {len(checks)}, провалов: {len(checks) - sum(checks)}")
    return 0 if all(checks) else 1


if __name__ == "__main__":
    sys.exit(main())
