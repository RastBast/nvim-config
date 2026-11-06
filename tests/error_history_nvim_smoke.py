#!/usr/bin/env python3
"""Настоящий Neovim UI: команды до Noice, fallback, два меню и фильтр Noice.

Нужны NVIM_TEST_BIN и NOICE_TEST_DEPS с noice.nvim, lazy.nvim, nui.nvim,
nvim-notify, which-key.nvim, а также pynvim. Можно запускать на 0.11 и 0.12.
"""
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402


def close_child(child):
    try:
        child.command("qa!")
    except Exception:
        pass


def wait(child, ms=250):
    child.exec_lua(f"vim.wait({ms})")


def text(child):
    return "\n".join(child.current.buffer[:])


def close_window(child):
    child.input("q")
    wait(child, 100)


def fallback_scenario(pynvim, nvim):
    child = pynvim.attach("child", argv=[nvim, "--embed", "--headless", "-u", "NONE", "-i", "NONE"])
    try:
        child.ui_attach(120, 40, rgb=True)
        child.exec_lua('''
          vim.opt.rtp:prepend(vim.env.NOICE_TEST_ROOT)
          vim.g.mapleader = ' '
          vim.cmd('set nomore')
          require('config.error_history').setup()
          for i=1,12 do vim.cmd('echom "early marker #' .. i .. '#"') end
          vim.v.errmsg = 'E999: last native marker\\ntraceback marker'
        ''')
        assert child.exec_lua("return vim.fn.exists(':ErrorLast10') == 2 and vim.fn.exists(':ErrorLog') == 2")
        assert not child.exec_lua("return package.loaded.noice ~= nil"), "Noice присутствует в тесте fallback"
        for seq, recent in ((" xe", True), (" xl", False), (" Hxe", True), (" Hxg", False)):
            child.input(seq)
            wait(child)
            out = text(child)
            assert child.current.buffer.options["buftype"] == "nofile", f"нет запасного окна для {seq}: {out}"
            assert "Noice недоступен" in out and "E999: last native marker" in out and "traceback marker" in out, out
            assert "early marker #12#" in out and "могут быть и другие сообщения" in out, out
            assert ("early marker #1#" not in out) if recent else ("early marker #1#" in out), out
            close_window(child)
        # Команды тоже работают, даже когда ни lazy, ни Noice не установлены.
        child.command("ErrorLog")
        assert "early marker #1#" in text(child)
        close_window(child)
        print("OK   UI Neovim: все клавиши и команды до lazy, без Noice: честный fallback с :messages")
    finally:
        close_child(child)


def which_menu(child, prefix):
    child.input(prefix)
    wait(child, 800)
    return child.exec_lua('''
      local view = require('which-key.view').view
      if not view or not view:valid() then return '' end
      return table.concat(vim.api.nvim_buf_get_lines(view.buf, 0, -1, false), '\\n')
    ''')


def noice_scenario(pynvim, nvim):
    child = pynvim.attach("child", argv=[nvim, "--embed", "--headless", "-u", "NONE", "-i", "NONE"])
    try:
        child.ui_attach(120, 40, rgb=True)
        child.exec_lua('''
          vim.opt.rtp:prepend(vim.env.NOICE_TEST_ROOT)
          vim.opt.rtp:prepend(vim.env.NOICE_TEST_DEPS .. '/lazy.nvim')
          vim.go.loadplugins = true
          vim.g.mapleader = ' '
          vim.o.timeoutlen = 300
          vim.cmd('set nomore')
          require('config.error_history').setup()
          -- Сообщение до загрузки Noice остаётся в :messages, но не всегда
          -- имеет отдельный уровень error в истории самого Noice.
          vim.cmd('echom "before VeryLazy marker"')
          local spec = dofile(vim.env.NOICE_TEST_ROOT .. '/lua/plugins/noice.lua')[1]
          spec.dir, spec.name = vim.env.NOICE_TEST_DEPS .. '/noice.nvim', 'noice.nvim'
          spec.dependencies = {
            {dir=vim.env.NOICE_TEST_DEPS .. '/nui.nvim', name='nui.nvim'},
            {dir=vim.env.NOICE_TEST_DEPS .. '/nvim-notify', name='nvim-notify'},
          }
          local which = dofile(vim.env.NOICE_TEST_ROOT .. '/lua/plugins/which-key.lua')[1]
          which.dir, which.name, which.event, which.lazy = vim.env.NOICE_TEST_DEPS .. '/which-key.nvim', 'which-key.nvim', nil, false
          require('lazy').setup({spec, which}, {
            root=vim.env.NOICE_TEST_TMP .. '/lazy', lockfile=vim.env.NOICE_TEST_TMP .. '/lock.json',
            install={missing=false}, checker={enabled=false}, change_detection={enabled=false},
            performance={rtp={reset=false}},
          })
          assert(not package.loaded['noice.config'], 'Noice загружен до проверки')
          assert(not vim.g.did_very_lazy, 'VeryLazy сработал до ранней клавиши')
          -- Тот же реальный mapping, но до возврата в event loop, где lazy
          -- мог бы уже успеть отправить событие VeryLazy.
          local keys = vim.api.nvim_replace_termcodes('<Space>xe', true, false, true)
          vim.api.nvim_feedkeys(keys, 'xt', false)
          assert(package.loaded['noice.config'], 'ранняя клавиша не загрузила Noice')
        ''')
        for key in ("xe", "xl", "Hxe", "Hxg"):
            assert child.exec_lua("return vim.fn.maparg(' ' .. ..., 'n') ~= ''", key), key
        assert child.exec_lua("return vim.wait(3000, function() return package.loaded['noice.config'] and require('noice.config').is_running() end, 10)"), "Noice не загрузился по ранней клавише"
        wait(child, 250)
        early = text(child)
        assert "запасной режим" in early and "before VeryLazy marker" in early, early
        close_window(child)
        print("OK   UI Neovim: ранний <leader>xe загружает Noice и показывает ранние сообщения")

        # Реальный which-key, не только проверка maparg или деклараций в Lua.
        for prefix in (" x", " Hx"):
            menu = which_menu(child, prefix)
            assert "Последние 10 ошибок Neovim" in menu and "Журнал ошибок Neovim" in menu, (prefix, menu)
            child.input("\x1b")
            wait(child, 150)
        print("OK   which-key: оба действия видны в меню <leader>x и <leader>Hx")

        child.exec_lua('''
          for i=1,12 do vim.notify('notify error #' .. i .. '#', vim.log.levels.ERROR) end
          vim.notify('warning marker', vim.log.levels.WARN)
          vim.api.nvim_err_writeln('native error marker')
          local ns = vim.api.nvim_create_namespace('test_lsp')
          vim.diagnostic.set(ns, 0, {{lnum=0, col=0, message='LSP diagnostic marker', severity=vim.diagnostic.severity.ERROR}})
          vim.wait(200)
        ''')
        for seq in (" xe", " Hxe"):
            child.input(seq)
            wait(child, 400)
            last = text(child)
            assert child.current.buffer.options["filetype"] == "noice", f"последние ошибки не открылись {seq}: {last}"
            assert "native error marker" in last and "notify error #4#" in last and "notify error #12#" in last, last
            assert "notify error #3#" not in last and "notify error #1#" not in last, last
            assert "warning marker" not in last and "LSP diagnostic marker" not in last, last
            assert len(child.current.buffer[:]) == 10, last
            close_window(child)
        print("OK   UI Neovim: оба пути показывают последние 10 native/notify ERROR, без WARN и LSP")
        for seq in (" xl", " Hxg"):
            child.input(seq)
            wait(child, 400)
            log = text(child)
            assert child.current.buffer.options["filetype"] == "noice", f"журнал не открылся {seq}: {log}"
            assert "notify error #1#" in log and "notify error #12#" in log and "native error marker" in log, log
            assert "warning marker" not in log and "LSP diagnostic marker" not in log, log
            assert len(child.current.buffer[:]) >= 13, log
            close_window(child)
        print("OK   UI Neovim: оба пути показывают журнал Noice текущего сеанса")

        child.command("Noice disable")
        wait(child, 100)
        child.exec_lua("vim.cmd('echom \"after Noice disabled marker\"')")
        child.input(" Hxg")
        wait(child, 300)
        disabled = text(child)
        assert "Noice не запущен" in disabled and "after Noice disabled marker" in disabled, disabled
        close_window(child)
        print("OK   UI Neovim: после отключения Noice клавиша открывает :messages")
    finally:
        close_child(child)


def startup_scenario(pynvim, nvim, tmp, deps):
    """Запускаем настоящий init.lua с ограниченным набором настоящих плагинов."""
    lazy_home = os.path.join(tmp, "data", "nvim", "lazy")
    os.makedirs(lazy_home, exist_ok=True)
    lazy_link = os.path.join(lazy_home, "lazy.nvim")
    if not os.path.exists(lazy_link):
        os.symlink(os.path.join(deps, "lazy.nvim"), lazy_link)
    preinit = os.path.join(tmp, "preinit.lua")
    with open(preinit, "w", encoding="utf-8") as fh:
        fh.write(r'''
          vim.opt.rtp:prepend(vim.env.NOICE_TEST_ROOT)
          vim.opt.rtp:prepend(vim.env.NOICE_TEST_DEPS .. '/lazy.nvim')
          -- Отключаем только сетевые таймеры/внешние приложения, не клавиши.
          package.loaded['config.hud'] = {setup=function() end}
          package.loaded['config.streak'] = {setup=function() end}
          package.loaded['config.telegram'] = {setup=function() end}
          package.preload['lazy'] = function()
            local lazy = dofile(vim.env.NOICE_TEST_DEPS .. '/lazy.nvim/lua/lazy/init.lua')
            local original = lazy.setup
            lazy.setup = function(_, opts)
              assert(vim.fn.exists(':AvanteStatus') == 2 and vim.fn.exists(':AvanteRebuild') == 2)
              assert(vim.fn.exists(':ErrorLast10') == 2 and vim.fn.maparg(' xe', 'n') ~= '')
              vim.g.early_bootstrap_checked = true
              local noice = dofile(vim.env.NOICE_TEST_ROOT .. '/lua/plugins/noice.lua')[1]
              noice.dir, noice.name = vim.env.NOICE_TEST_DEPS .. '/noice.nvim', 'noice.nvim'
              noice.dependencies = {
                {dir=vim.env.NOICE_TEST_DEPS .. '/nui.nvim', name='nui.nvim'},
                {dir=vim.env.NOICE_TEST_DEPS .. '/nvim-notify', name='nvim-notify'},
              }
              local which = dofile(vim.env.NOICE_TEST_ROOT .. '/lua/plugins/which-key.lua')[1]
              which.dir, which.name = vim.env.NOICE_TEST_DEPS .. '/which-key.nvim', 'which-key.nvim'
              local avante = dofile(vim.env.NOICE_TEST_ROOT .. '/lua/plugins/avante.lua')[1]
              avante.dir, avante.name, avante.dependencies = vim.env.NOICE_TEST_TMP .. '/missing-avante', 'avante.nvim', {}
              opts.root = vim.env.NOICE_TEST_TMP .. '/startup-lazy'
              opts.lockfile = vim.env.NOICE_TEST_TMP .. '/startup-lock.json'
              opts.install.missing = false
              opts.performance.rtp.reset = false
              return original({noice, which, avante}, opts)
            end
            return lazy
          end
        ''')
    child = pynvim.attach("child", argv=[nvim, "--embed", "--headless", "--cmd", "luafile " + preinit,
                                          "-u", os.path.join(_lua.ROOT, "init.lua"), "-i", "NONE"])
    try:
        child.ui_attach(120, 40, rgb=True)
        wait(child, 800)
        assert child.exec_lua("return vim.g.early_bootstrap_checked == true"), "ранняя регистрация не дошла до lazy.setup"
        assert child.exec_lua("return vim.fn.exists(':Tui') == 2"), "полный init.lua не дошёл до конца настроек"
        assert child.exec_lua("return vim.fn.exists(':AvanteStatus') == 2 and vim.fn.exists(':AvanteRebuild') == 2")
        status = child.exec_lua('''
          local old, messages = vim.api.nvim_echo, {}
          vim.api.nvim_echo = function(chunks)
            for _, chunk in ipairs(chunks) do messages[#messages + 1] = chunk[1] end
          end
          vim.cmd.AvanteStatus()
          vim.cmd.AvanteRebuild()
          vim.api.nvim_echo = old
          return table.concat(messages, '\\n')
        ''')
        assert "нужен Neovim 0.12+" in status or "не установлен" in status, status
        assert not child.exec_lua("return package.loaded.avante ~= nil"), "отключённый/отсутствующий Avante загрузился"
        for key, target in (("xe", "ErrorLast10"), ("Hxe", "ErrorLast10"), ("xl", "ErrorLog"), ("Hxg", "ErrorLog")):
            mapping = child.exec_lua("return vim.fn.maparg(' ' .. ..., 'n', false, true)", key)
            assert target in mapping.get("rhs", ""), (key, mapping)
        assert child.exec_lua("return package.loaded['which-key'] ~= nil"), "which-key не загрузился после VeryLazy"
        for prefix in (" x", " Hx"):
            menu = which_menu(child, prefix)
            assert "Последние 10 ошибок Neovim" in menu and "Журнал ошибок Neovim" in menu, (prefix, menu)
            child.input("\x1b")
            wait(child, 150)
        child.exec_lua("vim.api.nvim_err_writeln('full init error marker'); vim.wait(200)")
        child.input(" Hxe")
        wait(child, 400)
        assert "full init error marker" in text(child), text(child)
        close_window(child)
        print("OK   настоящий init.lua с ограниченным набором плагинов: ранние команды, оба меню и просмотр ошибки")
    finally:
        close_child(child)


def main():
    nvim = os.environ.get("NVIM_TEST_BIN") or shutil.which("nvim")
    deps = os.environ.get("NOICE_TEST_DEPS")
    try:
        import pynvim  # noqa: PLC0415
    except ImportError:
        print("SKIP: нужна библиотека pynvim")
        return 0
    names = ("noice.nvim", "lazy.nvim", "nui.nvim", "nvim-notify", "which-key.nvim")
    if not nvim or not deps or not all(os.path.isdir(os.path.join(deps, name)) for name in names):
        print("SKIP: нужны NVIM_TEST_BIN и NOICE_TEST_DEPS с Noice/lazy/Nui/notify/which-key")
        return 0
    with tempfile.TemporaryDirectory(prefix="noice-ui-") as tmp:
        old_env = os.environ.copy()
        try:
            for key, name in (("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"),
                              ("XDG_CACHE_HOME", "cache"), ("XDG_STATE_HOME", "state")):
                os.environ[key] = os.path.join(tmp, name)
            os.environ["NOICE_TEST_ROOT"] = _lua.ROOT
            os.environ["NOICE_TEST_TMP"] = tmp
            fallback_scenario(pynvim, nvim)
            noice_scenario(pynvim, nvim)
            startup_scenario(pynvim, nvim, tmp, deps)
        finally:
            os.environ.clear()
            os.environ.update(old_env)
    return 0


if __name__ == "__main__":
    sys.exit(main())
