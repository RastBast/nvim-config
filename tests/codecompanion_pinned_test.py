#!/usr/bin/env python3
"""Необязательная проверка адаптеров на реальных Lua-модулях CodeCompanion из lockfile.

CC_SOURCE=/путь/к/codecompanion.nvim PYTHONPATH=... python3 tests/codecompanion_pinned_test.py
Зависимости Neovim и сети здесь заменены заглушками; полноценный запуск чата не проверяется.
"""
import os
import subprocess
import sys
sys.path.insert(0, os.path.dirname(__file__))
import _lua
source = os.environ.get('CC_SOURCE')
if not source:
    print('SKIP: задайте CC_SOURCE на checkout CodeCompanion из lazy-lock.json')
    sys.exit(0)
import json
with open(os.path.join(_lua.ROOT, 'lazy-lock.json'), encoding='utf-8') as f:
    expected = json.load(f)['codecompanion.nvim']['commit']
actual = subprocess.check_output(['git', '-C', source, 'rev-parse', 'HEAD'], text=True).strip()
assert actual == expected, f'ожидается {expected}, получено {actual}'
rt, _ = _lua.runtime()
rt.globals().CC_SOURCE = source
with open(os.path.join(_lua.ROOT, 'tests/lua_stubs.lua'), encoding='utf-8') as f:
    rt.execute(f.read())
rt.execute(r'''
package.path = CC_SOURCE .. '/lua/?.lua;' .. CC_SOURCE .. '/lua/?/init.lua;' .. package.path
local function copy(t)
 if type(t) ~= 'table' then return t end
 local out = {}; for k,v in pairs(t) do out[k] = copy(v) end; return out
end
vim.deepcopy = copy
vim.tbl_deep_extend = function(_, ...)
 local out = {}
 local function merge(dst, src)
  for k,v in pairs(src) do
   if type(v)=='table' then
    if type(dst[k])~='table' then dst[k]={} end
    merge(dst[k],v)
   else dst[k]=v end
  end
 end
 for _,t in ipairs({...}) do merge(out,t) end
 return out
end
vim.fn.tempname = function() return '/tmp/cc-models' end
local log = setmetatable({}, { __index = function(_, key) return function(_, ...) if key == 'error' then error('adapter error') end end end })
package.preload['codecompanion.utils.log'] = function() return log end
package.preload['codecompanion.utils.adapters'] = function() return {} end
package.preload['plenary.curl'] = function() return {} end
package.preload['codecompanion.adapters.http.openai'] = function() return {handlers={tools={}}} end
local cfg = {adapters={http={}, acp={}}, interactions={chat={}}}
package.preload['codecompanion.config'] = function() return cfg end
vim.env.AI_PROVIDER = 'openrouter'
vim.env.OPENROUTER_API_KEY = 'dummy'
local opts = require('plugins.ai')[1].opts
cfg.adapters.http = opts.adapters.http
cfg.interactions.chat = opts.interactions.chat
local engine = require('codecompanion.adapters')
for _, id in ipairs({'groq', 'kimi', 'openrouter', 'custom'}) do
 local adapter = engine.resolve(id)
 assert(adapter and adapter.name == id and adapter.model.name ~= nil, id)
 assert(adapter.url == '${url}${chat_url}', id)
 assert(adapter.env.chat_url == '/chat/completions', id)
 assert(type(adapter.handlers.chat_output) == 'function', id)
end
local adapter = engine.resolve(opts.interactions.chat.adapter)
assert(adapter.name == 'openrouter' and adapter.model.name == 'openrouter/free')
''')
print('OK: разрешение четырёх адаптеров реальным кодом CodeCompanion из lockfile')
