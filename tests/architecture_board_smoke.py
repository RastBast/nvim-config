#!/usr/bin/env python3
"""Опциональная интеграция доски, локального HTTP и сканирования с настоящим nvim.

Дополнительно Node + jsdom проверяют браузерный JS. Для реального Chromium:
ARCH_BROWSER_BIN=/path/to/chromium NODE_PATH=/path/to/node_modules (puppeteer-core).
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua


def main():
    nvim = os.environ.get('NVIM_TEST_BIN') or shutil.which('nvim')
    if not nvim or not shutil.which('curl'):
        print('SKIP: для интеграции доски нужны Neovim 0.11+ и curl')
        return 0
    version = subprocess.run([nvim, '--version'], capture_output=True, text=True, check=True).stdout.splitlines()[0]
    found = re.match(r'NVIM v(\d+)\.(\d+)', version)
    if not found or tuple(map(int, found.groups())) < (0, 11):
        print('SKIP: требуется Neovim 0.11+; найден', version)
        return 0
    with tempfile.TemporaryDirectory(prefix='arch-board-') as tmp:
        project = Path(tmp) / 'project'
        files = {
            'go.mod': 'module example.com/app\n',
            'cmd/server/main.go': 'package main\nimport "example.com/app/internal/service"\n',
            'internal/service/service.go': 'package service\nimport (\n "example.com/app/internal/db"\n)\n',
            'internal/db/db.go': 'package db\n',
            'web/app/main.js': 'import { helper } from "../lib/util.js";\n',
            'web/lib/util.js': 'export const helper = 1;\n',
            'pyapp/api/main.py': 'from pyapp.store.db import query\n',
            'pyapp/store/db.py': 'def query(): pass\n',
            'node_modules/ignored/bad.js': 'import "../lib/util.js";\n',
            '.git/ignored/no.py': 'from pyapp.store.db import query\n',
        }
        for name, content in files.items():
            path = project / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding='utf-8')
        large_project = Path(tmp) / 'many-files'
        for index in range(45):
            path = large_project / f'n{index:02}' / 'mod.js'
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("import '../n00/mod.js';\n", encoding='utf-8')
        large_files = Path(tmp) / 'large-files'
        large_files.mkdir()
        (large_files / 'small.py').write_text('pass\n', encoding='utf-8')
        (large_files / 'big.py').write_bytes(b'#' * (256 * 1024 + 1))
        outside = Path(tmp) / 'outside-real'
        outside.mkdir()
        (outside / 'secret.py').write_text('from pyapp.store.db import query\n', encoding='utf-8')
        try:
            (project / 'outside').symlink_to(outside, target_is_directory=True)
        except OSError:
            pass
        env = os.environ.copy()
        env.update({
            'ARCH_TEST_CONFIG': _lua.ROOT,
            'ARCH_BOARD_FILE': str(Path(tmp) / 'схема с пробелом.arch.json'),
            'ARCH_SCAN_ROOT': str(project),
            'ARCH_SCAN_MANY': str(large_project),
            'ARCH_SCAN_LARGE': str(large_files),
            'XDG_CONFIG_HOME': str(Path(tmp) / 'config'),
            'XDG_DATA_HOME': str(Path(tmp) / 'data'),
            'XDG_CACHE_HOME': str(Path(tmp) / 'cache'),
            'XDG_STATE_HOME': str(Path(tmp) / 'state'),
        })
        if shutil.which('node'):
            jsdom = subprocess.run(['node', '-e', "require('jsdom'); if (!global.fetch) process.exit(1)"],
                                   env=env, capture_output=True, text=True)
            if jsdom.returncode == 0:
                env['ARCH_BOARD_JS_SMOKE'] = '1'
            else:
                print('SKIP: тест браузера требует Node.js с fetch и jsdom (можно указать NODE_PATH)')
        else:
            print('SKIP: тест браузера требует Node.js и jsdom')
        if env.get('ARCH_BROWSER_BIN'):
            if not os.path.isfile(env['ARCH_BROWSER_BIN']) or not shutil.which('node'):
                print('FAIL: ARCH_BROWSER_BIN должен указывать на Chromium; нужен Node.js')
                return 1
            puppeteer = subprocess.run(['node', '-e', "require('puppeteer-core')"], env=env, capture_output=True, text=True)
            if puppeteer.returncode:
                print('FAIL: для ARCH_BROWSER_BIN нужен puppeteer-core (укажи NODE_PATH)')
                return 1
            env['ARCH_BOARD_REAL_SMOKE'] = '1'
        else:
            print('SKIP: настоящий Chromium (укажи ARCH_BROWSER_BIN и NODE_PATH с puppeteer-core)')
        script = os.path.join(_lua.ROOT, 'tests', 'architecture_board_smoke.lua')
        result = subprocess.run([nvim, '--headless', '-u', 'NONE', '-l', script], env=env,
                                capture_output=True, text=True, timeout=90 if env.get('ARCH_BOARD_REAL_SMOKE') else 40)
        output = result.stdout + result.stderr
        print(output.strip())
        if result.returncode or 'OK   сканер:' not in output or 'OK   Neovim:' not in output:
            print('FAIL: nvim exit', result.returncode)
            return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
