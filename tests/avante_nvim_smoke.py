#!/usr/bin/env python3
"""Опциональный интеграционный smoke-тест на настоящих Neovim и avante.

Нужны Linux, Neovim >= 0.12, git, cc и локальные копии плагинов. Никаких AI
запросов и загрузок: тест создаёт временный git-checkout и поддельный архив с
C-библиотеками, так что проверяет сценарии UI/автособытий, но не Rust-релиз.

  AVANTE_TEST_SOURCE=/path/to/avante.nvim \
  AVANTE_TEST_DEPS=/path/to/lazy \
  NVIM_TEST_BIN=/path/to/nvim python3 tests/avante_nvim_smoke.py

AVANTE_TEST_DEPS должен содержать plenary.nvim, nui.nvim, mega.cmdparse и
mega.logging. Для проверки регистрации команд через настоящий lazy.nvim можно
дополнительно указать AVANTE_TEST_LAZY=/path/to/lazy.nvim. Если условия не
выполнены, тест явно пропускается.
"""
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402
from avante_native_test import C_MODULE  # noqa: E402

REVISION = "079d964ea88bff4953996ee26d31314df5dc757f"
DEPS = ("plenary.nvim", "nui.nvim", "mega.logging", "mega.cmdparse")


def main():
    nvim = os.environ.get("NVIM_TEST_BIN") or shutil.which("nvim")
    source = os.environ.get("AVANTE_TEST_SOURCE")
    deps = os.environ.get("AVANTE_TEST_DEPS")
    if not (sys.platform.startswith("linux") and nvim and source and deps and shutil.which("git") and shutil.which("cc")):
        print("SKIP: задайте NVIM_TEST_BIN, AVANTE_TEST_SOURCE и AVANTE_TEST_DEPS; нужны Linux, git и cc")
        return 0
    if not os.path.exists(os.path.join(source, ".git")) or not all(os.path.isdir(os.path.join(deps, d)) for d in DEPS):
        print("SKIP: нет git-checkout avante или обязательных локальных зависимостей")
        return 0
    version = subprocess.run([nvim, "--version"], capture_output=True, text=True, check=True).stdout.splitlines()[0]
    match = re.match(r"NVIM v(\d+)\.(\d+)", version)
    if not match or tuple(map(int, match.groups())) < (0, 12):
        print("SKIP: нужен Neovim 0.12+; найден", version)
        return 0

    with tempfile.TemporaryDirectory(prefix="avante-nvim-smoke-") as tmp:
        c_file, lib = os.path.join(tmp, "fixture.c"), os.path.join(tmp, "fixture.so")
        with open(c_file, "w", encoding="utf-8") as fh:
            fh.write(C_MODULE)
        subprocess.run(["cc", "-shared", "-fPIC", "-o", lib, c_file], check=True, capture_output=True, text=True)
        archive = os.path.join(tmp, "fixture.tar.gz")
        with tarfile.open(archive, "w:gz") as tar:
            for name in ("templates", "tokenizers", "repo_map", "html2md"):
                tar.add(lib, arcname="avante_" + name + ".so")
        fake_bin = os.path.join(tmp, "bin")
        os.mkdir(fake_bin)
        fake_curl = os.path.join(fake_bin, "curl")
        with open(fake_curl, "w", encoding="utf-8") as fh:
            fh.write("""#!/bin/sh
if [ \"$AVANTE_TEST_FAIL\" = 1 ]; then echo 'test 404' >&2; exit 22; fi
out=
while [ \"$#\" -gt 0 ]; do
  if [ \"$1\" = '-o' ]; then out=$2; shift 2; else shift; fi
done
[ -n \"$out\" ] || exit 1
cp \"$AVANTE_TEST_ARCHIVE\" \"$out\"
""")
        os.chmod(fake_curl, 0o755)
        # Резервный сценарий make: атомарная замена, как у Makefile плагина.
        for name, content in {
            "cargo": "#!/bin/sh\nexit 0\n",
            "make": """#!/bin/sh
for part in templates tokenizers repo_map html2md; do
  path="lua/avante_${part}.so"
  rm -f "$path"
  if [ "$AVANTE_TEST_CORRUPT" = 1 ] && [ "$part" = templates ]; then
    printf 'invalid binary' > "$path"
  else
    cp "$AVANTE_TEST_LIBRARY" "$path"
  fi
done
""",
        }.items():
            path = os.path.join(fake_bin, name)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(content)
            os.chmod(path, 0o755)

        cases = [("archive", False, False), ("fail", True, False), ("make", True, True)]
        if os.environ.get("AVANTE_TEST_LAZY"):
            cases.extend([("lazy", False, False), ("unsupported", False, False)])
        else:
            print("SKIP: lazy.nvim интеграция (задай AVANTE_TEST_LAZY)")
        for case, fail, source_build in cases:
            plugin = os.path.join(tmp, "plugin-" + case)
            subprocess.run(["git", "clone", "--quiet", "--shared", "--no-checkout", source, plugin], check=True)
            subprocess.run(["git", "-C", plugin, "checkout", "--quiet", "--detach", REVISION], check=True)
            env = os.environ.copy()
            env.update({
                "PATH": fake_bin + os.pathsep + env.get("PATH", ""),
                "AVANTE_TEST_CONFIG": _lua.ROOT,
                "AVANTE_TEST_PLUGIN": plugin,
                "AVANTE_TEST_DEPS": deps,
                "AVANTE_TEST_ARCHIVE": archive,
                "AVANTE_TEST_LIBRARY": lib,
                "AVANTE_TEST_FAIL": "1" if fail else "0",
                "AVANTE_TEST_SOURCE_BUILD": "1" if source_build else "0",
                "AVANTE_TEST_USE_LAZY": "1" if case in ("lazy", "unsupported") else "0",
                "AVANTE_TEST_UNSUPPORTED": "1" if case == "unsupported" else "0",
                "AVANTE_TEST_TMP": tmp,
                "XDG_CONFIG_HOME": os.path.join(tmp, "config"),
                "XDG_DATA_HOME": os.path.join(tmp, "data"),
                "XDG_CACHE_HOME": os.path.join(tmp, "cache"),
                "XDG_STATE_HOME": os.path.join(tmp, "state"),
            })
            script = os.path.join(_lua.ROOT, "tests", "avante_nvim_smoke.lua")
            result = subprocess.run([nvim, "--headless", "-u", "NONE", "-l", script], env=env,
                                    capture_output=True, text=True, timeout=60)
            output = result.stdout + result.stderr
            print(output.strip())
            if result.returncode != 0 or "OK   реальный Neovim" not in output:
                print("FAIL: nvim exit", result.returncode)
                return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
