#!/usr/bin/env python3
"""Проверки ИИ-реестра и конфигурации адаптеров без внешних API."""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
import _lua
rt, _ = _lua.runtime()
with open(os.path.join(_lua.ROOT, 'tests/lua_stubs.lua'), encoding='utf-8') as f:
    rt.execute(f.read())
rt.execute(r'''
vim.fn.executable = function() return 1 end
vim.json = {
 encode = function(value) BODY = value; return 'encoded' end,
 decode = function(text)
   if text == 'success' then return { choices = { { message = { content = 'Ответ' } } } } end
   if text == 'error' then return { error = { message = 'bad key' } } end
   error('invalid json')
 end,
}
vim.list_extend = function(dst, src) for _,v in ipairs(src) do dst[#dst+1]=v end; return dst end
vim.system = function(args, opts, cb) ARGS = args; STDIN = opts.stdin; cb(RESPONSE) end
local AI = require('config.ai_api')
local text, err, provider
local function done(a,b,c) text,err,provider=a,b,c end
AI.chat({}, {}, done)
assert(not text and err:find('ни один'))
vim.env.GROQ_API_KEY = 'private-test-key'
vim.env.AI_PROVIDER = 'groq'
RESPONSE = { code = 0, stdout = 'success\n200', stderr = '' }
AI.chat({{ role='user', content='hello' }}, {}, done)
assert(text == 'Ответ' and err == nil and provider.id == 'groq')
assert(BODY.model == 'openai/gpt-oss-120b')
assert(STDIN:find('private-test-key', 1, true))
for _,v in ipairs(ARGS) do assert(not tostring(v):find('private-test-key', 1, true)) end
RESPONSE = { code = 0, stdout = 'error\n401', stderr = '' }
AI.chat({}, {}, done); assert(not text and err:find('HTTP 401', 1, true))
RESPONSE = { code = 7, stdout = '', stderr = 'cannot connect' }
AI.chat({}, {}, done); assert(not text and err:find('cannot connect',1,true))

package.preload['codecompanion.adapters'] = function()
  return { extend = function(base, opts) assert(base == 'openai_compatible'); return opts end }
end
local function spec_for(id)
  vim.env.AI_PROVIDER = id
  package.loaded['plugins.ai'] = nil
  return require('plugins.ai')[1].opts
end
local spec = spec_for('groq')
local prompt = spec.prompt_library['Explain Code'].prompts[1].content({filetype='go', lines={'a := 1','b := 2'}})
assert(prompt:find('a := 1\nb := 2', 1, true) and not prompt:find('${selected}',1,true))
local adapter = spec.adapters.http.groq()
assert(adapter.env.url .. adapter.env.chat_url == 'https://api.groq.com/openai/v1/chat/completions')
assert(adapter.env.api_key == 'GROQ_API_KEY')
assert(spec.interactions.chat.adapter.name == 'groq')
spec = spec_for('moonshot')
assert(type(spec.interactions.chat.adapter) == 'string' and spec.interactions.chat.adapter == 'kimi')
adapter = spec.adapters.http.kimi()
assert(adapter.env.url .. adapter.env.chat_url == 'https://api.moonshot.ai/v1/chat/completions')
assert(adapter.env.api_key == 'MOONSHOT_API_KEY')
spec = spec_for('openrouter')
adapter = spec.adapters.http.openrouter()
assert(adapter.env.url .. adapter.env.chat_url == 'https://openrouter.ai/api/v1/chat/completions')
assert(adapter.env.api_key == 'OPENROUTER_API_KEY')
vim.env.AI_BASE_URL = 'http://localhost:8080/api/v1/'
spec = spec_for('custom')
adapter = spec.adapters.http.custom()
assert(adapter.env.url .. adapter.env.chat_url == 'http://localhost:8080/api/v1/chat/completions')

vim.fn.has = function() return 1 end
vim.tbl_extend = function(_, a, b) for k,v in pairs(b) do a[k]=v end; return a end
vim.env.AI_PROVIDER = 'groq'; vim.env.AVANTE_PROVIDER = nil; vim.env.AVANTE_SUGGEST_PROVIDER = nil
package.loaded['plugins.avante'] = nil
local av = require('plugins.avante')[1].opts
assert(av.provider == 'groq' and av.auto_suggestions_provider == 'groq')
vim.env.AVANTE_PROVIDER = 'openrouter-free'
package.loaded['plugins.avante'] = nil
av = require('plugins.avante')[1].opts
assert(av.auto_suggestions_provider == 'openrouter-free')
vim.env.AVANTE_SUGGEST_PROVIDER = 'gemini-flash'
package.loaded['plugins.avante'] = nil
av = require('plugins.avante')[1].opts
assert(av.auto_suggestions_provider == 'gemini-flash')
''')
print('OK: AiAsk, ошибки, ключ через stdin, адаптеры и выбор провайдера подсказок')
