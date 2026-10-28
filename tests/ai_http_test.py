#!/usr/bin/env python3
"""Реальный curl -> локальный фальшивый OpenAI API; не использует ключи/внешний сервис."""
import json
import os
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
sys.path.insert(0, os.path.dirname(__file__))
import _lua

requests_seen = []
class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers['Content-Length']))
        requests_seen.append((self.path, self.headers.get('Authorization'), json.loads(body)))
        status = 401 if self.path.startswith('/unauthorized/') else 200
        payload = {'error': {'message': 'denied'}} if status == 401 else {'choices': [{'message': {'content': 'local answer'}}]}
        raw = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)
    def log_message(self, *_):
        pass

server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    rt, _ = _lua.runtime()
    with open(os.path.join(_lua.ROOT, 'tests/lua_stubs.lua'), encoding='utf-8') as f:
        rt.execute(f.read())
    def from_lua(value):
        if not hasattr(value, 'items'):
            return value
        items = list(value.items())
        if items and all(isinstance(k, int) for k, _ in items) and sorted(k for k, _ in items) == list(range(1, len(items)+1)):
            return [from_lua(value[i]) for i in range(1, len(items)+1)]
        return {k: from_lua(v) for k, v in items}
    def to_lua(value):
        if isinstance(value, dict):
            return rt.table_from({k: to_lua(v) for k, v in value.items()})
        if isinstance(value, list):
            return rt.table_from([to_lua(v) for v in value])
        return value
    def run_system(args, opts, callback):
        command = [args[i] for i in range(1, len(args)+1)]
        proc = subprocess.run(command, input=opts['stdin'], capture_output=True, text=True, timeout=10)
        callback(rt.table_from({'code': proc.returncode, 'stdout': proc.stdout, 'stderr': proc.stderr}))
    rt.globals().PY_ENCODE = lambda obj: json.dumps(from_lua(obj))
    rt.globals().PY_DECODE = lambda text: to_lua(json.loads(text))
    rt.globals().PY_SYSTEM = run_system
    rt.globals().BASE = f'http://127.0.0.1:{server.server_port}'
    rt.execute(r'''
vim.env.AI_PROVIDER = 'custom'; vim.env.AI_API_KEY = 'test-key'; vim.env.AI_MODEL = 'local-model'
vim.env.AI_BASE_URL = BASE .. '/v1'
vim.fn.executable = function() return 1 end
vim.json = { encode = PY_ENCODE, decode = PY_DECODE }
vim.system = PY_SYSTEM
local ai = require('config.ai_api')
local result, failure
ai.chat({{role='user', content='test question'}}, {}, function(a,b) result,failure=a,b end)
assert(result == 'local answer' and failure == nil)
vim.env.AI_BASE_URL = BASE .. '/unauthorized/v1'
ai.chat({{role='user', content='test question'}}, {}, function(a,b) result,failure=a,b end)
assert(result == nil and failure:find('HTTP 401',1,true) and failure:find('denied',1,true))
''')
    assert requests_seen[0][0] == '/v1/chat/completions'
    assert requests_seen[0][1] == 'Bearer test-key'
    assert requests_seen[0][2]['model'] == 'local-model'
    assert requests_seen[0][2]['messages'][0]['content'] == 'test question'
    print('OK: реальный curl, локальный HTTP, тело запроса, ключ, ответ 200 и ошибка 401')
finally:
    server.shutdown()
    server.server_close()
    thread.join()
