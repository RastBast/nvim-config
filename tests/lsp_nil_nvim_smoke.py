#!/usr/bin/env python3
"""Опциональный настоящий Neovim и fake nil LSP, без Nix и сети.

Задайте NVIM_TEST_BIN и NIL_TEST_LSPCONFIG (локальный checkout nvim-lspconfig).
"""
import os
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402

FAKE_NIL = '''#!/usr/bin/python3
import json,sys
inp,out=sys.stdin.buffer,sys.stdout.buffer
while True:
    length=None
    while True:
        line=inp.readline()
        if not line: sys.exit(0)
        if line in (b'\\r\\n', b'\\n'): break
        if line.lower().startswith(b'content-length:'): length=int(line.split(b':',1)[1])
    if length is None: continue
    msg=json.loads(inp.read(length))
    if 'id' in msg:
        result={'capabilities': {'textDocumentSync': 1}, 'serverInfo': {'name':'nil-test'}} if msg.get('method')=='initialize' else None
        payload=json.dumps({'jsonrpc':'2.0','id':msg['id'],'result':result}).encode()
        out.write(('Content-Length: %d\\r\\n\\r\\n' % len(payload)).encode()+payload); out.flush()
    if msg.get('method')=='exit': sys.exit(0)
'''


def main():
    nvim = os.environ.get("NVIM_TEST_BIN") or shutil.which("nvim")
    lspconfig = os.environ.get("NIL_TEST_LSPCONFIG")
    if not nvim or not lspconfig or not os.path.isfile(os.path.join(lspconfig, "lsp", "nil_ls.lua")):
        print("SKIP: нужны NVIM_TEST_BIN и NIL_TEST_LSPCONFIG (nvim-lspconfig)")
        return 0
    with tempfile.TemporaryDirectory(prefix="nil-lsp-") as tmp:
        project = os.path.join(tmp, "project")
        fake_bin = os.path.join(tmp, "bin")
        os.makedirs(project)
        os.makedirs(fake_bin)
        with open(os.path.join(project, "flake.nix"), "w", encoding="utf-8") as fh:
            fh.write("{}\n")
        executable = os.path.join(fake_bin, "nil")
        with open(executable, "w", encoding="utf-8") as fh:
            fh.write(FAKE_NIL)
        os.chmod(executable, 0o755)
        for present in (False, True):
            env = os.environ.copy()
            env.update({
                "PATH": (fake_bin + os.pathsep if present else "") + "/usr/bin:/bin",
                "NIL_TEST_ROOT": _lua.ROOT,
                "NIL_TEST_LSPCONFIG": lspconfig,
                "NIL_TEST_PROJECT": project,
                "NIL_TEST_PRESENT": "1" if present else "0",
                "XDG_CONFIG_HOME": os.path.join(tmp, "config"),
                "XDG_DATA_HOME": os.path.join(tmp, "data"),
                "XDG_CACHE_HOME": os.path.join(tmp, "cache"),
                "XDG_STATE_HOME": os.path.join(tmp, "state"),
            })
            script = os.path.join(_lua.ROOT, "tests", "lsp_nil_nvim_smoke.lua")
            proc = subprocess.run([nvim, "--headless", "-u", "NONE", "-i", "NONE", "-l", script],
                                  env=env, capture_output=True, text=True, timeout=15)
            output = proc.stdout + proc.stderr
            print(output.strip())
            if proc.returncode != 0 or "OK   реальный Neovim" not in output:
                return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
