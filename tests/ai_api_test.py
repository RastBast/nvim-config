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
AI.chat({}, {}, done); assert(not text and err:find('curl 7',1,true))
RESPONSE = { code = 28, stdout = '', stderr = 'private-test-key should not leak' }
AI.chat({}, {}, done); assert(not text and err:find('curl 28',1,true) and not err:find('private-test-key',1,true))
vim.env.AI_TIMEOUT = '75'
AI.chat({}, {}, done); assert(ARGS[4] == '75')
vim.env.AI_TIMEOUT = '0'
AI.chat({}, {}, done); assert(ARGS[4] == '40')
vim.env.AI_TIMEOUT = nil
vim.env.AI_PROXY = 'http://user:password@localhost:1080'
AI.chat({}, {}, done)
assert(STDIN:find('proxy =', 1, true) and STDIN:find('password',1,true))
for _,v in ipairs(ARGS) do assert(not tostring(v):find('password',1,true)) end
RESPONSE = { code = 0, stdout = '401', stderr = '' }
vim.fn.has = function() return 0 end
AI.network_check()
assert(NOTES[#NOTES].msg:find('HTTP 401',1,true))
assert(STDIN:find('password',1,true) and not STDIN:find('private-test-key',1,true))
vim.env.AI_PROXY = nil
vim.env.GROQ_API_KEY = 'bad\nkey'
AI.chat({}, {}, done); assert(err:find('перевод строки', 1, true))
vim.env.GROQ_API_KEY = 'private-test-key'


package.preload['codecompanion.adapters'] = function()
  return { extend = function(base, opts) assert(base == 'openai_compatible' or base == 'gemini'); return opts end }
end
local function spec_for(id)
  vim.env.AI_PROVIDER = id
  package.loaded['plugins.ai'] = nil
  return require('plugins.ai')[1].opts()
end
local spec = spec_for('groq')
vim.env.AVANTE_GEMINI_API_KEY = 'scoped'; vim.env.GEMINI_API_KEY = 'regular'
assert(spec.adapters.http.gemini().env.api_key() == 'scoped')
vim.env.AVANTE_GEMINI_API_KEY = nil
assert(spec.adapters.http.gemini().env.api_key() == 'regular')
vim.env.GEMINI_API_KEY = nil
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
local av = require('plugins.avante')[1].opts()
assert(av.provider == 'groq' and av.auto_suggestions_provider == 'groq')
-- Спеки уже импортированы, но выбор до загрузки плагина ещё учитывается.
local av_spec = require('plugins.avante')[1]
local cc_spec = require('plugins.ai')[1]
vim.g.ai_provider = 'openrouter'
vim.env.OPENROUTER_API_KEY = 'another-key'
assert(av_spec.opts().provider == 'openrouter')
assert(cc_spec.opts().interactions.chat.adapter.name == 'openrouter')
vim.g.ai_provider = nil

vim.env.AVANTE_PROVIDER = 'openrouter-free'
package.loaded['plugins.avante'] = nil
av = require('plugins.avante')[1].opts()
assert(av.auto_suggestions_provider == 'openrouter-free')
vim.env.AVANTE_SUGGEST_PROVIDER = 'gemini-flash'
package.loaded['plugins.avante'] = nil
av = require('plugins.avante')[1].opts()
assert(av.auto_suggestions_provider == 'gemini-flash')

-- Проверка защиты от битого шаблона «автор/модель:free» во всех 3 местах (ai_api, avante, CodeCompanion):
vim.env.OPENROUTER_MODEL = 'автор/модель:free'
vim.env.OPENROUTER_API_KEY = 'sk-or-real-key-123'
local resolved_or = AI.resolve('openrouter')
assert(resolved_or and resolved_or.model == 'openrouter/free')
assert(AI.ignored_model_envs.OPENROUTER_MODEL == 'автор/модель:free')
package.loaded['plugins.avante'] = nil
local av_or = require('plugins.avante')[1].opts()
assert(av_or.providers.openrouter.model == 'openrouter/free')
assert(av_or.providers['openrouter-free'].model == 'openrouter/free')
vim.env.OPENROUTER_MODEL = nil

-- Проверка очистки ~/.local/state/nvim/avante/config.json от «автор/модель:free»:
local tmp_state = '/tmp/test_avante_bad_config.json'
local wf = io.open(tmp_state, 'w')
wf:write('{"last_model":"автор/модель:free","last_provider":"openrouter","save_provider":true}')
wf:close()
vim.json.decode = function(raw)
  if raw:find('автор/модель:free', 1, true) then
    return { last_model = 'автор/модель:free', last_provider = 'openrouter', save_provider = true }
  end
  return { choices = { { message = { content = 'Ответ' } } } }
end
vim.json.encode = function(val) SAVED_STATE_TBL = val; return '{"last_model":"' .. tostring(val.last_model) .. '"}' end
assert(AI.sanitize_avante_state_file(tmp_state) == true)
assert(SAVED_STATE_TBL and SAVED_STATE_TBL.last_model == 'openrouter/free')
os.remove(tmp_state)

-- Проверка мгновенного переключения живого чата Avante на прямой Google Gemini (<leader>Ag / :AvanteGemini):
SWITCHED_TO, OVERRIDDEN_SUGGEST, SIDEBAR_OPENED = nil, nil, false
package.loaded['avante.utils.environment'] = { cache = { AVANTE_GEMINI_API_KEY = 'stale' } }
package.loaded['avante.config'] = {
  providers = { gemini = { model = 'gemini-3.6-flash' }, ['gemini-flash'] = { model = 'gemini-3.6-flash' }, openrouter = { model = 'openrouter/free' } },
  override = function(o) OVERRIDDEN_SUGGEST = o.auto_suggestions_provider end,
}
package.loaded['avante.api'] = {
  switch_provider = function(name, save) SWITCHED_TO = { name = name, save = save } end,
}
package.loaded['avante'] = {
  is_sidebar_open = function() return false end,
  open_sidebar = function() SIDEBAR_OPENED = true end,
}
vim.env.AVANTE_GEMINI_API_KEY = nil
vim.env.GEMINI_API_KEY = nil
vim.env.GOOGLE_API_KEY = nil
vim.ui = {
  input = function(_, cb) cb('AIzaDirectGeminiKeyTest123') end,
  select = function() end,
}
AI.use_gemini()
assert(vim.env.AVANTE_GEMINI_API_KEY == 'AIzaDirectGeminiKeyTest123')
assert(SWITCHED_TO and SWITCHED_TO.name == 'gemini' and SWITCHED_TO.save == true)
assert(OVERRIDDEN_SUGGEST == 'gemini-flash')
assert(SIDEBAR_OPENED == true)
assert(next(package.loaded['avante.utils.environment'].cache) == nil)
''')
print('OK: AiAsk, ошибки, ключ через stdin, защита от автор/модель:free и переключение чата Avante на прямой Gemini')
