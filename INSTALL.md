# УСТАНОВКА КОНФИГА С НУЛЯ — ПОЛНАЯ ИНСТРУКЦИЯ

Ветка: `arena/01a05448-nvim-config`. macOS (homebrew) и Linux.

## 0. Требования

| Что | Зачем | Установка (macOS) |
|---|---|---|
| Neovim **0.10+** | база | `brew install neovim` |
| `git` | lazy клонирует плагины | `brew install git` |
| clang | сборка treesitter-парсеров | `xcode-select --install` |
| `ripgrep` | live-grep `<leader>fg` | `brew install ripgrep` |
| `lazygit` | `<leader>gg` | `brew install lazygit` |
| `lazydocker` | `<leader>dc` (Docker-TUI) | `brew install lazydocker` |
| `go` | Go-стек | `brew install go` |
| `tele` | Telegram в терминале и в nvim (`<leader>m…`) | brew tap + `brew install tele`, либо apt/dnf из репозитория автора, либо `go build -o tele ./cmd/tele` |
| `sqlite3` | мост читает кэш tele → уведомления в nvim | обычно уже стоит; `brew install sqlite` / `apt install sqlite3` |
| — (ничего ставить не надо) | 🕐 HUD в правом верхнем углу: время МСК, заряд, IP. Заряд — `pmset -g batt` (встроен в macOS) или `/sys/class/power_supply/BAT*` (Linux); локальный IP — `ipconfig`/`ip`; публичный — `curl` (встроен) | если чего-то нет, сегмент просто исчезает: `:Hud debug` покажет, чего именно |
| `git` (уже требуется выше) | 🔥 огонёк за коммиты: число коммитов за день берётся из локального `git log`, никуда не отправляется | ничего; журнал живёт в `stdpath("data")/streak.json` |
| Nerd Font | иконки | `brew install --cask font-jetbrains-mono-nerd-font` (или любой с nerd-fonts.com) |

Опционально для proto: `buf`, `protolint` — можно из Neovim: `:MasonInstall buf protolint`.
`grpcurl` для gRPC из терминала: https://github.com/fullstorydev/grpcurl.

Проверка версии: `nvim --version` → первая строка ≥ 0.10.

## 1. Алacritty: шрифт с иконками

`~/.config/alacritty/alacritty.toml`:

```toml
[font]
normal = { family = "JetBrainsMono Nerd Font" }
size = 13
```

## 1.1. Ghostty: терминал, сочетающийся с nvim (вместо Alacritty)

Конфиг лежит в репозитории: `macos/ghostty/config` (чёрный фон `#000000`,
палитра, синее свечение `#0d00ff` — как тема «new» в nvim).

```bash
# из папки репозитория
mkdir -p ~/.config/ghostty
cp macos/ghostty/config ~/.config/ghostty/config
```

Установка самого Ghostty: `brew install --cask ghostty` (или сайт ghostty.org).
Проверка конфига без запуска: `ghostty +validate-config`
(если `ghostty` не в PATH — `/Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config`).

**Панели и навигация (как hjkl в nvim):**

| Клавиши | Что делает |
|---|---|
| `ctrl+shift+h` / `j` / `k` / `l` | перейти в панель влево / вниз / вверх / вправо |
| `ctrl+shift+alt+h/j/k/l` | изменить размер панели (шаг 20 px) |
| `cmd+d` | делить справа |
| `cmd+shift+d` | делить снизу |
| `cmd+shift+enter` | развернуть панель на весь экран и вернуть |
| `cmd+enter` / `cmd+ctrl+f` | полный экран вкл/выкл |
| `ctrl+shift+e` | выровнять все панели |

Почему `ctrl+shift`, а не `cmd+h`: `cmd+h` в macOS — «Скрыть окно». В nvim
`ctrl+h` — backspace, поэтому ctrl+shift безопаснее всего.

**Alt в nvim:** в конфиге стоит `macos-option-as-alt = true`, чтобы
Option работал как Alt (иначе `<A-…>` в nvim не сработает).

**Полный экран без рамок.** В конфиге: `window-decoration = none` (без заголовка и рамок), `fullscreen = non-native`
(окно стартует сразу в полном экране, без строки меню). Переключение: `cmd+ctrl+f` или `cmd+enter`.
Вкладок Ghostty в этом режиме нет — панели делаются через `cmd+d` и `cmd+shift+d`. Значения сверены с
исходниками Ghostty. Если хочешь обычное окно с рамкой — удали строки `window-decoration`, `fullscreen`
и `macos-non-native-fullscreen`.

Проверить, что клавиши действительно назначены: `ghostty +list-keybinds`.

## 2. Скачать репозиторий и ветку

```bash
# резервная копия старого конфига, если есть
[ -d ~/.config/nvim ] && mv ~/.config/nvim ~/.config/nvim.backup.$(date +%F)

# клонировать ИМЕННО ветку с фиксами
git clone -b arena/01a05448-nvim-config \
  https://github.com/RastBast/nvim-config ~/.config/nvim
```

## 3. Первый запуск — всё ставится само

```bash
nvim
```

1. `init.lua` **сам** скачает lazy.nvim (бутстрап встроен).
2. lazy поставит все плагины **по lazy-lock.json** (фиксированные версии).
3. mason-lspconfig сам докачает LSP из `lua/config/servers.lua`
   (gopls, protols, sqls, dockerls, lua_ls и т.д.) + delve/golangci-lint.
4. treesitter сам скачает парсеры (go, proto, lua, …).

Внутри Neovim (если что-то не доустановилось):

```
:Lazy sync        — досинхронизировать плагины
:Mason            — UI установленных серверов/тулзов
:MasonInstall buf protolint   — инструменты proto
:TSUpdate         — свежие парсеры
:checkhealth      — зелёное = хорошо
```

## 4. Если конфиг УЖЕ лежал локально (обновление)

Вариант А (git):

```bash
cd ~/.config/nvim
git fetch origin
git merge origin/arena/01a05448-nvim-config   # HEAD станет как на remote
```

Вариант Б (один скрипт, если git-состояние messy):

```bash
curl -fsSL -o /tmp/APPLY_UPDATE.sh \
  https://raw.githubusercontent.com/RastBast/nvim-config/arena/01a05448-nvim-config/APPLY_UPDATE.sh
bash /tmp/APPLY_UPDATE.sh
```

После любого варианта — **полный перезапуск Neovim**.

Локальное состояние (не часть репозитория, при обновлении не трогается и не
трогается `git reset`): `~/.local/share/nvim/streak.json` — 🔥 огонёк за
коммиты, и `~/.config/tele/config.yml` + `state_dir` (кэш `state.db`) — telegram-
мост. При переносе на новую машину их стоит скопировать руками, иначе серия
начнётся с нуля (§24 в DOCS.md).

## 4.5. Ключ Google Gemini (бесплатный ИИ)

1. Открой https://aistudio.google.com/apikey → «Create API key» (бесплатный тариф).
2. В fish: `set -Ux GEMINI_API_KEY "AIza…"` и перезапусти терминал.
   Модель по умолчанию — `gemini-3.6-flash` (старый `gemini-2.5-flash`
   новым аккаунтам Google уже не отдаёт: 404 «no longer available to
   new users»). Сменить: `set -Ux GEMINI_MODEL "имя-модели"`.
   Если Google отвечает `400 "User location is not supported for the API
   use"` — это геоблок по IP: нужен VPN/туннель с выходом не из РФ или
   ретранслятор на сервере не в РФ (**PROXY.md**, §1.5). Совсем без
   обхода — план B на OpenRouter (**PROXY.md**, §5):
   `set -Ux OPENROUTER_API_KEY "sk-or-…"` и `set -Ux AVANTE_PROVIDER "openrouter-free"`.
3. В Neovim: `<leader>Aa` — чат-агент, `<leader>Ax` — объяснить код/ошибку,
   просто печатай код — inline-подсказки придут сами, `<Tab>` — принять.
4. Если Google не отвечает или «палит» твой VPN — **PROXY.md** в корне
   репозитория: диагностика за 30 секунд + ретранслятор на своём сервере
   (nginx) или HTTP-прокси через SSH-туннель. Конфиг переключается
   переменными окружения, Lua править не нужно:

   | Переменная (fish) | Что делает |
   |---|---|
   | `set -Ux GEMINI_ENDPOINT "https://127.0.0.1:8443/S-СЕКРЕТ/v1beta/models"` | ходить через свой ретранслятор вместо Google |
   | `set -Ux GEMINI_PROXY "socks5h://127.0.0.1:1080"` | слать запросы Gemini через прокси (`curl -x`) |
   | `set -Ux GEMINI_INSECURE 1` | не проверять сертификат ретранслятора |
   | `set -e GEMINI_ENDPOINT GEMINI_PROXY GEMINI_INSECURE` | вернуть прямой доступ |

## 4.6. Groq (console.groq.com): универсальный ИИ

Groq — **обязательный** провайдер в этом конфиге: быстрый, есть бесплатный тариф.
Все остальные (Gemini, OpenAI, OpenRouter, Mistral, DeepSeek, Kimi, Ollama,
свой сервис) подключаются через ту же точку входа — `lua/config/ai_api.lua`.

1. Зайди на https://console.groq.com, создай ключ в разделе **API Keys**.
   Ключ показывается один раз — скопируй сразу.
2. В **fish** сохрани его в переменную окружения (один раз, навсегда):

   ```fish
   set -Ux GROQ_API_KEY "gsk_…"
   ```

   Затем открой новый терминал. Ключ не попадает в репозиторий и не
   хранится в конфиге Neovim — только в переменной окружения fish
   (fish сохраняет её в `~/.config/fish/fish_variables`).
3. Проверь в Neovim: `:AiStatus` — Groq должен быть отмечен как активный.
4. Модель по умолчанию — `openai/gpt-oss-120b`. Llama 3.3 70B Groq уже
   отключил (16.08.2026), поэтому старые примеры с ней не работают.
   Быстрее и легче — `openai/gpt-oss-20b`:
   `set -Ux GROQ_MODEL "openai/gpt-oss-20b"`.
5. Выбрать провайдера: `<leader>Ap` (меню) или
   `set -Ux AI_PROVIDER groq` (постоянно). Сменить на время сессии —
   `:AiProvider gemini`.

**Как пользоваться:**

| Что | Как |
|---|---|
| Перевод по словам с грамматикой | выдели английский текст → `K` (или `<leader>Kw` для слова) |
| Быстрый вопрос любому ИИ | `<leader>Aq` (ответ откроется в окне) |
| Чат-агент, объяснить код, inline | `<leader>Aa`, `<leader>Ax` (avante); `<leader>Hat` (CodeCompanion) |

Перевод `K` и `:AiAsk` переключаются сразу. Чат CodeCompanion и avante
читают провайдера при запуске Neovim — после смены `AI_PROVIDER`
перезапусти Neovim.

**Свой OpenAI-совместимый сервис:** `set -Ux AI_BASE_URL "https://…/v1"`,
`set -Ux AI_API_KEY "…"`, `set -Ux AI_MODEL "имя"`, затем
`set -Ux AI_PROVIDER custom`.

## 5. Что проверить после запуска

| Действие | Ожидание |
|---|---|
| `:Lazy` | нет Failed; «Not Loaded» — это норма (ленивые) |
| `<leader>ff` | telescope нашёл файлы |
| открыть `.go`, написать ошибку | ошибка по-русски (DiagRu) |
| `K` на функции | подсказка: сигнатура кодом, текст по-русски (HoverRu) |
| `<leader>HGb` в go-проекте | вывод сборки; уведомления по-русски (NotifyRu) |
| `<leader>HGS` в go-файле со struct | формочка: поля, `<Tab>` по значениям |
| открыть `.proto` | подсветка + LSP protols |
| `<leader>dc` | lazydocker (если установлен) |
| `<leader>tt` на слове | перевод (translate.nvim) |

Выключить переводы, если надоели: `:HoverRu off`, `:DiagRu off`, `:NotifyRu off`.

## 5.1. Темы, быстрое перемещение и палитра команд

* **Темы:** `<leader>uT` — меню из 7 тем, или `:Theme tokyonight` (варианты: `new`, `classic`, `tokyonight`,
  `gruvbox`, `kanagawa`, `rosepine`, `carbonfox`). Пять полных схем подтягиваются плагинами при первом выборе.
  Если тема не загрузилась — `:Lazy sync`.
* **Перемещение:** `H`/`L` — начало и конец строки, `n`/`N` — поиск по центру экрана, `<M-1>`…`<M-4>` — файлы
  из Harpoon, `[b`/`]b` — вкладки. Подробно: DOCS.md, раздел «Быстрое перемещение».
* **Палитра команд:** `<leader><Space>` (пробел-пробел) — список всех `:команд` с описанием.

## 6. Частые грабли

| Симптом | Лечение |
|---|---|
| `Failed to spawn process git` на ВСЕХ плагинах в `:Lazy` | nvim не видит `git` в своём `PATH` (запуск из GUI: launchd даёт урезанный PATH, а git из Homebrew). Конфиг сам дописывает нужные каталоги (`lua/config/env_path.lua`); проверка — `:EnvCheck`. Если не помогло: `xcode-select --install` или запускай nvim из терминала |
| Кракозябры вместо иконок | Nerd Font в терминале (п.1) |
| `lazy.nvim не установился` | нет доступа к github: удали `~/.local/share/nvim/lazy` и повтори |
| Плагин «Failed: checkout…» | `:Lazy restore <имя>` или `rm -rf ~/.local/share/nvim/lazy/<имя>` + `:Lazy sync` |
| Переводы приходят английскими | нет curl/сети до translate.googleapis.com — конфиг молча работает по-английски, кеш греется при появлении сети |
| Ошибка `RestAPI/proto is not in std` | это твой проект: импорт должен начинаться с имени модуля из `go.mod` |
| avante: `E239: Invalid sign text` при загрузке | в `windows.input.prefix` стоял эмодзи: текст знака не может быть шире 2 ячеек. Ставь `"> "` (уже исправлено в конфиге) |
| avante: `400 User location is not supported` | геоблок Google по IP — нужен выход не из РФ или план B (OpenRouter). **PROXY.md**, §1.5 и §5 |
| avante: `404 … no longer available to new users` | устарело имя модели: `set -Ux GEMINI_MODEL "gemini-3.6-flash"` |

### 6.1. `:EnvCheck` — что видит nvim

Команда печатает пути к `git`/`curl`/`tar` и `PATH` текущего nvim. Если `git:
НЕ НАЙДЕН` — плагины обновляться не будут, пока это не починишь. Модуль
`lua/config/env_path.lua` подключается в `init.lua` первым (до установки
lazy.nvim, чей bootstrap тоже зовёт git) и дописывает в конец `PATH`
существующие каталоги: `/opt/homebrew/bin`, `/usr/local/bin`,
`~/.local/share/nvim/mason/bin` и системные. Твой `PATH` остаётся
приоритетнее — ничего не перезаписывается.

### 6.2. `./tools/check_config.sh` — проверить конфиг до запуска

```fish
cd ~/.config/nvim
./tools/check_config.sh
```

Без запуска редактора проверяет все `.lua`: компилируется ли каждый
(`loadfile`), нет ли где маркеров git-конфликта (`<<<<<<<` / `=======` /
`>>>>>>>`) и видны ли `git`/`curl`/`tar` в `PATH`. Код возврата 0 — чисто,
1 — список проблем напечатан. Полезно сразу после `git merge`/`git pull`:
именно так в конфиг однажды попали неразрешённые маркеры конфликта, и nvim
отказался стартовать с `unexpected symbol near '<<'`.

Внутри — обычный headless-nvim:
`nvim --headless --noplugin -u NONE -c "luafile tools/check_config.lua" -c "qa!"`.

Полная документация по клавишам и устройству — `DOCS.md`.
