#!/usr/bin/env python3
"""Опционально: реальные команды конструктора в Neovim, без плагинов/сети.

NVIM_TEST_BIN=/path/to/nvim python3 tests/architecture_nvim_smoke.py
Для проверки синтаксиса реальным Mermaid из markdown-preview.nvim дополнительно
можно указать MERMAID_JS=/.../app/_static/mermaid.min.js и NODE_PATH с jsdom.
Для локального HTTP-предпросмотра: MARKDOWN_PREVIEW_DIR=/path/to/markdown-preview.nvim
(в каталоге app должны быть установлены зависимости Node.js).
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402


def main():
    nvim = os.environ.get("NVIM_TEST_BIN") or shutil.which("nvim")
    if not nvim:
        print("SKIP: Neovim не найден (можно указать NVIM_TEST_BIN)")
        return 0
    version = subprocess.run([nvim, "--version"], capture_output=True, text=True, check=True).stdout.splitlines()[0]
    match = re.match(r"NVIM v(\d+)\.(\d+)", version)
    if not match or tuple(map(int, match.groups())) < (0, 11):
        print("SKIP: нужен Neovim 0.11+; найден", version)
        return 0
    with tempfile.TemporaryDirectory(prefix="arch-nvim-") as tmp:
        out = os.path.join(tmp, "architecture with space.md")
        env = os.environ.copy()
        env.update({
            "ARCH_TEST_CONFIG": _lua.ROOT,
            "ARCH_TEST_FILE": out,
            "XDG_CONFIG_HOME": os.path.join(tmp, "config"),
            "XDG_DATA_HOME": os.path.join(tmp, "data"),
            "XDG_CACHE_HOME": os.path.join(tmp, "cache"),
            "XDG_STATE_HOME": os.path.join(tmp, "state"),
        })
        script = os.path.join(_lua.ROOT, "tests", "architecture_nvim_smoke.lua")
        result = subprocess.run([nvim, "--headless", "-u", "NONE", "-l", script], env=env,
                                capture_output=True, text=True, timeout=30)
        output = result.stdout + result.stderr
        print(output.strip())
        if result.returncode != 0 or "OK   реальный Neovim" not in output:
            print("FAIL: nvim exit", result.returncode)
            return 1
        mermaid = env.get("MERMAID_JS")
        if mermaid and shutil.which("node"):
            text = open(out, encoding="utf-8").read()
            block = text.split("```mermaid\n", 1)[1].split("\n```", 1)[0]
            diagram = os.path.join(tmp, "diagram.mmd")
            with open(diagram, "w", encoding="utf-8") as fh:
                fh.write(block)
            parser = os.path.join(_lua.ROOT, "tests", "architecture_mermaid_smoke.js")
            parsed = subprocess.run(["node", parser, diagram], env=env, capture_output=True, text=True, timeout=30)
            print((parsed.stdout + parsed.stderr).strip())
            if parsed.returncode != 0:
                return 1
        else:
            print("SKIP: Mermaid parser (задай MERMAID_JS и NODE_PATH с jsdom)")
        preview = env.get("MARKDOWN_PREVIEW_DIR")
        if preview and shutil.which("node") and shutil.which("curl"):
            env["ARCH_PREVIEW_FILE"] = os.path.join(tmp, "preview.md")
            preview_script = os.path.join(_lua.ROOT, "tests", "architecture_preview_smoke.lua")
            actual = subprocess.run([nvim, "--headless", "-u", "NONE", "-l", preview_script], env=env,
                                    capture_output=True, text=True, timeout=30)
            print((actual.stdout + actual.stderr).strip())
            if actual.returncode != 0 or "OK   markdown-preview.nvim" not in actual.stdout + actual.stderr:
                return 1
        else:
            print("SKIP: реальный preview (задай MARKDOWN_PREVIEW_DIR с установленными Node-зависимостями)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
