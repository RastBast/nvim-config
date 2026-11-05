#!/usr/bin/env python3
"""Опционально: настоящий Neovim UI + закреплённый Noice, lazy.nvim и Nui.

Нужны NVIM_TEST_BIN и NOICE_TEST_DEPS с noice.nvim, lazy.nvim, nui.nvim,
nvim-notify, а также pynvim. Проверяет клавиши, native emsg, уведомления ERROR,
отсутствие WARN/LSP-диагностики, последние 10 и полный журнал за сеанс.
"""
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402


def main():
    nvim = os.environ.get("NVIM_TEST_BIN") or shutil.which("nvim")
    deps = os.environ.get("NOICE_TEST_DEPS")
    try:
        import pynvim  # noqa: PLC0415
    except ImportError:
        print("SKIP: нужна библиотека pynvim")
        return 0
    names = ("noice.nvim", "lazy.nvim", "nui.nvim", "nvim-notify")
    if not nvim or not deps or not all(os.path.isdir(os.path.join(deps, name)) for name in names):
        print("SKIP: нужны NVIM_TEST_BIN и NOICE_TEST_DEPS с Noice/lazy/Nui/notify")
        return 0

    with tempfile.TemporaryDirectory(prefix="noice-ui-") as tmp:
        old_env = os.environ.copy()
        try:
            for key, name in (("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"),
                              ("XDG_CACHE_HOME", "cache"), ("XDG_STATE_HOME", "state")):
                os.environ[key] = os.path.join(tmp, name)
            os.environ["NOICE_TEST_ROOT"] = _lua.ROOT
            os.environ["NOICE_TEST_TMP"] = tmp
            child = pynvim.attach("child", argv=[nvim, "--embed", "--headless", "-u", "NONE", "-i", "NONE"])
            try:
                child.ui_attach(120, 40, rgb=True)
                child.exec_lua('''
                  vim.opt.rtp:prepend(vim.env.NOICE_TEST_ROOT)
                  vim.opt.rtp:prepend(vim.env.NOICE_TEST_DEPS .. '/lazy.nvim')
                  vim.go.loadplugins = true
                  vim.g.mapleader = ' '
                  vim.cmd('set nomore')
                  local spec = dofile(vim.env.NOICE_TEST_ROOT .. '/lua/plugins/noice.lua')[1]
                  spec.dir, spec.name = vim.env.NOICE_TEST_DEPS .. '/noice.nvim', 'noice.nvim'
                  spec.event = nil -- проверить загрузку непосредственно по клавише
                  spec.dependencies = {
                    {dir=vim.env.NOICE_TEST_DEPS .. '/nui.nvim', name='nui.nvim'},
                    {dir=vim.env.NOICE_TEST_DEPS .. '/nvim-notify', name='nvim-notify'},
                  }
                  local specs = {spec}
                  if vim.fn.isdirectory(vim.env.NOICE_TEST_DEPS .. '/which-key.nvim') == 1 then
                    local which = dofile(vim.env.NOICE_TEST_ROOT .. '/lua/plugins/which-key.lua')[1]
                    which.dir, which.name, which.event, which.lazy = vim.env.NOICE_TEST_DEPS .. '/which-key.nvim', 'which-key.nvim', nil, false
                    table.insert(specs, which)
                  end
                  require('lazy').setup(specs, {
                    root=vim.env.NOICE_TEST_TMP .. '/lazy', lockfile=vim.env.NOICE_TEST_TMP .. '/lock.json',
                    install={missing=false}, checker={enabled=false}, change_detection={enabled=false},
                    performance={rtp={reset=false}},
                  })
                ''')
                assert child.exec_lua("return vim.fn.maparg('<leader>xe', 'n') ~= ''")
                child.input(" xe")
                assert child.exec_lua("return vim.wait(3000, function() return package.loaded['noice.config'] and require('noice.config').is_running() end, 10)"), "Noice не загрузился по клавише"
                child.exec_lua("vim.wait(150)")
                # Добавляем и ошибки интерфейса Neovim, и error-уведомления;
                # диагностика языка должна оставаться в Trouble, не в журнале.
                child.exec_lua('''
                  for i=1,12 do vim.notify('notify error #' .. i .. '#', vim.log.levels.ERROR) end
                  vim.notify('warning marker', vim.log.levels.WARN)
                  vim.api.nvim_err_writeln('native error marker')
                  local ns = vim.api.nvim_create_namespace('test_lsp')
                  vim.diagnostic.set(ns, 0, {{lnum=0, col=0, message='LSP diagnostic marker', severity=vim.diagnostic.severity.ERROR}})
                  vim.wait(200)
                ''')
                child.input(" xe")
                child.exec_lua("vim.wait(400)")
                last = "\n".join(child.current.buffer[:])
                assert child.current.buffer.options["filetype"] == "noice", "последние ошибки не открылись"
                assert "native error marker" in last and "notify error #4#" in last and "notify error #12#" in last, last
                assert "notify error #3#" not in last and "notify error #1#" not in last, last
                assert "warning marker" not in last and "LSP diagnostic marker" not in last, last
                assert len(child.current.buffer[:]) == 10, last
                print("OK   UI Neovim: <leader>xe показывает последние 10 native/notify ERROR, без WARN и LSP")
                child.input("q")
                child.exec_lua("vim.wait(100)")
                child.input(" xl")
                child.exec_lua("vim.wait(400)")
                log = "\n".join(child.current.buffer[:])
                assert child.current.buffer.options["filetype"] == "noice", "журнал не открылся"
                assert "notify error #1#" in log and "notify error #12#" in log and "native error marker" in log, log
                assert "warning marker" not in log and "LSP diagnostic marker" not in log, log
                assert len(child.current.buffer[:]) >= 13, log
                print("OK   UI Neovim: <leader>xl показывает весь журнал ошибок этого сеанса")
            finally:
                try:
                    child.command("qa!")
                except Exception:
                    pass
        finally:
            os.environ.clear()
            os.environ.update(old_env)
    return 0


if __name__ == "__main__":
    sys.exit(main())
