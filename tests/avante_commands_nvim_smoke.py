#!/usr/bin/env python3
"""Команды Avante до lazy, с отключённым, отсутствующим и сломанным плагином.

Можно запустить на Neovim 0.11 и 0.12: нужны NVIM_TEST_BIN и AVANTE_TEST_LAZY.
Временный плагин не содержит код Avante и не обращается к сети.
"""
import os
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402

SCRIPT = r'''
vim.opt.rtp:prepend(vim.env.TEST_CONFIG)
vim.opt.rtp:prepend(vim.env.TEST_LAZY)
vim.go.loadplugins = true
local notes = {}
vim.api.nvim_echo = function(chunks)
  for _, chunk in ipairs(chunks) do notes[#notes + 1] = tostring(chunk[1]) end
end
vim.notify = function(msg) notes[#notes + 1] = tostring(msg) end
local function contains(s)
  for _, note in ipairs(notes) do if note:find(s, 1, true) then return true end end
  return false
end
local commands = require('config.avante_commands')
commands.setup()
assert(vim.fn.exists(':AvanteStatus') == 2 and vim.fn.exists(':AvanteRebuild') == 2)
vim.cmd.AvanteStatus()
local supported = vim.fn.has('nvim-0.12') == 1
assert(contains(supported and 'не зарегистрирован в lazy.nvim' or 'нужен Neovim 0.12+'), 'ранняя диагностика')

local spec = dofile(vim.env.TEST_CONFIG .. '/lua/plugins/avante.lua')[1]
spec.name, spec.dir, spec.dependencies = 'avante.nvim', vim.env.TEST_PLUGIN, {}
if vim.env.TEST_CASE == 'disabled' then spec.cond = false end
spec.config = function()
  if vim.env.TEST_CASE == 'broken' then error('synthetic plugin config failure') end
  commands.bind(function() vim.g.test_status = (vim.g.test_status or 0) + 1 end,
                function() vim.g.test_rebuild = (vim.g.test_rebuild or 0) + 1 end)
end
require('lazy').setup({spec}, {
  root=vim.env.TEST_TMP .. '/lazy', lockfile=vim.env.TEST_TMP .. '/lock.json',
  install={missing=false}, checker={enabled=false}, change_detection={enabled=false},
  performance={rtp={reset=false}},
})
assert(vim.fn.exists(':AvanteStatus') == 2 and vim.fn.exists(':AvanteRebuild') == 2, 'lazy удалил команды')
notes = {}
vim.cmd.AvanteStatus()
vim.cmd.AvanteRebuild()
assert(vim.fn.exists(':AvanteStatus') == 2 and vim.fn.exists(':AvanteRebuild') == 2, 'команды исчезли после вызова')
if not supported then
  assert(contains('нужен Neovim 0.12+'), 'нет пояснения о версии')
  assert(contains(vim.env.TEST_PLUGIN), 'не указан каталог отключённого плагина')
  assert(not vim.g.test_plugin_loaded and not vim.g.test_status and not vim.g.test_rebuild, 'Avante загружен на 0.11')
elseif vim.env.TEST_CASE == 'disabled' then
  assert(contains('отключён в lazy.nvim') and contains(vim.env.TEST_PLUGIN), 'нет пояснения об отключённом плагине')
  assert(not vim.g.test_plugin_loaded, 'загружен отключённый плагин')
elseif vim.env.TEST_CASE == 'missing' then
  assert(contains('не установлен'), 'нет пояснения об отсутствующем плагине')
  assert(not vim.g.test_plugin_loaded, 'загружен несуществующий плагин')
elseif vim.env.TEST_CASE == 'broken' then
  assert(contains('не удалось настроить'), 'нет пояснения об ошибке плагина')
  assert(not vim.g.test_status and not vim.g.test_rebuild, 'вызван неверный обработчик')
  vim.cmd.AvanteStatus()
  assert(vim.fn.exists(':AvanteStatus') == 2, 'команда пропала после второй ошибки')
else
  assert(vim.g.test_plugin_loaded and vim.g.test_status == 1 and vim.g.test_rebuild == 1, 'нет делегирования runtime')
  vim.cmd.AvanteStatus()
  assert(vim.g.test_status == 2, 'нет повторного делегирования')
end
print('OK   bootstrap Avante / ' .. vim.env.TEST_CASE .. ' / ' .. tostring(vim.version().minor))
vim.cmd('qa!')
'''


def main():
    nvim = os.environ.get("NVIM_TEST_BIN") or shutil.which("nvim")
    lazy = os.environ.get("AVANTE_TEST_LAZY")
    if not nvim or not lazy or not os.path.isdir(lazy):
        print("SKIP: нужны NVIM_TEST_BIN и AVANTE_TEST_LAZY")
        return 0
    with tempfile.TemporaryDirectory(prefix="avante-commands-") as tmp:
        plugin = os.path.join(tmp, "avante.nvim")
        os.makedirs(os.path.join(plugin, "plugin"))
        with open(os.path.join(plugin, "plugin", "stub.lua"), "w", encoding="utf-8") as fh:
            fh.write("vim.g.test_plugin_loaded = true\n")
        script = os.path.join(tmp, "smoke.lua")
        with open(script, "w", encoding="utf-8") as fh:
            fh.write(SCRIPT)
        for case in ("ready", "missing", "disabled", "broken"):
            env = os.environ.copy()
            env.update({
                "TEST_CONFIG": _lua.ROOT, "TEST_LAZY": lazy, "TEST_TMP": tmp,
                "TEST_PLUGIN": os.path.join(tmp, "not-installed") if case == "missing" else plugin,
                "TEST_CASE": case,
                "XDG_CONFIG_HOME": os.path.join(tmp, "config"),
                "XDG_DATA_HOME": os.path.join(tmp, "data"),
                "XDG_CACHE_HOME": os.path.join(tmp, "cache"),
                "XDG_STATE_HOME": os.path.join(tmp, "state"),
            })
            result = subprocess.run([nvim, "--headless", "-u", "NONE", "-l", script], env=env,
                                    capture_output=True, text=True, timeout=40)
            output = result.stdout + result.stderr
            print(output.strip())
            if result.returncode != 0 or "OK   bootstrap Avante" not in output:
                return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
