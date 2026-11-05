#!/usr/bin/env python3
"""Проверка формы настроек Noice и классификации Nix LSP."""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
import _lua
rt, _ = _lua.runtime()
with open(os.path.join(_lua.ROOT, 'tests/lua_stubs.lua'), encoding='utf-8') as f:
    rt.execute(f.read())
rt.execute(r'''
package.preload['noice'] = function() return { setup = function(opts) OPTIONS = opts end } end
require('plugins.noice')[1].config()
assert(OPTIONS.lsp.override['cmp.entry.get_documentation'] == false)
assert(OPTIONS.lsp.override['vim.lsp.util.stylize_markdown'] == true)
local servers = require('config.servers')
local function has(t, name) for _, v in ipairs(t) do if v == name then return true end end return false end
assert(not has(servers.mason, 'nil_ls'))
assert(has(servers.all, 'nil_ls'))
assert(has(servers.toolchain, 'nil_ls'))
assert(has(servers.mason, 'gopls'))
local mason_opts = require('plugins.lsp-config')[2].opts()
assert(not has(mason_opts.ensure_installed, 'nil_ls'))
assert(has(mason_opts.automatic_enable.exclude, 'nil_ls'))
''')
print('OK: Noice использует boolean false; Nix LSP остаётся доступным без автоустановки Mason')
