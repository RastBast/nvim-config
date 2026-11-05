#!/usr/bin/env python3
"""Nix LSP: Mason не компилирует nil автоматически, LSP остаётся доступным."""
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
      function contains(t, name)
        for _, v in ipairs(t) do if v == name then return true end end
        return false
      end
      SERVERS = require('config.servers')
      SPEC = dofile(ROOT_PATH .. '/lua/plugins/lsp-config.lua')
      OPTS = SPEC[2].opts()
      ENABLED, CONFIGS, EXISTS, NOTES = {}, {}, false, {}
      vim.lsp = {
        config = function(name, cfg) CONFIGS[name] = cfg end,
        enable = function(names) ENABLED = names end,
        protocol = { make_client_capabilities = function() return {} end },
      }
      vim.fn.executable = function(name) return name == 'nil' and EXISTS and 1 or 0 end
      SPEC[3].config()
      for _, event in ipairs(AUTOCMDS) do
        if event.ev == 'FileType' and event.opts.pattern == 'nix' then NIX_HINT = event.opts end
      end
    ''')
    checks = []

    def check(label, cond):
        checks.append(bool(cond))
        print(("OK   " if cond else "FAIL ") + label)

    check("nil_ls отсутствует в автоматической установке Mason",
          rt.eval("not contains(SERVERS.mason, 'nil_ls') and not contains(OPTS.ensure_installed, 'nil_ls')"))
    check("nil_ls исключён из automatic_enable Mason",
          rt.eval("contains(SERVERS.toolchain, 'nil_ls') and contains(OPTS.automatic_enable.exclude, 'nil_ls')"))
    check("nil_ls настроен и включён для системного бинарника",
          rt.eval("contains(SERVERS.all, 'nil_ls') and contains(ENABLED, 'nil_ls') and CONFIGS.nil_ls ~= nil"))
    check("остальные серверы Mason не исчезли", rt.eval("contains(SERVERS.mason, 'lua_ls') and contains(SERVERS.mason, 'gopls')"))
    check("предупреждение привязано только к первому Nix-файлу", rt.eval("NIX_HINT and NIX_HINT.once == true"))
    rt.execute("NOTES={}; NIX_HINT.callback()")
    check("при отсутствии nil показана команда установки", rt.eval("#NOTES == 1") and "nix profile install" in rt.eval("NOTES[1].msg"))
    rt.execute("NOTES={}; EXISTS=true; NIX_HINT.callback()")
    check("когда nil доступен в PATH, предупреждения нет", rt.eval("#NOTES == 0"))
    docs = open(os.path.join(_lua.ROOT, "DOCS.md"), encoding="utf-8").read()
    check("справка объясняет ручную установку и диагностику Mason",
          "nix profile install nixpkgs#nil" in docs and ":MasonLog" in docs and ":EnvCheck" in docs)
    print(f"\nпроверок: {len(checks)}, провалов: {len(checks) - sum(checks)}")
    return 0 if all(checks) else 1


if __name__ == "__main__":
    sys.exit(main())
