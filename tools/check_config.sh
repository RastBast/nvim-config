#!/usr/bin/env bash
# ========================================================================== #
#   ПРЕФЛАЙТ-ПРОВЕРКА КОНФИГА:  ./tools/check_config.sh                      #
# ========================================================================== #
# Проверяет конфиг БЕЗ запуска nvim: синтаксис всех .lua, маркеры git-
# конфликтов (<<<<<<< / ======= / >>>>>>>) и наличие git/curl/tar в PATH.
#
# Код возврата: 0 — чисто, 1 — есть что чинить (список напечатан).
# Вся логика в tools/check_config.lua, здесь только запуск headless-nvim.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

if ! command -v nvim >/dev/null 2>&1; then
  echo "nvim не найден в PATH — поставь Neovim (см. INSTALL.md, п.2)" >&2
  exit 1
fi

# --noplugin/-u NONE: чужие плагины и твой init.lua не грузятся, проверяем
# только файлы на диске.
nvim --headless --noplugin -u NONE \
  -c "luafile tools/check_config.lua"
