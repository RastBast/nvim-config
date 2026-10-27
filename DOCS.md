# RastBast/nvim-config — ПОЛНАЯ ДОКУМЕНТАЦИЯ

> Ветка: `arena/a58e587f-nvim-config`. Обновлено: **2026-10-28**.
> Целевой Neovim: **0.11+** (конфиг использует `vim.lsp.config` / `vim.lsp.enable`). Для treesitter-unit (`iu`/`au`) нужен Neovim **0.12+**.
> Что проверено и как — §22. Живой запуск nvim в sandbox не выполнялся: поведение проверяется на Mac.
> Навигация: по технологиям — §27 (Go §28, БД §29, Redis §30, Docker §31, Kubernetes §32, Kafka §33, Protobuf §34, HTTP §35, Git §36, терминал и TUI §37, переводы §38, ИИ §39, мессенджеры §40). Все клавиши — §44 и §6, все команды — §25, плагины — §26. Новое: игры — §41, питомцы и картинки — §42, история правок, выравнивание и sudo — §43.

---

## Содержание

1. [Что это и философия](#1-что-это-и-философия)
2. [Требования](#2-требования)
3. [Установка и перенос на новую машину](#3-установка-и-перенос-на-новую-машину)
4. [Структура репозитория](#4-структура-репозитория)
5. [Как устроена загрузка (lazy.nvim)](#5-как-устроена-загрузка-lazynvim)
6. [ПОЛНАЯ ТАБЛИЦА ГОРЯЧИХ КЛАВИШ](#6-полная-таблица-горячих-клавиш)
7. [Система префиксов](#7-система-префиксов)
8. [Go-стек](#8-go-стек)
9. [Docker](#9-docker)
10. [Базы данных и SQL](#10-базы-данных-и-sql)
11. [HTTP / gRPC / Protobuf (Kulala + proto-стек)](#11-http--grpc--protobuf-kulala--proto-стек)
12. [Терминал](#12-терминал)
13. [Git](#13-git)
14. [Метки (marks.nvim)](#14-метки-marksnvim)
15. [Lua-разработка](#15-lua-разработка)
16. [Визуал и UX](#16-визуал-и-ux)
17. [AI, Obsidian и прочее](#17-ai-obsidian-и-прочее)
18. [LSP / Mason и языки](#18-lsp--mason-и-языки)
19. [Troubleshooting](#19-troubleshooting)
20. [Как расширять конфиг](#20-как-расширять-конфиг)
21. [Дорожная карта: Go-микросервисы](#21-дорожная-карта-go-микросервисы)
22. [Как проверялся конфиг](#22-как-проверялся-конфиг)
23. [Telegram в редакторе (консольный tele)](#23-telegram-в-редакторе-консольный-tele)
24. [HUD в углу (время МСК, батарея, IP) и огонёк за коммиты](#24-hud-в-углу-время-мск-батарея-ip-и-огонёк-за-коммиты)
25. [Команды (`:`)](#25-команды-)
26. [Плагины](#26-плагины)
27. [По технологиям: указатель](#27-по-технологиям-указатель)
28. [Go](#28-go)
29. [PostgreSQL и другие базы (SQL)](#29-postgresql-и-другие-базы-sql)
30. [Redis](#30-redis)
31. [Docker](#31-docker)
32. [Kubernetes](#32-kubernetes)
33. [Kafka](#33-kafka)
34. [Protobuf и gRPC](#34-protobuf-и-grpc)
35. [HTTP-запросы (kulala)](#35-http-запросы-kulala)
36. [Git, GitHub и GitLab](#36-git-github-и-gitlab)
37. [Терминал и TUI-утилиты](#37-терминал-и-tui-утилиты)
38. [Переводы и английский](#38-переводы-и-английский)
39. [ИИ](#39-ии)
40. [Мессенджеры](#40-мессенджеры)
41. [Игры в nvim](#41-игры-в-nvim)
42. [Питомцы и картинки](#42-питомцы-и-картинки)
43. [История правок, выравнивание, sudo](#43-история-правок-выравнивание-sudo)
44. [Полный список клавиш](#44-полный-список-клавиш)

---

## 1. Что это и философия

Личный боевой конфиг Neovim: IDE-подобная связка для **Go / Lua / Docker / SQL /
HTTP-запросов** с упором на то, чтобы всё работало «из коробки» и ни одна клавиша
не вела в никуда. Принципы ревизии 2026-08:

* **Каждая клавиша и команда проверена против исходников плагина** — мёртвые
  маппинги удалены, битые API-вызовы заменены на существующие.
* **Один плагин — один спек.** Раньше `ray-x/go.nvim` объявлялся дважды — выживал
  последний `config`, терялись клавиши. Теперь дубли запрещены (проверяется харнесом).
* **lazy-lock.json — часть конфига**: версии плагинов зафиксированы, установка
  воспроизводима на любой машине.
* Мёртвые/недоступные на Neovim плагины удалены: `skanehira/docker.vim` (Vim-only),
  `folke/bigfile.nvim` (репозиторий удалён автором), `olexsmir/gopher.nvim`
  (конфликтовал с go.nvim), `nvim-insx`, `renamer.nvim`, `utilyre/barbecue.nvim`
  (архивирован).

## 2. Требования

Обязательно:

| Компонент | Зачем |
|---|---|
| Neovim **0.10+** (лучше свежий stable) | API `vim.lsp`, treesitter main |
| `git` | lazy клонирует плагины |
| `magick` (ImageMagick), необязательно | Картинки jpg/gif/webp в `snacks.image`; PNG работает без него. macOS: `brew install imagemagick` |
| `gcc`/`clang` | сборка treesitter-парсеров |
| [nerd-font](https://www.nerdfonts.com) | иконки в lualine/nvim-tree/which-key |

Рекомендовано (фичи без них просто вежливо отключаются или подсказывают):

| Компонент | Зачем |
|---|---|
| `ripgrep` | live grep (`<leader>fg`, `<leader>Hfg`) |
| `lazygit` | `<leader>gg`, `<leader>Hgg`, `<leader>TG` |
| `go`, `gopls`, `golangci-lint`, `delve` | Go-стек (gopls/delve ставит сам Mason) |
| `docker` + (опц.) `lazydocker` | `<leader>dc/dp/di/dn` |
| `fish` или любая оболочка | терминал берёт `vim.o.shell` |
| `tele` + `sqlite3` | Telegram прямо в nvim: `<leader>m…`, §23 |
| `git` (уже в обязательных) | 🔥 огонёк за коммиты и стрик в HUD (§24) — берёт число коммитов из `git log` |
| `pmset` (есть в macOS) / `/sys/class/power_supply` (Linux) | 🕐 HUD: заряд батареи (§24); нет источника — сегмент молча исчезает |
| `curl` + сеть | 🕐 HUD: публичный IP (§24, кэш 10 минут); локальный IP, часы и стрик работают офлайн |
| `openssl` + ssh | (будущий live-share) |

## 3. Установка и перенос на новую машину

```bash
# 0) резервная копия старого конфига, если есть
[ -d ~/.config/nvim ] && mv ~/.config/nvim ~/.config/nvim.backup.$(date +%F)

# 1) клонируем ветку с фиксами
git clone -b arena/01a05448-nvim-config https://github.com/RastBast/nvim-config \
  ~/.config/nvim

# 2) первый запуск: lazy сам поставит плагины по lazy-lock.json
nvim
# внутри:  :Lazy sync          — доустановить/синхронизировать
#          :Mason              — UI; ensure_installed подтянет LSP сам
#          :checkhealth        — зелёное = хорошо
#          :TSUpdate           — свежие treesitter-парсеры
```

Если конфиг **уже** лежит локально и надо просто накатить новую ревизию:

```bash
cd ~/.config/nvim
git fetch origin
git checkout arena/01a05448-nvim-config        # или: git merge origin/arena/...
rm -rf ~/.local/share/nvim/lazy/kulala.nvim    # лечение старого кеша сабмодулей
:Lazy sync                                     # в Neovim
```

Сравнить с main в браузере:
`https://github.com/RastBast/nvim-config/compare/main...arena/01a05448-nvim-config`

## 4. Структура репозитория

```
init.lua                     — точка входа: базовые опции, порядок загрузки модулей, lazy.nvim
lazy-lock.json               — зафиксированные версии плагинов (не править руками, см. §26)
all_keymaps.txt              — список всех горячих клавиш (тот же, что §6; обновлён 2026-10-16)
DOCS.md · CHANGES.md         — эта документация · отчёт по частям работ
INSTALL.md · PROXY.md        — установка и прокси
assets/pets/                — спрайты собственных питомцев (гофер, нян, тостер, призрак), 128×88 PNG; создаёт tools/gen_pet_sprites.py
tests/                      — проверки без nvim: perft шахмат, логика игр, smoke-тесты UI (§41, §42)
APPLY_UPDATE.sh              — применение обновления конфига
PLUGINS_AUDIT.md             — аудит плагинов
macos/                       — всё для macOS вне Neovim: Hammerspoon (экранная клавиатура), README (KeyCastr, Maccy)
tools/                       — preflight-проверка: check_config.sh (синтаксис, маркеры конфликтов, PATH)
lua/
├── config/                  — логика модулей
│   ├── keymaps.lua          — базовые клавиши: окна (C-h/j/k/l), сплиты, jk
│   ├── servers.lua          — списки LSP для Mason и vim.lsp (собираются из languages.lua)
│   ├── languages.lua        — единый список языков (45): LSP, treesitter, форматтеры
│   ├── termcmd.lua          — запуск TUI (k9s, lazydocker, gh dash…) в плавающем терминале
│   ├── webtools.lua         — GitHub (gh dash), GitLab (glab-tui), Хабр (:Habr)
│   ├── themes.lua           — 7 тем (2 на catppuccin + 5 полных схем), :Theme, <leader>uT
│   ├── cmd_palette.lua      — палитра команд <leader><Space> (все :команды с описанием)
│   ├── browser_ask.lua      — запрос в Firefox: <leader>Ab, :Ask
│   ├── ru_util.lua          — переводчики (DeepL через DEEPL_API_KEY), :RuCheck
│   ├── diag_ru.lua          — русский текст диагностик (:DiagRu)
│   ├── hover_ru.lua         — русский перевод подсказки K (:HoverRu)
│   ├── gloss.lua            — английский по словам: перевод + часть речи (K в визуале, <leader>Kw, :Gloss)
│   ├── notify_ru.lua        — русский текст уведомлений (:NotifyRu)
│   ├── hud.lua              — плашка времени, заряда и IP в углу (:Hud…)
│   ├── streak.lua           — огонёк за коммиты (:Streak…)
│   ├── telegram.lua         — мост с консольным tele: уведомления в nvim (:Tele…)
│   ├── db_menu.lua          — каталог баз данных: <leader>D + СУБД + действие
│   ├── keydoc.lua           — справка по клавишам: <leader>? и <leader>?m
│   ├── keydocs/             — тексты справки g1…g8 (то, что показывает <leader>?)
│   ├── keyshow.lua          — показ нажатий внизу экрана: <leader>kk
│   ├── winnav.lua           — фокус окон: <leader>W…
│   ├── yank_ring.lua        — кольцо буфера обмена: регистры "1…"9, <leader>yr
│   ├── env_path.lua         — PATH для запуска из Dock/Finder, :EnvCheck
│   └── go_*.lua             — Go: сниппеты, инфраструктурные сниппеты, доп. команды
└── plugins/                 — 79 файлов-спеков lazy.nvim (состав — §26)
```

## 5. Как устроена загрузка (lazy.nvim)

* `init.lua` бутстрапит lazy и вызывает `require("lazy").setup("lua.plugins", …)`.
* Каждый файл в `lua/plugins/` возвращает таблицу спеков. Плагины грузятся **лениво**
  (ft/keys/cmd/event) — кроме жизненно важных (`toggleterm` теперь `lazy = false`,
  чтобы `:ToggleTerm` существовал всегда).
* `lazy-lock.json` фиксирует коммиты. **Никогда не правь руками** — только через
  `:Lazy update` + коммит.
* Полезные команды: `:Lazy` (UI), `:Lazy sync`, `:Lazy update`, `:Lazy clean`,
  `:Lazy check`, `:Lazy restore <plugin>` (переставить с нуля), `:Lazy profile`,
  `:HoverRu on|off|toggle` (перевод LSP-подсказок, см. §8),
  `:DiagRu on|off|toggle` (перевод ошибок LSP на лету, см. §19).

## 6. ПОЛНАЯ ТАБЛИЦА ГОРЯЧИХ КЛАВИШ

> Ниже — по категориям. Полный список всех записей справки с описаниями — §44. Новое: `<leader>U` и `<leader>HU` (TUI-утилиты, §37), `<leader>Kw` и `<leader>HKw` (английский, §38).

Таблица собрана из исходников конфига 2026-10-16: все `vim.keymap.set`, `keys = {}`, which-key-спеки, клавиши Super Mode, автодополнения, буферные клавиши (telegram, Habr, справка) и клавиши баз данных `<leader>D…`. `<leader>` = пробел.

* Строки «Группа» — префиксы which-key: нажми префикс и увидишь меню.
* Та же справка открывается в nvim: `<leader>?` + клавиша (разовая справка, команда не выполняется), `<leader>?m` — режим справки (клавиши объясняются вместо выполнения, выход — `Esc`). Тексты — `lua/config/keydocs/`.
* Клавиши, которые задаёт сам Vim (`zR`, `za`, `gd` и т. п.), в таблицу не входят, кроме тех, что конфиг переназначил или описал.
* Если добавляешь клавишу — добавь её и в таблицу, и в `keydocs`.
* Быстрое перемещение по тексту, файлам и вкладкам — отдельный раздел «Быстрое перемещение» (перед «Окна, переходы»).

### Нормальный режим (`n`) — клавиши с `<leader>` (пробел)

Строки «Группа» — префиксы which-key: нажми префикс и увидишь меню.

| Клавиша | Что делает | Где задано |
|---|---|---|
| `<leader>A` | **Группа:** 🤖 AI (avante) · 🦊 Firefox | which-key |
| `<leader>Ap` | 🤖 Выбрать ИИ-провайдера (Groq, Gemini, OpenAI…) | `ai_api` |
| `<leader>Aq` | 🤖 Быстрый вопрос выбранному ИИ (ответ в окне) | `ai_api` |
| `<leader>a` | **Группа:** 🌳 Структура (aerial) | which-key |
| `<leader>b` | **Группа:** 📑 Буферы | which-key |
| `<leader>c` | **Группа:** 🛠 Код | which-key |
| `<leader>D` | **Группа:** 🗄 Базы данных (каталог) | which-key |
| `<leader>Dc` | **Группа:** 🏠 ClickHouse | which-key |
| `<leader>Dm` | **Группа:** 🐬 MySQL / MariaDB | which-key |
| `<leader>Do` | **Группа:** 🏛 Oracle | which-key |
| `<leader>Dp` | **Группа:** 🐘 PostgreSQL | which-key |
| `<leader>Ds` | **Группа:** 🪶 SQLite | which-key |
| `<leader>Dx` | **Группа:** 🟦 SQL Server | which-key |
| `<leader>G` | **Группа:** 🐙 GitHub · 🦊 GitLab · 📰 Хабр | which-key |
| `<leader>g` | **Группа:** 🐹 Go и LazyGit | which-key |
| `<leader>gi` | 🧠 Go IDE-меню (как Alt+Enter в GoLand) | `go_ide` |
| `<leader>HGi` | 🧠 То же меню — зеркало в группе Go | `go_ide` |
| `<leader>gT` | 🧪 Тест для функции под курсором (gotests или каркас) | `go_ide` |
| `<leader>gC` | 🏗 Конструктор `New<Тип>` для struct | `go_ide` |
| `<leader>gD` | 📝 Комментарий-документация к функции | `go_ide` |
| `<leader>ga` | ↔ Файл ↔ `_test.go` | `go_ide` |
| `<leader>go` | 🧹 Оптимизировать импорты | `go_ide` |
| `<leader>gr` | ▶ Запустить пакет (`go run .`) | `go_ide` |
| `<leader>gx` (визуал) | ✂ Извлечь выделение в переменную/функцию | `go_ide` |
| `<leader>H` | **Группа:** 🎛 Главное меню | which-key |
| `<leader>h` | **Группа:** 📌 Harpoon (закладки) | which-key |
| `<leader>Ha` | **Группа:** 🤖 AI и Структура | which-key |
| `<leader>Hb` | **Группа:** 📋 Буфер обмена и macOS | which-key |
| `<leader>Hc` | **Группа:** 📂 Создать файл/директорию | which-key |
| `<leader>Hd` | **Группа:** 🗄 Базы и Отладка | which-key |
| `<leader>Hf` | **Группа:** 🔍 Поиск и Файлы | which-key |
| `<leader>Hg` | **Группа:** 🌿 Git и Go | which-key |
| `<leader>HG` | **Группа:** 🐹 Go: K8s · Docker · Kafka | which-key |
| `<leader>HGa` | **Группа:** 📨 Kafka | which-key |
| `<leader>HGd` | **Группа:** 🐳 Docker | which-key |
| `<leader>HGk` | **Группа:** ☸ Kubernetes | which-key |
| `<leader>Hgm` | **Группа:** ⚔ Мерж-конфликты | which-key |
| `<leader>Hh` | **Группа:** 📌 Harpoon | which-key |
| `<leader>Hk` | **Группа:** 📚 Шпаргалки (cheat.sh) | which-key |
| `<leader>Hn` | **Группа:** 📦 Прочее | which-key |
| `<leader>Ho` | **Группа:** 💎 Obsidian | which-key |
| `<leader>Hp` | **Группа:** 🔌 Плагины | which-key |
| `<leader>Hq` | **Группа:** ❓ Справка по клавишам | which-key |
| `<leader>Ht` | **Группа:** 🧪 Тесты | which-key |
| `<leader>Hu` | **Группа:** 🎨 Визуал и UI | which-key |
| `<leader>HW` | **Группа:** 🧰 Утилиты и диагностика | which-key |
| `<leader>Hx` | **Группа:** ⚠️ Диагностика | which-key |
| `<leader>Hy` | **Группа:** 💬 Чаты (терминал) | which-key |
| `<leader>j` | **Группа:** 🧾 JSON | which-key |
| `<leader>k` | **Группа:** ⌨️ Показ нажатий | which-key |
| `<leader>m` | **Группа:** TG ✈ Telegram (tele) | which-key |
| `<leader>n` | **Группа:** 📓 Черновики и подсветка | which-key |
| `<leader>o` | **Группа:** 💎 Obsidian | which-key |
| `<leader>P` | **Группа:** 🧊 Protobuf (buf) | which-key |
| `<leader>p` | **Группа:** ⏱ Pomodoro (таймер) | which-key |
| `<leader>q` | **Группа:** 🚪 Закрыть окно · сессии | which-key |
| `<leader>r` | **Группа:** 🚀 HTTP и переименование | which-key |
| `<leader>s` | **Группа:** 🎵 Spotify · 📸 скриншот | which-key |
| `<leader>T` | **Группа:** 🖥 Терминал (toggleterm) | which-key |
| `<leader>t` | **Группа:** 🌐 Перевод · 🧪 Тесты · 📖 Док | which-key |
| `<leader>u` | **Группа:** 🎨 Визуал и тема · 🐾 Питомцы | which-key |
| `<leader>W` | **Группа:** 🪟 Окна: дерево · код · терминал | which-key |
| `<leader>x` | **Группа:** ⚠️ Ошибки (Trouble) | which-key |
| `<leader>y` | **Группа:** 📋 Буфер обмена | which-key |
| `<leader>-` | Горизонтальный сплит | `keymaps` |
| `<leader>?` | ❓ Справка по клавише (не выполняет) | `keydoc` |
| `<leader>?m` | ❓ Режим справки вкл/выкл | `keydoc` |
| `<leader>a` | 📑 Структура кода | `aerial` |
| `<leader>Ab` | 🦊 Спросить в Firefox (запрос) | `browser_ask` |
| `<leader>K` | **Группа:** 📖 Английский: перевод слов | which-key |
| `<leader>Kw` | 📖 Слово под курсором: транскрипция, часть речи, перевод, значение | `gloss` |
| `<leader>aj` | 🌳 Дерево JSON/структура | `aerial` |
| `<leader>bd` | Закрыть буфер | `snacks` |
| `<leader>cf` | 🎨 Форматировать файл | `format` |
| `<leader>cj` | 🔀 Разбить/собрать конструкцию (переключить) | `which-key` |
| `<leader>cJ` | 🔗 Собрать конструкцию в одну строку | `which-key` |
| `<leader>cl` | 🔍 Линтеры для этого файла | `lint` |
| `<leader>cs` | ✂ Разбить конструкцию на строки | `which-key` |
| `<leader>db` | 🛑 Точка остановки | `dap` |
| `<leader>dc` | 🐳 Docker: lazydocker (TUI) | `toggleterm` |
| `<leader>di` | 🐳 Docker: образы | `toggleterm` |
| `<leader>dn` | 🐳 Docker: сети | `toggleterm` |
| `<leader>dp` | 🐳 Docker: контейнеры | `toggleterm` |
| `<leader>dr` | 🔍 Найти текущую БД | `dadbod-ultimate` |
| `<leader>dt` | 🧪 Отладка теста | `dap` |
| `<leader>du` | 🗄 Панель БД (IDE Style) | `dadbod-ultimate` |
| `<leader>e` | 🌲 Дерево файлов: вкл/выкл | `nvim-tree` |
| `<leader>fb` | 🗂 Буферы | `telescope` |
| `<leader>fc` | 🧰 Все команды | `telescope` |
| `<leader><Space>` | ⌨ Палитра команд: все `:команды` с описанием (пробел-пробел) | `keymaps` |
| `<leader>fd` | ⚠️ Диагностика проекта | `telescope` |
| `<leader>ff` | 📂 Найти файл | `telescope` |
| `<leader>fg` | 🔎 Поиск по содержимому | `telescope` |
| `<leader>fh` | ❓ Поиск по справке | `telescope` |
| `<leader>fk` | ⌨️ Все горячие клавиши | `telescope` |
| `<leader>fL` | 🚀 Код потёк! | `matrix` |
| `<leader>fn` | 💎 Поиск в Obsidian | `telescope` |
| `<leader>fr` | 🕑 Недавние файлы | `telescope` |
| `<leader>ft` | Найти TODO | `todo` |
| `<leader>gb` | 🔨 Собрать | `go-tools` |
| `<leader>gg` | LazyGit | `lazygit` |
| `<leader>gl` | 🧹 Линтер | `go-tools` |
| `<leader>gm` | 🎭 Сгенерировать мок | `go-tools` |
| `<leader>gt` | 🧪 Тесты пакета | `go-tools` |
| `<leader>gv` | 🛡 Проверить уязвимости | `go-tools` |
| `<leader>h1` | Harpoon: файл 1 | `harpoon` |
| `<leader>h2` | Harpoon: файл 2 | `harpoon` |
| `<leader>h3` | Harpoon: файл 3 | `harpoon` |
| `<leader>h4` | Harpoon: файл 4 | `harpoon` |
| `<leader>ha` | Добавить в Harpoon | `harpoon` |
| `<leader>Hac` | ✚ ✨ Команда в CodeCompanion | `which-key` |
| `<leader>Hae` | 📤 Отправить выделение ИИ | `which-key` |
| `<leader>Hai` | 🛠 AI‑меню действий | `which-key` |
| `<leader>Has` | 📑 Показать структуру файла | `which-key` |
| `<leader>Hat` | 💬 Открыть чат с ИИ | `which-key` |
| `<leader>Hbk` | ⌨ Экранная клавиатура macOS (⌃⌥⌘K) | `which-key` |
| `<leader>Hbm` | 🍎 macOS: клавиатура и Maccy (инструкция) | `which-key` |
| `<leader>Hbr` | 📋 Кольцо буфера обмена (1–9) | `which-key` |
| `<leader>Hcf` | 🆕 Дерево: создать файл (клавиша a) | `which-key` |
| `<leader>Hch` | ⚙️ Checkhealth | `which-key` |
| `<leader>Hcr` | ✏️ Переименовать файл | `which-key` |
| `<leader>Hda` | ➕ Добавить подключение | `which-key` |
| `<leader>Hdb` | ⛔ Точка останова | `which-key` |
| `<leader>Hde` | 🚀 Выполнить запрос | `which-key` |
| `<leader>Hdf` | ✚ 🔍 Найти БД буфера | `which-key` |
| `<leader>Hdi` | 🔽 Шаг в | `which-key` |
| `<leader>Hdo` | ⏭ Шаг через | `which-key` |
| `<leader>Hdr` | ▶️ Старт/Продолжить | `which-key` |
| `<leader>Hdt` | 🧪 Тест в режиме отладки | `which-key` |
| `<leader>Hdu` | 💾 Открыть панель БД | `which-key` |
| `<leader>He` | 🗂 Дерево файлов (nvim‑tree) | `which-key` |
| `<leader>Hfb` | 🗂 Открыть буферы | `which-key` |
| `<leader>Hfc` | ✚ ⌨️ Все команды Neovim | `which-key` |
| `<leader>Hff` | 📂 Найти файл | `which-key` |
| `<leader>Hfg` | 🔎 Live grep | `which-key` |
| `<leader>Hfh` | ❓ Поиск по справке | `which-key` |
| `<leader>Hfk` | ⌨️ Все горячие клавиши | `which-key` |
| `<leader>Hfm` | ✚ 🔖 Метки (marks) | `which-key` |
| `<leader>Hfr` | 🕑 Недавние файлы | `which-key` |
| `<leader>Hfs` | 🧩 Заполнить struct | `which-key` |
| `<leader>Hft` | 📝 TODO/FIXME | `which-key` |
| `<leader>Hfw` | ✚ 🔍 Найти слово под курсором | `which-key` |
| `<leader>HGab` | 🖧 kafkactl: брокеры | `which-key` |
| `<leader>HGag` | 👥 kafkactl: consumer-группы | `which-key` |
| `<leader>HGak` | 📨 ktea — Kafka TUI (топики, группы, сообщения) | `which-key` |
| `<leader>HGat` | 📋 kafkactl: топики | `which-key` |
| `<leader>Hgb` | 🕵️‍♂️ Показать автора строки | `which-key` |
| `<leader>Hgd` | ✚ 🔀 Diff текущего файла | `which-key` |
| `<leader>HGdd` | 🐳 lazydocker — TUI Docker | `which-key` |
| `<leader>HGdi` | 🖼 docker images | `which-key` |
| `<leader>HGdp` | 📦 docker ps -a | `which-key` |
| `<leader>HGf` | 🧱 Поля struct'а под курсором | `go-tools` |
| `<leader>Hgf` | 🕰 История файла (Diffview) | `which-key` |
| `<leader>Hgg` | ✚ 🐙 LazyGit | `which-key` |
| `<leader>Hgh` | 🔎 Предпросмотр изменений | `which-key` |
| `<leader>HGkc` | 🔀 kubectl: контексты | `which-key` |
| `<leader>HGkk` | ☸ k9s — TUI кластера | `which-key` |
| `<leader>HGkp` | 📦 kubectl: поды текущего namespace | `which-key` |
| `<leader>Hgl` | ✚ 👤 Blame строки вкл/выкл | `which-key` |
| `<leader>Hgm0` | 🚫 Убрать оба куска | `which-key` |
| `<leader>Hgmb` | ⬌ Оставить оба куска | `which-key` |
| `<leader>Hgml` | 📋 Все конфликты в quickfix | `which-key` |
| `<leader>Hgmn` | ⏭ Следующий конфликт | `which-key` |
| `<leader>Hgmo` | ⬅ Оставить СВОЁ (ours) | `which-key` |
| `<leader>Hgmp` | ⏮ Предыдущий конфликт | `which-key` |
| `<leader>Hgmt` | ➡ Оставить ЧУЖОЁ (theirs) | `which-key` |
| `<leader>Hgq` | ❌ Закрыть Diffview | `which-key` |
| `<leader>HGS` | 🧩 Формочка struct (выбор из списка) | `go-tools` |
| `<leader>Hgs` | 📦 Stage hunk | `which-key` |
| `<leader>Hgt` | 🧪 Запуск Go-тестов | `which-key` |
| `<leader>Hgu` | ↩️ Undo stage hunk | `which-key` |
| `<leader>Hgv` | 🆚 Diffview: сравнить изменения | `which-key` |
| `<leader>hh` | Меню Harpoon | `harpoon` |
| `<leader>Hh1` | 🚀 Перейти к 1‑му файлу | `which-key` |
| `<leader>Hh2` | 🚀 Перейти к 2‑му файлу | `which-key` |
| `<leader>Hha` | 📍 Добавить файл в Harpoon | `which-key` |
| `<leader>Hhh` | 📂 Открыть меню Harpoon | `which-key` |
| `<leader>Hie` | ❗ Авто‑if err | `which-key` |
| `<leader>Him` | ⚙️ Сгенерировать impl | `which-key` |
| `<leader>Hj2s` | 📦 JSON → struct | `which-key` |
| `<leader>Hkc` | 📚 Шпаргалка по запросу (cheat.sh) | `which-key` |
| `<leader>Hkl` | 📋 Поиск по всем шпаргалкам | `which-key` |
| `<leader>Hli` | 📝 LspInfo | `which-key` |
| `<leader>Hm` | 🪟 Развернуть/восстановить окно | `which-key` |
| `<leader>Hnh` | 🔎 Убрать подсветку поиска | `which-key` |
| `<leader>Hof` | 🔗 Перейти по ссылке | `which-key` |
| `<leader>Hon` | 📝 Новая заметка | `which-key` |
| `<leader>Hos` | 🔎 Поиск заметок | `which-key` |
| `<leader>Hot` | ☑ Тоггл чекбокса | `which-key` |
| `<leader>Hpc` | ✚ 🎨 Чем форматируется файл | `which-key` |
| `<leader>Hpl` | 📦 Открыть Lazy UI | `which-key` |
| `<leader>Hpm` | 🛠 Открыть Mason UI | `which-key` |
| `<leader>Hps` | ⏱️ Стоп Pomodoro | `which-key` |
| `<leader>Hpt` | ⏱️ Старт Pomodoro | `which-key` |
| `<leader>Hpy` | ✚ 🔄 Lazy sync (поставить новые плагины) | `which-key` |
| `<leader>Hq?` | ❓ Справка по клавише (не выполняет) | `which-key` |
| `<leader>Hqm` | ❓ Режим справки вкл/выкл | `which-key` |
| `<leader>Hrr` | 🚀 HTTP‑запрос (Kulala) | `which-key` |
| `<leader>Hsc` | 📸 Скриншот кода (Silicon) | `which-key` |
| `<leader>Htf` | 📂 Запуск всех тестов в файле | `which-key` |
| `<leader>Hti` | 🏷 Добавить json‑теги | `which-key` |
| `<leader>Htn` | ⬇️ Следующий тест | `which-key` |
| `<leader>Hto` | 📄 Показать вывод ошибки | `which-key` |
| `<leader>Htr` | ▶️ Запуск теста под курсором | `which-key` |
| `<leader>Hts` | 🗂 Окно со статусом тестов | `which-key` |
| `<leader>Hua` | ✨ Переключить анимации | `which-key` |
| `<leader>Huc` | 🕐 HUD: 12/24-часовой формат | `hud` |
| `<leader>Hud` | 🕐 HUD: что он видит (диагностика) | `hud` |
| `<leader>Huh` | 🕐 HUD: плашка в углу (вкл/выкл) | `hud` |
| `<leader>Hui` | 🌐 HUD: какой IP (lan → public → both → off) | `hud` |
| `<leader>Huk` | 🔥 HUD: огонёк за коммиты (:Streak) | `hud` |
| `<leader>Hum` | 🪟 Развернуть/восстановить окно | `maximizer` |
| `<leader>HuM` | 🪟 Принудительно вернуть раскладку | `maximizer` |
| `<leader>Huo` | 🙈 HUD: IP в углу — скрыть/показать | `hud` |
| `<leader>Hup` | 🐾 Питомец (Pets) | `which-key` |
| `<leader>Hvc` | 🔐 Проверка уязвимостей | `which-key` |
| `<leader>HWa` | 🔕 Огонёк: без уведомлений | `which-key` |
| `<leader>HWA` | 🔔 Огонёк: уведомления вкл | `which-key` |
| `<leader>HWb` | 🔥 Огонёк: день до 03:00 МСК | `which-key` |
| `<leader>HWc` | 🕐 Часы: 24 часа | `which-key` |
| `<leader>HWC` | 🕐 Часы: 12 часов | `which-key` |
| `<leader>HWd` | 🩺 Русские ошибки LSP: вкл/выкл | `which-key` |
| `<leader>HWe` | 🧪 Проверка PATH и утилит | `which-key` |
| `<leader>HWg` | 🔥 Огонёк: цель 1 коммит в день | `which-key` |
| `<leader>HWh` | 🌐 Перевод подсказок K: вкл/выкл | `which-key` |
| `<leader>HWm` | 🟢 Дождь из символов | `which-key` |
| `<leader>HWn` | 🔔 Русские уведомления: вкл/выкл | `which-key` |
| `<leader>HWr` | 🌐 Проверить переводчики | `which-key` |
| `<leader>HWt` | 🕐 Обновить часы и HUD | `which-key` |
| `<leader>HWz` | 🕐 Пояс UTC+3 (МСК) | `which-key` |
| `<leader>Hxl` | 📋 Location list | `which-key` |
| `<leader>Hxq` | 📋 Quickfix list | `which-key` |
| `<leader>Hxs` | ✚ 🧭 Символы файла (Trouble) | `which-key` |
| `<leader>Hxt` | ✚ 📝 TODO‑комментарии (Trouble) | `which-key` |
| `<leader>Hxx` | ❗ Показать все ошибки (Trouble) | `which-key` |
| `<leader>Hyd` | 💬 Discordo — Discord в терминале (⚠ риск для аккаунта, см. доку) | `which-key` |
| `<leader>Hz` | 🧘 Дзен‑режим | `which-key` |
| `<leader>jq` | 🔎 jq-запрос по JSON | `json-pro` |
| `<leader>jx` | 🔍 Список ключей JSON | `json-pro` |
| `<leader>kk` | ⌨️ Показ нажатий: вкл/выкл | `keyshow` |
| `<leader>M` | 🦹 Super Mode | `hydra` |
| `<leader>m?` | 📋 шпаргалка по telegram-мосту | `which-key` |
| `<leader>mb` | 🔔 гудок вкл/выкл | `which-key` |
| `<leader>mc` | 🎯 выбрать чат и сесть на него | `which-key` |
| `<leader>md` | 🩺 диагностика (:TeleCheck) | `which-key` |
| `<leader>mf` | 🖥 tele: на весь экран | `which-key` |
| `<leader>mh` | 🙈 спрятать окно (tele останется живым) | `which-key` |
| `<leader>mi` | 📥 история входящих | `which-key` |
| `<leader>mk` | 💀 убить процесс tele | `which-key` |
| `<leader>mm` | 🗕 tele: маленькое окно (float) | `which-key` |
| `<leader>mn` | 🔇 режим тишины (dnd) | `which-key` |
| `<leader>mo` | ↩︎ открыть чат последнего уведомления | `which-key` |
| `<leader>mp` | ▐ tele: боковой панелью | `which-key` |
| `<leader>mq` | ↩︎ ответить в чат последнего уведомления | `which-key` |
| `<leader>mr` | ✍️ ответить через tele | `which-key` |
| `<leader>ms` | 📤 отправить выделение в tele (visual) | `which-key` |
| `<leader>mS` | 📤 отправить текущую строку в tele | `which-key` |
| `<leader>mt` | 📖 прочитать чат, не открывая tele | `which-key` |
| `<leader>ns` | 📓 Черновик | `snacks` |
| `<leader>nS` | 📓 История черновиков | `snacks` |
| `<leader>ob` | 🔗 Связь с Obsidian | `obsidian-bridge` |
| `<leader>Pb` | 🧊 buf build (валидация proto) | `toggleterm` |
| `<leader>Pg` | 🧊 buf generate (codegen по buf.gen.yaml) | `toggleterm` |
| `<leader>Pl` | 🧊 buf lint (стиль proto) | `toggleterm` |
| `<leader>pp` | ⏸ Пауза | `pomo` |
| `<leader>pr` | ▶ Снять с паузы | `pomo` |
| `<leader>ps` | ⏱️ Остановить таймер | `pomo` |
| `<leader>pt` | ⏱️ Запустить таймер (25м) | `pomo` |
| `<leader>q` | Закрыть окно | `keymaps` |
| `<leader>qs` | 🕑 Восстановить сессию этого проекта | `persistence` |
| `<leader>rr` | 🚀 Запустить запрос | `kulala` |
| `<leader>S` | Поиск и замена во всем проекте | `spectre` |
| `<leader>sb` | 🎵 Назад | `spotify` |
| `<leader>sd` | 🎵 Spotify устройства | `spotify` |
| `<leader>sn` | 🎵 Вперёд | `spotify` |
| `<leader>so` | 🎵 Spotify поиск | `spotify` |
| `<leader>sp` | 🎵 Пауза/Плей | `spotify` |
| `<leader>Ta` | ❎ Показать/скрыть все терминалы | `toggleterm` |
| `<leader>Tc` | ❎ Закрыть все терминалы | `toggleterm` |
| `<leader>tf` | Запустить тесты в файле | `neotest` |
| `<leader>Tg` | 🌿 git status | `toggleterm` |
| `<leader>TG` | 🌿 lazygit в терминале | `toggleterm` |
| `<leader>Th` | 📟 Терминал снизу | `toggleterm` |
| `<leader>Tl` | ➡ Строку в терминал | `toggleterm` |
| `<leader>to` | Показать лог ошибки | `neotest` |
| `<leader>tr` | Запустить тест под курсором | `neotest` |
| `<leader>ts` | Панель тестов (IDE style) | `neotest` |
| `<leader>Tt` | 📟 Плавающий терминал | `toggleterm` |
| `<leader>tt` | 🌐 Перевести слово (ru) | `translate` |
| `<leader>Tv` | 📟 Терминал справа | `toggleterm` |
| `<leader>ua` | Переключить анимации | `animate` |
| `<leader>uc` | 🖱 Плавный курсор вкл/выкл | `smoothcursor` |
| `<leader>un` | 🔕 Спрятать уведомления | `snacks` |
| `<leader>uo` | 😴 Питомец: сон | `pets` |
| `<leader>up` | 🐾 Питомец: меню «выбрать и призвать» (вид, окрас, имя) | `pets` |
| `<leader>ug` / `uy` / `ut` / `uG` | 🐹 гофер Харек / 🐱 нян-кот / 🍞 тостер / 👻 призрак (мемы) | `pets` |
| `<leader>uT` | 🎨 Выбрать тему (7 штук: новая, старая и 5 полных схем) | `themes` |
| `<leader>ux` | 💀 Убрать питомцев | `pets` |
| `<leader>w` | Сохранить | `keymaps` |
| `<leader>Wc` | 💻 Фокус: файл (код) | `winnav` |
| `<leader>Wf` | 🌲 Фокус: дерево файлов | `winnav` |
| `<leader>Wo` | 🪟 Оставить только это окно | `winnav` |
| `<leader>Wt` | 📟 Фокус: терминал | `winnav` |
| `<leader>Wx` | ✖ Закрыть окно | `winnav` |
| `<leader>xx` | Список всех ошибок | `trouble` |
| `<leader>yr` | 📋 Кольцо буфера обмена (1–9) | `yank_ring` |
| `<leader>z` | Дзен режим | `zen` |
| `<leader>\|` | Вертикальный сплит | `keymaps` |

### Визуальный режим (`v`, `x`) — клавиши с `<leader>`

| Клавиша | Режим | Что делает | Где задано |
|---|---|---|---|
| `K` | x | 📖 Английский: исходный текст, перевод фразы и разбор по словам (транскрипция, часть речи, перевод, значение) | `gloss` |
| `<leader>Ab` | x | 🦊 Спросить в Firefox (выделение) | `browser_ask` |
| `<leader>Ax` | n, v | 🤖 Объяснить код/ошибку (ИИ; по умолчанию Gemini, см. `AI_PROVIDER`) | `avante` |
| `<leader>Hac` | n, v | ✨ Команда в CodeCompanion | `ai` |
| `<leader>Hae` | n, v | 📤 Отправить выделение ИИ | `ai` |
| `<leader>Hai` | n, v | 🛠 Действия AI | `ai` |
| `<leader>Hat` | n, v | 💬 Чат CodeCompanion с выбранным ИИ (по умолчанию Kimi; при `AI_PROVIDER=groq` — Groq) | `ai` |
| `<leader>ms` | v | ✈ отправить выделение в tele | `telegram` |
| `<leader>r` | v | Запустить кусок кода | `sniprun` |
| `<leader>sc` | v | 📸 Скриншот Silicon | `silicon` |
| `<leader>te` | n, v | 🌐 Перевести на английский | `translate` |
| `<leader>Tl` | v | ➡ Выделение в терминал | `toggleterm` |
| `<leader>tt` | v | 🌐 Перевести выделение (ru) | `translate` |

### Обычный режим (`n`) — остальные клавиши

| Клавиша | Что делает | Где задано |
|---|---|---|
| `<C-\>` | 📟 Переключить терминал | `toggleterm` |
| `<C-Down>` | Ниже | `keymaps` |
| `<C-h>` | Окно слева | `keymaps` |
| `<C-j>` | Окно снизу (терминал — сразу ввод) | `keymaps` |
| `<C-k>` | Окно сверху | `keymaps` |
| `<C-l>` | Окно справа | `keymaps` |
| `<C-Up>` | Выше | `keymaps` |
| `<Esc>` | Выйти из режима справки | `keydoc` |
| `<F10>` | ↷ Шаг через | `dap` |
| `<F11>` | ↴ Шаг в | `dap` |
| `<F5>` | ▶ Запуск / Продолжить | `dap` |
| `<M-h>` | Уже | `keymaps` |
| `<M-H>` | ⬅ Слово влево | `move` |
| `<M-j>` | ⬇ Строку вниз | `move` |
| `<M-k>` | ⬆ Строку вверх | `move` |
| `<M-l>` | Шире | `keymaps` |
| `<M-L>` | ➡ Слово вправо | `move` |
| `H` | В начало строки (первый непробельный символ, как `^`). Заменяет экранный H. В визуальном режиме растягивает выделение | `keymaps` |
| `L` | В конец строки (как `$`). Заменяет экранный L. В визуальном режиме растягивает выделение | `keymaps` |
| `n` | Следующее совпадение поиска, строка центрируется на экране (`nzzzv`) | `keymaps` |
| `N` | Предыдущее совпадение поиска, по центру (`Nzzzv`) | `keymaps` |
| `<M-1>` … `<M-4>` | Харпун: файл 1–4 из списка (Alt+цифра, см. раздел «Быстрое перемещение») | `harpoon` |
| `[b` | Предыдущая вкладка (буфер) в строке bufferline | `bufferline` |
| `]b` | Следующая вкладка (буфер) в строке bufferline | `bufferline` |
| `<S-Tab>` | Предыдущий буфер | `bufferline` |
| `<Tab>` | Следующий буфер | `bufferline` |
| `K` | Предпросмотр свёрнутого блока; если блока нет — документация LSP (hover) | `folding` |
| `zM` | Свернуть всё | `folding` |
| `zm` | Свернуть блоки | `folding` |
| `zR` | Развернуть всё | `folding` |
| `zr` | Развернуть, кроме… | `folding` |

### Визуальный и операторный режимы — остальные клавиши

| Клавиша | Режим | Что делает | Где задано |
|---|---|---|---|
| `b` | n, o, x | Умное b (подслова) | `spider` |
| `e` | n, o, x | Умное e (подслова) | `spider` |
| `ge` | n, o, x | Умное ge (подслова) | `spider` |
| `s` | n, o, x | Прыжок | `flash` |
| `w` | n, o, x | Умное w (подслова) | `spider` |
| `[[` | n, t | Предыдущее слово | `snacks` |
| `]]` | n, t | Следующее слово | `snacks` |
| `<C-n>` | n, x | Несколько курсоров: выделить слово | `visual-multi` |
| `<` | v | Отступ влево | `keymaps` |
| `<M-H>` | v | ⬅ Блок влево | `move` |
| `<M-j>` | v | ⬇ Блок вниз | `move` |
| `<M-k>` | v | ⬆ Блок вверх | `move` |
| `<M-L>` | v | ➡ Блок вправо | `move` |
| `>` | v | Отступ вправо | `keymaps` |
| `p` | v | Вставить, не затирая регистр | `keymaps` |
| `au` | x | Внешняя единица кода (treesitter-unit) | `ts-unit` |
| `iu` | x | Внутренняя единица кода (treesitter-unit) | `ts-unit` |

### Режим вставки (`i`) и терминала (`t`)

| Клавиша | Режим | Что делает | Где задано |
|---|---|---|---|
| `<Esc><Esc>` | t | Выйти в Normal в терминале | `keymaps` |

**Автодополнение (nvim-cmp, режим `i` и `s`), `lua/plugins/completions.lua`:**

| Клавиша | Что делает |
|---|---|
| `<C-n>` | Следующий пункт меню автодополнения |
| `<C-p>` | Предыдущий пункт меню автодополнения |
| `<CR>` | Принять выбранное автодополнение |
| `<C-e>` | Закрыть меню автодополнения |
| `<C-Space>` | Открыть меню автодополнения вручную |
| `<C-b> / <C-f>` | Прокрутка документации в меню автодополнения |
| `<Tab>` | Следующий пункт меню → прыжок по сниппету → принять подсказку Avante → Tab |
| `<S-Tab>` | Предыдущий пункт меню → прыжок назад по сниппету |

### Клавиши LSP (появляются, когда у буфера подключился сервер)

| Клавиша | Режим | Что делает |
|---|---|---|
| `<F2>` | i, n | ✏️ Переименовать |
| `<leader>ca` | n | 💡 Действия кода |
| `<leader>d` | n | 🩺 Диагностика строки |
| `<leader>f` | n | 🎨 Формат (LSP) |
| `<leader>rn` | n | ✏️ Переименовать |
| `[d` | n | ⬆ Пред. ошибка |
| `]d` | n | ⬇ След. ошибка |
| `gD` | n | 📌 К декларации |

### Super Mode (`<leader>M`, hydra)

Нажми `<leader>M` — появится подсказка. Дальше клавиши без `<leader>`:

| Клавиша | Что делает |
|---|---|
| `s` | Сохранить (`:w`) |
| `f` | Поиск файлов (Telescope) |
| `g` | LazyGit (выход из режима) |
| `b` | Буферы (Telescope) |
| `q / <Esc>` | Выход из Super Mode |

### Буферные клавиши (работают только в своём окне)

| Где | Клавиша | Что делает |
|---|---|---|
| tele: история чата (`<leader>mm`/`mi`…) | `q` | закрыть окно |
| tele: история чата | `R` | ответить в этот чат |
| tele: история чата | `o` | открыть чат в tele |
| tele: входящие (`<leader>mi`) | `q` | закрыть |
| tele: входящие | `i` | обновить из БД |
| tele: входящие | `f` | автообновление буфера вкл/выкл |
| tele: входящие | `<CR>` | открыть этот чат в tele |
| tele: входящие | `o` | прочитать переписку, не открывая tele |
| tele: входящие | `R` | ответить через tele |
| Habr: статья (`<leader>Gb`) | `q` | закрыть вкладку со статьёй |
| Habr: статья | `o` | открыть статью в браузере (`open`) |
| Справка `<leader>?` | `Esc` | закрыть справку / выйти из режима справки |

### Базы данных: `<leader>D` + СУБД + действие

Генерируется из `lua/config/db_menu.lua` (клавиши совпадают с меню which-key и `<leader>?`).

| СУБД | Код | Подключиться `c` | Выполнить `r` | Таблицы `t` | Описание таблицы `d` | Новый буфер `n` | Панель DBUI `u` |
|---|---|---|---|---|---|---|---|
| 🪶 SQLite | `s` | `<leader>Dsc` | `<leader>Dsr` | `<leader>Dst` | `<leader>Dsd` | `<leader>Dsn` | `<leader>Dsu` |
| 🐬 MySQL / MariaDB | `m` | `<leader>Dmc` | `<leader>Dmr` | `<leader>Dmt` | `<leader>Dmd` | `<leader>Dmn` | `<leader>Dmu` |
| 🐘 PostgreSQL | `p` | `<leader>Dpc` | `<leader>Dpr` | `<leader>Dpt` | `<leader>Dpd` | `<leader>Dpn` | `<leader>Dpu` |
| 🏛 Oracle | `o` | `<leader>Doc` | `<leader>Dor` | `<leader>Dot` | `<leader>Dod` | `<leader>Don` | `<leader>Dou` |
| 🟦 SQL Server | `x` | `<leader>Dxc` | `<leader>Dxr` | `<leader>Dxt` | `<leader>Dxd` | `<leader>Dxn` | `<leader>Dxu` |
| 🏠 ClickHouse | `c` | `<leader>Dcc` | `<leader>Dcr` | `<leader>Dct` | `<leader>Dcd` | `<leader>Dcn` | `<leader>Dcu` |

`<leader>D` + код СУБД + `r` выполняет буфер (обычный режим) или выделение (визуальный режим), например `<leader>Dpr` для PostgreSQL. Списка баз по `<leader>D` нет, есть каталог по СУБД выше.

### Новое: TUI-утилиты (`<leader>U` и зеркало `<leader>HU`)

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>Uu` | n | Меню всех TUI-утилит |
| `<leader>Uh` | n | Проверка TUI-утилит |
| `<leader>Uk` | n | k9s — Kubernetes |
| `<leader>Ur` | n | iredis — Redis с автодополнением |
| `<leader>Uc` | n | redis-cli — Redis классический |
| `<leader>Up` | n | pgcli — PostgreSQL с автодополнением |
| `<leader>Ul` | n | lazysql — TUI-клиент БД |
| `<leader>Ud` | n | lazydocker — Docker |
| `<leader>Ui` | n | dive — слои Docker-образа |
| `<leader>Ub` | n | btop — монитор ресурсов |
| `<leader>Ua` | n | ktea — Kafka TUI |
| `<leader>HUu` | n | Меню всех TUI-утилит |
| `<leader>HUh` | n | Проверка TUI-утилит |
| `<leader>HUk` | n | k9s — Kubernetes |
| `<leader>HUr` | n | iredis — Redis с автодополнением |
| `<leader>HUc` | n | redis-cli — Redis классический |
| `<leader>HUp` | n | pgcli — PostgreSQL с автодополнением |
| `<leader>HUl` | n | lazysql — TUI-клиент БД |
| `<leader>HUd` | n | lazydocker — Docker |
| `<leader>HUi` | n | dive — слои Docker-образа |
| `<leader>HUb` | n | btop — монитор ресурсов |
| `<leader>HUa` | n | ktea — Kafka TUI |

### Новое: игры, картинки, питомцы, история правок

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>Xc` | n | ♟ Шахматы: два игрока или против ПК (5 уровней) |
| `<leader>Xs` | n | 🐍 Змейка (гофер ест конфеты) |
| `<leader>Xt` | n | 🧱 Тетрис |
| `<leader>Xf` | n | 🔢 2048 |
| `<leader>Xm` | n | 🎮 Меню игр |
| `<leader>Ii` | n | 🖼 Показать картинку под курсором (нужна Ghostty) |
| `<leader>If` | n | 🖼 Найти картинку в проекте |
| `<leader>v` | n | ⏪ История правок (undotree) |
| `<leader>=` | n, x | ↔ Выровнять по символу (mini.align) |
| `<leader>qW` | n | 💾 Записать файл через sudo |
| `<leader>HX…` / `<leader>HI…` / `<leader>HV` | n | Зеркала в главном меню `<leader>H` |

Подробно: игры — §41, питомцы и картинки — §42, история/выравнивание/sudo — §43. Полный список — §44.

### Новое: перевод по словам и подсказки

| Клавиша | Режим | Что делает |
|---|---|---|
| `K` | x | Английский по словам |
| `<leader>Kw` | n | Слово под курсором: транскрипция, часть речи, перевод |
| `<leader>HKw` | n | Английский: слово под курсором (то же, что <leader>Kw) |
| `<leader>tt` | n | Перевести слово (ru) |
| `<leader>te` | n | Перевести на английский |
| `<leader>tD` | n | Документация в боковом окне |
| `<leader>HWr` | n | Проверить переводчики |
| `<leader>HWh` | n | Перевод подсказок K вкл/выкл |
| `<leader>HWd` | n | Русские ошибки LSP вкл/выкл |
| `<leader>HWn` | n | Русские уведомления вкл/выкл |

## 7. Система префиксов

| Префикс | Смысл |
|---|---|
| `<leader>H` | Главное меню which-key: подгруппы `Hf` поиск, `Hg` git, `Hd` БД+отладка, `HG` Go, `Ht` тесты, `Hu` визуал+🕐HUD+🔥стрик, `Hx` диагностика, `Ho` obsidian, `Hh` harpoon, `Hp` плагины, `Hc` файлы, `Ha` AI |
| `<leader>Hu` | Визуал и UI: `us/ur/uz/um/uM/up/ua/ut/uP` плагины и pomodoro, `h/d/i/c/o` — сам HUD (показать, debug, IP, 12/24, `o` — скрыть/показать IP в углу), `k` — огонёк за коммиты (§24) |
| `<leader>T` | Терминалы toggleterm (`Tt/Th/Tv/Ta/Tc/Tl/Tg/TG`); `Tc` — закрыть все |
| `<leader>HW` | 🧰 Утилиты (заглавная W — строчные буквы под `<leader>H` уже заняты): `HWr` переводчики, `HWh/HWd/HWn` переводы K/LSP/уведомлений, `HWe` PATH, `HWm` матрица, `HWt/HWc/HWC/HWz` HUD, `HWa/HWA/HWg/HWb` огонёк |
| `<leader>d` + буква | Docker (`dc` lazydocker, `dp` ps, `di` images, `dn` сети); `<leader>d` один — диагностика строки (LSP) |
| `<leader>f` | Поиск telescope/fzf-стиль (`ff/fg/fb/fr/fh/fk/fc/fd`) |
| `<leader>g` | Go-быстрые (`gb/gl/gt/gm/gv`) и `gg` lazygit |
| `<leader>m` | **Отдел TG** в which-key: Telegram через консольный `tele` (§23) — `mm/mf/mp` окна, `mi/mt` чтение, `mr/mq` ответ. Раньше тут же сидел `MaximizerToggle`, из-за чего нажатие `<leader>m` молча разворачивало окно; клавиша переехала на `<leader>Hum` |
| `<C-\>` | Открыть/скрыть терминал из любого места |

which-key всплывает по `<leader>` автоматически; `<leader>Hfk` и `<leader>fk` —
интерактивный список **всех** клавиш.

## 8. Go-стек

> Подробно по технологии: **§28**.

LSP — `gopls` (Mason). Поверх — `ray-x/go.nvim` (**единственный** спек, файл
`go-tools.lua`): автоформат `goimports` при сохранении, команды `GoBuild/GoTest/
GoTestFunc/GoLint/GoVulnCheck/GoMockGen/GoImpl/GoIfErr/GoJson2Struct…`.

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>gb` | n | Собрать |
| `<leader>gt` | n | Тесты пакета |
| `<leader>Hgt` | n | Запуск Go-тестов |
| `<leader>gl` | n | Линтер |
| `<leader>gv` | n | Проверить уязвимости |
| `<leader>Hvc` | n | Проверка уязвимостей |
| `<leader>gm` | n | Сгенерировать мок |
| `<leader>Hie` | n | Авто if err |
| `<leader>Hti` | n | Добавить json-теги |
| `<leader>Hj2s` | n | JSON → struct |
| `<leader>Hfs` | n | Заполнить struct |
| `<leader>Him` | n | Сгенерировать impl |
| `<leader>HGS` | n | Формочка struct (выбор из списка) |
| `<leader>HGf` | n | Поля struct'а под курсором |
| `<leader>db` | n | Точка останова |
| `<leader>dt` | n | Отладка теста (Go) |
| `<leader>Hdt` | n | Тест в режиме отладки |
| `<leader>Hdr` | n | Старт/Продолжить |
| `<leader>Hdi` | n | Шаг в |
| `<leader>Hdo` | n | Шаг через |
| `<leader>Hdb` | n | Точка останова |
| `<F5>` | n | Запуск / продолжить (DAP) |
| `<F10>` | n | Шаг через (DAP) |
| `<F11>` | n | Шаг в (DAP) |
| `<leader>tr` | n | Тест под курсором |
| `<leader>tf` | n | Тесты в файле |
| `<leader>ts` | n | Панель тестов |
| `<leader>to` | n | Лог ошибки теста |

**Умный Go (как в VSCode).** `<leader>HGS` — «формочка»: пикер struct'ов
(красивый через snacks.picker), вставляется сниппет со ВСЕМИ полями, курсор прыгает
по значениям `<Tab>`, дефолты — нулевые значения Go по типу поля.
`<leader>HGf` — то же для struct'а под курсором. Сниппет `gstr` в
автодополнении — динамическая формочка ближайшего struct'а. Описания всех
Go-сниппетов в меню — по-русски (`dstring`). Модули: `lua/config/go_extras.lua`,
`lua/config/go_snips.lua`.

**Английский по словам (учим язык).** Модуль `lua/config/gloss.lua`.
Выдели фразу или предложение в визуальном режиме и нажми `K`. Откроется окно по центру:
1. исходный английский текст;
2. перевод всей фразы;
3. разбор по словам в порядке текста, в таком виде:

   - **If** [иф] — «если» (союз, связывает части предложения).
   - **are** [ар] — «ты» (глагол, форма to be для you; здесь помощник).

Слово под курсором — `<leader>Kw`. Команда `:Gloss` делает то же для строк диапазона.
Закрыть окно: `q` или `Esc`.

**Откуда разбор.**
- С ключом `GEMINI_API_KEY` (или `AVANTE_GEMINI_API_KEY`) разбор делает ИИ Gemini — тот же
  ключ, что у avante. Он видит всю фразу, поэтому грамматика и перевод учитывают
  контекст. Модель — `GEMINI_MODEL` (по умолчанию как у avante). Ключ в fish:
  `set -Ux GEMINI_API_KEY "..."`. Фраза уходит в Google, так же как в avante.
- Без ключа — словарь `dictionaryapi.dev` (ключ не нужен, нужен `curl`). Транскрипция
  переводится из IPA таблицей, часть речи и первое значение — из словаря. Контекста
  словарь не знает, поэтому разбор менее точный. Перевод слов — через `ru_util`
  (DeepL, если задан `DEEPL_API_KEY`; иначе Google/MyMemory).
- Если ИИ не ответил (нет сети, ошибка ключа), окно сообщит причину и покажет словарь.

Честно: транскрипция от ИИ — его оценка, не словарная. За раз разбирается до 40 слов.
Если в словаре нет слова, на месте транскрипции и части речи стоит «—».

**Русский в подсказках.** Модуль `lua/config/hover_ru.lua` (включён в `init.lua`)
перехватывает hover LSP — подсказку «что делает функция» (клавиша `K`) — и
переводит описательный текст на русский через Google (асинхронно, ~1 с).
Код НЕ переводится: fenced-блоки ``` (сигнатуры/примеры) и inline `code`
остаются как есть. Нет сети/curl — молча показывается оригинал.
Выключить: `:HoverRu off`. Окно документации автодополнения (nvim-cmp) не
переводится осознанно (иначе запрос на каждый пункт списка).

Отладка: `nvim-dap` + `leoluz/nvim-dap-go` (delve ставит Mason): `<leader>Hdr` старт,
`Hdb` брейкпоинт, `Hdi/Hdo` шаги, `Hdg` debug-тест. Тесты: `neotest` + `neotest-go`:
`<leader>Htr` тест под курсором, `Htf` файл, `Hts` статус-окно, `Htn` следующий,
`Hto` вывод ошибки.

## 9. Docker

> Подробно по технологии: **§31**.

* **Подсветка** Dockerfile/docker-compose — `ekalinin/Dockerfile.vim`.
* **LSP** — `dockerls` (Mason) + `docker_compose_language_service` доступны в `servers.lua`.
* **Интерфейс** — «маленькое окно» поверх toggleterm:
  * `<leader>dc` — **lazydocker** (TUI: контейнеры, логи, kill, образы, сети — всё в одном окне). Ставится отдельно: https://github.com/jesseduffield/lazydocker
  * `<leader>dp` — `docker ps -a` в плавающем терминале
  * `<leader>di` — `docker images`
  * `<leader>dn` — `docker network ls`
* Отладка контейнеров — `nvim-dap-docker`.
* Если бинара нет — конфиг не падает, а вежливо подсказывает, что поставить.

## 10. Базы данных и SQL

> Подробно по технологии: **§29**.

Связка **vim-dadbod + dadbod-ui + dadbod-completion**:

| Клавиша | Действие |
|---|---|
| `<leader>Hdu` / `<leader>Hdt` | Панель БД (открыть / toggle) |
| `<leader>Hda` | Добавить подключение (prompt: `postgres://user@host/db`) |
| `<leader>Hdf` | Автоподключение по БД текущего буфера |

Внутри панели: `dd` — выполнить запрос, автодополнение таблиц/колонок в SQL-буфере.
Quickfix по JSON/SQL — `nvim-jqx` (`<leader>jq`, `<leader>jx` — для JSON).

## 11. HTTP / gRPC / Protobuf (Kulala + proto-стек)

> Подробно по технологии: **§35**.

`mistweaverco/kulala.nvim` — RestClient прямо в nvim: файлы `*.http`, `*.rest`.
`<leader>rr` (или `<leader>Hrr`) — выполнить запрос под курсором; поддерживает **gRPC**
(`GRPC http://host:50051/pkg.Service/Method` в .http-файле).

### Protobuf: полный стек

| Слой | Что | Где |
|---|---|---|
| Подсветка/парсер | treesitter `proto` | `lua/plugins/treesitter.lua` (ensure) |
| LSP | `protols` (подсказки, диагностика, переходы) | `lua/config/servers.lua` (Mason ставит сам) |
| Форматтер | `buf format` через conform, фолбэк — LSP | `lua/plugins/format.lua` (`proto = { "buf" }`) |
| Линт/сборка/кодоген | `buf lint / build / generate` в плавающем окне | `<leader>Pl / Pb / Pg` (`toggleterm.lua`) |
| Сниппеты | `hdr` `svc` `msg` `rpc` `enum` `opt` | `lua/plugins/completions.lua` (LuaSnip, ft=proto) |
| gRPC-запросы | kulala (`GRPC …` в .http) | `<leader>rr` |

Внешние бинари (один раз): `:MasonInstall buf protolint` (+ по желанию
`grpcurl` — https://github.com/fullstorydev/grpcurl для запросов из терминала).

## 12. Терминал

> Подробно по технологии: **§37**.

`akinsho/toggleterm.nvim` загружается **при старте** (`lazy = false`):

| Клавиша | Действие |
|---|---|
| `<C-\>` | toggle терминала |
| `<leader>Tt/Th/Tv` | float / снизу (15 строк) / справа |
| `<leader>Ta` | показать/скрыть все |
| `<leader>Tl` (n/v) | отправить строку/выделение в терминал |
| `<leader>Tg`, `<leader>TG` | git status / lazygit в терминале |
| `<Esc><Esc>` | выйти в normal внутри терминала |

Оболочка — твой `fish`; тонирование фона выключено (терминал выглядит как в alacritty).

### Ghostty — основной терминал (конфиг `macos/ghostty/config`)

С 2026-10-28 основной терминал — **Ghostty**. Конфиг подобран под тему «new» в nvim:
фон `#000000`, палитра пользователя, выделение и синее свечение `#0d00ff`.
Установка и копирование конфига — INSTALL.md, раздел «1.1. Ghostty».

| Клавиша | Что делает |
|---|---|
| `ctrl+shift+h` / `j` / `k` / `l` | фокус на панель влево / вниз / вверх / вправо (как hjkl в nvim) |
| `ctrl+shift+alt+h/j/k/l` | изменить размер панели (шаг 20 px) |
| `cmd+d` | делить панель справа |
| `cmd+shift+d` | делить панель снизу |
| `cmd+shift+enter` | развернуть панель на весь экран / вернуть |
| `ctrl+shift+e` | выровнять все панели |
| `cmd+enter` / `cmd+ctrl+f` | полный экран вкл/выкл (стандартные сочетания Ghostty) |

**Полный экран без рамок.** В конфиге: `window-decoration = none` (без заголовка и рамок окна),
`macos-titlebar-style = hidden` и `macos-window-buttons = hidden` (кнопки закрыть/свернуть скрыты),
`fullscreen = non-native` — окно стартует сразу в полном экране без строки меню и без анимации,
`macos-non-native-fullscreen = true` — переключение (`cmd+ctrl+f`, `cmd+enter`) тоже без отдельного
пространства macOS. Вкладок в этом режиме нет, и они нам не нужны: панели делаются через `cmd+d` и `cmd+shift+d`.
Значения сверены с исходниками Ghostty (`src/config/Config.zig`).

**Исправлено:** `scrollback-limit = 20000` понималось как 20 КБ (ключ переименован в Ghostty 1.4,
значение трактуется в байтах) — теперь `scrollback-limit-lines = 20000`. Убран `macos-titlebar-style = tabs`,
который оставлял заголовок окна.

- `macos-option-as-alt = true`: Option работает как Alt, поэтому `<A-…>` в nvim работает.
- Почему `ctrl+shift`, а не `cmd+h`: `cmd+h` в macOS — «Скрыть окно».
  `ctrl+h` в nvim — backspace, поэтому `ctrl+shift` ничему не мешает.
- Проверка: `ghostty +validate-config` (ошибки конфига), `ghostty +list-keybinds` (назначенные клавиши).


Отдельно `tele` (Telegram-TUI) живёт не здесь, а в `lua/config/telegram.lua` —
три способа открытия и уведомления внутри редактора, см. §23.

## 13. Git

> Подробно по технологии: **§36**.

`gitsigns.nvim` (hunk'и: `<leader>Hgs` stage, `Hgu` undo, `Hgb` blame-строки,
`Hgh` предпросмотр) + `lazygit.nvim` (`<leader>gg`, `<leader>Hgg`) +
`diff`-подсветка и `vim-fugitive`-стиль через telescope (`<leader>Hg…`).
История/черновики буфера — `<leader>ns`, `<leader>nS`.

## 14. Метки (marks.nvim)

`chentoast/marks.nvim` включён с дефолтами. Шпаргалка:

| Клавиша | Действие |
|---|---|
| `mx` | поставить метку x |
| `m,` | следующая свободная буквенная метка |
| `m;` | toggle метки на строке |
| `dmx` / `dm-` / `dm<Space>` | удалить метку x / на строке / все в буфере |
| `m]` / `m[` | следующая / предыдущая метка |
| `m:` | предпросмотр метки |
| `m0`…`m9` | закладки-группы (своя иконка/текст) |

Проверено: репозиторий живой, `setup({})` валиден, конфликтов с нашими клавишами нет.

## 15. Lua-разработка

* `lua_ls` (Mason) + `folke/lazydev.nvim`: автоматически добавляет в workspace
  типы плагинов (`lazy`, `snacks`) и **luvit-meta** (`vim.uv`-подсказки).
* Форматирование — `stylua` через conform (если установлен).

## 16. Визуал и UX

* Тема — **catppuccin** (`colorscheme.lua`), прозрачность/отступы — по вкусу в options.
* `lualine` (статус), `bufferline` (вкладки), `nvim-tree` (файлы: `<leader>Hne/Hcf`),
  `which-key` (меню), `noice`+`nvim-notify`+`fidget` (уведомления/прогресс LSP),
  `indent-blankline`, `nvim-ufo` (супер-фолды + `<Tab>`-peek), `rainbow-delimiters`,
  `colorful-winsep`, `neoscroll`, `mini.animate` (тумблер `<leader>Hua`),
  `SmoothCursor`, `nvim-colorizer`, `vim-illuminate`, `zen-mode` (`<leader>z`),
  `maximizer` (`<leader>Hum`), `alpha-nvim` (стартовый экран),
  `cellular-automaton` (`<leader>fL` — «код потёк», пасхалка),
  `pets.nvim` (питомец: `<leader>Hup`, `up/uo/ux`), `nvim-silicon`
  (скриншот кода в визуальном режиме `<leader>sc`), `pomo.nvim` (помодоро `<leader>pt/ps/pp/pr`),
  `translate.nvim` (`<leader>tt/te`), `vim-spotify` (`<leader>so/sd`),
  `vim-numbertoggle`, `vim-highlighturl`, `undotree`-стиль истории через shada.

## 17. AI, Obsidian и прочее

* **AI** — единая точка входа `lua/config/ai_api.lua` (Groq обязателен, выбор `<leader>Ap`; подробно — §39). `codecompanion.nvim`: `<leader>Hat` чат, `Hac` команда, `Hae` отправить
  выделение, `Hai` действия.
* **ИИ-агент как в Cursor** — `avante.nvim` + бесплатный Google Gemini
  (`gemini-3.6-flash`): чат-сайдбар справа с контекстом проекта и
  рефакторингом, inline-подсказки целыми блоками при наборе, окно
  объяснения кода/ошибок. Ключ: https://aistudio.google.com/apikey →
  `set -Ux GEMINI_API_KEY "..."` (fish).
  Модель меняется переменной `set -Ux GEMINI_MODEL "имя"` (список своих
  моделей: `curl -sS ".../v1beta/models?key=$GEMINI_API_KEY"`).
  Если Google отвечает `400 "User location is not supported"` — геоблок по
  IP, смотри **PROXY.md** (§1.5 — что делать, §5 — план B на OpenRouter:
  `set -Ux AVANTE_PROVIDER "openrouter-free"`).
  Сеть: по умолчанию ходит в Google напрямую. Если Google недоступен или
  «палит» твой VPN — поднимается ретранслятор на своём сервере, конфиг
  переключается одной переменной: `set -Ux GEMINI_ENDPOINT "…"` или
  `set -Ux GEMINI_PROXY "…"` (пошагово в **PROXY.md**).
  Клавиши: `<leader>Aa` чат о выделенном, `<leader>Ax` «объясни по-русски»,
  `<leader>Ae` рефакторинг по инструкции, `<leader>At` сайдбар,
  `<leader>As` позвать подсказку, `<leader>AR` карта репо;
  inline: `<Tab>` принять (в цепочке cmp→сниппеты→ИИ), `<M-l>` принять
  напрямую, `<M-]>/<M-[>` варианты, `<C-]>` скрыть; отправка сообщения
  `<C-s>`.
* **Obsidian** — `obsidian.nvim` + `obsidian-bridge`: `<leader>Hon` новая заметка,
  `Hos` поиск, `Hof` по ссылке, `Hot` чекбокс.
* **Harpoon** (ветка harpoon2): `Hha` добавить, `Hh1/Hh2` перейти, `Hhh` меню.
* **SnipRun** — выполнить кусок кода из буфера.
* **Spectre** — поиск-и-замена по проекту (`<leader>`-меню f-группы + команды).

## 18. LSP / Mason и языки

`lua/config/languages.lua` — единый список языков (45 записей). Из него берутся: LSP (Mason ставит поле `lsp`), парсеры treesitter и форматтеры conform. Имена LSP — из `nvim-lspconfig`, Mason-пакет находится по полю `neovim.lspconfig` реестра.

| Язык (filetype) | LSP | Форматтер (conform) | Примечание |
|---|---|---|---|
| go | `gopls` | — |  |
| lua | `lua_ls` | `stylua` |  |
| javascript | `ts_ls` | `prettier` |  |
| typescript | `ts_ls` | `prettier` |  |
| sh | `bashls` | `shfmt` |  |
| json | `jsonls` | `prettier` |  |
| yaml | `yamlls` | `prettier` |  |
| html | `html` | `prettier` |  |
| css | `cssls` | `prettier` |  |
| sql | `sqls` | `sqlfluff` |  |
| dockerfile | `dockerls` | — |  |
| proto | `protols` | `buf` |  |
| xml | `lemminx` | `xmlformat` |  |
| dot | `dotls` | — |  |
| markdown | `marksman` | `prettier` |  |
| python | `pyright`, `ruff` | `ruff_format` | pyright (типы) + ruff (LSP) |
| rust | `rust_analyzer` | `rustfmt` |  |
| c | `clangd` | `clang-format` |  |
| cpp | `clangd` | `clang-format` |  |
| java | `jdtls` | `google-java-format` |  |
| kotlin | `kotlin_language_server` | `ktlint` |  |
| scala | — | `scalafmt` | LSP `metals`: в реестре Mason его нет, системный тулчейн. Установка: `cs install metals` (Coursier) |
| cs | `csharp_ls` | `csharpier` | системный тулчейн, Mason не ставит |
| ruby | `ruby_lsp` | `rubocop` |  |
| php | `intelephense` | `php_cs_fixer` |  |
| swift | `sourcekit` | `swiftformat` | системный тулчейн, Mason не ставит |
| dart | `dartls` | `dart_format` | системный тулчейн, Mason не ставит |
| elixir | `elixirls` | `mix` |  |
| haskell | `hls` | `ormolu` | системный тулчейн, Mason не ставит |
| ocaml | `ocamllsp` | `ocamlformat` | системный тулчейн, Mason не ставит |
| zig | `zls` | `zigfmt` |  |
| r | `r_language_server` | `styler` | системный тулчейн, Mason не ставит |
| julia | `julials` | `runic` | системный тулчейн, Mason не ставит |
| terraform | `terraformls` | `terraform_fmt` |  |
| nix | `nil_ls` | `nixfmt` |  |
| vue | `vue_ls` | `prettier` |  |
| svelte | `svelte` | `prettier` |  |
| graphql | `graphql` | `prettier` |  |
| toml | `taplo` | `taplo` |  |
| tex | `texlab` | `latexindent` |  |
| typst | `tinymist` | `typstyle` |  |
| clojure | `clojure_lsp` | `cljfmt` |  |
| perl | `perlnavigator` | `perltidy` |  |
| cmake | `neocmake` | `cmake_format` | LSP `neocmake` (бинарник neocmakelsp). Форматтер `cmake_format` — команда из пакета cmakelang: `pipx install cmakelang` |
| groovy | `groovyls` | — | системный тулчейн, Mason не ставит |

**Важно про установку:**

* Mason ставит только LSP-серверы (`ensure_installed`). Форматтеры и линтеры **не ставятся автоматически**: если conform пишет «not found», установи их сам (brew / npm / pip / cargo — команда зависит от инструмента).
* Серверы, которые Mason ставит из PyPI (например, `cmake-language-server`), зависят от версии Python. Если установка падает — `:MasonLog`; это бывает на Python 3.14+. Поэтому cmake переведён на `neocmake` (см. §19).
* Инструменты `golangci-lint`, `hadolint`, `delve`, `protolint` ставятся вручную или через `:Mason`.

Базовые LSP-клавиши (ставятся при подключении сервера): `K` документация (или предпросмотр свёрнутого блока), `gd` определение, `gD` декларация, `gr` ссылки, `gi` реализация, `<leader>rn` / `<F2>` переименование, `<leader>ca` действия кода, `<leader>f` формат, `[d` / `]d` ошибки, `<leader>d` диагностика строки. Полный список — §6.

## 19. Troubleshooting

| Симптом | Причина / лечение |
|---|---|
| В `:Lazy` плагины «Not Loaded» | Это НОРМА: ленивые плагины стартуют по триггеру (клавиша/команда/ft/event) — список в Lazy и показывает триггеры. «Disabled» — выключено осознанно (nvim-spotify) |
| `E492: Not an editor command: …` при нажатии клавиши | which-key вызывал `<cmd>X` до загрузки плагина без стаба. Лечится объявлением `cmd = {"X"}` в спеке (так сделаны Go*, MaximizerToggle, Obsidian*, ToggleTerm, aerial и др.); аудит: все 37 строковых команд which-key прикрыты стабами/жадными плагинами |
| `E492: Not an editor command: ToggleTerm…` | Было: ленивая загрузка + чужой набор клавиш. Исправлено: `lazy=false`. Если вдруг вернётся — `:Lazy restore toggleterm.nvim` |
| kulala «checkout failed … .git/modules/fmt» | Старый коммит kulala с сабмодулями + битый кеш. Лечится: `rm -rf ~/.local/share/nvim/lazy/kulala.nvim` + `:Lazy sync` (в lock уже новый коммит без сабмодулей) |
| «docker.vim: doesn't support neovim» | Плагин Vim-only — **удалён** из конфига. Если ошибка осталая — `rm -rf ~/.local/share/nvim/lazy/docker.vim` |
| Ошибки/подсказки LSP по-русски | Из коробки: `diag_ru.lua` — ошибки при наборе (Go/Docker/SQL/proto/Lua…), `hover_ru.lua` — подсказка `K` (код не трогается), `notify_ru.lua` — уведомления и вывод сборок (`<leader>HGb`, lint), окно документации автодополнения — через `cmp.entry.get_documentation`. Кеш переводов — файл `stdpath("cache")/ru_cache.json`, переживает перезапуск; первый показ: notify ждёт перевод до 0.7 с (обычно успевает — сразу русский), диагностика — до 2.5 с; кеш греется и переживает перезапуск. Выкл: `:DiagRu off`, `:HoverRu off`, `:NotifyRu off` |
| Плагин «Failed: checkout/clone» | Почти всегда битый кеш: `:Lazy restore <имя>` или `rm -rf` папки + `:Lazy sync` |
| `famiu/bufdelete.nvim`, `stevearc/dressing.nvim` | **Удалены из конфига** (заменены snacks). Записи в `lazy-lock.json` могут остаться — не мешают; `:Lazy clean` удалит папки |
| `failed to install cmake` (mason-lspconfig) | Пакет `cmake-language-server` ставится из PyPI и **не поддерживает Python 3.14+**. Конфиг переведён на `neocmake` (бинарник neocmakelsp из GitHub). Если старый пакет остался: `:MasonUninstall cmake-language-server`, затем `:MasonInstall neocmakelsp`. Подробности — `:MasonLog` |
| Любой `failed to install …` для серверов из PyPI | Причина почти всегда в версии Python на машине. Смотри `:MasonLog`. Лечение: поставить Python 3.13 (`brew install python@3.13`) или заменить сервер (как с cmake) |
| LSP не стартовал | `:Mason` → проверить установку; `:LspInfo`; `:checkhealth` |
| Нет иконок/кракозябры | Nerd Font в терминале (alacritty: `font.family = "JetBrainsMono Nerd Font"`) |

## 20. Как расширять конфиг

* **Новый плагин**: файл `lua/plugins/имя.lua`, `return { { "org/repo", … } }`.
  Проверь харнесом (см. §22) на дубли и конфликты.
* **Новая клавиша**: в существующий спек (`keys = {…}` с `desc`) — попадёт в
  which-key и в автотаблицу; глобальные — `lua/config/keymaps.lua`.
* **Сниппеты**: LuaSnip + `rafamadriz/friendly-snippets` уже подключены; свои —
  в `lua/snippets/*.lua` (формат LuaSnip) — запланировано под Go/SQL/Dockerfile
  шаблоны дорожной карты.

## 21. Дорожная карта: Go-микросервисы

Согласованный план (инструменты проверены на живость репозиториев):

1. **Фаза 1 — терминальные TUI в окнах nvim**: lazydocker ✔ (уже), далее `iredis`
   (Redis-клиент с автодополнением), `harlequin` или `pgcli` (SQL-IDE уровня
   «pgAdmin в терминале»), `k9s` (Kubernetes).
2. **Фаза 2 — GoLand-паритет**: `refactoring.nvim` (Extract Function/Variable/Inline),
   `nvim-coverage`, `diffview.nvim`, codelens, call-hierarchy (уже через gopls).
3. **Фаза 3 — сниппеты/скелеты**: LuaSnip-наборы `go/sql/docker/proto/yaml` +
   автокаркас нового файла (`BufNewFile`).
4. **Фаза 4 — proto/gRPC-обвязка**: treesitter `proto`, Mason `protols` +
   `protolint`, `grpcurl` наружу; kulala уже шлёт gRPC.
5. **Фаза 5 — live-режим на двух машинах**: `azratul/live-share.nvim`
   (`:LiveShareHostStart` / `:LiveShareJoin`, нужен OpenSSL + ssh-туннель).

**Невозможно в Neovim** (честно): GUI-профайлер (только `go tool pprof -http`),
диаграммы схем БД, визуальные конструкторы манифестов.

## 22. Как проверялся конфиг

Состояние на 2026-10-16. Честно о том, что сделано и что нет.

* **Клавиши и команды:** все `vim.keymap.set`, локальные `map(...)`, `keys = {}`, which-key-спеки и `nvim_create_user_command` разобраны скриптом по исходникам. Комментарии в коде не учитываются. Результат — таблицы §6, §25 и справка `<leader>?` (`lua/config/keydocs/`). Скрипт не входит в репозиторий.
* **Синтаксис:** каждый изменённый Lua-файл проверен загрузкой через `load` (lupa). Полный luacheck в sandbox недоступен.
* **На Mac перед запуском nvim:** `./tools/check_config.sh` — синтаксис всех `.lua`, маркеры конфликтов и наличие git/curl/tar в PATH. Код возврата 0 — всё чисто.
* **Mason:** имена LSP сверены с реестром `mason-org/mason-registry` (поле `neovim.lspconfig` в `packages/<имя>/package.yaml`); требования PyPI-пакетов — через PyPI API.
* **Плагины:** репозитории из спецификаций сверены с `lazy-lock.json` (§26).
* **Живой Neovim в sandbox не запускался.** Внешний вид, работа пикеров, toggleterm и сетевые функции (Habr, GitHub, DeepL) проверяются на Mac.
* **Раньше:** на предыдущих ревизиях харнес (lupa) с заглушками API прогонял 78 спеков: 0 ошибок загрузки, 0 конфликтов клавиш. Это было до позднейших правок и не перепроверено.
* **Отдельные модули** проверялись своими тестами с заглушками: мост telegram (121 проверка, §23), HUD и огонёк (154 проверки, §24). Хабр (§GitHub/GitLab/Хабр): разбор RSS и HTML проверен на примерах, живой habr.com из sandbox недоступен.
* **Mason-аудит:** каждое имя LSP из `languages.lua` сверено с реестром Mason.

Проверка 2026-10-28 (ИИ, Ghostty, Go IDE, перевод `K`): синтаксис всех изменённых
Lua-файлов — загрузкой через lupa; логика — тестами с заглушками `vim.*` (выбор
провайдера, запрос без утечки ключа в аргументах curl, разбор ошибок HTTP,
Gemini через ретранслятор и прокси, перерисовка окна после ответа ИИ, генерация
Go-тестов, конструктора и документации по фиктивным узлам treesitter, уникальность
клавиш справки). Итог: 78 проверок, все прошли. Ghostty-конфиг проверен
по официальной справке действий (`goto_split`, `resize_split`, `new_split`).
Не проверено в sandbox: живой Neovim, `gotests`, `go` и `ghostty` — их нужно
проверить на Mac (`:checkhealth`, `:AiStatus`, `K`, `<leader>gi`).

Проверка 2026-10-28 (темы, быстрое перемещение, палитра команд, Ghostty без рамок): синтаксис
121 Lua-файла (lupa `load`); поведение тем и палитры — 37 тестов с заглушками `vim.*`
(ленивая загрузка плагина, чёрный фон у всех тем, сохранение выбора, отложенный старт на `VimEnter`,
ошибка «схема не загрузилась», меню `vim.ui.select`, `nargs` в палитре). Ghostty: все ключи и значения
конфига сверены с `Config.zig` (37 строк, ошибок 0); 5 используемых действий `keybind` — с 91 тегом
`Action` в `Binding.zig`; дефолтные сочетания полного экрана — из `Config.zig`.
Не проверено в sandbox: живой Neovim (lazy-загрузка схем, реальный `nvim_get_commands` в палитре),
Ghostty на Mac (`ghostty +validate-config`, сам полный экран), внешний вид каждой из 7 тем.

## 23. Telegram в редакторе (консольный tele)

Мост к [`sorokin-vladimir/tele`](https://github.com/sorokin-vladimir/tele) —
клавиатурному Telegram-TUI на Go. Код: `lua/config/telegram.lua` (вся логика),
подключается одной строкой в `init.lua`. Плагина из vim-world здесь нет: `tele`
— внешний бинарник, а интеграция написана вручную, потому что **у tele нет ни
CLI для отправки/чтения, ни демона** (`cmd/tele/main.go` знает только
`--config/-e/--trace/--version/--theme-*`; обещанный resident daemon — это v2.0).

### Как уведомления попадают в nvim

tele пишет всю переписку в локальный SQLite — `~/.local/state/tele/state.db`,
пачками раз в 2 секунды (`persistFlushInterval`). Мост читает таблицу `chats`
тем же `sqlite3`, что и остальной конфиг (только чтение), и ловит **рост
`unread_count`** — единственный признак «входящее, которое ты ещё не видел»
(`last_message` меняется и от собственных сообщений, и от «прочитано»).
Отсюда следствия, которые важно принимать осознанно:

* задержка до ~2-3 секунд — быстрее не знает сам tele;
* tele должен быть запущен **где угодно** (эта вкладка, tmux, любой другой терминал) —
  уведомления всё равно придут, потому что читается кэш, а не окно;
* если tele не запущен нигде, новых сообщений физически нет: sync живёт в TUI.
  В v2.0 с демоном это исчезнет, мост тогда переключится на сокет;
* нужны `tele` и `sqlite3` (≥ 3.33 ради `--json`). Что не так — показывает
  `:TeleCheck`, и он же говорит, где искал базу.

Свои уведомления tele (OSC 777/beeep) Neovim перехватить не может, поэтому
popup рисуется свой — **мимо** фильтра `init.lua`, который глушит всё кроме
ERROR. Чтобы не было двойни, `:TeleQuiet` выключает `ui.notifications.desktop`
в конфиге tele (правка точечная, с `config.yml.bak`).

### Клавиши (`<leader>m` — «messenger», префикс был свободен)

| Клавиша | Действие |
|---|---|
| `<leader>mm` | tele в маленьком плавающем окне (быстро глянуть и закрыть) |
| `<leader>mf` | tele **на весь экран** (режим редактора, `direction=editor`) |
| `<leader>mp` | tele **боковой панелью** рядом с кодом (≈68 колонок) |
| `<leader>mh` | спрятать окно, **не убивая процесс** → уведомления идут дальше |
| `<leader>mc` | выбрать чат списком и открыться сразу на нём |
| `<leader>mo` | открыть чат последнего уведомления |
| `<leader>mi` | `:TeleInbox` — лента входящих прямо в nvim |
| `<leader>mt` | читать переписку чата, **не открывая tele** (`:TeleRead`) |
| `<leader>mr` | ответить: печать в PTY tele (`Esc → i → текст → Enter`) |
| `<leader>mq` | ответить в чат последнего уведомления |
| `<leader>ms` (v) | отправить выделение как сообщение |
| `<leader>mS` | отправить текущую строку |
| `<leader>mn` | режим тишины: счётчик растёт, popup молчит |
| `<leader>mb` | гудок терминала на входящее |
| `<leader>md` | `:TeleCheck` — диагностика |
| `<leader>mk` | убить процесс tele |
| `<leader>m?` | шпаргалка (`:TeleDocs`) |

Все три окна — **один и тот же процесс**: у tele lock на `state_dir`, второй
экземпляр сразу умирает с «tele is already running», поэтому переключается
геометрия, а не процесс.

### Команды

`:Tele full|panel|chat|<имя чата>` · `:TeleInbox` · `:TeleRead {чат}` ·
`:TeleChatPick` · `:TeleReply` · `:TeleSend` (range) · `:TeleHide` · `:TeleKill` ·
`:TeleDnd` · `:TeleFocus {чаты}` / `:TeleIgnore {чаты}` · `:TeleBell` ·
`:TeleTheme mocha|black` · `:TeleQuiet [off]` · `:TeleStart`/`:TeleStop`/`:TeleToggle` ·
`:TeleDb {путь}` · `:TeleCheck` · `:TeleStatus` · `:TeleTest` · `:TeleDocs`

Один ответ на вопрос «а можно совсем без списка чатов и папок»: сам tele так не
умеет (`internal/ui/layout/layout.go` всегда делит ширину на sidebar + chat),
поэтому «чистый» вид — это `:TeleRead` (нативное окно nvim из кэша), а `<leader>mc`
— маленький float, куда чат открывается сразу.

### Цвет

`:TeleTheme` кладёт в `~/.config/tele/themes/nvim-mocha.yml` тему на базе
вшитой в tele `catppuccin-macchiato`, перекрашенной в **точную палитру mocha**
(та же, что у `colorscheme.lua`), и прописывает `ui.theme` в конфиг tele.
`black` — вариант для тех, кто красит `Normal` в `#000000` (как делает `init.lua`
здесь): фон отдаётся терминалу. Нужен перезапуск tele; проверить: `tele --theme-check`.

### Настройка

```lua
require("config.telegram").setup({
  poll = 2000,               -- мс, чаще 2000 смысла нет (см. выше)
  style = "auto",            -- auto | notify | float | echo | none
  timeout = 5000,
  bell = false,
  respect_mute = true,       -- мьют Telegram = не всплывать
  loud_mentions = true,      -- @mention разбуди даже в мьюте
  focus = {},                -- {"Иван", "#go-prod"} — только эти чаты
  mode = "chat",             -- режим <leader>mm по умолчанию
  kill_on_exit = true,       -- убить tele при выходе из nvim
})
```

Свои реакции на входящие: `require("config.telegram").on_message(function(ev) … end)`
или autocmd `User TeleMessage` (`ev.data = {id,title,text,author,unread,kind,at}`),
для счётчиков — `User TeleUnread`. Компонент в статус-баре уже подключён в
`lualine.lua` (`✈ N`, с `!` при упоминаниях).

## 24. HUD в углу (время МСК, батарея, IP) и огонёк за коммиты

Два маленьких модуля: `lua/config/hud.lua` (плашка в правом верхнем углу) и
`lua/config/streak.lua` (стрик по коммитам). Оба — чистый Lua в стиле
`config/telegram.lua`, плагинами не являются.

### Что видно

```
                                        🕐 3:56 PM   🔋 82%   🏠 192.168.1.5   🌐 84.22.1.1   🔥4
```

Одна строка в **нефокусируемом** float-окне `relative=editor`, `row=0`,
прижатая к правому краю, `zindex=60`, без рамки (`style=minimal`).

| Сегмент | Откуда | Если не удалось |
|---|---|---|
| 🕐 время | `os.time() + 3*3600`, часы считаются **арифметикой** | — не может «не удался» |
| 🔋 / ⚡ / 🪫 заряд | macOS: `pmset -g batt` (раз в 60 с); Linux: `/sys/class/power_supply/BAT*/capacity` | сегмент исчезает (десктоп), вранья «0%» нет |
| 🏠 локальный IP | mac: интерфейс из `route -n get default` → `ipconfig getifaddr`; Linux: `ip -4 -o addr show scope global` | сегмент исчезает |
| 🌐 публичный IP | `curl -s --max-time 4 https://api.ipify.org`, раз в 10 минут | остаётся последнее значение с `~` (устарел) |
| 🔥 N | `config.streak`, см. ниже | пустая строка, если `git` не найден |

Почему float, а не `statusline`/`virtual text`: статус-лайн здесь глобальный
(`laststatus=3`) и находится **внизу**, а virtual text на первой строке сдвигает
код и прыгает вместе со скроллом. Плашка не перехватывает фокус (`focusable=false`)
и **сама уходит**, если чужое float-окно (tele, telescope, which-key) налезает на
её угол — проверка по `getwininfo()` (пересечение прямоугольников), возврат по
`WinClosed`. Отсюда же само-восстановление после `:only` и `:hud refresh`.

### Почему время не берётся из локали

`H.time_str()` делает `t = os.time() + tz_offset`, а часы/минуты вытаскивает
делением, а не `os.date("!%H:%M")`. Причина: «!» понимают не все рантаймы Lua,
а `os.date` **без** «!» считает по поясу машины — на ноутбуке в Хельсинки
«время в МСК» показывало бы хельсинкское, и AM/PM уезжали бы вместе с ним.
12-часовой формат: `hh % 12`, ноль → `12`, `PM` после полудня — то есть полночь
это `12:00 AM`, а не `0:00`. Тот же подход у календаря стрика: `civil_from_days`
Хиннанта вместо `os.date("%d.%m")`, поэтому «15 октября» не превращается в
«14 октября» для людей, у которых `TZ` сдвинут.

### 🔥 Огонёк за коммиты

Правило: **один коммит или одна новая ветка в день = один огонёк** (ветка считается,
чтобы огонёк загорался сразу; выключается `branch_counts = false`). День, когда активности
не было, сгорает; **сутки заканчиваются не в 00:00, а в 03:00 МСК**.

```lua
-- «полночь» стрика = 03:00 МСК  ⇒  id дня = floor((ts + tz - burn_hour*3600) / 86400)
-- МСК = UTC+3, переводов времени нет с 2014  ⇒  03:00 МСК == 00:00 UTC ровно,
-- то есть окно стрика = целые сутки UTC. Проверка закреплена тестом:
-- day_window(d) == d*86400  (при burn_hour=3, tz=10800)
```

Зачем граница в три, а не в ноль: коммит в 01:40 ночи — это ещё «вчера» для
человека, и при полуночной границе он бы либо засчитался завтрашним днём, либо
сжёг вчерашний огонёк на пустом месте. Ночные коммиты — обычное дело, поэтому
сутки кончаются в 03:00.

Как считается:

1. **Источник** — локальный `git log`, ничего не отправляется наружу:
   `git -C <repo> log --pretty=%ct -n 800 --branches [--author=<user.email>]`.
   Timestamps фильтруются в Lua по окну суток (никакого `--since=YYYY-MM-DD`:
   он по-разному трактует пояс и время в разных версиях git). `--branches`,
   а не `--all`: `--all` затягивает `stash` и `origin/*` (чужие коммиты), а
   без него — только HEAD, из-за чего коммит в боковой ветере не засчитывался бы.
   Считаются **локальные** коммиты, до `git push` тоже.
2. **Журнал** — `stdpath("data")/streak.json`: `days[<id дня>] = кол-во коммитов`
   (0 пишется явно: «мы посмотрели и не нашли»), `burned[<id>] = true`, плюс
   `current/best/total/last_day`. Файл — единственная память между запусками;
   ошибка записи не глотается, её видно в `:Streak` («⚠ не сохранилось: …»).
3. **Сгорание** — `melt()` помечает сгоревшими **только дни, про которые мы знаем**,
   что коммитов не было. Это принципиально: наивный проход «от начала журнала до
   сегодня» на свежей машине сжёг бы 400 несуществующих огоньков и показал бы
   `💀 сгорело 400`. Дни, которые nvim не видел вообще (редактор был закрыт),
   помечает `melt_gaps()` — **молча**, без уведомления.
4. **Серия** — `recompute()` идёт назад от сегодня, **если сегодня уже зачтено**,
   и от вчера, **если ещё нет**. «Сегодня пока ноль коммитов» — не обрыв серии:
   серия живёт до 03:00 следующих суток, а не до полуночи (иначе любой утренний
   запуск показывал бы `🔥0` до первого коммита).
5. **Уведомления** — `🔥 Огонёк за … зажжён` (в момент, когда день закрыт) и
   `💀 … огонёк сгорает в 03:00 МСК, а коммита не было. Серия 7 → 0`. Второе
   приходит **ровно в 03:00**, а не «когда повезёт»: на границу ставится
   one-shot `vim.uv`-таймер (`arm_burn_timer`), который после срабатывания
   перевешивается на следующие сутки. Пересчёт идёт **сам**: при коммите или создании
   ветки (fs_event на `.git/logs` и `.git/refs/heads`), при возврате фокуса в nvim и
   после выхода из терминала (lazygit, git в toggleterm). Плановый опрос
   (`check_every`, 5 мин) — только страховка. Как и у telegram-моста, сообщения идут мимо фильтра
   `vim.notify` в `init.lua` (там остаются только ERROR), — напрямую в
   `notify.nvim`/`Snacks.notifier`, иначе `nvim_echo`.

### Команды

| Команда | Что делает |
|---|---|
| `:Hud on\|off\|toggle\|refresh\|debug` | плашка: показать/спрятать/опросить/что он видит |
| `:HudIp lan\|public\|both\|off` | какой IP показывать |
| `:HudClock 12\|24` | формат часов |
| `:HudTz 3` | смещение пояса (3 = МСК, `0` = UTC) |
| `:HudNow` | опросить заново, не ждать таймеров |
| `:Streak` | отчёт: серия, рекорд, сетка последних 14 дней |
| `:Streak sync` / `:Streak reset` | пересчитать сейчас / обнулить журнал |
| `:StreakRepo ~/code/api` | вручную добавить репозиторий (обычно не нужно — находит сам) |
| `:StreakGoal 2` | сколько коммитов зажигают огонёк (минимум 1) |
| `:StreakHour 3` | во сколько МСК кончаются сутки (`0` = классическая полночь) |
| `:StreakNotify off` | не пиликать про огоньки и сгорания |

Сетка дней в `:Streak`: `▇ закрыт · ░ ещё идёт · × сгорел`.

### Клавиши (префикс `<leader>Hu`, группа «🎨 Визуал и UI»)

| Клавиша | Что делает |
|---|---|
| `<leader>Huh` | показать/спрятать плашку |
| `<leader>Huo` | скрыть/показать IP в правом верхнем углу (время и заряд остаются) |
| `<leader>Hud` | диагностика: время, заряд, оба IP, геометрия окна, последняя ошибка |
| `<leader>Hui` | переключатель IP: `lan → public → both → off` |
| `<leader>Huc` | 12/24-часовой формат |
| `<leader>Huk` | отчёт стрика прямо в редакторе (`:Streak`) |

Отдел **TG** (`<leader>m`) с этой же ревизии объявлен прямо в
`lua/plugins/which-key.lua` — отдельной группой со всеми 17 подписями, чтобы на
`<leader>` Telegram был отделом, а не россыпью клавиш (§23). Подписи сделаны
строками **без** `rhs`: в which-key v3 маппинг создаётся только когда задан rhs,
а `desc` без него лишь подписывает уже существующую клавишу. Сами маппинги как
ставил, так и ставит `lua/config/telegram.lua` — дублей не будет.

### Настройка

```lua
require("config.hud").setup({
  enabled = true,
  segments = { time = true, battery = true, ip = true, flames = true },
  ip_mode = "both",          -- lan | public | both | off
  clock = 12,                -- 12 | 24
  tz_offset = 3 * 3600,      -- МСК
  time_every = 15000,        -- мс
  battery_every = 60000,
  ip_every = 600000,         -- публичный IP: раз в 10 минут, не чаще
  low_at = 20,               -- ниже этого заряд краснеет
  margin = 0,
  avoid_overlap = true,      -- уходить, если чужой float налез на угол
  sep = "   ",               -- разделитель сегментов (3 пробела: один «|» сливается с иконками)
})

require("config.streak").setup({
  burn_hour = 3,             -- «полночь» стрика, часов МСК
  tz_offset = 3 * 3600,
  goal = 1,                  -- коммитов в день
  repos = nil,               -- nil = репозиторий этого конфига; остальные находятся сами
  roots = { "~/code", "~/projects", … }, -- где искать репозитории (на 1–2 уровня вглубь)
  watch = true,              -- fs_event на .git: коммит и новая ветка сразу пересчитываются
  debounce_ms = 800,         -- склейка серии событий git
  branch_counts = true,      -- создание ветки за день тоже зажигает огонёк
  author_only = true,        -- считать только свои (по user.email)
  all_branches = true,       -- --branches
  check_every = 300,         -- сек между плановыми проверками
  notify = true,
})
```

### Честные ограничения

* Цвета сегментов — не хардкод, а линки: `HudBatteryOk` → `DiagnosticOk`,
  `HudBatteryLow` → `DiagnosticError`, `HudIp` → `DiagnosticInfo`,
  `HudFlames` → `DiagnosticWarn`, фон `HudNormal` → `NormalFloat`. Поэтому и на
  catppuccin-mocha, и на запасном habamax плашка выглядит в теме, а
  `:hi link HudFlames Title` перекрашивает один огонёк. Краска — extmark-ами по
  байтовым смещениям, и строка с разметкой берутся ОДНИМ вызовом `line()`: два
  раздельных вызова на границе минуты подсвечивали бы «4:0» вместо «4:07».
* `pmset` — только macOS; на Linux — sysfs; на десктопе без батареи сегмента нет.
  «Насколько разряжен мак» таким способом узнаётся за ~10 мс, но только когда nvim
  открыт: цифры за закрытый редактор не копятся.
* Публичный IP — единственный сегмент, которому нужна сеть наружу; при VPN/прокси
  он будет адресом прокси-выхода (это вообще-то правильно), а при недоступности
  `api.ipify.org` показывается последний известный с `~`.
* Стрик считает **коммиты и новые ветки**, а не продуктивность. Репозитории
  находятся сами: открытые файлы, каталог nvim и папки из `roots`. `git log` читается локально,
  офлайн-тоже; `push` не обязателен.
* Состояние живёт в `stdpath("data")/streak.json` — при переносе конфига на другую
  машину его стоит скопировать вместе с `~/.config/tele` (см. INSTALL.md), иначе
  история дней начнётся заново (серия не «украшится», но `best/total` обнулятся).
* `:HudTz 3` и `:StreakHour 3` — про время **в редакторе**; настройки системы не
  трогаются.

---

---

*Документ поддерживается вместе с конфигом; таблица клавиш (§6) регенерируется
харнесом при каждом изменении маппингов.*

## Быстрое перемещение: текст, файлы, вкладки

Все клавиши ниже проверены по `lua/config/keymaps.lua`, `lua/plugins/harpoon.lua`, `lua/plugins/bufferline.lua`,
`lua/plugins/move.lua`, `lua/plugins/flash.lua`, `lua/plugins/snacks.lua`, `lua/plugins/scroll.lua`.
Справка по каждой — `<leader>?` и клавиша. Окна (`<C-h/j/k/l>`) — в разделе «Окна, переходы» ниже.

### По тексту

| Клавиша | Что делает |
|---|---|
| `H` | В начало строки (первый непробельный символ). В визуальном режиме растягивает выделение |
| `L` | В конец строки. В визуальном режиме растягивает выделение |
| `n` / `N` | Следующее / предыдущее совпадение поиска; строка сразу центрируется на экране |
| `s` | Прыжок flash: нажми `s`, набери 1–2 символа, выбери метку |
| `b` / `e` / `ge` | «Умные» слова (spider): учитывают подслова CamelCase и snake_case |
| `<M-H>` / `<M-L>` | Переставить слово влево / вправо (move.nvim) |
| `<M-j>` / `<M-k>` | Перенести строку вниз / вверх (в визуальном — блок) |
| `<C-d>` / `<C-u>` | Полстраницы вниз / вверх, плавно (neoscroll, дефолтные клавиши плагина) |
| `<C-o>` / `<C-i>` | Назад / вперёд по истории переходов (стандартный Vim) |
| `]]` / `[[` | Следующее / предыдущее вхождение слова под курсором (snacks) |
| `{` / `}` | Предыдущий / следующий абзац (стандартный Vim) |

Что сознательно не менялось: `<M-h>`/`<M-l>` — ширина окна, `<C-Up>`/`<C-Down>` — высота окна.
Экранные `H` и `L` (верх и низ окна) заменены на начало и конец строки; середина окна остаётся на `M`.

### По файлам (Harpoon)

| Клавиша | Что делает |
|---|---|
| `<leader>ha` | Добавить текущий файл в список Harpoon |
| `<M-1>` … `<M-4>` | Открыть файл 1–4 из списка (Alt+цифра, одно нажатие) |
| `<leader>h1` … `<leader>h4` | То же через пробел |
| `<leader>hh` | Меню списка (там же можно переставлять и удалять строки) |
| `<leader>ff` | Найти файл (Telescope) |
| `<leader>fr` | Недавние файлы |
| `<leader>e` | Дерево файлов: показать / спрятать |

Пока Harpoon не заполнен, `<M-1>`…`<M-4>` ничего не делают. Заполняй: открой файл и нажми `<leader>ha`.

### По вкладкам (буферам)

| Клавиша | Что делает |
|---|---|
| `Tab` / `Shift+Tab` | Следующая / предыдущая вкладка (bufferline) |
| `]b` / `[b` | То же, удобнее для рук на клавиатуре |
| `<leader>bd` | Закрыть текущую вкладку (буфер) без поломки окон |
| `gt` / `gT` | Стандартные вкладки Vim (страницы-tabpage), не буферы |

### Палитра команд (`<leader><Space>`)

Открывает список всех пользовательских команд `:Имя` с описанием. Команда без аргументов
(например `:Theme`, `:GoIde`) запускается сразу. Команда с аргументами (например `:AiAsk`)
подставляется в командную строку как `:AiAsk ` — дописываешь аргумент и Enter.
Список строится при каждом открытии, поэтому новые команды появляются без правок.
Парные поиски: `<leader>fc` (Telescope: все команды) и `<leader>fk` (Telescope: все клавиши с описаниями).

## Окна, переходы и показ нажатий

| Клавиша | Что делает |
|---|---|
| `<leader>W` | 🪟 Группа «Окна: дерево · код · терминал» (подсказка появляется сразу) |
| `<leader>Wf` | 🌲 Фокус в дерево файлов (открывает, если закрыто) |
| `<leader>Wc` | 💻 Фокус в файл (код): предыдущее окно или первое окно с файлом |
| `<leader>Wt` | 📟 Фокус в терминал toggleterm (открывает снизу, если закрыт) |
| `<leader>Wo` | 🪟 Оставить только текущее окно (`:only`) |
| `<leader>Wx` | ✖ Закрыть текущее окно (`:close`) |
| `<C-h>/<C-j>/<C-k>/<C-l>` | Переход между соседними окнами; в терминал — сразу режим ввода |
| `<C-\><C-n>` | Из терминала в обычный режим, дальше `<C-h/j/k/l>` или `<leader>W*` |
| `<leader>e` | Показать / спрятать дерево файлов |
| `<C-\>` | Открыть / спрятать терминал |
| `<leader>k` | ⌨️ Группа «Показ нажатий» |
| `<leader>kk` или `:KeyShow` | Внизу экрана показывать нажатые клавиши (вкл/выкл) |

Файлы, открытые буферы: `<Tab>` / `<S-Tab>` (bufferline); то же — `[b` / `]b`. Файлы из Harpoon: `<M-1>`…`<M-4>`.
Показ нажатий на весь macOS (вне Neovim) — Hammerspoon.

### Запрос в Firefox
| Клавиша | Что делает |
|---|---|
| `<leader>Ab` | 🦊 Спросить запрос в Neovim и открыть Firefox с ответом |
| `<leader>Ab` (в выделении) | То же, с выделенным текстом в запросе |
| `:Ask текст` | То же из командной строки |

Префиксы сервиса в запросе: `P=текст` или `?P=текст` — Perplexity, `G=текст` или `?G=текст` — Google, `D=` — DuckDuckGo, `C=` — ChatGPT. Без префикса — сервис по умолчанию (Perplexity).

### Темы (7 штук)

| В меню | Имя для `:Theme` | Основа | Плагин |
|---|---|---|---|
| 🆕 Новая | `new` | catppuccin-mocha + оверлей: чёрный фон, палитра пользователя, синее свечение `#0d00ff` | `catppuccin/nvim` |
| 🕰 Старая | `classic` | catppuccin-mocha + прежние цвета (до правок) | `catppuccin/nvim` |
| 🌃 Tokyo Night (night) | `tokyonight` | схема `tokyonight-night` | `folke/tokyonight.nvim` |
| 🟤 Gruvbox | `gruvbox` | схема `gruvbox` | `ellisonleao/gruvbox.nvim` |
| 🌊 Kanagawa (wave) | `kanagawa` | схема `kanagawa-wave` | `rebelot/kanagawa.nvim` |
| 🌙 Rosé Pine (moon) | `rosepine` | схема `rose-pine-moon` | `rose-pine/neovim` |
| 🟦 Carbonfox | `carbonfox` | схема `carbonfox` | `EdenEast/nightfox.nvim` |

| Клавиша / команда | Что делает |
|---|---|
| `<leader>uT` | 🎨 Меню из 7 тем |
| `:Theme <имя>` | Включить тему сразу, например `:Theme tokyonight` |
| `:Theme` | То же меню, что `<leader>uT` |

* Выбор сохраняется в `stdpath("state")/theme.txt` и применяется при старте.
* Пять полных схем — отдельные плагины с `lazy = true`: они грузятся при первом выборе и не замедляют старт.
  На новой машине первый раз — `:Lazy sync`. Если схема не загрузилась, появится ERROR с этой подсказкой.
* Фон у всех тем принудительно чёрный `#000000` (требование пользователя); остальные цвета — из самой схемы.
* «Новая» и «Старая» — оверлеи подсветки поверх catppuccin, сохранены как были.

## GitHub, GitLab и Хабр в Neovim

| Клавиша / команда | Что делает | Нужно один раз |
|---|---|---|
| `<leader>Gh` | `gh dash`: PR и issues GitHub в плавающем терминале | `brew install gh`, `gh auth login`, `gh extension install dlvhdr/gh-dash` |
| `<leader>Gl` | `glab-tui`: merge requests и issues GitLab | `brew install glab`, `glab auth login`, установка glab-tui (github.com/rcieri/glab-tui) |
| `<leader>Gb` / `:Habr` | Список статей Хабра, чтение во вкладке nvim | ничего (нужен `curl`, есть в macOS); `pandoc` по желанию |

* В статье: `q` закрыть вкладку, `o` открыть в браузере.
* Утилита GitLab задаётся в `lua/config/webtools.lua` (`GITLAB_BIN`).
* Проверка на Mac: `:Habr`, затем открыть любую статью; `<leader>Gh` без расширения должен показать команду установки.

---

## 25. Команды (`:`)

Все пользовательские команды, которые создаёт конфиг (через `nvim_create_user_command` и обёртку `def` в `telegram.lua`). Встроенные команды Neovim и команды плагинов (`:Lazy`, `:Mason`, `:Telescope`, `:Trouble`, `:ToggleTerm` и т. п.) сюда не входят — их описания в своих разделах и в `:help`.

| Команда | Что делает | Файл |
|---|---|---|
| `:Ask` | Открыть запрос в Firefox | `browser_ask.lua` |
| `:AiProvider [id]` | Выбрать ИИ-провайдера (без аргумента — меню). Действует на `K`, `:AiAsk`; чат — после перезапуска | `ai_api.lua` |
| `:AiStatus` | Какие ИИ настроены: только имена переменных, значения ключей не показываются | `ai_api.lua` |
| `:AiAsk [вопрос]` | Вопрос выбранному ИИ, ответ в окне (без аргумента — ввод строки) | `ai_api.lua` |
| `:GoIde` | Меню Go IDE (то же, что `<leader>gi`) | `go_ide.lua` |
| `:DiagRu` | Русские подписи ошибок LSP на лету (on \| off \| toggle) | `diag_ru.lua` |
| `:EnvCheck` | — | `init.lua` |
| `:Flex` | Анимация «дождь» из символов (плагин cellular-automaton); то же, что Matrix | `matrix.lua` |
| `:Gloss` | 📖 Английский по словам для диапазона строк | `gloss.lua` |
| `:Habr` | Хабр: лента и чтение статьи | `webtools.lua` |
| `:HoverRu` | Перевод окна подсказки K на русский (on \| off \| toggle) | `hover_ru.lua` |
| `:Hud` | 🕐 плашка в правом верхнем углу (on\|off\|toggle\|refresh\|debug) | `hud.lua` |
| `:HudClock` | 🕐 12 или 24 часа | `hud.lua` |
| `:HudIp` | 🌐 какой IP показывать (lan\|public\|both\|off) или скрыть/показать (hide\|show\|toggle) | `hud.lua` |
| `:HudNow` | 🕐 опросить заново, не waiting таймеры | `hud.lua` |
| `:HudTz` | 🕐 смещение часового пояса (3 = МСК) | `hud.lua` |
| `:KeyShow` | Показ нажатий в Neovim | `keyshow.lua` |
| `:Matrix` | Анимация «дождь» из символов (плагин cellular-automaton) | `matrix.lua` |
| `:NotifyRu` | Русские системные уведомления: сборки, линтеры (on \| off \| toggle) | `notify_ru.lua` |
| `:RuCheck` | — | `init.lua` |
| `:Streak` | 🔥 огонёк за коммиты: отчёт (sync — пересчитать, reset — обнулить) | `streak.lua` |
| `:StreakGoal` | 🔥 сколько коммитов зажигают огонёк | `streak.lua` |
| `:StreakHour` | 🔥 во сколько МСК день считается законченным | `streak.lua` |
| `:StreakNotify` | 🔥 сообщения о огоньках | `streak.lua` |
| `:StreakRepo` | 🔥 вручную добавить репозиторий (обычно не нужно: находит сам) | `streak.lua` |
| `:Theme` | Выбрать тему: new \| classic \| tokyonight \| gruvbox \| kanagawa \| rosepine \| carbonfox (без аргумента — меню) | `themes.lua` |
| `:Tui` | 🧰 Меню TUI-утилит | `tui_tools.lua` |
| `:TuiCheck` | 🩺 Проверка TUI-утилит | `tui_tools.lua` |
| `:Tele` | ✈ tele: full \| panel \| chat \| <имя чата> | `telegram.lua` |
| `:TeleBell` | ✈ гудок терминала на входящее | `telegram.lua` |
| `:TeleChat` | ✈ tele в маленьком окне, сразу на один чат | `telegram.lua` |
| `:TeleChatPick` | ✈ то же, но чат выбирается списком | `telegram.lua` |
| `:TeleCheck` | ✈ что нашлось и что работает | `telegram.lua` |
| `:TeleDb` | ✈ путь к state.db вручную | `telegram.lua` |
| `:TeleDnd` | ✈ режим тишины | `telegram.lua` |
| `:TeleDocs` | ✈ шпаргалка по клавишам и командам | `telegram.lua` |
| `:TeleFocus` | ✈ всплывать только про эти чаты | `telegram.lua` |
| `:TeleFull` | ✈ tele на весь экран | `telegram.lua` |
| `:TeleHide` | ✈ спрятать окно, процесс оставить живым | `telegram.lua` |
| `:TeleIgnore` | ✈ не всплывать про эти чаты | `telegram.lua` |
| `:TeleInbox` | ✈ буфер истории входящих | `telegram.lua` |
| `:TeleKill` | ✈ убить процесс tele | `telegram.lua` |
| `:TeleOpen` | ✈ вернуть окно tele | `telegram.lua` |
| `:TelePanel` | ✈ tele боковой панелью рядом с кодом | `telegram.lua` |
| `:TeleQuiet` | ✈ уведомления только в nvim, без уведомления ОС | `telegram.lua` |
| `:TeleRead` | ✈ прочитать переписку чата, не открывая tele | `telegram.lua` |
| `:TeleReply` | ✈ ответить в tele, не выходя из кода | `telegram.lua` |
| `:TeleReplyLast` | ✈ ответить в чат последнего уведомления | `telegram.lua` |
| `:TeleSend` | ✈ отправить строки/выделение в tele как сообщение | `telegram.lua` |
| `:TeleStart` | ✈ включить слежение за state.db | `telegram.lua` |
| `:TeleStatus` | ✈ краткое состояние | `telegram.lua` |
| `:TeleStop` | ✈ выключить слежение | `telegram.lua` |
| `:TeleTest` | ✈ показать, как будет выглядеть popup | `telegram.lua` |
| `:TeleTheme` | ✈ тема tele в палитре nvim (mocha \| black) | `telegram.lua` |
| `:TeleToggle` | ✈ слежение вкл/выкл | `telegram.lua` |
| `:Chess` | ♟ Шахматы: выбор режима (2 игрока / против ПК, 5 уровней) | `games/chess/ui.lua` |
| `:Snake` | 🐍 Змейка | `games/snake.lua` |
| `:Tetris` | 🧱 Тетрис | `games/tetris.lua` |
| `:Game2048` | 🔢 2048 | `games/game2048.lua` |
| `:Games` | 🎮 Меню игр (выбор через picker) | `config/games.lua` |
| `:SudoWrite` | 💾 Записать файл через sudo (то же, что `<leader>qW`) | `config/sudo_write.lua` |

Всего команд: **61** (из них `:Tele*` — 27; новые: `:Chess`, `:Snake`, `:Tetris`, `:Game2048`, `:Games`, `:SudoWrite`).

---

## 26. Плагины

Плагины, которые объявлены в `lua/plugins/*.lua` (и в `init.lua`). Колонка «В lazy-lock» — есть ли плагин в `lazy-lock.json` (зафиксированная версия).

| Плагин | Для чего | Где объявлен | В lazy-lock |
|---|---|---|---|
| `stevearc/aerial.nvim` | Структура файла (символы) в боковой панели; группа <leader>a | aerial.lua | да |
| `goolord/alpha-nvim` | Стартовый экран при запуске без файла | alpha.lua | да |
| `avante-corp/avante.nvim` | AI-ассистент (avante): вопросы по коду, ИИ-подсказки; группа <leader>A | avante.lua | **нет** |
| `akinsho/bufferline.nvim` | Вкладки открытых буферов сверху; Tab / Shift-Tab переключают | bufferline.lua | да |
| `eandrju/cellular-automaton.nvim` | Развлекательные эффекты: :Matrix и :Flex | matrix.lua | да |
| `hrsh7th/cmp-buffer` | Источник автодополнения из слов буфера | completions.lua | да |
| `hrsh7th/cmp-cmdline` | Автодополнение командной строки (:) | completions.lua | **нет** |
| `hrsh7th/cmp-nvim-lsp` | Источник автодополнения из LSP | completions.lua, lsp-config.lua | да |
| `hrsh7th/cmp-path` | Источник автодополнения путей файлов | completions.lua | да |
| `saadparwaiz1/cmp_luasnip` | Сниппеты LuaSnip в автодополнении | completions.lua | да |
| `olimorris/codecompanion.nvim` | AI-чат и действия над кодом (CodeCompanion), <leader>Hac / Hat | ai.lua | да |
| `nvim-zh/colorful-winsep.nvim` | Подсветка разделителя между окнами | winsep.lua | да |
| `numToStr/Comment.nvim` | Комментирование строк и блоков (gc / gcc) | comment.lua | да |
| `stevearc/conform.nvim` | Форматирование по filetype (форматтеры из языков) | format.lua | да |
| `sindrets/diffview.nvim` | Сравнение веток и коммитов, история файла | diffview.lua | **нет** |
| `ekalinin/Dockerfile.vim` | Подсветка и типы Dockerfile | docker-cli.lua | да |
| `j-hui/fidget.nvim` | Прогресс работы LSP в углу экрана | fidget.lua | да |
| `folke/flash.nvim` | Быстрые прыжки по видимому тексту (s) | flash.lua | да |
| `willothy/flatten.nvim` | Открывает файлы из вложенного nvim в текущем окне | flatten.lua | **нет** |
| `rafamadriz/friendly-snippets` | Готовые сниппеты для многих языков | completions.lua | **нет** |
| `akinsho/git-conflict.nvim` | Разрешение git-конфликтов (своё / чужое / оба) | git-conflict.lua | **нет** |
| `lewis6991/gitsigns.nvim` | Знаки изменений git в колонке, hunks | gitsigns.lua | да |
| `ray-x/go.nvim` | Инструменты Go: сборка, тесты, теги, impl (группа <leader>HG) | go-tools.lua | да |
| `ray-x/guihua.lua` | UI-зависимость go.nvim | go-tools.lua | да |
| `ThePrimeagen/harpoon` | Закладки файлов: ha / hh / h1 / h2 (группа <leader>h) | harpoon.lua | да |
| `giusgad/hologram.nvim` | Картинки в терминале (для питомца) | pets.lua | да |
| `nvimtools/hydra.nvim` | Super Mode: быстрые клавиши после <leader>M | hydra.lua | да |
| `lukas-reineke/indent-blankline.nvim` | Линии отступов | indent.lua | да |
| `anuvyklack/keymap-layer.nvim` | Слой клавиш для hydra | hydra.lua | да |
| `dont-be-evil-company/kulala.nvim` | HTTP-запросы из .http файлов | kulala.lua | да |
| `folke/lazydev.nvim` | Подсказки API Neovim при правке этого конфига | lsp-config.lua | **нет** |
| `kdheepak/lazygit.nvim` | LazyGit внутри Neovim (<leader>gg) | lazygit.lua | да |
| `ray-x/lsp_signature.nvim` | Подсказка сигнатуры функции при наборе аргументов | signature.lua | да |
| `onsails/lspkind.nvim` | Иконки типов в меню автодополнения | completions.lua | **нет** |
| `nvim-lualine/lualine.nvim` | Статусная строка | lualine.lua | да |
| `L3MON4D3/LuaSnip` | Движок сниппетов | completions.lua | да |
| `Bilal2453/luvit-meta` | Описания API libuv для lazydev | lsp-config.lua | **нет** |
| `chentoast/marks.nvim` | Метки на строках (знаки в колонке) | marks.lua | да |
| `mason-org/mason-lspconfig.nvim` | Связка Mason с nvim-lspconfig: какие серверы ставить и включать | lsp-config.lua | да |
| `mason-org/mason.nvim` | Установка LSP-серверов и инструментов | lsp-config.lua | да |
| `ColinKennedy/mega.cmdparse` | Зависимость avante | avante.lua | **нет** |
| `ColinKennedy/mega.logging` | Зависимость avante | avante.lua | **нет** |
| `nvim-mini/mini.ai` | Текстовые объекты: выделение около скобок и кавычек | mini.lua | **нет** |
| `nvim-mini/mini.animate` | Анимации прокрутки и окон (вкл/выкл: <leader>ua) | animate.lua | да |
| `nvim-mini/mini.diff` | Изменения относительно git в буфере (AI-модуль) | ai.lua | да |
| `nvim-mini/mini.surround` | Работа с окружением: скобки, кавычки | mini.lua | **нет** |
| `fedepujol/move.nvim` | Перемещение строк и блоков (Alt-клавиши) | move.lua | да |
| `karb94/neoscroll.nvim` | Плавная прокрутка | scroll.lua | да |
| `nvim-neotest/neotest` | Запуск и панель тестов (<leader>t…) | neotest.lua | да |
| `nvim-neotest/neotest-go` | Адаптер neotest для Go | neotest.lua | да |
| `folke/noice.nvim` | Интерфейс сообщений и командной строки (hover выключен) | noice.lua | да |
| `MunifTanjim/nui.nvim` | UI-компоненты для avante, pets и noice | avante.lua, noice.lua, pets.lua | да |
| `catppuccin/nvim` | Цветовая схема Catppuccin (основа тем «Новая» и «Старая», см. раздел «Темы») | colorscheme.lua | **нет** |
| `folke/tokyonight.nvim` | Полная схема Tokyo Night (`:Theme tokyonight`), грузится лениво при выборе | colorscheme.lua | да |
| `ellisonleao/gruvbox.nvim` | Полная схема Gruvbox (`:Theme gruvbox`), лениво | colorscheme.lua | да |
| `rebelot/kanagawa.nvim` | Полная схема Kanagawa wave (`:Theme kanagawa`), лениво | colorscheme.lua | да |
| `rose-pine/neovim` | Полная схема Rosé Pine moon (`:Theme rosepine`), лениво | colorscheme.lua | да |
| `EdenEast/nightfox.nvim` | Полная схема Carbonfox (`:Theme carbonfox`), лениво | colorscheme.lua | да |
| `windwp/nvim-autopairs` | Автозакрытие скобок и кавычек | autopairs.lua | да |
| `kevinhwang91/nvim-bqf` | Улучшенное окно quickfix | bqf.lua | **нет** |
| `RishabhRD/nvim-cheat.sh` | cheat.sh: шпаргалка по команде (нужен curl и интернет) | cheatsheet.lua | **нет** |
| `hrsh7th/nvim-cmp` | Автодополнение (меню в режиме вставки) | autopairs.lua, completions.lua | да |
| `catgoose/nvim-colorizer.lua` | Подсветка цветов (#hex) в коде | colorizer.lua | да |
| `mfussenegger/nvim-dap` | Отладчик (DAP): <F5>, <F10>, <F11>, <leader>db | dap.lua, docker.lua | да |
| `docker/nvim-dap-docker` | Отладка в Docker-контейнере | docker.lua | да |
| `leoluz/nvim-dap-go` | Отладка Go через delve | dap.lua | да |
| `rcarriga/nvim-dap-ui` | Окна отладчика | dap.lua | да |
| `kevinhwang91/nvim-hlslens` | Номер совпадения при поиске | hlslens.lua | да |
| `gennaro-tedesco/nvim-jqx` | Работа с JSON через jq-подобные запросы | json-pro.lua | да |
| `kosayoda/nvim-lightbulb` | Лампочка в колонке знаков, если для строки есть code action | lightbulb.lua | **нет** |
| `mfussenegger/nvim-lint` | Линтеры по filetype (асинхронно) | lint.lua | **нет** |
| `neovim/nvim-lspconfig` | Готовые конфиги LSP-серверов | lsp-config.lua, navic.lua | да |
| `SmiteshP/nvim-navic` | Путь до текущего символа (хлебные крошки) | navic.lua | да |
| `nvim-neotest/nvim-nio` | Асинхронная библиотека для DAP и neotest | dap.lua, neotest.lua | да |
| `rcarriga/nvim-notify` | Всплывающие уведомления | noice.lua, notify.lua | да |
| `michaelrommel/nvim-silicon` | Красивый PNG-скриншот кода (нужен silicon), <leader>sc | silicon.lua | да |
| `nvim-pack/nvim-spectre` | Поиск и замена по проекту | spectre.lua | да |
| `chrisgrieser/nvim-spider` | Умные w / e / b / ge по подсловам (CamelCase, snake_case) | spider.lua | **нет** |
| `KadoBOT/nvim-spotify` | Управление Spotify из Neovim | spotify.lua | да |
| `nvim-tree/nvim-tree.lua` | Дерево файлов | nvim-tree.lua | да |
| `nvim-treesitter/nvim-treesitter` | Подсветка и разбор кода по дереву (parsers) | aerial.lua, ai.lua, avante.lua, go-tools.lua, markdown.lua, neotest.lua, treesitter.lua, ts-context.lua | да |
| `nvim-treesitter/nvim-treesitter-context` | Липкий заголовок текущей функции сверху | ts-context.lua | да |
| `windwp/nvim-ts-autotag` | Автозакрытие и переименование HTML/JSX-тегов | autotag.lua | да |
| `kevinhwang91/nvim-ufo` | Сворачивание кода (zR, zM, zr, zm, предпросмотр по K) | folding.lua | да |
| `nvim-tree/nvim-web-devicons` | Иконки файлов (нужен Nerd Font) | aerial.lua, alpha.lua, avante.lua, bufferline.lua, lualine.lua, markdown.lua, nvim-tree.lua, snacks.lua, trouble.lua | да |
| `oflisback/obsidian-bridge.nvim` | Связь с Obsidian (синхронизация) | obsidian-bridge.lua | да |
| `epwalsh/obsidian.nvim` | Заметки Obsidian | obsidian.lua | да |
| `folke/persistence.nvim` | Сохранение и восстановление сессий по проекту (<leader>qs) | persistence.lua | да |
| `giusgad/pets.nvim` | Питомец в редакторе (<leader>up, <leader>Hup); собственные виды — `config/pets_custom.lua` | pets.lua | да |
| `nvim-lua/plenary.nvim` | Библиотека-утилиты для других плагинов | ai.lua, avante.lua, diffview.lua, harpoon.lua, lazygit.lua, neotest.lua, obsidian.lua, spectre.lua, telescope.lua, todo.lua | да |
| `epwalsh/pomo.nvim` | Таймер помодоро | pomo.lua | да |
| `RishabhRD/popfix` | Зависимость nvim-cheat.sh | cheatsheet.lua | **нет** |
| `kevinhwang91/promise-async` | Зависимость nvim-ufo | folding.lua | да |
| `HiPhish/rainbow-delimiters.nvim` | Радужная подсветка скобок | rainbow.lua | да |
| `MeanderingProgrammer/render-markdown.nvim` | Оформление markdown прямо в буфере | avante.lua, markdown.lua | да |
| `gen740/SmoothCursor.nvim` | Плавный курсор | smoothcursor.lua | да |
| `folke/snacks.nvim` | Пикеры, dashboard, выбор из списка (vim.ui.select), переименование | avante.lua, snacks.lua | да |
| `michaelb/sniprun` | Запуск выделенного куска кода (<leader>r) | sniprun.lua | да |
| `nvim-telescope/telescope.nvim` | Поиск файлов, текста, буферов | ai.lua, avante.lua, obsidian-bridge.lua, spotify.lua, telescope.lua | да |
| `folke/todo-comments.nvim` | Подсветка TODO / FIXME и поиск по ним | todo.lua | да |
| `akinsho/toggleterm.nvim` | Терминалы: плавающий, снизу, справа; утилиты (<leader>T, <C-\>) | toggleterm.lua | да |
| `uga-rosa/translate.nvim` | Перевод текста (DeepL через DEEPL_API_KEY) | translate.lua | да |
| `David-Kunz/treesitter-unit` | Выделение единиц кода: iu / au | ts-unit.lua | да |
| `Wansmer/treesj` | Разбить/собрать конструкцию одной клавишей | treesj.lua | **нет** |
| `folke/trouble.nvim` | Список ошибок и диагностики (<leader>xx) | trouble.lua | да |
| `tpope/vim-dadbod` | Подключение к базам данных | dadbod-ultimate.lua | да |
| `kristijanhusak/vim-dadbod-completion` | Автодополнение SQL по схеме базы | completions.lua, dadbod-ultimate.lua | да |
| `kristijanhusak/vim-dadbod-ui` | Панель баз данных (DBUI) | dadbod-ultimate.lua | да |
| `itchyny/vim-highlighturl` | Подсветка ссылок | ui-extras.lua | да |
| `RRethy/vim-illuminate` | Подсветка одинаковых слов под курсором | ui-extras.lua | да |
| `szw/vim-maximizer` | Развернуть окно (<leader>Hum), принудительно восстановить (<leader>HuM) | maximizer.lua | да |
| `jeffkreeftmeijer/vim-numbertoggle` | Относительные номера строк в нормальном режиме | numbertoggle.lua | да |
| `mg979/vim-visual-multi` | Несколько курсоров (<C-n>) | visual-multi.lua | **нет** |
| `folke/which-key.nvim` | Всплывающие подсказки клавиш после префикса | which-key.lua | да |
| `folke/zen-mode.nvim` | Режим «дзен» (<leader>z) | zen.lua | да |

Всего репозиториев в спецификациях: **110**. В `lazy-lock.json` записей: **91**.
| `mbbill/undotree` | История правок: дерево undo (<leader>v) | `undotree.lua` | да |
| `nvim-mini/mini.align` | Выравнивание по символу (<leader>=) | `mini-align.lua` | да |

**Не закреплены в lazy-lock.json** (22): `avante-corp/avante.nvim`, `hrsh7th/cmp-cmdline`, `sindrets/diffview.nvim`, `willothy/flatten.nvim`, `rafamadriz/friendly-snippets`, `akinsho/git-conflict.nvim`, `folke/lazydev.nvim`, `onsails/lspkind.nvim`, `Bilal2453/luvit-meta`, `ColinKennedy/mega.cmdparse`, `ColinKennedy/mega.logging`, `nvim-mini/mini.ai`, `nvim-mini/mini.surround`, `catppuccin/nvim`, `kevinhwang91/nvim-bqf`, `RishabhRD/nvim-cheat.sh`, `kosayoda/nvim-lightbulb`, `mfussenegger/nvim-lint`, `chrisgrieser/nvim-spider`, `RishabhRD/popfix`, `Wansmer/treesj`, `mg979/vim-visual-multi`.

Что с этим делать на Mac: открыть `nvim`, выполнить `:Lazy sync` и затем `:Lazy restore`/коммит обновлённого `lazy-lock.json`. Пока lock не обновлён, новые плагины ставятся самой свежей версией и могут отличаться у разных машин.

Записей, которых нет в конфиге (удалённые плагины): `dressing.nvim`, `bufdelete.nvim` — остались в lock-файле, в конфиге не используются.

---

## 27. По технологиям: указатель

Каждая технология — отдельный раздел (§28–§40). Таблицы клавиш собраны из файлов справки `lua/config/keydocs/` (те же записи показывает `<leader>?`). Полный список всех клавиш — §41, всех команд `:` — §25.

| Технология | Раздел | Главные клавиши | Что работает внутри |
|---|---|---|---|
| Go | §28 | `<leader>gt`, `<leader>gb`, `<leader>HGf`, `<leader>db` | gopls, go.nvim, nvim-dap (delve), neotest-go |
| PostgreSQL и другие SQL | §29 | `<leader>Dp` + действие, `<leader>Up`, `<leader>Ul` | vim-dadbod, DBUI, pgcli, lazysql |
| Redis | §30 | `<leader>Ur`, `<leader>Uc` | iredis, redis-cli |
| Docker | §31 | `<leader>dc`, `<leader>dp`, `<leader>Ui` | lazydocker, dive, dockerls, nvim-dap-docker |
| Kubernetes | §32 | `<leader>HGkk`, `<leader>Uk` | k9s, kubectl |
| Kafka | §33 | `<leader>HGak`, `<leader>Ua` | ktea, kafkactl |
| Protobuf и gRPC | §34 | `<leader>Pb`, `<leader>Pl`, `<leader>Pg` | buf, protols |
| HTTP-запросы | §35 | `<leader>rr` | kulala.nvim |
| Git, GitHub, GitLab | §36 | `<leader>gg`, `<leader>Hgs`, `<leader>Gh`, `<leader>Gl` | lazygit, gitsigns, diffview, gh-dash, glab-tui |
| Терминал и TUI-утилиты | §37 | `<leader>Tt`, `<leader>Uu`, `<leader>HUu` | toggleterm, termcmd |
| Переводы и английский | §38 | `K`, `<leader>Kw`, `<leader>tt` | ru_util, gloss, hover_ru |
| ИИ | §39 | `<leader>Aa`, `<leader>Hat`, `<C-s>` в чате | avante, CodeCompanion |
| Мессенджеры | §40 | `<leader>mm`, `<leader>Hyd` | tele, discordo |

---

## 28. Go

**Что стоит.** `gopls` — LSP (ставится через Mason). `ray-x/go.nvim` — единственный спек в `lua/plugins/go-tools.lua`: сборка, тесты, линтер, моки, `if err`, теги для struct, `impl`. Отладка — `nvim-dap` с delve (`dlv`). Тесты под курсором и в файле — `neotest` с адаптером `neotest-go` (`<leader>tr`, `<leader>tf`, `<leader>ts`, `<leader>to`).

**Установка на Mac.**
```
brew install go golangci-lint
go install github.com/go-delve/delve/cmd/dlv@latest
go install golang.org/x/vuln/cmd/govulncheck@latest
```
Остальные утилиты, которые вызывает go.nvim (gomodifytags, impl, iferr, gotests, mockgen), — список в README go.nvim. Проверка: `:checkhealth go` и `:LspInfo` (gopls должен быть подключён).

**Клавиши.**

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>gb` | n | Собрать |
| `<leader>gt` | n | Тесты пакета |
| `<leader>Hgt` | n | Запуск Go-тестов |
| `<leader>gl` | n | Линтер |
| `<leader>gv` | n | Проверить уязвимости |
| `<leader>Hvc` | n | Проверка уязвимостей |
| `<leader>gm` | n | Сгенерировать мок |
| `<leader>Hie` | n | Авто if err |
| `<leader>Hti` | n | Добавить json-теги |
| `<leader>Hj2s` | n | JSON → struct |
| `<leader>Hfs` | n | Заполнить struct |
| `<leader>Him` | n | Сгенерировать impl |
| `<leader>HGS` | n | Формочка struct (выбор из списка) |
| `<leader>HGf` | n | Поля struct'а под курсором |
| `<leader>db` | n | Точка останова |
| `<leader>dt` | n | Отладка теста (Go) |
| `<leader>Hdt` | n | Тест в режиме отладки |
| `<leader>Hdr` | n | Старт/Продолжить |
| `<leader>Hdi` | n | Шаг в |
| `<leader>Hdo` | n | Шаг через |
| `<leader>Hdb` | n | Точка останова |
| `<F5>` | n | Запуск / продолжить (DAP) |
| `<F10>` | n | Шаг через (DAP) |
| `<F11>` | n | Шаг в (DAP) |
| `<leader>tr` | n | Тест под курсором |
| `<leader>tf` | n | Тесты в файле |
| `<leader>ts` | n | Панель тестов |
| `<leader>to` | n | Лог ошибки теста |
**Умный Go (как в VSCode).** `<leader>HGS` — выбор struct из списка и вставка «формочки» со всеми полями; курсор прыгает по значениям через `<Tab>` / `<S-Tab>`, дефолты — нулевые значения Go по типу поля. `<leader>HGf` — то же для struct под курсором. Модули: `lua/config/go_extras.lua`, `lua/config/go_snips.lua`.

**Команды.** `:GoBuild`, `:GoTest`, `:GoTestFunc`, `:GoLint`, `:GoVulnCheck`, `:GoMockGen`, `:GoImpl`, `:GoIfErr`, `:GoJson2Struct` — из go.nvim. Полный список: §25.

**Грабли.**
- Раньше в конфиге был второй спек go.nvim (`go-security.lua`); lazy.nvim склеивал их и терял настройки. Файл удалён, всё в `go-tools.lua`.
- Клавиши `<leader>HGb`, `<leader>HGo`, `<leader>HGl` из старых версий DOCS не существуют. Актуальные — в таблице выше.

---

### GoLand-функции: `<leader>gi` (`lua/config/go_ide.lua`)

Меню `<leader>gi` (зеркало `<leader>HGi`, команда `:GoIde`) — аналог Alt+Enter в GoLand.
Работает только в Go-файлах.

| Клавиша | Что делает | Как работает |
|---|---|---|
| `<leader>gT` | Тест для функции или метода под курсором | через `gotests`, если установлен (`go install github.com/cweill/gotests/gotests@latest`); иначе каркас table-driven теста в `*_test.go` с TODO для значений |
| `<leader>gC` | Конструктор `New<Тип>` для struct | пишет функцию после объявления типа по полям; поля-ключевые слова Go получают `_` (`type` → `type_`) |
| `<leader>gD` | Комментарий-документация | заготовка `// Имя … TODO` над функцией в формате godoc |
| `<leader>ga` | Файл ↔ тест | переходит между исходником и `_test.go`; если теста нет — создаёт с `import "testing"` |
| `<leader>go` | Оптимизировать импорты | gopls: добавить нужные, убрать лишние |
| `<leader>gx` (визуал) | Извлечь выделение | gopls code action: в переменную или функцию |
| `<leader>gr` | Запустить пакет | `go run .` в плавающем терминале |

В меню также собраны уже существующие функции (их не дублируем):
`:GoIfErr` (if err != nil), `:GoImpl` (реализация интерфейса), `:GoAddTag` (теги json/yaml),
формочка struct (`<leader>HGS`), тест под курсором (`<leader>tr`), references (`gr`),
реализации, rename и все действия gopls.

Ограничения: в sandbox нет `go` и `gotests`, поэтому генерацию проверили тестами
на фиктивных узлах treesitter, а не на настоящем Go-файле. Перед использованием
сгенерируй тест и проверь `go test ./...` на Mac.

## 29. PostgreSQL и другие базы (SQL)

Есть три способа работать с базой, они дополняют друг друга.

1. **Каталог `<leader>D`.** Выбираешь СУБД, потом действие. Для PostgreSQL:

| Действие | Клавиша | Что делает |
|---|---|---|
| c | `<leader>Dpc` | 🔌 Подключиться (консоль) |
| r | `<leader>Dpr` | ▶ Выполнить буфер / выделение (SQL) (в визуальном режиме — выделение) |
| t | `<leader>Dpt` | 📋 Список таблиц |
| d | `<leader>Dpd` | 🔍 Описание таблицы |
| n | `<leader>Dpn` | 📄 Новый SQL-буфер с подключением |
| u | `<leader>Dpu` | 🗄 Панель DBUI |
Для остальных СУБД — те же действия под своими буквами (`s` SQLite, `m` MySQL, `o` Oracle, `x` SQL Server, `c` ClickHouse). Полная таблица — §41.

2. **vim-dadbod и панель DBUI.** `<leader>du` (или `<leader>Hdu`) — панель баз. `<leader>Hda` — добавить подключение. `<leader>Hdf` — найти БД, которая относится к текущему буферу. `<leader>Hde` — выполнить запрос. Автодополнение таблиц и колонок — `vim-dadbod-completion`.

3. **Терминальные клиенты** (тоже в плавающем окне, см. §37):
   - `<leader>Up` — pgcli: автодополнение, подсветка, команды `\dt`, `\d имя`, `\q`.
   - `<leader>Ul` — lazysql: TUI-клиент PostgreSQL, MySQL, SQLite, MSSQL. Подключения добавляются внутри.

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>du` | n | Панель БД |
| `<leader>Hdu` | n | Открыть панель БД |
| `<leader>Hda` | n | Добавить подключение |
| `<leader>Hdf` | n | Найти БД буфера |
| `<leader>Hde` | n | Выполнить запрос |
| `<leader>dr` | n | Найти БД буфера |
| `<leader>Up` | n | pgcli — PostgreSQL с автодополнением |
| `<leader>Ul` | n | lazysql — TUI-клиент БД |
| `<leader>HUp` | n | pgcli — PostgreSQL с автодополнением |
| `<leader>HUl` | n | lazysql — TUI-клиент БД |
**Адреса подключений.** Из переменных окружения. Пароли в файлы конфига не пишутся, в адресе пароль указывается в виде `%XX` для спецсимволов (см. `:h dadbod-url`).

| Переменная | Пример |
|---|---|
| `NVIM_DB_PG` | `postgresql://user@localhost/app` |
| `NVIM_DB_MYSQL` | `mysql://user@localhost/app` |
| `NVIM_DB_SQLITE` | `sqlite:./app.db` |
| `NVIM_DB_ORACLE` | `oracle://user:pass@host:1521/service` |
| `NVIM_DB_MSSQL` | `sqlserver://user:pass@host:1433/app` |
| `NVIM_DB_CLICKHOUSE` | `clickhouse://user:pass@host:9000/app` |

Установка на Mac: `brew install libpq` (psql), `brew install pgcli`, `brew install lazysql`. Проверка: `<leader>Uh`.

**Грабли.**
- `<leader>D<СУБД>r` выполняет буфер (обычный режим) или выделение (визуальный режим). Работает только в SQL-буфере.
- `<leader>Dr` без буквы СУБД не назначен. Старые версии DOCS указывали его неверно.

---

## 30. Redis

**Что стоит.** `iredis` — клиент с автодополнением команд и ключей, подсветкой и историей. `redis-cli` — классический клиент. Оба открываются в плавающем окне. В каталог `<leader>D` Redis не входит: это клиент командной строки, а не SQL-база.

**Установка на Mac.**
```
brew install iredis redis        # iredis; redis даёт redis-cli
pipx install iredis              # альтернатива через pipx
```

**Адрес.** Переменная `NVIM_REDIS_URL`, например `redis://localhost:6379/0`. Если её нет — клиенты подключаются к `localhost:6379`.

```
set -Ux NVIM_REDIS_URL "redis://localhost:6379/0"      # fish
```

С паролем в адресе: `set -Ux` записывает значение в `~/.config/fish/fish_variables` — на общей машине это небезопасно. Тогда задай переменную только на сессию (`set -x NVIM_REDIS_URL "redis://:пароль@host:6379/0"`) перед запуском nvim.

**Клавиши.**

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>Ur` | n | iredis — Redis с автодополнением |
| `<leader>Uc` | n | redis-cli — Redis классический |
| `<leader>HUr` | n | iredis — Redis с автодополнением |
| `<leader>HUc` | n | redis-cli — Redis классический |
**Практика.** В iredis и redis-cli `KEYS *` обходит все ключи и блокирует сервер на большой базе. Для просмотра ключей используй `SCAN 0 MATCH user:* COUNT 100`. Выход из iredis — `exit` или `Ctrl-D`, поиск по истории — `Ctrl-R`.

---

## 31. Docker

**Что стоит.** `lazydocker` — TUI: контейнеры, логи, образы, сети. `dive` — слои образа: что добавляет каждый слой и сколько места он занимает. `docker` CLI — в плавающем окне (`ps -a`, `images`, `network ls`). Подсветка `Dockerfile` и `docker-compose` — `Dockerfile.vim`; LSP — `dockerls` (через Mason). Отладка сборки Dockerfile — `docker/nvim-dap-docker` (адаптер `dockerfile`).

Важно: `skanehira/docker.vim` удалён — он не работает в Neovim (падает при старте). Вместо него — lazydocker и кнопки ниже.

**Установка на Mac.**
```
brew install lazydocker dive
```
Нужен запущенный Docker Desktop (или colima). Проверка: `:TuiCheck` (`<leader>Uh`).

**Клавиши.**

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>dc` | n | Docker: lazydocker (TUI) |
| `<leader>dp` | n | Docker: контейнеры |
| `<leader>di` | n | Docker: образы |
| `<leader>dn` | n | Docker: сети |
| `<leader>HGd` | n | 🐳 Docker |
| `<leader>HGdd` | n | lazydocker — TUI Docker |
| `<leader>HGdp` | n | docker ps -a |
| `<leader>HGdi` | n | docker images |
| `<leader>Ud` | n | lazydocker — Docker |
| `<leader>Ui` | n | dive — слои Docker-образа |
| `<leader>HUd` | n | lazydocker — Docker |
| `<leader>HUi` | n | dive — слои Docker-образа |
**Отладка Dockerfile.** Открой Dockerfile, поставь точку останова `<leader>db`, запусти `<F5>`. Конфигурация «Build (Cache-Only)» собирает образ с `-o type=cacheonly`, то есть без записи результата.

---

## 32. Kubernetes

**Что стоит.** `k9s` — TUI кластера: поды, deployments, сервисы, логи, контексты. `kubectl` — в плавающем окне (`get pods`, `config get-contexts`). Нужен kubeconfig: `~/.kube/config` или путь в `KUBECONFIG`.

**Установка на Mac.**
```
brew install derailed/k9s/k9s kubectl
```

**Клавиши.**

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>HGk` | n | ☸ Kubernetes |
| `<leader>HGkk` | n | k9s — TUI кластера |
| `<leader>HGkp` | n | kubectl: поды текущего namespace |
| `<leader>HGkc` | n | kubectl: контексты |
| `<leader>Uk` | n | k9s — Kubernetes |
| `<leader>HUk` | n | k9s — Kubernetes |
**Внутри k9s.** `:ctx` — сменить контекст, `:ns` — namespace, `:pods` — поды. На строке пода: `l` — логи, `d` — описание, `y` — YAML, `s` — shell в контейнер, `?` — все клавиши.

---

## 33. Kafka

**Что стоит.** `ktea` — TUI: топики, consumer-группы, сообщения. `kafkactl` — CLI: `get topics`, `get consumer-groups`, `get brokers`. Адреса брокеров задаются в конфиге самих утилит (см. README `ktea` и `kafkactl`), в конфиг Neovim они не попадают.

**Установка.** ktea — https://github.com/jonas-grgt/ktea. kafkactl — https://github.com/fgrosse/kafkactl. Проверка: `<leader>Uh`.

**Клавиши.**

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>HGa` | n | 📨 Kafka |
| `<leader>HGak` | n | ktea — Kafka TUI |
| `<leader>HGat` | n | kafkactl: топики |
| `<leader>HGag` | n | kafkactl: consumer-группы |
| `<leader>HGab` | n | kafkactl: брокеры |
| `<leader>Ua` | n | ktea — Kafka TUI |
| `<leader>HUa` | n | ktea — Kafka TUI |
---

## 34. Protobuf и gRPC

**Стек.**
- Подсветка и парсер: treesitter `proto`.
- LSP: `protols` (подсказки, диагностика, переходы). Ставится через Mason.
- Форматирование: `buf format` через conform, если LSP не справился — LSP (`lua/plugins/format.lua`).
- Сниппеты: `hdr`, `svc`, `msg`, `rpc`, `enum`, `opt` (LuaSnip, только для `proto`).
- Сборка, линт, кодогенерация — `buf`, в плавающем окне.

**Установка.**
```
brew install bufbuild/buf/buf grpcurl
```
`protolint` ставится через Mason (`:MasonInstall protolint`).

**Клавиши.**

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>Pb` | n | buf build (валидация proto) |
| `<leader>Pl` | n | buf lint (стиль proto) |
| `<leader>Pg` | n | buf generate (codegen) |
**gRPC-запросы** — через kulala, см. §35. `grpcurl` нужен для запросов из терминала (`<leader>Tt`).

---

## 35. HTTP-запросы (kulala)

`kulala.nvim` — REST-клиент внутри Neovim. Файлы `*.http` и `*.rest`. Запрос под курсором запускается `<leader>rr` (в меню — `<leader>Hrr`). Поддерживается gRPC: строка `GRPC http://host:50051/pkg.Service/Method` в `.http`-файле.

В конфиге kulala добавлены аргументы curl `-L -k`. `-k` отключает проверку TLS-сертификата. Это удобно для локальных стендов, но на внешних адресах так лучше не делать: уберите `-k` в `lua/plugins/kulala.lua`.

**Клавиши.**

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>rr` | n | Запустить HTTP-запрос |
| `<leader>Hrr` | n | HTTP-запрос (Kulala) |
---

## 36. Git, GitHub и GitLab

**Локальный git.** `lazygit` — полный TUI. Внутри файла — `gitsigns`: индикаторы, stage/undo hunk, blame, предпросмотр. `diffview` — сравнение и история файла. Конфликты слияния — `git-conflict.nvim`: оставить своё, чужое или оба куска.

**GitHub и GitLab.** `gh-dash` — дашборд PR и issues (`<leader>Gh`). `glab-tui` — merge requests и issues GitLab (`<leader>Gl`). Имя утилиты задаётся в `lua/config/webtools.lua` (`GITLAB_BIN`), по умолчанию `glab-tui`, альтернатива — `gitlab-tui`.

**Установка на Mac.**
```
brew install lazygit gh glab
gh auth login && gh extension install dlvhdr/gh-dash
glab auth login
```
`glab-tui` — https://github.com/rcieri/glab-tui. Токены — только через `gh auth` и `glab auth`, в конфиг они не попадают.

**Клавиши.**

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>gg` | n | LazyGit |
| `<leader>Hgg` | n | LazyGit |
| `<leader>TG` | n | LazyGit в терминале |
| `<leader>Tg` | n | git status в терминале |
| `<leader>Hgs` | n | Stage hunk |
| `<leader>Hgu` | n | Undo stage hunk |
| `<leader>Hgb` | n | Показать автора строки |
| `<leader>Hgh` | n | Предпросмотр изменений |
| `<leader>Hgd` | n | Diff текущего файла |
| `<leader>Hgl` | n | Blame строки вкл/выкл |
| `<leader>Hgf` | n | История файла (Diffview) |
| `<leader>Hgv` | n | Diffview: сравнить изменения |
| `<leader>Hgq` | n | Закрыть Diffview |
| `<leader>Hgmo` | n | Оставить СВОЁ (ours) |
| `<leader>Hgmt` | n | Оставить ЧУЖОЁ (theirs) |
| `<leader>Hgmb` | n | Оставить оба куска |
| `<leader>Hgm0` | n | Убрать оба куска |
| `<leader>Hgmn` | n | Следующий конфликт |
| `<leader>Hgmp` | n | Предыдущий конфликт |
| `<leader>Hgml` | n | Все конфликты в quickfix |
| `<leader>Gh` | n | GitHub: gh dash |
| `<leader>Gl` | n | GitLab: glab-tui |
---

## 37. Терминал и TUI-утилиты

**Два способа открыть терминал.** `toggleterm.nvim`: `<leader>Tt` (плавающий), `<leader>Th` (снизу), `<leader>Tv` (справа), `<C-\>` (открыть/скрыть). Процесс в скрытом терминале продолжает работать.

**Утилиты.** Каждая утилита открывается в плавающем окне внутри Neovim — как Telegram-клиент `tele` (§23). Скрыть окно: та же клавиша (повторное нажатие). Процесс при этом продолжает работать; когда программа завершится сама, окно закроется.

Один терминал на одну команду: номер терминала выдаётся по самой команде. Раньше номера задавались вручную и повторялись (k9s и gh dash оба были 120), из-за этого разные утилиты могли делить один терминал.

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>Tt` | n | Плавающий терминал |
| `<leader>Th` | n | Терминал снизу |
| `<leader>Tv` | n | Терминал справа |
| `<leader>Ta` | n | Показать/скрыть все терминалы |
| `<leader>Tl` | v | Строку в терминал |
| `<leader>Tc` | n | Закрыть все терминалы |
| `<leader>Tg` | n | git status в терминале |
| `<leader>TG` | n | LazyGit в терминале |
**TUI-утилиты (`<leader>U`).** Тот же набор доступен под `<leader>HU` (видно в главном меню `<leader>H`).

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>Uu` | n | Меню всех TUI-утилит |
| `<leader>Uh` | n | Проверка TUI-утилит |
| `<leader>Uk` | n | k9s — Kubernetes |
| `<leader>Ur` | n | iredis — Redis с автодополнением |
| `<leader>Uc` | n | redis-cli — Redis классический |
| `<leader>Up` | n | pgcli — PostgreSQL с автодополнением |
| `<leader>Ul` | n | lazysql — TUI-клиент БД |
| `<leader>Ud` | n | lazydocker — Docker |
| `<leader>Ui` | n | dive — слои Docker-образа |
| `<leader>Ub` | n | btop — монитор ресурсов |
| `<leader>Ua` | n | ktea — Kafka TUI |
Проверка установки всех утилит: `<leader>Uh` или `:TuiCheck`. Меню со всем списком: `<leader>Uu` или `:Tui`. Недостающая утилита не запускается, а показывает команду установки.

---

## 38. Переводы и английский

> Исправлено 2026-10-28: после ответа ИИ окно `K` перерисовывается сразу. Раньше
> разбор грамматики появлялся только после следующего нажатия клавиши.

**Перевод интерфейса и подсказок.** Ошибки LSP, подсказка `K`, уведомления переводятся на русский автоматически: `diag_ru.lua`, `hover_ru.lua`, `notify_ru.lua`. Выключить: `:DiagRu off`, `:HoverRu off`, `:NotifyRu off` или клавиши `<leader>HWd`, `<leader>HWh`, `<leader>HWn`.

**Переводчики.** Цепочка: DeepL (если задан `DEEPL_API_KEY`), затем Google, затем MyMemory. Проверка: `<leader>HWr` или `:RuCheck`.
```
set -Ux DEEPL_API_KEY "..."     # fish; ключ не записывается в конфиг и в git
```

**Английский по словам.** Выдели фразу в визуальном режиме и нажми `K`, или поставь курсор на слово и нажми `<leader>Kw` (то же — `<leader>HKw`). Окно показывает исходный текст, перевод фразы и разбор по словам в виде `- **слово** [транскрипция] — «перевод» (часть речи, грамматика)`. Команда `:Gloss` делает то же для строк диапазона.

С ключом Gemini разбор делает ИИ с учётом всей фразы (`GEMINI_API_KEY` или `AVANTE_GEMINI_API_KEY`, модель — `GEMINI_MODEL`). Без ключа — словарь `dictionaryapi.dev`: транскрипция переводится из IPA таблицей, контекста нет. Текст фразы при этом уходит в Google.

**Клавиши.**

| Клавиша | Режим | Что делает |
|---|---|---|
| `K` | x | Английский по словам |
| `<leader>Kw` | n | Слово под курсором: транскрипция, часть речи, перевод |
| `<leader>HKw` | n | Английский: слово под курсором (то же, что <leader>Kw) |
| `<leader>tt` | n | Перевести слово (ru) |
| `<leader>te` | n | Перевести на английский |
| `<leader>tD` | n | Документация в боковом окне |
| `<leader>HWr` | n | Проверить переводчики |
| `<leader>HWh` | n | Перевод подсказок K вкл/выкл |
| `<leader>HWd` | n | Русские ошибки LSP вкл/выкл |
| `<leader>HWn` | n | Русские уведомления вкл/выкл |
**Переводы в тексте.** `<leader>tt` — перевести слово на русский, `<leader>te` — на английский (`translate.nvim`, DeepL/Google). `<leader>tD` — документация символа в боковом окне.

---

## 39. ИИ

**Инструменты.** `avante.nvim` — чат о коде, правка выделения, карта репозитория (группа `<leader>A`). `CodeCompanion` — чат и действия (группа `<leader>Ha`). Подсказки при наборе — inline-подсказки ИИ в режиме вставки.

**Единая точка входа — `lua/config/ai_api.lua`.** Все ИИ подключены через один модуль:
реестр провайдеров, один способ вызова (OpenAI-совместимый `/chat/completions`),
ключи только из переменных окружения, ничего не пишется в репозиторий.
**Groq** (console.groq.com) — обязательный провайдер этого конфига: быстрый, есть бесплатный тариф.
Перевод `K`, `:AiAsk` и `<leader>Aq` используют выбранного провайдера; avante и CodeCompanion
получают тот же список (в avante — провайдеры из реестра, в CodeCompanion — Groq и «свой сервис»).

**Выбор провайдера.** Порядок: выбор на сессии (`<leader>Ap` или `:AiProvider id`) → переменная
`AI_PROVIDER` → первый провайдер, у которого задан ключ. `:AiStatus` покажет, что настроено.

| id | Переменная с ключом | Модель по умолчанию (переменная модели) |
|---|---|---|
| `groq` | `GROQ_API_KEY` | `openai/gpt-oss-120b` (`GROQ_MODEL`) |
| `gemini` | `AVANTE_GEMINI_API_KEY` или `GEMINI_API_KEY` | `gemini-3.6-flash` (`GEMINI_MODEL`) |
| `openai` | `OPENAI_API_KEY` | `gpt-4o-mini` (`OPENAI_MODEL`) |
| `openrouter` | `OPENROUTER_API_KEY` | `openrouter/free` (`OPENROUTER_MODEL`) |
| `mistral` | `MISTRAL_API_KEY` | `mistral-small-latest` (`MISTRAL_MODEL`) |
| `deepseek` | `DEEPSEEK_API_KEY` | `deepseek-chat` (`DEEPSEEK_MODEL`) |
| `moonshot` (Kimi) | `MOONSHOT_API_KEY` | `moonshot-v1-8k` (`MOONSHOT_MODEL`) |
| `ollama` | не нужен (локально, `localhost:11434`) | `llama3.2` (`OLLAMA_MODEL`) |
| `custom` | `AI_API_KEY` + адрес `AI_BASE_URL` | `AI_MODEL` |

Модель Groq `llama-3.3-70b-versatile` выведена из бесплатного тарифа 16.08.2026, поэтому по умолчанию
стоит `openai/gpt-oss-120b` (рекомендация Groq; `openai/gpt-oss-20b` — быстрее). Модели других
провайдеров по умолчанию в этой версии не сверены с актуальными списками — при ошибке «модель не найдена»
задай свою через переменную модели.

**Переменные окружения (fish: `set -Ux ИМЯ "значение"`).**

| Переменная | Для чего |
|---|---|
| `GROQ_API_KEY` | ключ Groq (обязателен для Groq) |
| `GROQ_MODEL` | модель Groq |
| `AI_PROVIDER` | провайдер по умолчанию (`groq`, `gemini`, `openai`, `custom`…) |
| `AI_BASE_URL`, `AI_API_KEY`, `AI_MODEL` | свой OpenAI-совместимый сервис (`AI_BASE_URL` — с `/v1` на конце) |
| `GEMINI_API_KEY` или `AVANTE_GEMINI_API_KEY` | Gemini (`AVANTE_…` важнее) |
| `GEMINI_MODEL` | модель Gemini |
| `GEMINI_ENDPOINT` | свой ретранслятор Gemini (PROXY.md); путь `…/v1beta/models` преобразуется в `…/v1beta/openai` |
| `GEMINI_PROXY` | прокси для запросов к Gemini (`curl -x`), например `socks5h://127.0.0.1:1080` |
| `GEMINI_INSECURE` | `1` — не проверять сертификат ретранслятора (`curl -k`) |
| `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `MISTRAL_API_KEY`, `DEEPSEEK_API_KEY`, `MOONSHOT_API_KEY` | ключи соответствующих провайдеров |

Ключ не попадает в командную строку curl: он передаётся через stdin (`curl -K -`), поэтому не виден в `ps`.
Ответы об ошибках объясняют причину по-русски (401 — ключ не принят, 429 — лимит, 404 — модель, сеть).

**Перевод по словам `K`** (выдели английский текст → `K`) использует выбранного провайдера и формат
«разбор по словам»; без ключа — словарь + ru_util (§38).

**Клавиши.**

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>Aa` | n | ИИ: чат о коде |
| `<leader>An` | n | ИИ: новый чат |
| `<leader>Ae` | n | ИИ: правка выделения |
| `<leader>Ar` | n | ИИ: обновить окна |
| `<leader>Af` | n | ИИ: фокус на сайдбар |
| `<leader>AS` | n | ИИ: остановить генерацию |
| `<leader>Az` | n | ИИ: дзен-режим |
| `<leader>At` | n | ИИ: сайдбар вкл/выкл |
| `<leader>Ad` | n | ИИ: отладочный режим |
| `<leader>AC` | n | ИИ: окно выбора |
| `<leader>As` | n | ИИ: подсказка вручную |
| `<leader>AR` | n | ИИ: карта репозитория |
| `<leader>Ap` | n | 🤖 Выбрать ИИ-провайдера (меню) |
| `<leader>Aq` | n | 🤖 Быстрый вопрос выбранному ИИ (ответ в окне) |
| `<leader>Ax` | n | Объяснить код/ошибку (ИИ, по умолчанию Gemini) |
| `<leader>Hat` | n | Чат CodeCompanion с выбранным ИИ |
| `<leader>Hai` | n | Действия AI |
| `<leader>Hae` | v | Отправить выделение ИИ |
| `<leader>Hac` | n | Команда в CodeCompanion |
| `<M-l>` | i | Принять подсказку ИИ |
| `<M-]>` | i | Следующая подсказка ИИ |
| `<M-[>` | i | Предыдущая подсказка ИИ |
| `<C-]>` | i | Скрыть подсказку ИИ |
| `<C-s>` | i | Отправить сообщение ИИ |
| `<C-c>` | i | Закрыть чат ИИ |
| `<C-c>` | n | Остановить ответ ИИ |
**Что уходит наружу.** Чат и разбор отправляют код или текст выделения провайдеру. Не выделяй то, что нельзя передавать сторонним сервисам.

---

## 40. Мессенджеры

**Telegram (`tele`).** Консольный клиент, работает в Neovim как окно. Подробно — §23. Клавиши — в таблице ниже.

**Discord (`discordo`).** Клиент Discord в терминале. **Важно:** Discord запрещает клиенты, которые работают от имени пользователя (self-bot). Аккаунт могут заблокировать. Токен не записывай в конфиг: логинься в самом приложении или используй переменную `DISCORDO_TOKEN` на сессию.

**Клавиши.**

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>mm` | n | tele: маленькое окно (float) |
| `<leader>mf` | n | tele: на весь экран |
| `<leader>mp` | n | tele: боковой панелью |
| `<leader>mh` | n | Спрятать окно tele |
| `<leader>mo` | n | Открыть чат последнего уведомления |
| `<leader>mc` | n | Выбрать чат и сесть на него |
| `<leader>mi` | n | История входящих |
| `<leader>mt` | n | Прочитать чат, не открывая tele |
| `<leader>mr` | n | Ответить через tele |
| `<leader>mq` | n | Ответить в чат последнего уведомления |
| `<leader>ms` | v | Отправить выделение в tele |
| `<leader>mS` | n | Отправить текущую строку в tele |
| `<leader>mn` | n | Режим тишины (dnd) |
| `<leader>mb` | n | Гудок вкл/выкл |
| `<leader>md` | n | Диагностика (:TeleCheck) |
| `<leader>mk` | n | Убить процесс tele |
| `<leader>m?` | n | Шпаргалка по telegram-мосту |
| `<leader>Hyd` | n | Discordo — Discord в терминале |
---

## 41. Игры в nvim

Игры открываются в плавающем окне: чёрный фон, синяя рамка (`#0d00ff`), цвета из палитры пользователя. Всё управляется с клавиатуры, мышь не нужна.

| Клавиша | Игра | Команда |
|---|---|---|
| `<leader>Xc` | ♟ Шахматы (2 игрока или против ПК) | `:Chess` |
| `<leader>Xs` | 🐍 Змейка | `:Snake` |
| `<leader>Xt` | 🧱 Тетрис | `:Tetris` |
| `<leader>Xf` | 🔢 2048 | `:Game2048` |
| `<leader>Xm` | 🎮 Меню игр (список через picker) | `:Games` |

Зеркала в главном меню: `<leader>HXc`, `<leader>HXs`, `<leader>HXt`, `<leader>HXf`, `<leader>HXm`.

### Шахматы (`<leader>Xc`)

**Режимы.** При запуске выбираете:
- `👥 Два игрока на одной клавиатуре` — ходят по очереди белые и чёрные.
- `🤖 Против ПК` — затем уровень и цвет.

**Пять уровней ПК:**

| # | Уровень | Как думает |
|---|---|---|
| 1 | Новичок | Случайный легальный ход. |
| 2 | Лёгкий | Смотрит на 1 полуход, оценка с шумом, ошибается. |
| 3 | Средний | Смотрит на 2 полухода. |
| 4 | Сильный | Смотрит на 3 полухода. |
| 5 | Мастер | Смотрит на 4 полухода с «покоем» (доигрывает взятия). Ход занимает около 0,4 с. |

ИИ оценивает материал и положение фигур (таблицы позиции), видит мат в один ход и не отдаёт ферзя даром. Среди равных ходов выбирает случайно, поэтому партии разные.

**Правила — полные.** Ходы всех фигур, рокировка (проверяется, что король не проходит под боем), взятие на проходе, превращение пешки (выбираете фигуру), шах, мат, пат, ничья по правилу 50 ходов, троекратное повторение позиции, ничья при недостатке материала. Сдачи нет: `n` начинает новую партию.

**Управление:**

| Клавиша | Что делает |
|---|---|
| `h` `j` `k` `l` или стрелки | Курсор по доске |
| `Enter` или `Space` | Выбрать свою фигуру; затем — клетку, куда ходить |
| `Esc` | Отменить выбор фигуры (без выбора — закрыть окно) |
| `u` | Отменить ход. Против ПК откатываются два полухода: ваш и ответ ПК |
| `f` | Перевернуть доску |
| `n` | Новая партия (выбор режима заново) |
| `q` | Закрыть окно (партия сохраняется: при следующем `<leader>Xc` она продолжится) |

**Подсветка.** Курсор — фиолетовый, выбранная фигура — оранжевая, куда можно сходить — зелёная, последний ход — голубой, король под шахом — красный. Фигуры: белые — заглавными буквами `K Q R B N P`, чёрные — строчными. Буквы выбраны намеренно: так доска не зависит от того, как терминал рисует Unicode-символы фигур.

**Как проверено.** Генератор ходов сверён с эталонными значениями perft (`tests/chess_perft.py`): стартовая позиция до глубины 4 (197 281 позиция), Kiwipete до глубины 3 (97 862), и ещё три позиции с взятием на проходе, превращениями и рокировками. Отдельно проверены мат и пат. Интерфейс проверен smoke-тестом (`tests/chess_ui_smoke.py`) на заглушке `vim.*`: выбор режима, ход человека, ответ ПК, отмена, превращение. **Живой запуск в nvim в песочнице не выполнялся**: проверьте на Mac.

**Ограничения.** ИИ не знает дебютов и слабее сильных движков (Stockfish). Уровень 5 — это глубина 4 полухода, не больше. Ничья «пятьдесят ходов» и повторение учитываются в партии, но не в поиске ИИ.

### Змейка (`<leader>Xs`)

Голова змейки — гофер 🐹, еда — конфета 🍬. За каждую конфету длина растёт на один сегмент и на один пункт растёт счёт; скорость растёт со счётом (но не быстрее некоторого предела). Разворот на 180° запрещён. Упереться в стену или в себя — конец игры; рекорд сохраняется, пока открыт nvim.

| Клавиша | Что делает |
|---|---|
| `h` `j` `k` `l` или стрелки | Поворот |
| `p` | Пауза |
| `r` | Заново |
| `q` или `Esc` | Выход |

### Тетрис (`<leader>Xt`)

Поле 10×20. Фигуры выдаются «мешком» из семи: каждая появляется один раз за каждые семь. Превью следующей фигуры — справа, тень (где упадёт фигура) — серые точки. Поворот пробует сдвиги влево и вправо у стенки. Очки: 100 / 300 / 500 / 800 за одну, две, три или четыре линии, умножается на уровень. Уровень растёт каждые 10 линий, падение ускоряется.

| Клавиша | Что делает |
|---|---|
| `h` / `l` | Влево / вправо |
| `j` | Мягкое падение (+1 очко) |
| `k` или `x` | Поворот |
| `Space` | Жёсткое падение (+2 очка за клетку) |
| `p` | Пауза |
| `r` | Заново |
| `q` или `Esc` | Выход |

### 2048 (`<leader>Xf`)

Поле 4×4. Сдвиг сдвигает все плитки в сторону; одинаковые плитки при столкновении сливаются в одну (сумма). За один сдвиг каждая плитка сливается не более одного раза. После каждого хода появляется плитка 2 (9 из 10) или 4. Достигли 2048 — можно играть дальше. Ходов нет — конец игры.

| Клавиша | Что делает |
|---|---|
| `h` `j` `k` `l` или стрелки | Сдвиг |
| `u` | Отменить последний ход (один шаг) |
| `r` | Заново |
| `q` или `Esc` | Выход |

**Логика игр** отделена от окна (`lua/games/snake.lua`, `tetris.lua`, `game2048.lua`), поэтому проверяется без nvim: `tests/games_logic.py` (23 проверки: повороты, очистка линий, слияния, столкновения).

**Файлы:** `lua/games/float.lua` (общее окно, палитра), `lua/games/chess/board.lua` (правила), `chess/ai.lua` (ИИ), `chess/ui.lua` (окно шахмат), `lua/config/games.lua` (команды и клавиши).

---

## 42. Питомцы и картинки

### Питомцы (`<leader>up`)

Питомцы — это анимированные картинки поверх окна nvim. Показывает их `hologram.nvim`, а картинки рисует терминал по протоколу Kitty graphics. **Нужна Ghostty** (или Kitty, WezTerm). В Alacritty протокола нет, поэтому питомцы там не появляются. Именно это было причиной прежних проблем с картинками.

`<leader>up` открывает меню: сначала вид и окрас, затем имя. В меню есть штатные виды pets.nvim (собака, попугай, краб, слайм, змея и другие) и наши:

| Клавиша | Питомец | Окрас | Примечание |
|---|---|---|---|
| `<leader>up` | Меню: любой вид и окрас, имя | — | Выбор через список |
| `<leader>ug` | 🐹 Гофер Харек | синий | Талисман Go: синий, с большими зубами, ходит, бегает, спит. |
| `<leader>uy` | 🐱 Нян-кот | классический | Мем: печенье с розовой глазурью и радужный след. |
| `<leader>ut` | 🍞 Тостер | серебристый | Мем: из тостера выскакивает хлеб. |
| `<leader>uG` | 👻 Призрак «бу» | белый | Мем: парит и покачивает подол. |

Прежние клавиши: `<leader>uo` — сон питомца, `<leader>ux` — убрать всех. Зеркала: `<leader>Hup`, `<leader>Hug`, `<leader>Huy`, `<leader>Hut`, `<leader>HuG`.

**Что изменилось у всех питомцев.**
- Кадры анимации теперь идут по порядку номеров (`0`, `1`, `2`…). Раньше плагин читал файлы в случайном порядке, и кадры дёргались. Сортировка подключается в `lua/config/pets_custom.lua` (подмена `utils.listdir`).
- По умолчанию (`:PetsNew`) питомец выбирается из всех видов, включая наши. Раньше по умолчанию была собака.
- Новые виды подключаются автоматически: симлинки `assets/pets/<вид>` попадают в папку плагина, описание поведения (`next_actions`, `movements`) отдаётся через `package.preload`.

**Спрайты.** Кадры нарисованы кодом: `tools/gen_pet_sprites.py` (Python 3, без зависимостей). Каждый кадр — 128×88 px, как у штатных питомцев. Перегенерировать: `python3 tools/gen_pet_sprites.py` из корня репозитория. Для каждого вида есть `idle` (2 кадра), `walk`, `run` (по 4 кадра) и зеркальные `walk_left`, `run_left`. Рисунки простые, в стиле пиксель-арт. Если хотите нарисовать своего питомца — добавьте папку `assets/pets/<вид>/<окрас>/<действие>/0.png…`, плюс строку в `M.custom` в `pets_custom.lua`.

**Если питомец не появился.** Перезапустите nvim после установки pets.nvim (симлинки создаются при запуске). Проверьте, что терминал — Ghostty: `echo $TERM_PROGRAM` внутри него.

### Картинки (`<leader>Ii`, `<leader>If`)

Модуль `snacks.image` показывает картинки в Ghostty (он определяет терминал по переменным окружения).

| Клавиша | Что делает |
|---|---|
| `<leader>Ii` | Показать картинку, путь к которой под курсором, в плавающем окне |
| `<leader>If` | Список картинок проекта (png, jpg, jpeg, gif, webp) через picker |

Зеркала: `<leader>HIi`, `<leader>HIf`. В markdown-файлах картинки показываются внутри текста (нужен парсер markdown из treesitter).

**PNG работает без дополнительных программ. Для jpg, gif и webp нужен ImageMagick:** `brew install imagemagick`. Проверка: `:checkhealth snacks`.

---

## 43. История правок, выравнивание, sudo

Это то, чего раньше в конфиге не хватало. Все клавиши — под `<leader>`.

### История правок (`<leader>v`)

Открывает дерево всех правок файла (`mbbill/undotree`). Ветки видны сразу: когда вы отменили несколько правок и сделали новую, старая ветка не теряется. Подсказка по клавишам — в самом окне undotree. Undo-история сохраняется между запусками (`undofile` включён в `init.lua`). Зеркало: `<leader>HV`.

### Выравнивание по символу (`<leader>=`)

Плагин `nvim-mini/mini.align`. Полезно для таблиц, присваиваний, словарей, комментариев.
- Визуально: выделите строки (`V`), нажмите `<leader>=`, введите символ (например `=`, `:` или `,`). Строки выровняются по нему.
- Обычный режим: `<leader>=` и затем движение: `<leader>=ip` выравнивает абзац.

Стандартный `ga` от mini.align отключён, потому что `ga` в этом конфиге — переход файл ↔ тест для Go (§28).

### Запись через sudo (`<leader>qW`, `:SudoWrite`)

Для файлов, которым нужны права root (например `/etc/hosts`). Команда пишет буфер через `sudo tee`, пароль спрашивает терминал, после записи файл перечитывается с диска. Работает, только если nvim запущен в терминале (не в GUI без tty).

---

## 44. Полный список клавиш

Все клавиши из справки `<leader>?` и клавиши баз данных. Таблица — по группам, с описаниями. Клавиша с `<leader>` — пробел. Режим: `n` обычный, `v` / `x` визуальный, `i` вставка, `t` терминал.

Всего записей справки: **452** (из них клавиши баз данных — 36; 416 остальные: 405 из `lua/config/keydocs/g1…g12` и 11 зеркал `<leader>HU…` из `tui_tools.lua`).

### Игры, картинки, питомцы, история, выравнивание, sudo — 27

| Клавиша | Режим | Что делает | Подробно |
|---|---|---|---|
| `<leader>ug` | n | Гофер Харек | Призывает синего гофера (талисман Go) по имени Харек. Анимация: idle, ходьба, бег, в обе стороны. |
| `<leader>uy` | n | Нян-кот (мем) | Призывает нян-кота: печенье с розовой глазурью и радужный след. Мем. |
| `<leader>ut` | n | Тостер (мем) | Призывает тостер: из него выскакивает хлеб. Мем. |
| `<leader>uG` | n | Призрак «бу» (мем) | Призывает призрака «бу»: парит и покачивает подол. Мем. |
| `<leader>Hug` | n | Гофер Харек | Зеркало <leader>ug. |
| `<leader>Huy` | n | Нян-кот (мем) | Зеркало <leader>uy. |
| `<leader>Hut` | n | Тостер (мем) | Зеркало <leader>ut. |
| `<leader>HuG` | n | Призрак «бу» (мем) | Зеркало <leader>uG. |
| `<leader>Xc` | n | Шахматы | Шахматы в окне: режим «два игрока» или «против ПК» (5 уровней, выбор цвета). Ходы: курсор hjkl, Enter/Space — фигура, затем клетка. u — отмена, f — перевернуть доску, n — новая партия, q — выход. |
| `<leader>Xs` | n | Змейка | Змейка: гофер-голова 🐹 ест конфеты 🍬, длина растёт, скорость растёт со счётом. p — пауза, r — заново. |
| `<leader>Xt` | n | Тетрис | Тетрис 10×20: мешок из 7 фигур, поворот k, Space — падение, очистка линий, уровни. |
| `<leader>Xf` | n | 2048 | 2048: сдвиги hjkl/стрелками, слияние одинаковых плиток, u — отмена хода, r — заново. |
| `<leader>Xm` | n | Меню игр | Выбор игры через список (шахматы, змейка, тетрис, 2048). То же: команда :Games. |
| `<leader>HXc` | n | Шахматы | Зеркало <leader>Xc в главном меню. |
| `<leader>HXs` | n | Змейка | Зеркало <leader>Xs. |
| `<leader>HXt` | n | Тетрис | Зеркало <leader>Xt. |
| `<leader>HXf` | n | 2048 | Зеркало <leader>Xf. |
| `<leader>HXm` | n | Меню игр | Зеркало <leader>Xm. |
| `<leader>Ii` | n | Показать картинку под курсором | Открывает картинку, путь к которой стоит под курсором, в плавающем окне. Ghostty показывает картинку, Alacritty — нет. PNG работает сразу; jpg/gif/webp — нужен ImageMagick (magick). |
| `<leader>If` | n | Найти картинку в проекте | Список картинок проекта (png, jpg, jpeg, gif, webp) через picker Snacks. Enter открывает картинку. |
| `<leader>HIi` | n | Показать картинку под курсором | Зеркало <leader>Ii. |
| `<leader>HIf` | n | Найти картинку в проекте | Зеркало <leader>If. |
| `<leader>v` | n | История правок (undotree) | Дерево всех правок файла: видно ветки отмен. Сохраняется между запусками (undofile). |
| `<leader>HV` | n | История правок (undotree) | Зеркало <leader>v. |
| `<leader>=` | n | Выровнять по символу (оператор) | Оператор mini.align: <leader>= и затем движение, например <leader>=ip — выровнять абзац по символу, который введёте. |
| `<leader>=` | x | Выровнять выделение по символу | В визуальном режиме: выделите строки и нажмите <leader>=, введите символ (например =, : или ,) — строки выровняются по нему. |
| `<leader>qW` | n | Записать через sudo | Сохраняет файл, которому нужны права root (например /etc/hosts). Спросит пароль sudo в терминале. Команда: :SudoWrite. |

### Окна, редактор, складывание, движение, ИИ-hydra, служебные — 48

| Клавиша | Режим | Что делает | Подробно |
|---|---|---|---|
| `<C-h>` | n | Окно слева | Переход в окно слева. Удобно вместо Ctrl-w h. |
| `<C-j>` | n | Окно снизу | Переход в окно снизу (Ctrl-w j). |
| `<C-k>` | n | Окно сверху | Переход в окно сверху (Ctrl-w k). |
| `<C-l>` | n | Окно справа | Переход в окно справа (Ctrl-w l). |
| `<M-h>` | n | Уже | Уменьшает ширину текущего окна на несколько колонок. |
| `<M-l>` | n | Шире | Увеличивает ширину текущего окна на несколько колонок. |
| `<C-Up>` | n | Выше | Увеличивает высоту текущего окна. |
| `<C-Down>` | n | Ниже | Уменьшает высоту текущего окна. |
| `<leader>\|` | n | Вертикальный сплит | Делит окно вертикально: новое окно справа. Ничего не сохраняет и не закрывает. |
| `<leader>-` | n | Горизонтальный сплит | Делит окно горизонтально: новое окно снизу. |
| `<` | v | Отступ влево | В визуальном режиме сдвигает выделенные строки влево на один уровень. Выделение остаётся, можно нажать ещё раз. |
| `>` | v | Отступ вправо | В визуальном режиме сдвигает выделенные строки вправо. Выделение остаётся. |
| `p` | v | Вставить, не затирая регистр | В визуальном режиме вставляет копию, но НЕ кладёт заменённый текст в регистр обмена. Обычный p в визуале затёр бы буфер. |
| `<leader>w` | n | Сохранить | Сохраняет текущий файл (:w). Аналог Cmd+S. |
| `<leader>q` | n | Закрыть окно | Закрывает текущее окно (:q). Если в буфере есть несохранённые изменения, Neovim спросит. |
| `<Esc><Esc>` | t | Выйти в Normal в терминале | В терминале Neovim (toggleterm) переводит в normal-режим, чтобы можно было листать вывод. Обычный Esc в терминале отправляется программе. |
| `<leader>yr` | n | Кольцо буфера обмена (1–9) | Открывает список девяти последних скопированных фрагментов. Enter вставляет выбранный. Сами регистры: "1p … "9p. |
| `zR` | n | Развернуть всё | Раскрывает все свёрнутые блоки в файле (складывание кода). |
| `zM` | n | Свернуть всё | Сворачивает все блоки в файле. |
| `zr` | n | Развернуть, кроме… | Раскрывает уровень складывания на один шаг глубже. |
| `zm` | n | Свернуть блоки | Сворачивает ещё один уровень блоков. |
| `K` | n | Предпросмотр свёрнутого блока | Над свёрнутым блоком показывает его содержимое. Во всех остальных местах K — подсказка LSP (с переводом на русский). |
| `za` | n | Свернуть/развернуть блок | Переключает складывание блока под курсором. |
| `<M-j>` | n | Строку вниз | Переносит текущую строку на одну вниз (plugin move.nvim). |
| `<M-k>` | n | Строку вверх | Переносит текущую строку на одну вверх. |
| `<M-H>` | n | Слово влево | Переносит слово под курсором влево. |
| `<M-L>` | n | Слово вправо | Переносит слово под курсором вправо. |
| `]]` | n | Следующее слово | Переход к следующему упоминанию слова под курсором (snacks.words). |
| `[[` | n | Предыдущее слово | Переход к предыдущему упоминанию слова под курсором. |
| `<leader>?` | n | ❓ Справка по клавише | Открывает справку: нажмите <leader>? и затем клавиши, которые хотите понять. Команда НЕ выполняется, только объясняется. Режим справки (вкл. до Esc) — <leader>?m. |
| `<leader>M` | n | Войти в Super Mode | Включает Hydra-режим: короткие клавиши s/f/g/b (сохранить, файлы, git, буферы) без префикса leader. Выход: q или Esc. |
| `s` | n | Save (в Super Mode) | Внутри Super Mode: сохранить файл. Работает только пока активен Hydra-режим <leader>M. |
| `f` | n | Files (в Super Mode) | Внутри Super Mode: открыть поиск файлов. |
| `g` | n | Git (в Super Mode) | Внутри Super Mode: меню git. |
| `b` | n | Buffers (в Super Mode) | Внутри Super Mode: список буферов. |
| `q` | n | Quit (в Super Mode) | Выход из Super Mode. Обычная q в normal-режиме — запись макроса, не путать. |
| `<Esc>` | n | Quit (в Super Mode) | Выход из Super Mode. |
| `<leader>Wf` | n | Фокус: дерево файлов | Переводит курсор в панель дерева. <leader>e показывает или прячет дерево. Если дерева нет на экране, открывает его и переходит в него. |
| `<leader>Wc` | n | Фокус: файл (код) | Возвращает курсор в окно с кодом: сначала в предыдущее окно, иначе в первое обычное окно с файлом. |
| `<leader>Wt` | n | Фокус: терминал | Переходит в открытый терминал toggleterm (снизу или плавающий). Если терминала нет, открывает его снизу. В терминале сразу включается режим ввода. |
| `<leader>Wo` | n | Оставить только это окно | Закрывает все остальные окна (:only). Буферы не закрываются. |
| `<leader>Wx` | n | Закрыть окно | Закрывает текущее окно (:close). Буфер остаётся открытым. |
| `<leader>kk` | n | Показ нажатий: вкл/выкл | Внизу экрана всплывают последние нажатые клавиши и гаснут примерно через 1.5 с. То же делает :KeyShow. Показ на весь macOS — через Hammerspoon. |
| `<leader>Gh` | n | GitHub: gh dash | Открывает gh dash (дашборд PR и issues) в плавающем терминале. Нужно один раз: gh auth login и gh extension install dlvhdr/gh-dash. Если расширения нет, покажет команду установки. |
| `<leader>Gl` | n | GitLab: glab-tui | Открывает GitLab TUI (merge requests и issues) в плавающем терминале. Нужны glab (brew install glab, glab auth login) и установленный glab-tui (https://github.com/rcieri/glab-tui). Имя утилиты меняется в lua/config/webtools.lua (GITLAB_BIN), можно вернуть gitlab-tui. |
| `<leader>Gb` | n | Хабр: читать статьи | Список свежих статей Хабра из RSS. Выбор статьи открывает её во вкладке Neovim: заголовок, автор, дата и текст. q — закрыть вкладку, o — открыть в браузере. Команда: :Habr. Текст берётся через JSON API Хабра; если установлен pandoc, разметка аккуратнее. |
| `<leader>Ab` | n | Спросить в Firefox | Спрашивает запрос в Neovim и открывает Firefox с ответом (по умолчанию Perplexity, сервис меняется в lua/config/browser_ask.lua). В визуальном режиме подставляет выделенный текст. Команда: :Ask текст. |
| `<leader>uT` | n | Выбрать тему (7 штук) | Меню из 7 цветовых тем: «Новая» (чёрный фон, яркая палитра) и «Старая» (прежние цвета) на catppuccin, плюс 5 полных схем — Tokyo Night, Gruvbox, Kanagawa, Rosé Pine, Carbonfox. Фон у всех чёрный #000000. Полные схемы грузятся при первом выборе. Выбор сохраняется между запусками. То же без меню: :Theme <имя>. |

### Плагины и инструменты — 72

| Клавиша | Режим | Что делает | Подробно |
|---|---|---|---|
| `<leader>a` | n | Структура кода | Боковая панель символов файла (aerial): функции, типы, методы. Переход по Enter. |
| `<leader>aj` | n | Дерево JSON/структура | Показывает структуру JSON-документа деревом (aerial). |
| `<leader>gv` | n | Проверить уязвимости | Go: команда :GoVulnCheck — проверка зависимостей модуля на известные уязвимости (govulncheck). |
| `<leader>gl` | n | Линтер | Go: команда :GoLint — запуск линтера (golangci-lint) по пакету. |
| `<leader>gt` | n | Тесты пакета | Go: запускает тесты текущего пакета (go test). |
| `<leader>gb` | n | Собрать | Go: сборка текущего пакета (go build). Ошибки появятся в списке quickfix. |
| `<leader>gm` | n | Сгенерировать мок | Go: команда :GoMockGen — генерирует мок для интерфейса (mockgen). |
| `<leader>HGS` | n | Формочка struct (выбор из списка) | Go: выбираешь struct из списка буфера — вставляется сниппет с её полями (go_extras.fill_struct). |
| `<leader>HGf` | n | Поля struct'а под курсором | Go: автодополнение полей struct, в которой стоит курсор (go_extras.add_fields). Если struct не найден — как <leader>HGS. |
| `<leader>jx` | n | Список ключей JSON | Показывает все ключи JSON-файла, переход к ключу по Enter. |
| `<leader>jq` | n | jq-запрос по JSON | Запрашивает текст jq-выражения и применяет его к JSON-буферу. Нужен установленный jq. |
| `<leader>gg` | n | LazyGit | Открывает LazyGit в плавающем окне: коммиты, ветки, stage построчно. |
| `<leader>fL` | n | Код потёк! | Пасхалка: запускает анимацию «матрицы» (plugins/matrix.lua). Ничего не меняет в файле. |
| `<leader>e` | n | Дерево файлов (nvim-tree) | Открывает или закрывает боковое дерево файлов проекта. |
| `<leader>up` | n | Питомец: выбрать и призвать | Меню: вид и окрас (гофер, нян-кот, тостер, призрак и штатные), затем имя. Спрайты — картинки: нужна Ghostty. |
| `<leader>uo` | n | Питомец: сон | Усыпляет питомца. |
| `<leader>ux` | n | Убрать питомцев | Убирает всех питомцев. |
| `<leader>pt` | n | Запустить таймер (25м) | Pomodoro: запускает таймер 25 минут на работу. |
| `<leader>ps` | n | Остановить таймер | Pomodoro: останавливает текущий таймер. |
| `<leader>pp` | n | Пауза | Pomodoro: ставит таймер на паузу. |
| `<leader>pr` | n | Снять с паузы | Pomodoro: продолжает таймер после паузы. |
| `<leader>ns` | n | Черновик | Открывает scratch-буфер для заметок, который не сохраняется на диск. |
| `<leader>nS` | n | История черновиков | Показывает прошлые черновики (snacks.scratch) и открывает нужный. |
| `<leader>un` | n | Спрятать уведомления | Скрывает всплывающие уведомления (snacks.notifier) — для режима концентрации. |
| `<leader>sc` | v | Скриншот Silicon | Из выделения делает красивый PNG-скриншот кода (nvim-silicon). Нужен установленный silicon. |
| `<leader>uc` | n | Плавный курсор (вкл/выкл) | Переключает анимацию курсора (smoothcursor). |
| `<leader>S` | n | Поиск и замена во всём проекте | Открывает spectre: поиск и замена по всему проекту с предпросмотром каждого совпадения. |
| `<leader>so` | n | Spotify поиск | Открывает поиск треков в Spotify (nvim-spotify). Нужен spt и подписка. |
| `<leader>sd` | n | Spotify устройства | Показывает список устройств Spotify Connect и выбирает, куда выводить звук. |
| `<leader>sp` | n | Пауза/Плей | Ставит Spotify на паузу или продолжает воспроизведение. |
| `<leader>sn` | n | Вперёд | Следующий трек Spotify. |
| `<leader>sb` | n | Назад | Предыдущий трек Spotify. |
| `<leader>ff` | n | Найти файл | Telescope: быстрый поиск файлов по имени в проекте. |
| `<leader>fg` | n | Поиск по содержимому | Telescope: live grep — ищет текст во всех файлах проекта. |
| `<leader>fb` | n | Буферы | Telescope: список открытых буферов. |
| `<leader>fr` | n | Недавние файлы | Telescope: недавно открытые файлы. |
| `<leader>fh` | n | Поиск по справке | Telescope: поиск по документации Neovim (:help). |
| `<leader>fd` | n | Диагностика проекта | Telescope: все ошибки и предупреждения LSP во всём проекте. |
| `<leader>fk` | n | Все горячие клавиши | Telescope: список всех клавиш Neovim с описаниями (keymaps). |
| `<leader>fc` | n | Все команды | Telescope: список всех команд Neovim. Enter выполняет выбранную. |
| `<leader>Tt` | n | Плавающий терминал | Открывает терминал в плавающем окне. Повторное нажатие — закрыть. |
| `<leader>Th` | n | Терминал снизу | Открывает терминал внизу экрана. |
| `<leader>Tv` | n | Терминал справа | Открывает терминал справа. |
| `<leader>Ta` | n | Показать/скрыть все терминалы | Прячет или показывает все открытые терминалы (toggleterm). |
| `<leader>Tl` | v | Строку в терминал | Отправляет выделенные строки в терминал как команды. |
| `<leader>dc` | n | Docker: lazydocker (TUI) | Запускает lazydocker в плавающем терминале. Нужен установленный lazydocker. |
| `<leader>dp` | n | Docker: контейнеры | Выводит `docker ps` в терминал. |
| `<leader>di` | n | Docker: образы | Выводит список образов (`docker images`). |
| `<leader>dn` | n | Docker: сети | Выводит список сетей Docker (`docker network ls`). |
| `<leader>Pb` | n | buf build (валидация proto) | Protobuf: проверяет .proto через buf build. Нужен установленный buf. |
| `<leader>Pl` | n | buf lint (стиль proto) | Protobuf: проверяет стиль .proto (buf lint). |
| `<leader>Pg` | n | buf generate (codegen) | Protobuf: генерирует код по buf.gen.yaml. |
| `<leader>tt` | n | Перевести слово (ru) | Переводит слово под курсором на русский (plugin translate.nvim). |
| `<leader>te` | n | Перевести на английский | Переводит слово или выделение на английский. |
| `<leader>mm` | n | tele: маленькое окно (float) | Telegram-мост: показывает окно tele плавающим, маленьким. |
| `<leader>mf` | n | tele: на весь экран | Telegram-мост: окно на весь экран. |
| `<leader>mp` | n | tele: боковой панелью | Telegram-мост: окно сбоку, как панель. |
| `<leader>mh` | n | Спрятать окно tele | Закрывает окно tele. Сам мост продолжает работать в фоне. |
| `<leader>mo` | n | Открыть чат последнего уведомления | Открывает чат, из которого пришло последнее уведомление. |
| `<leader>mc` | n | Выбрать чат и сесть на него | Список чатов: выбрать и открыть. |
| `<leader>mi` | n | История входящих | Показывает последние входящие сообщения. |
| `<leader>mt` | n | Прочитать чат, не открывая tele | Выводит историю чата в буфер для чтения. |
| `<leader>mr` | n | Ответить через tele | Открывает ввод ответа в выбранный чат. |
| `<leader>mq` | n | Ответить в чат последнего уведомления | Быстрый ответ в последний чат. |
| `<leader>ms` | v | Отправить выделение в tele | Отправляет выделенный текст в текущий чат tele. |
| `<leader>mS` | n | Отправить текущую строку в tele | Отправляет строку под курсором в чат. |
| `<leader>mn` | n | Режим тишины (dnd) | Включает режим «не беспокоить» для уведомлений tele. |
| `<leader>mb` | n | Гудок вкл/выкл | Включает или выключает звуковой сигнал при новом сообщении. |
| `<leader>md` | n | Диагностика (:TeleCheck) | Проверяет состояние моста tele и выводит отчёт. |
| `<leader>mk` | n | Убить процесс tele | Аварийно останавливает процесс tele, если он завис. |
| `<leader>m?` | n | Шпаргалка по telegram-мосту | Показывает краткую шпаргалку всех команд tele. |
| `<C-\>` | n | Открыть/скрыть терминал | Показывает или прячет плавающий терминал (toggleterm) из любого места. Из терминала тот же выход — <C-\><C-n> в normal-режим. |

### Главное меню <leader>H — 77

| Клавиша | Режим | Что делает | Подробно |
|---|---|---|---|
| `<leader>Hff` | n | Найти файл | Telescope: поиск файла по имени (то же, что <leader>ff). |
| `<leader>Hfg` | n | Live grep | Поиск текста по всему проекту с предпросмотром совпадений. |
| `<leader>Hfb` | n | Открыть буферы | Список открытых буферов для переключения. |
| `<leader>Hfh` | n | Поиск по справке | Поиск по :help Neovim. |
| `<leader>Hfr` | n | Недавние файлы | Файлы, открывавшиеся недавно. |
| `<leader>Hft` | n | TODO/FIXME | Список всех TODO, FIXME, BUG-комментариев проекта (todo-comments). |
| `<leader>Hfk` | n | Все горячие клавиши | Список всех клавиш Neovim с описаниями. Здесь же видно, что делает каждая. |
| `<leader>Hfc` | n | Все команды Neovim | Список всех команд (:команды) с описаниями. |
| `<leader>Hfw` | n | Найти слово под курсором | Поиск слова под курсором по всему проекту. |
| `<leader>Hfm` | n | Метки (marks) | Список закладок (marks) текущего файла и проекта. |
| `<leader>Hgs` | n | Stage hunk | Git: добавляет в индекс (stage) изменённый фрагмент под курсором (gitsigns). |
| `<leader>Hgu` | n | Undo stage hunk | Git: отменяет stage для фрагмента под курсором. |
| `<leader>Hgb` | n | Показать автора строки | Git: показывает, кто и когда изменил строку под курсором (blame). |
| `<leader>Hgh` | n | Предпросмотр изменений | Git: показывает diff изменённого фрагмента в плавающем окне. |
| `<leader>Hgd` | n | Diff текущего файла | Git: сравнение текущего файла с версией из индекса. |
| `<leader>Hgl` | n | Blame строки вкл/выкл | Git: показывает автора строки прямо в конце строки. Повторное нажатие выключает. |
| `<leader>Hgg` | n | LazyGit | Открывает LazyGit в плавающем окне. |
| `<leader>Hgt` | n | Запуск Go-тестов | Go: команда :GoTest (go.nvim). |
| `<leader>Hti` | n | Добавить json-теги | Go: добавляет json-теги к полям структуры (`json:"name"`). |
| `<leader>Hie` | n | Авто if err | Go: вставляет блок `if err != nil { return … }` под текущей строкой. |
| `<leader>Hfs` | n | Заполнить struct | Go: заполняет поля структуры значениями по умолчанию. |
| `<leader>Hj2s` | n | JSON → struct | Go: из вставленного JSON генерирует структуру Go. |
| `<leader>Him` | n | Сгенерировать impl | Go: создаёт заготовку методов, чтобы тип реализовал интерфейс (impl). |
| `<leader>Hvc` | n | Проверка уязвимостей | Go: govulncheck по модулю. |
| `<leader>Hdu` | n | Открыть панель БД | Открывает vim-dadbod-ui: дерево подключений и таблиц. |
| `<leader>Hda` | n | Добавить подключение | Добавляет подключение к базе данных в список DBUI. |
| `<leader>Hdf` | n | Найти БД буфера | Ищет подключение, которое привязано к текущему буферу. |
| `<leader>Hdb` | n | Точка останова | Отладка (DAP): ставит или снимает breakpoint на текущей строке. |
| `<leader>Hdr` | n | Старт/Продолжить | Отладка: запускает программу или продолжает до следующей точки останова. |
| `<leader>Hdi` | n | Шаг в | Отладка: войти в функцию на текущей строке. |
| `<leader>Hdo` | n | Шаг через | Отладка: выполнить строку, не заходя в функции. |
| `<leader>Hdt` | n | Тест в режиме отладки | Отладка: запускает тест под курсором через DAP. |
| `<leader>Has` | n | Показать структуру файла | Открывает структуру (символы) файла в боковой панели (aerial). |
| `<leader>Hos` | n | Поиск заметок | Obsidian: поиск заметок в хранилище. |
| `<leader>Hon` | n | Новая заметка | Obsidian: создаёт новую заметку в хранилище. |
| `<leader>Hof` | n | Перейти по ссылке | Obsidian: открывает ссылку [[…]] под курсором. |
| `<leader>Hot` | n | Тоггл чекбокса | Obsidian: переключает чекбокс задачи [ ] / [x]. |
| `<leader>Htr` | n | Запуск теста под курсором | Neotest: запускает тест, в котором стоит курсор. |
| `<leader>Htf` | n | Запуск всех тестов в файле | Neotest: запускает все тесты текущего файла. |
| `<leader>Hts` | n | Окно со статусом тестов | Neotest: панель со списком тестов и их статусом. |
| `<leader>Hto` | n | Показать вывод ошибки | Neotest: вывод упавшего теста. |
| `<leader>Htn` | n | Следующий тест | Neotest: переход к следующему тесту. |
| `<leader>Hsc` | n | Скриншот кода (Silicon) | Скриншот выделенного кода (то же, что <leader>sc). |
| `<leader>Hrr` | n | HTTP-запрос (Kulala) | Выполняет HTTP-запрос из .http-файла под курсором (kulala). |
| `<leader>Hz` | n | Дзен-режим | Убирает всё лишнее и оставляет один буфер по центру (zen-mode). |
| `<leader>Hum` | n | Развернуть/восстановить окно | Разворачивает текущее окно на весь экран; повторно — восстанавливает. |
| `<leader>Hm` | n | Развернуть/восстановить окно | То же, что <leader>Hum (maximizer). |
| `<leader>Hup` | n | Питомец: выбрать и призвать | Меню питомцев (то же, что <leader>up). |
| `<leader>Hua` | n | Переключить анимации | Включает или выключает анимации mini.animate (переключает vim.g.minianimate_disable). |
| `<leader>Hpt` | n | Старт Pomodoro | Запускает таймер Pomodoro (то же, что <leader>pt). |
| `<leader>Hps` | n | Стоп Pomodoro | Останавливает Pomodoro. |
| `<leader>Huh` | n | HUD: плашка в углу (вкл/выкл) | Прячет или показывает плашку с временем, зарядом и IP. |
| `<leader>Hud` | n | HUD: что он видит | Выводит диагностику HUD: откуда берутся время, заряд, IP. |
| `<leader>Hui` | n | HUD: какой IP | Переключает показ IP: lan → public → both → off. |
| `<leader>Huc` | n | HUD: 12/24-часовой формат | Переключает формат времени в плашке. |
| `<leader>Huk` | n | Огонёк за коммиты (:Streak) | Показывает серию дней с коммитами. |
| `<leader>Hha` | n | Добавить файл в Harpoon | Harpoon: запоминает текущий файл в списке быстрых файлов проекта. |
| `<leader>Hhh` | n | Открыть меню Harpoon | Harpoon: список запомненных файлов, его можно редактировать. |
| `<leader>Hh1` | n | Перейти к 1-му файлу | Harpoon: открывает первый запомненный файл. |
| `<leader>Hh2` | n | Перейти к 2-му файлу | Harpoon: открывает второй запомненный файл. |
| `<leader>Hpl` | n | Открыть Lazy UI | Окно менеджера плагинов Lazy: обновление, установка, ошибки. |
| `<leader>Hpm` | n | Открыть Mason UI | Окно Mason: установка LSP-серверов, линтеров, форматтеров. |
| `<leader>Hpy` | n | Lazy sync (поставить новые плагины) | Ставит, обновляет и удаляет плагины по lazy-lock.json. Нужна после добавления плагинов. |
| `<leader>Hli` | n | LspInfo | Показывает, какие LSP-серверы подключены к буферу и их статус. |
| `<leader>Hch` | n | Checkhealth | Проверяет здоровье Neovim и плагинов, выводит предупреждения. |
| `<leader>Hpc` | n | Чем форматируется файл | Показывает, какой форматтер (conform) применяется к текущему типу файла. |
| `<leader>Hxx` | n | Показать все ошибки (Trouble) | Список ошибок и предупреждений проекта в удобной панели. |
| `<leader>Hxl` | n | Location list | Список location list (ошибки текущего окна) в панели Trouble. |
| `<leader>Hxq` | n | Quickfix list | Список quickfix (результаты grep, сборки) в панели Trouble. |
| `<leader>Hxs` | n | Символы файла (Trouble) | Символы файла (функции, типы) в панели Trouble. |
| `<leader>Hxt` | n | TODO-комментарии (Trouble) | TODO/FIXME в панели Trouble. |
| `<leader>Hnh` | n | Убрать подсветку поиска | Снимает подсветку после поиска (:nohlsearch). |
| `<leader>He` | n | Дерево файлов (nvim-tree) | Открывает или закрывает дерево файлов (то же, что <leader>e). |
| `<leader>Hc` | n | Создать файл/директорию | Группа: создание файлов и папок (см. подсказки which-key). |
| `<leader>Hcf` | n | Дерево: создать файл | В дереве файлов (nvim-tree) клавиша a создаёт файл; этот пункт — подсказка. |
| `<leader>Hcr` | n | Переименовать файл | Переименовывает текущий файл в дереве или буфере. |
| `<leader>Hkl` | n | Поиск по всем шпаргалкам | cheat.sh: список всех доступных шпаргалок. |

### ИИ, терминальные утилиты (K8s/Docker/Kafka/Discord), Git-конфликты, шпаргалки, код — 41

| Клавиша | Режим | Что делает | Подробно |
|---|---|---|---|
| `<leader>Hat` | n | Чат с ИИ | Открывает чат CodeCompanion с выбранным провайдером (по умолчанию Kimi, нужен MOONSHOT_API_KEY; при AI_PROVIDER=groq — Groq, нужен GROQ_API_KEY). |
| `<leader>Hai` | n | Действия AI | Меню действий CodeCompanion: объяснить, исправить, написать тесты. |
| `<leader>Ap` | n | ИИ: выбрать провайдера | Меню провайдеров (Groq, Gemini, OpenAI, OpenRouter, Mistral, DeepSeek, Kimi, Ollama, свой сервис). Ключи — только из окружения. |
| `<leader>Aq` | n | ИИ: быстрый вопрос | Спрашивает выбранный ИИ (как :AiAsk); ответ в окне, q или Esc — закрыть. |
| `<leader>gi` | n | Go IDE: меню | Меню функций в духе GoLand (тесты, конструкторы, файл↔тест, импорты, if err, интерфейсы, теги, запуск, references, rename, code action). Только в Go-файлах. |
| `<leader>HGi` | n | Go IDE: меню (зеркало) | То же меню в группе <leader>HG. |
| `<leader>gT` | n | Go: тест для функции | Тест под курсором в *_test.go: gotests, если установлен, иначе каркас table-driven теста. |
| `<leader>gC` | n | Go: конструктор New… | Для struct под курсором пишет New<Тип>(поля…) после объявления типа. |
| `<leader>gD` | n | Go: документация | Вставляет заготовку комментария godoc над функцией или методом. |
| `<leader>ga` | n | Go: файл ↔ тест | Переход между исходником и _test.go; создаёт тест, если его нет. |
| `<leader>go` | n | Go: импорты | Оптимизирует импорты через gopls. |
| `<leader>gr` | n | Go: запуск пакета | go run . в плавающем терминале. |
| `<leader>gx` | x | Go: извлечь выделение | Извлекает выделенный код в переменную или функцию (gopls code action). |
| `<leader>Hae` | v | Отправить выделение ИИ | Отправляет выделенный код в CodeCompanion (визуальный режим). |
| `<leader>Hac` | n | Команда в CodeCompanion | Команда CodeCompanion: запрос к ИИ, применяется к выделению или строке. |
| `<leader>HGk` | n | ☸ Kubernetes | Группа: инструменты Kubernetes (k9s, kubectl). |
| `<leader>HGkk` | n | k9s — TUI кластера | Открывает k9s в плавающем терминале: поды, сервисы, логи. Нужен k9s и kubeconfig. |
| `<leader>HGkp` | n | kubectl: поды текущего namespace | Выводит `kubectl get pods` в терминал. |
| `<leader>HGkc` | n | kubectl: контексты | Выводит список контекстов kubeconfig (`kubectl config get-contexts`). |
| `<leader>HGd` | n | 🐳 Docker | Группа: инструменты Docker. |
| `<leader>HGdd` | n | lazydocker — TUI Docker | Открывает lazydocker в плавающем терминале. |
| `<leader>HGdp` | n | docker ps -a | Выводит все контейнеры (включая остановленные). |
| `<leader>HGdi` | n | docker images | Выводит список образов. |
| `<leader>HGa` | n | 📨 Kafka | Группа: инструменты Kafka. |
| `<leader>HGak` | n | ktea — Kafka TUI | Открывает ktea: топики, consumer-группы, сообщения. Нужен установленный ktea. |
| `<leader>HGat` | n | kafkactl: топики | Выводит список топиков (`kafkactl get topics`). |
| `<leader>HGag` | n | kafkactl: consumer-группы | Выводит consumer-группы (`kafkactl get consumer-groups`). |
| `<leader>HGab` | n | kafkactl: брокеры | Выводит список брокеров (`kafkactl get brokers`). |
| `<leader>Hyd` | n | Discordo — Discord в терминале | Запускает клиент Discordo. ВНИМАНИЕ: клиенты для личного аккаунта нарушают правила Discord (риск блокировки). Токен не хранится в конфиге. |
| `<leader>Hgv` | n | Diffview: сравнить изменения | Открывает Diffview: все изменённые файлы и их diff. |
| `<leader>Hgf` | n | История файла (Diffview) | История коммитов текущего файла с diff по каждому. |
| `<leader>Hgq` | n | Закрыть Diffview | Закрывает панель Diffview. |
| `<leader>Hgmo` | n | Оставить СВОЁ (ours) | В конфликте слияния оставляет вашу версию (верхний кусок). |
| `<leader>Hgmt` | n | Оставить ЧУЖОЁ (theirs) | В конфликте слияния оставляет входящую версию (нижний кусок). |
| `<leader>Hgmb` | n | Оставить оба куска | В конфликте оставляет обе версии одна за другой. |
| `<leader>Hgm0` | n | Убрать оба куска | В конфликте удаляет оба варианта. |
| `<leader>Hgmn` | n | Следующий конфликт | Переход к следующему конфликту в файле. |
| `<leader>Hgmp` | n | Предыдущий конфликт | Переход к предыдущему конфликту. |
| `<leader>Hgml` | n | Все конфликты в quickfix | Собирает все конфликты проекта в quickfix-список. |
| `<leader>Hkc` | n | Шпаргалка по запросу (cheat.sh) | Спрашивает запрос и показывает шпаргалку cheat.sh в окне, например `tar extract`. |
| `<leader>cj` | n | Разбить/собрать конструкцию | Переключает: однострочный список/аргументы разбивает по строкам, многострочный собирает (treesj). |
| `<leader>cs` | n | Разбить конструкцию на строки | Разбивает список, аргументы или объект по строкам. |
| `<leader>cJ` | n | Собрать конструкцию в одну строку | Собирает многострочную конструкцию в одну строку. |
| `<leader>cl` | n | Линтеры для этого файла | Запускает линтеры (shellcheck, ruff, hadolint и др.), которые установлены в PATH. Отсутствующие тихо пропускаются. |
| `<leader>cf` | n | Форматировать файл | Форматирует буфер через conform (форматтер для типа файла). |
| `<leader>ca` | n | Действия кода | Меню LSP code actions: быстрые исправления и рефакторинги под курсором. Лампочка 💡 в колонке знаков — когда действия доступны. |
| `<leader>Hk` | n | Шпаргалки (cheat.sh) | Группа: шпаргалки cheat.sh. |
| `<leader>Hbr` | n | Кольцо буфера обмена (1–9) | То же, что <leader>yr: выбрать одно из 9 последних копирований. |
| `<leader>Hbm` | n | macOS: инструкция | Открывает macos/README.md: KeyCastr, Hammerspoon, Maccy, соответствие 9 регистров Neovim и 9 записей Maccy. |
| `<leader>Hbk` | n | Экранная клавиатура macOS | Напоминание: клавиатура-оверлей на macOS включается в Hammerspoon сочетанием ⌃⌥⌘K (вне Neovim). |
| `<leader>Hq?` | n | Справка по клавише | То же, что <leader>?: нажмите <leader>?, затем клавиши — покажу, что они делают. Не выполняет команду. |
| `<leader>Hqm` | n | Режим справки вкл/выкл | То же, что <leader>?m: пока режим включён, клавиши объясняются вместо выполнения. |

### Клавиши LSP, диагностика, справка — 20

| Клавиша | Режим | Что делает | Подробно |
|---|---|---|---|
| `gd` | n | К определению | Переход к определению символа под курсором (LSP). |
| `gD` | n | К декларации | Переход к объявлению символа (может отличаться от определения, например в C). |
| `gr` | n | Все ссылки | Список всех мест, где используется символ под курсором. |
| `gi` | n | К реализации | Переход к реализации интерфейса или абстрактного метода. |
| `<leader>rn` | n | Переименовать | Переименовывает символ во всём проекте (LSP rename). |
| `<F2>` | n | Переименовать | То же, что <leader>rn: переименование символа. |
| `<leader>f` | n | Формат (LSP) | Форматирует буфер языковым сервером, если conform не настроен для этого типа файла. |
| `[d` | n | Пред. ошибка | Переход к предыдущей диагностике (ошибке или предупреждению). |
| `]d` | n | След. ошибка | Переход к следующей диагностике. |
| `<leader>d` | n | Диагностика строки | Показывает ошибку под курсором в плавающем окне (с переводом на русский). |
| `<leader>?m` | n | Режим справки (вкл/выкл) | Включает режим справки: нажатие любой назначенной клавиши ОБЪЯСНЯЕТ её, а не выполняет. Выход — Esc или снова <leader>?m. Нужен для «просмотра» всех команд подряд. |
| `<leader>Ax` | n | Объяснить код/ошибку (ИИ, по умолчанию Gemini) | Через avante: объясняет по-русски код или ошибку под курсором. Работает в обычном и визуальном режиме. |
| `<leader>fn` | n | Поиск в Obsidian | Telescope: поиск файлов в хранилище Obsidian (~/obsidian_base). Если папки нет — предупреждение. |
| `<leader>Tg` | n | git status в терминале | Выполняет `git status` в отдельном терминале toggleterm (№9). |
| `<leader>TG` | n | LazyGit в терминале | LazyGit в отдельном терминале toggleterm (№10). Отдельно от <leader>gg. |
| `<C-n>` | n | Несколько курсоров: слово | visual-multi: выделяет следующее совпадение слова под курсором. Повторное нажатие — следующее. Работает и в визуальном режиме. |
| `w` | n | Умное w (подсловами) | spider: переход к следующему «слову» с учётом CamelCase и snake_case (обычное w — только по пробелам). |
| `e` | n | Умное e (подсловами) | spider: конец следующего «слова» с учётом CamelCase и snake_case. |
| `b` | n | Умное b (подсловами) | spider: начало предыдущего «слова» с учётом CamelCase и snake_case. |
| `ge` | n | Умное ge (подсловами) | spider: конец предыдущего «слова» с учётом CamelCase и snake_case. |

### Клавиши, найденные аудитом (заданы в плагинах) — 40

| Клавиша | Режим | Что делает | Подробно |
|---|---|---|---|
| `<leader>bd` | n | Закрыть буфер | Закрывает текущий буфер, не ломая раскладку окон (Snacks.bufdelete). |
| `<leader>db` | n | Точка останова | Ставит или снимает точку останова в текущей строке (nvim-dap). |
| `<leader>dt` | n | Отладка теста (Go) | Запускает ближайший Go-тест под отладчиком (nvim-dap-go). |
| `<leader>du` | n | Панель БД | Открывает или закрывает боковую панель vim-dadbod-ui. |
| `<leader>dr` | n | Найти БД буфера | Открывает в панели БД подключение, которое относится к текущему буферу. |
| `<leader>ft` | n | Найти TODO | Поиск по TODO / FIXME / HACK во всём проекте через Telescope (todo-comments). |
| `<leader>ha` | n | Добавить файл в Harpoon | Запоминает текущий файл в списке Harpoon. |
| `<leader>hh` | n | Меню Harpoon | Окно быстрого переключения между файлами, которые вы отметили в Harpoon. |
| `<leader>h1` | n | Harpoon: файл 1 | Переходит к первому файлу в списке Harpoon. |
| `<leader>h2` | n | Harpoon: файл 2 | Переходит ко второму файлу в списке Harpoon. |
| `<leader>ob` | n | Связь с Obsidian | Включает или выключает мост к заметкам Obsidian (obsidian-bridge). |
| `<leader>qs` | n | Загрузить сессию | Восстанавливает сессию этого проекта: открытые файлы и раскладку окон (persistence). |
| `<leader>r` | v | Запустить выделенный код | SnipRun: выполняет выделенный кусок кода (plugin sniprun). |
| `<leader>rr` | n | Запустить HTTP-запрос | kulala: выполняет HTTP-запрос под курсором в файле *.http. |
| `<leader>tD` | n | Документация в боковом окне | Hover (документация) символа под курсором открывается справа, а не во всплывающем окне. Нужен подключённый LSP. |
| `<leader>tf` | n | Тесты в файле | Запускает все тесты текущего файла (neotest). |
| `<leader>tr` | n | Тест под курсором | Запускает тест под курсором (neotest). |
| `<leader>ts` | n | Панель тестов | Открывает или закрывает панель тестов neotest (IDE-вид). |
| `<leader>to` | n | Лог ошибки теста | Открывает вывод упавшего теста: текст ошибки и трассировку (neotest output). |
| `<leader>ua` | n | Анимации вкл/выкл | Включает или выключает плавную анимацию курсора и прокрутки (mini.animate). |
| `<leader>xx` | n | Список всех ошибок | Открывает панель Trouble со всеми диагностиками проекта. |
| `<leader>z` | n | Дзен-режим | Включает режим без отвлекающих окон: один буфер по центру (zen-mode). |
| `<leader>nh` | n | Убрать подсветку поиска | Выполняет :nohlsearch — гасит подсветку найденных совпадений. |
| `<leader>Aa` | n | ИИ: чат о коде | Avante: спрашивает ИИ о выделенном или текущем коде (агент). |
| `<leader>An` | n | ИИ: новый чат | Avante: начинает новый чат, старый сохраняется. |
| `<leader>Ae` | n | ИИ: правка выделения | Avante: переписывает выделенный код по вашей инструкции. |
| `<leader>Ar` | n | ИИ: обновить окна | Avante: перерисовывает окна чата и подсказок. |
| `<leader>Af` | n | ИИ: фокус на сайдбар | Avante: переводит курсор в боковую панель с чатом. |
| `<leader>AS` | n | ИИ: остановить генерацию | Avante: прерывает текущий ответ модели. |
| `<leader>Az` | n | ИИ: дзен-режим | Avante: включает режим без отвлекающих окон. |
| `<leader>At` | n | ИИ: сайдбар вкл/выкл | Avante: показывает или скрывает боковую панель с чатом. |
| `<leader>Ad` | n | ИИ: отладочный режим | Avante: показывает служебные отладочные окна. |
| `<leader>AC` | n | ИИ: окно выбора | Avante: окно выбора (selection) с контекстом для запроса. |
| `<leader>As` | n | ИИ: подсказка вручную | Avante: вызывает inline-подсказку в текущем месте, не дожидаясь паузы. |
| `<leader>AR` | n | ИИ: карта репозитория | Avante: строит карту файлов и символов проекта для контекста ИИ. |
| `<F5>` | n | Запуск / продолжить (DAP) | Запускает отладку или продолжает выполнение до следующей точки останова. |
| `<F10>` | n | Шаг через (DAP) | Выполняет текущую строку, не заходя внутрь вызываемых функций. |
| `<F11>` | n | Шаг в (DAP) | Заходит внутрь функции в текущей строке. |
| `gcc` | n | Закомментировать строку | Переключает комментарий в текущей строке (comment.nvim). С числом: 5gcc — пять строк. |
| `gc` | v | Закомментировать выделение | В визуальном режиме переключает комментарий у выделенных строк (comment.nvim). |

### Режимы вставки и терминала — 18

| Клавиша | Режим | Что делает | Подробно |
|---|---|---|---|
| `<C-Space>` | i | Автодополнение | Открывает список автодополнения вручную (nvim-cmp). |
| `<C-b>` | i | Документация вверх | Прокручивает окно документации выбранного пункта вверх (nvim-cmp). |
| `<C-f>` | i | Документация вниз | Прокручивает окно документации выбранного пункта вниз (nvim-cmp). |
| `<C-e>` | i | Закрыть автодополнение | Закрывает список автодополнения без вставки (nvim-cmp). |
| `<C-p>` | i | Предыдущий пункт | Перемещает выбор на предыдущий пункт списка автодополнения (nvim-cmp). |
| `<Tab>` | i | Принять подсказку | Принимает inline-подсказку ИИ (Avante) или выбранный пункт автодополнения. |
| `<M-l>` | i | Принять подсказку ИИ | Принимает inline-подсказку Avante напрямую (дубль <Tab>). |
| `<M-]>` | i | Следующая подсказка ИИ | Показывает следующий вариант подсказки Avante. |
| `<M-[>` | i | Предыдущая подсказка ИИ | Показывает предыдущий вариант подсказки Avante. |
| `<C-]>` | i | Скрыть подсказку ИИ | Закрывает inline-подсказку Avante. |
| `<C-s>` | i | Отправить сообщение ИИ | В поле ввода чата Avante отправляет сообщение модели. |
| `<C-c>` | n | Остановить ответ ИИ | В окне чата CodeCompanion прерывает генерацию ответа. |
| `<C-c>` | i | Закрыть чат ИИ | В окне чата CodeCompanion закрывает чат. |
| `<C-\><C-n>` | t | Выход из терминала | Переводит терминал toggleterm в обычный режим, чтобы листать вывод (альтернатива <Esc><Esc>). |
| `<leader>Hde` | n | Выполнить запрос | Выполняет текущий SQL-буфер через vim-dadbod (:%DB). Работает только в буфере с filetype sql. |
| `<leader>Tc` | n | Закрыть все терминалы | Завершает все терминалы toggleterm, включая скрытые. Команды ToggleTermCloseAll в плагине нет, поэтому используется API плагина. |
| `<CR>` | i | Принять автодополнение | Вставляет выбранный пункт меню автодополнения (nvim-cmp). Если меню не открыто — обычный перевод строки. |
| `<C-n>` | i | Следующий пункт автодополнения | В режиме вставки двигает выделение по меню автодополнения вниз (nvim-cmp). |

### Утилиты, огонёк, английский по словам — 23

| Клавиша | Режим | Что делает | Подробно |
|---|---|---|---|
| `<leader>HWr` | n | Проверить переводчики | Показывает, какой переводчик сейчас отвечает: DeepL, Google или MyMemory (:RuCheck). |
| `<leader>HWh` | n | Перевод подсказок K вкл/выкл | Переключает перевод окна подсказки по K на русский (:HoverRu toggle). |
| `<leader>HWd` | n | Русские ошибки LSP вкл/выкл | Переключает перевод сообщений диагностики LSP на русский (:DiagRu toggle). |
| `<leader>HWn` | n | Русские уведомления вкл/выкл | Переключает перевод системных уведомлений Neovim (:NotifyRu toggle). |
| `<leader>HWe` | n | Проверка PATH и утилит | Показывает, видит ли Neovim git, curl, tar и какой PATH у него (:EnvCheck). |
| `<leader>HWm` | n | Дождь из символов | Запускает визуальный эффект «Матрица» из cellular-automaton (:Matrix). |
| `<leader>HWt` | n | Обновить часы и HUD | Немедленно пересчитывает время, заряд и IP в углу (:HudNow). |
| `<leader>HWc` | n | Часы 24 часа | Формат времени в HUD — 24 часа (:HudClock 24). |
| `<leader>HWC` | n | Часы 12 часов | Формат времени в HUD — 12 часов (:HudClock 12). |
| `<leader>HWz` | n | Пояс UTC+3 (МСК) | Часовой пояс HUD = UTC+3, Москва (:HudTz 3). |
| `<leader>HWa` | n | Огонёк без уведомлений | Отключает сообщения о зажжённых и сгоревших огоньках (:StreakNotify off). |
| `<leader>HWA` | n | Огонёк с уведомлениями | Включает сообщения о огоньках (:StreakNotify on). |
| `<leader>HWg` | n | Огонёк: цель 1 в день | Огонёк зажигается от одного коммита или новой ветки за день (:StreakGoal 1). |
| `<leader>HWb` | n | Огонёк: сгорание в 03:00 | Во сколько по Москве день считается законченным (:StreakHour 3). |
| `<leader>Huo` | n | IP в углу: скрыть/показать | Прячет или показывает IP в правом верхнем углу HUD. Время и заряд остаются. Пока IP скрыт, публичный адрес по сети не запрашивается (:HudIp hide / show / toggle). |
| `<leader>HuM` | n | Принудительно вернуть раскладку | vim-maximizer: `!` принудительно ВОССТАНАВЛИВАЕТ сохранённую раскладку окон (а не разворачивает). Обычный разворот — <leader>Hum. |
| `<Tab>` | n | Следующий буфер | bufferline: переключает на следующий открытый буфер (вкладка в верхней строке). |
| `<S-Tab>` | n | Предыдущий буфер | bufferline: переключает на предыдущий открытый буфер. |
| `iu` | x | Внутренняя единица кода (treesitter-unit) | В визуальном режиме выделяет текущую единицу кода под курсором по дереву разбора (treesitter): функцию, аргумент, элемент. Пример: viu. Только визуальный режим; ciu/diu не назначены. |
| `au` | x | Внешняя единица кода (treesitter-unit) | В визуальном режиме выделяет следующий (внешний) узел дерева вокруг текущей единицы. Пример: vau. Плагин требует Neovim 0.12+ и parser для языка. |
| `K` | x | Английский по словам | Выдели фразу или предложение и нажми K. Откроется окно: исходный текст, перевод фразы и разбор по словам в формате «- **слово** [транскрипция] — «перевод» (часть речи, грамматика)». С ключом GEMINI_API_KEY разбор делает ИИ с учётом контекста фразы; без ключа — словарь (без контекста). Выход: q или Esc. |
| `<leader>HKw` | n | Английский: слово под курсором (то же, что <leader>Kw) | Главное меню → английский по словам. То же окно, что <leader>Kw: транскрипция, часть речи, перевод и значение. |
| `<leader>Kw` | n | Слово под курсором: транскрипция, часть речи, перевод | То же окно для слова под курсором: как читается, часть речи, перевод и значение. Удобно для незнакомых слов в тексте, комментариях и документации. Команда :Gloss делает то же для выбранных строк. |

### TUI-утилиты (<leader>U и <leader>HU) — 24

| Клавиша | Режим | Что делает | Подробно |
|---|---|---|---|
| `<leader>HU` | n | Группа: TUI-утилиты (то же, что <leader>U) | Главное меню → TUI-утилиты. Клавиши те же, что у <leader>U: HUk k9s, HUr iredis, HUc redis-cli, HUp pgcli, HUl lazysql, HUd lazydocker, HUi dive, HUb btop, HUa ktea, HUu меню, HUh проверка. |
| `<leader>U` | n | Группа: TUI-утилиты | Группа утилит с терминальным интерфейсом. Каждая открывается в плавающем окне внутри Neovim, как Tele. Закрыть окно — клавиша ещё раз или q; процесс продолжает работать. Список — <leader>Uu. |
| `<leader>Uu` | n | Меню всех TUI-утилит | Выбор утилиты списком. Перед названием: ✓ установлена, ✗ нет (тогда в описании/проверке — как поставить). Та же команда: :Tui. |
| `<leader>Uh` | n | Проверка TUI-утилит | Показывает, какие утилиты установлены, для недостающих — команду установки, и заданы ли переменные подключений NVIM_REDIS_URL и NVIM_DB_PG. Та же команда: :TuiCheck. |
| `<leader>Uk` | n | k9s — Kubernetes | TUI кластера Kubernetes: поды, deployments, сервисы, логи, контексты. Нужен kubeconfig. Клавиши внутри k9s: ? — справка, : — команды (например :pods), l — логи, d — описание, Esc — назад. |
| `<leader>Ur` | n | iredis — Redis с автодополнением | Клиент Redis с подсветкой и автодополнением команд и ключей. Адрес: переменная NVIM_REDIS_URL (например redis://localhost:6379/0), иначе localhost:6379. Выход: exit или Ctrl-D. Поиск по истории — Ctrl-R. |
| `<leader>Uc` | n | redis-cli — Redis классический | Стандартный клиент Redis (из пакета redis). Адрес — NVIM_REDIS_URL. Пример команды: KEYS *, GET key, HGETALL key. Выход: exit. |
| `<leader>Up` | n | pgcli — PostgreSQL с автодополнением | psql с автодополнением таблиц и колонок и подсветкой. Адрес — NVIM_DB_PG (та же переменная, что у <leader>Dp). Команды: \dt (таблицы), \d имя (описание), \q (выход). |
| `<leader>Ul` | n | lazysql — TUI-клиент БД | Клиент баз данных в терминальном окне: PostgreSQL, MySQL, SQLite, MSSQL. Подключения добавляются внутри: a — добавить, e — изменить (в списке подключений). Ctrl+e — SQL-редактор. F10 — проверка обновлений. Хранятся в конфиге lazysql (~/.config/lazysql). |
| `<leader>Ud` | n | lazydocker — Docker | TUI Docker: контейнеры, логи, образы, тома, сети. Клавиши показаны внизу окна. |
| `<leader>Ui` | n | dive — слои Docker-образа | Показывает, из каких слоёв состоит образ и сколько места занимает каждый. Спросит имя образа (например myapp:latest). Tab — переключить слои и дерево файлов, Q или Ctrl-C — выход. |
| `<leader>Ub` | n | btop — монитор ресурсов | Процессы, загрузка CPU, память, диски, сеть в одном окне. Внутри: q — выход, F2 — настройки. |
| `<leader>Ua` | n | ktea — Kafka TUI | Топики, consumer-группы, сообщения Kafka в терминальном окне. Нужен установленный ktea и адрес брокера в его настройках. |
| `<leader>HUu` | n | Меню всех TUI-утилит | Выбор утилиты списком. Перед названием: ✓ установлена, ✗ нет (тогда в описании/проверке — как поставить). Та же команда: :Tui. |
| `<leader>HUh` | n | Проверка TUI-утилит | Показывает, какие утилиты установлены, для недостающих — команду установки, и заданы ли переменные подключений NVIM_REDIS_URL и NVIM_DB_PG. Та же команда: :TuiCheck. |
| `<leader>HUk` | n | k9s — Kubernetes | TUI кластера Kubernetes: поды, deployments, сервисы, логи, контексты. Нужен kubeconfig. Клавиши внутри k9s: ? — справка, : — команды (например :pods), l — логи, d — описание, Esc — назад. |
| `<leader>HUr` | n | iredis — Redis с автодополнением | Клиент Redis с подсветкой и автодополнением команд и ключей. Адрес: переменная NVIM_REDIS_URL (например redis://localhost:6379/0), иначе localhost:6379. Выход: exit или Ctrl-D. Поиск по истории — Ctrl-R. |
| `<leader>HUc` | n | redis-cli — Redis классический | Стандартный клиент Redis (из пакета redis). Адрес — NVIM_REDIS_URL. Пример команды: KEYS *, GET key, HGETALL key. Выход: exit. |
| `<leader>HUp` | n | pgcli — PostgreSQL с автодополнением | psql с автодополнением таблиц и колонок и подсветкой. Адрес — NVIM_DB_PG (та же переменная, что у <leader>Dp). Команды: \dt (таблицы), \d имя (описание), \q (выход). |
| `<leader>HUl` | n | lazysql — TUI-клиент БД | Клиент баз данных в терминальном окне: PostgreSQL, MySQL, SQLite, MSSQL. Подключения добавляются внутри: a — добавить, e — изменить (в списке подключений). Ctrl+e — SQL-редактор. F10 — проверка обновлений. Хранятся в конфиге lazysql (~/.config/lazysql). |
| `<leader>HUd` | n | lazydocker — Docker | TUI Docker: контейнеры, логи, образы, тома, сети. Клавиши показаны внизу окна. |
| `<leader>HUi` | n | dive — слои Docker-образа | Показывает, из каких слоёв состоит образ и сколько места занимает каждый. Спросит имя образа (например myapp:latest). Tab — переключить слои и дерево файлов, Q или Ctrl-C — выход. |
| `<leader>HUb` | n | btop — монитор ресурсов | Процессы, загрузка CPU, память, диски, сеть в одном окне. Внутри: q — выход, F2 — настройки. |
| `<leader>HUa` | n | ktea — Kafka TUI | Топики, consumer-группы, сообщения Kafka в терминальном окне. Нужен установленный ktea и адрес брокера в его настройках. |

### База данных: `<leader>D` + СУБД + действие — 36

| Клавиша | Режим | Что делает |
|---|---|---|
| `<leader>Dsc` | n | 🪶 SQLite: 🔌 Подключиться (консоль) |
| `<leader>Dsr` | n, x | 🪶 SQLite: ▶ Выполнить буфер / выделение (SQL) |
| `<leader>Dst` | n | 🪶 SQLite: 📋 Список таблиц |
| `<leader>Dsd` | n | 🪶 SQLite: 🔍 Описание таблицы |
| `<leader>Dsn` | n | 🪶 SQLite: 📄 Новый SQL-буфер с подключением |
| `<leader>Dsu` | n | 🪶 SQLite: 🗄 Панель DBUI |
| `<leader>Dmc` | n | 🐬 MySQL / MariaDB: 🔌 Подключиться (консоль) |
| `<leader>Dmr` | n, x | 🐬 MySQL / MariaDB: ▶ Выполнить буфер / выделение (SQL) |
| `<leader>Dmt` | n | 🐬 MySQL / MariaDB: 📋 Список таблиц |
| `<leader>Dmd` | n | 🐬 MySQL / MariaDB: 🔍 Описание таблицы |
| `<leader>Dmn` | n | 🐬 MySQL / MariaDB: 📄 Новый SQL-буфер с подключением |
| `<leader>Dmu` | n | 🐬 MySQL / MariaDB: 🗄 Панель DBUI |
| `<leader>Dpc` | n | 🐘 PostgreSQL: 🔌 Подключиться (консоль) |
| `<leader>Dpr` | n, x | 🐘 PostgreSQL: ▶ Выполнить буфер / выделение (SQL) |
| `<leader>Dpt` | n | 🐘 PostgreSQL: 📋 Список таблиц |
| `<leader>Dpd` | n | 🐘 PostgreSQL: 🔍 Описание таблицы |
| `<leader>Dpn` | n | 🐘 PostgreSQL: 📄 Новый SQL-буфер с подключением |
| `<leader>Dpu` | n | 🐘 PostgreSQL: 🗄 Панель DBUI |
| `<leader>Doc` | n | 🏛 Oracle: 🔌 Подключиться (консоль) |
| `<leader>Dor` | n, x | 🏛 Oracle: ▶ Выполнить буфер / выделение (SQL) |
| `<leader>Dot` | n | 🏛 Oracle: 📋 Список таблиц |
| `<leader>Dod` | n | 🏛 Oracle: 🔍 Описание таблицы |
| `<leader>Don` | n | 🏛 Oracle: 📄 Новый SQL-буфер с подключением |
| `<leader>Dou` | n | 🏛 Oracle: 🗄 Панель DBUI |
| `<leader>Dxc` | n | 🟦 SQL Server: 🔌 Подключиться (консоль) |
| `<leader>Dxr` | n, x | 🟦 SQL Server: ▶ Выполнить буфер / выделение (SQL) |
| `<leader>Dxt` | n | 🟦 SQL Server: 📋 Список таблиц |
| `<leader>Dxd` | n | 🟦 SQL Server: 🔍 Описание таблицы |
| `<leader>Dxn` | n | 🟦 SQL Server: 📄 Новый SQL-буфер с подключением |
| `<leader>Dxu` | n | 🟦 SQL Server: 🗄 Панель DBUI |
| `<leader>Dcc` | n | 🏠 ClickHouse: 🔌 Подключиться (консоль) |
| `<leader>Dcr` | n, x | 🏠 ClickHouse: ▶ Выполнить буфер / выделение (SQL) |
| `<leader>Dct` | n | 🏠 ClickHouse: 📋 Список таблиц |
| `<leader>Dcd` | n | 🏠 ClickHouse: 🔍 Описание таблицы |
| `<leader>Dcn` | n | 🏠 ClickHouse: 📄 Новый SQL-буфер с подключением |
| `<leader>Dcu` | n | 🏠 ClickHouse: 🗄 Панель DBUI |

### Быстрое перемещение, палитра команд — 15

| Клавиша | Режим | Что делает | Подробно |
|---|---|---|---|
| `H` | n | В начало строки | Курсор на первый непробельный символ (как `^`). Заменяет экранный H (верх окна). |
| `H` | v | Выделить до начала строки | В визуальном режиме растягивает выделение до первого непробельного символа. |
| `L` | n | В конец строки | Курсор в конец строки (как `$`). Заменяет экранный L (низ окна); середина окна — `M`. |
| `L` | v | Выделить до конца строки | В визуальном режиме растягивает выделение до конца строки. |
| `n` | n | Следующее совпадение (по центру) | Как обычный `n`, но строка центрируется (`zz`) и открывается складка (`zv`). |
| `N` | n | Предыдущее совпадение (по центру) | Как обычный `N`, с центрированием и открытием складки. |
| `<M-1>` | n | Харпун: файл 1 (Alt+1) | Открывает первый файл из списка Harpoon. На Mac работает благодаря `macos-option-as-alt = true`. |
| `<M-2>` | n | Харпун: файл 2 (Alt+2) | Открывает второй файл из списка Harpoon. |
| `<M-3>` | n | Харпун: файл 3 (Alt+3) | Открывает третий файл из списка Harpoon. |
| `<M-4>` | n | Харпун: файл 4 (Alt+4) | Открывает четвёртый файл из списка Harpoon. |
| `<leader>h3` | n | Harpoon: файл 3 | То же, что Alt+3. Добавить файл в список — `<leader>ha`. |
| `<leader>h4` | n | Harpoon: файл 4 | То же, что Alt+4. |
| `]b` | n | Следующая вкладка (буфер) | Переход к следующему буферу — к следующей вкладке в bufferline. |
| `[b` | n | Предыдущая вкладка (буфер) | Переход к предыдущему буферу — к предыдущей вкладке в bufferline. |
| `<leader><Space>` | n | Палитра команд | Список всех пользовательских команд `:Имя` с описанием. Без аргументов — запуск сразу; с аргументами — подстановка `:Имя ` в строку. Новые команды появляются сами. |
