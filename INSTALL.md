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

Полная документация по клавишам и устройству — `DOCS.md`.
