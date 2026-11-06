#!/usr/bin/env python3
"""Регистрация Avante-команд не должна зависеть от загрузки или наличия плагина."""
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
      vim.version = function() return {major=0, minor=SUPPORTED and 12 or 11, patch=7} end
      vim.fn.has = function(feature) return feature == 'nvim-0.12' and SUPPORTED and 1 or 0 end
      vim.fn.stdpath = function(name) return '/active/' .. name end
      vim.env.MYVIMRC = '/active/config/init.lua'
      function reset(supported)
        SUPPORTED, CMDS, NOTES, LOADS, STATUSES, REBUILDS = supported, {}, {}, 0, 0, 0
        package.loaded['config.avante_commands'] = nil
        package.loaded['lazy.core.config'] = nil
        package.loaded['lazy'] = {load=function()
          LOADS = LOADS + 1
          if BIND_ON_LOAD then
            require('config.avante_commands').bind(
              function() STATUSES = STATUSES + 1 end,
              function() REBUILDS = REBUILDS + 1 end)
          end
        end}
        BIND_ON_LOAD = false
        COMMANDS = require('config.avante_commands')
        COMMANDS.setup()
      end
      function last() return NOTES[#NOTES] and NOTES[#NOTES].msg or '' end
      function plugin(installed, cond)
        package.loaded['lazy.core.config'] = {
          plugins={['avante.nvim']={dir='/custom/avante', _={installed=installed, cond=cond}}},
        }
      end
    ''')
    checks = []

    def check(label, cond):
        checks.append(bool(cond))
        print(("OK   " if cond else "FAIL ") + label)

    rt.execute("reset(false)")
    check("обе команды созданы до регистрации lazy", rt.eval("CMDS.AvanteStatus ~= nil and CMDS.AvanteRebuild ~= nil"))
    rt.execute("CMDS.AvanteStatus(); CMDS.AvanteRebuild()")
    check("Neovim 0.11: команды не загружают Avante и объясняют ограничение",
          rt.eval("LOADS == 0") and "Neovim 0.12+" in rt.eval("last()"))
    check("диагностика показывает версию, путь активного конфига и init",
          all(s in rt.eval("last()") for s in ("0.11.7", "/active/config", "/active/config/init.lua")))

    rt.execute("reset(true); CMDS.AvanteStatus()")
    check("до lazy: понятная диагностика вместо E492", "не зарегистрирован" in rt.eval("last()") and rt.eval("LOADS") == 0)
    rt.execute("plugin(false, true); CMDS.AvanteRebuild()")
    check("неустановленный плагин не загружается", "не установлен" in rt.eval("last()") and rt.eval("LOADS") == 0)
    check("выведен нестандартный каталог плагина", "/custom/avante/lua/avante_templates.so" in rt.eval("last()"))
    rt.execute("plugin(true, false); CMDS.AvanteStatus()")
    check("cond=false не обходит блокировку", "отключён условием" in rt.eval("last()") and rt.eval("LOADS") == 0)
    rt.execute("package.loaded['lazy.core.config']={plugins={}, spec={disabled={['avante.nvim']={dir='/disabled/avante'}}}}; CMDS.AvanteStatus()")
    check("отключённый lazy-плагин распознан и его нестандартный каталог указан",
          "отключён в lazy.nvim" in rt.eval("last()") and "/disabled/avante" in rt.eval("last()") and rt.eval("LOADS") == 0)
    rt.execute("package.loaded['lazy.core.config']={plugins={}, options={root='/custom/lazy'}}; CMDS.AvanteStatus()")
    check("если плагин отсутствует, учитывается заданный root lazy", "/custom/lazy/avante.nvim" in rt.eval("last()"))
    rt.execute("plugin(true, true); CMDS.AvanteStatus(); CMDS.AvanteRebuild()")
    check("после неудачной загрузки обе команды всё ещё доступны",
          "не удалось настроить" in rt.eval("last()") and rt.eval("LOADS") == 2
          and rt.eval("CMDS.AvanteStatus ~= nil and CMDS.AvanteRebuild ~= nil"))
    rt.execute("BIND_ON_LOAD=true; CMDS.AvanteRebuild(); CMDS.AvanteStatus()")
    check("успешная загрузка делегирует соответствующим runtime-обработчикам",
          rt.eval("LOADS == 3 and REBUILDS == 1 and STATUSES == 1"))
    rt.execute("CMDS.AvanteRebuild(); CMDS.AvanteStatus()")
    check("повторный вызов не загружает плагин заново", rt.eval("LOADS == 3 and REBUILDS == 2 and STATUSES == 2"))
    print(f"\nпроверок: {len(checks)}, провалов: {len(checks) - sum(checks)}")
    return 0 if all(checks) else 1


if __name__ == "__main__":
    sys.exit(main())
