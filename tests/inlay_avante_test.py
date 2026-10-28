#!/usr/bin/env python3
"""Поведение inlay и безопасная инициализация avante без сети и Neovim."""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
import _lua

rt, _ = _lua.runtime()
with open(os.path.join(_lua.ROOT, 'tests/lua_stubs.lua'), encoding='utf-8') as f:
    rt.execute(f.read())
rt.execute(r'''
current = 1
state = {}
default = true
vim.api.nvim_get_current_buf = function() return current end
vim.lsp = { inlay_hint = {
  enable = function(on, opts)
    if opts then state[opts.bufnr] = on else default = on end
  end,
  is_enabled = function(opts)
    if state[opts.bufnr] == nil then return default end
    return state[opts.bufnr]
  end,
} }
local hints = require('config.inlay')
hints.setup()
assert(default == false)
assert(KEYS[#KEYS].lhs == '<leader>uh')
hints.toggle(); assert(state[1] == true)
current = 2; assert(vim.lsp.inlay_hint.is_enabled({bufnr=2}) == false)
hints.toggle(); assert(state[2] == true)
current = 1; hints.toggle(); assert(state[1] == false and state[2] == true)
vim.lsp.inlay_hint = nil; hints.toggle(); assert(#NOTES > 0)

vim.tbl_extend = function(_, a, b) for k,v in pairs(b) do a[k]=v end; return a end
vim.fn.has = function() return 1 end
vim.fn.isdirectory = function() return 1 end
vim.fn.delete = function() EXISTS = false end
vim.schedule = function(f) QUEUE[#QUEUE+1] = f end
QUEUE = {}
EXISTS, LOADABLE, SETUPS, ASKS, BUILDS = false, false, 0, 0, 0
package.preload['config.ai_api'] = function() return {
  avante_default = function() return 'gemini' end,
  avante_providers = function() return {} end,
} end
package.preload['config.avante_build'] = function() return {
  TAG = 'v0.4.8',
  is_built = function() return EXISTS end,
  lib_file = function() return '/plugin/lua/avante_templates.so' end,
  build = function(_, cb, force) BUILDS = BUILDS + 1; CALLBACK = cb end,
} end
package.loadlib = function() if LOADABLE then return function() end end; return nil, 'wrong architecture' end
package.preload['avante_templates'] = function() return {} end
package.preload['avante'] = function() return { setup = function() SETUPS = SETUPS + 1 end } end
package.preload['avante.api'] = function() return { ask = function() ASKS = ASKS + 1 end } end
local spec = require('plugins.avante')[1]
spec.config({dir='/plugin'}, {})
assert(SETUPS == 0 and #QUEUE == 1 and CMDS.AvanteRebuild)
require('avante.api').ask(); assert(ASKS == 0)
QUEUE[1](); assert(BUILDS == 1)
CMDS.AvanteRebuild(); assert(BUILDS == 1) -- защита от параллельной сборки
EXISTS = true; LOADABLE = true; CALLBACK(true, 'ok')
assert(SETUPS == 1)
require('avante.api').ask(); assert(ASKS == 1)
CMDS.AvanteRebuild(); assert(BUILDS == 2)
CALLBACK(true, 'ok'); assert(SETUPS == 1)
''')
print('OK: inlay по буферам, защита avante до сборки, retry и настройка один раз')
