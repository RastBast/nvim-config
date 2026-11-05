#!/usr/bin/env python3
"""Опционально: настоящие события мыши через UI-протокол Neovim (нужен pynvim)."""
import os
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua


def main():
    nvim_bin = os.environ.get('NVIM_TEST_BIN') or shutil.which('nvim')
    try:
        import pynvim
    except ImportError:
        print('SKIP: UI-тест мыши требует pynvim')
        return 0
    if not nvim_bin:
        print('SKIP: UI-тест мыши требует Neovim 0.11+')
        return 0
    version = subprocess.run([nvim_bin, '--version'], capture_output=True, text=True, check=True).stdout.splitlines()[0]
    match = re.match(r'NVIM v(\d+)\.(\d+)', version)
    if not match or tuple(map(int, match.groups())) < (0, 11):
        print('SKIP: требуется Neovim 0.11+; найден', version)
        return 0
    with tempfile.TemporaryDirectory(prefix='arch-mouse-') as tmp:
        target = os.path.join(tmp, 'мышь.arch.json')
        nvim = pynvim.attach('child', argv=[nvim_bin, '--embed', '--headless', '-u', 'NONE'])
        try:
            nvim.ui_attach(120, 45, rgb=True, ext_linegrid=True)
            nvim.command('set mouse=a')
            nvim.exec_lua('''
              local root, path = ...
              vim.opt.rtp:prepend(root)
              require('config.architecture_board').open(path, require('config.architecture_model').template('layers'))
            ''', _lua.ROOT, target)
            win = nvim.current.window
            pos = nvim.api.win_get_position(win)
            info = nvim.call('getwininfo', win.handle)[0]
            # Верхний левый угол N2=(23,5); кликаем внутри блока.
            row = pos[0] + (5 + 5 + 2 - info['topline'])
            col = pos[1] + 23 + 3
            nvim.api.input_mouse('left', 'press', '', 0, row, col)
            nvim.exec_lua('vim.wait(100)')
            nvim.api.input_mouse('left', 'drag', '', 0, row + 1, col + 2)
            nvim.exec_lua('vim.wait(100)')
            nvim.api.input_mouse('left', 'drag', '', 0, row + 2, col + 4)
            nvim.exec_lua('vim.wait(100)')
            nvim.api.input_mouse('left', 'release', '', 0, row + 2, col + 4)
            nvim.exec_lua('vim.wait(100)')
            snap = nvim.exec_lua('return require("config.architecture_board").snapshot()')
            nodes = {node['id']: node for node in snap['model']['nodes']}
            assert (nodes['N2']['x'], nodes['N2']['y']) == (27, 7), nodes
            assert (nodes['N1']['x'], nodes['N1']['y']) == (2, 5), nodes
            assert snap['modified'] and not os.path.exists(target), 'файл записан без разрешения'
            nvim.input('u')
            nvim.exec_lua('vim.wait(100)')
            after_undo = nvim.exec_lua('return require("config.architecture_board").snapshot()')
            node = next(n for n in after_undo['model']['nodes'] if n['id'] == 'N2')
            assert (node['x'], node['y']) == (23, 5), 'перетаскивание не отменилось за один шаг'
            nvim.input(nvim.api.replace_termcodes('<C-r>', True, False, True))
            nvim.exec_lua('vim.wait(100)')
            after_redo = nvim.exec_lua('return require("config.architecture_board").snapshot()')
            node = next(n for n in after_redo['model']['nodes'] if n['id'] == 'N2')
            assert (node['x'], node['y']) == (27, 7), 'не удалось повторить перетаскивание'
            # Параллельное изменение схемы после нажатия не должно затираться drag-событием.
            info = nvim.call('getwininfo', win.handle)[0]
            row2, col2 = pos[0] + (5 + 7 + 2 - info['topline']), pos[1] + 27 + 3
            nvim.api.input_mouse('left', 'press', '', 0, row2, col2)
            nvim.exec_lua('vim.wait(100)')
            nvim.exec_lua('assert(require("config.architecture_board").apply({op="rename", id="N2", label="Из браузера"}))')
            nvim.api.input_mouse('left', 'drag', '', 0, row2 + 1, col2 + 2)
            nvim.exec_lua('vim.wait(100)')
            nvim.api.input_mouse('left', 'release', '', 0, row2 + 1, col2 + 2)
            nvim.exec_lua('vim.wait(100)')
            after_conflict = nvim.exec_lua('return require("config.architecture_board").snapshot()')
            node = next(n for n in after_conflict['model']['nodes'] if n['id'] == 'N2')
            assert (node['x'], node['y'], node['label']) == (27, 7, 'Из браузера'), 'конфликт перетаскивания не отклонён'
            print('OK   настоящий UI Neovim: мышь, отмена за один шаг, конфликты и отсутствие автосохранения')
        finally:
            try:
                nvim.command('qa!')
            except (EOFError, OSError):
                pass
            nvim.close()
    return 0


if __name__ == '__main__':
    sys.exit(main())
