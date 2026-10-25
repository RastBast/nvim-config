# RastBast/nvim-config — ПОЛНАЯ ДОКУМЕНТАЦИЯ

> Ветка: `arena/a58e587f-nvim-config`. Обновлено: **2026-10-16**.
> Целевой Neovim: **0.11+** (конфиг использует `vim.lsp.config` / `vim.lsp.enable`). Для treesitter-unit (`iu`/`au`) нужен Neovim **0.12+**.
> Что проверено и как — §22. Живой запуск nvim в sandbox не выполнялся: поведение проверяется на Mac.
> Размер справки: клавиш с описанием — см. §6, команд — §25, плагинов — §26.

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
11. [HTTP / gRPC-запросы (Kulala)](#11-http--grpc-запросы-kulala)
12. [Терминал](#12-терминал)
13. [Git](#13-git)
14. [Метки (marks.nvim)](#14-метки-marksnvim)
15. [Lua-разработка](#15-lua-разработка)
16. [Визуал и UX](#16-визуал-и-ux)
17. [AI, Obsidian и прочее](#17-ai-obsidian-и-прочее)
18. [LSP / Mason: что ставится](#18-lsp--mason-что-ставится)
19. [Troubleshooting (известные грабли и их лечение)](#19-troubleshooting)
20. [Как расширять конфиг](#20-как-расширять-конфиг)
21. [Дорожная карта: Go-микросервисы](#21-дорожная-карта-go-микросервисы)
22. [Как проверялся конфиг](#22-как-проверялся-конфиг)
23. [Telegram в редакторе (консольный tele)](#23-telegram-в-редакторе-консольный-tele)
24. [🕐 HUD в углу (время МСК, батарея, IP) и 🔥 огонёк за коммиты](#24-hud-в-углу-время-мск-батарея-ip-и-огонёк-за-коммиты)
25. [Команды (`:`)](#25-команды-)
26. [Плагины](#26-плагины)

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
│   ├── themes.lua           — темы «Новая» / «Старая», :Theme, <leader>uT
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

Таблица собрана из исходников конфига 2026-10-16: все `vim.keymap.set`, `keys = {}`, which-key-спеки, клавиши Super Mode, автодополнения, буферные клавиши (telegram, Habr, справка) и клавиши баз данных `<leader>D…`. `<leader>` = пробел.

* Строки «Группа» — префиксы which-key: нажми префикс и увидишь меню.
* Та же справка открывается в nvim: `<leader>?` + клавиша (разовая справка, команда не выполняется), `<leader>?m` — режим справки (клавиши объясняются вместо выполнения, выход — `Esc`). Тексты — `lua/config/keydocs/`.
* Клавиши, которые задаёт сам Vim (`zR`, `za`, `gd` и т. п.), в таблицу не входят, кроме тех, что конфиг переназначил или описал.
* Если добавляешь клавишу — добавь её и в таблицу, и в `keydocs`.

### Нормальный режим (`n`) — клавиши с `<leader>` (пробел)

Строки «Группа» — префиксы which-key: нажми префикс и увидишь меню.

| Клавиша | Что делает | Где задано |
|---|---|---|
| `<leader>A` | **Группа:** 🤖 AI (avante) · 🦊 Firefox | which-key |
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
| `<leader>up` | 🐾 Призвать питомца | `pets` |
| `<leader>uT` | 🎨 Выбрать тему (новая / старая) | `themes` |
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
| `<leader>Ax` | n, v | 🤖 Объяснить код/ошибку (Gemini) | `avante` |
| `<leader>Hac` | n, v | ✨ Команда в CodeCompanion | `ai` |
| `<leader>Hae` | n, v | 📤 Отправить выделение ИИ | `ai` |
| `<leader>Hai` | n, v | 🛠 Действия AI | `ai` |
| `<leader>Hat` | n, v | 💬 Чат с Kimi | `ai` |
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

`<leader>Dr` в визуальном режиме выполняет выделение. Список всех баз: `<leader>D`.

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

LSP — `gopls` (Mason). Поверх — `ray-x/go.nvim` (**единственный** спек, файл
`go-tools.lua`): автоформат `goimports` при сохранении, команды `GoBuild/GoTest/
GoTestFunc/GoLint/GoVulnCheck/GoMockGen/GoImpl/GoIfErr/GoJson2Struct…`.

| Клавиша | Действие |
|---|---|
| `<leader>gb` / `<leader>HGb` | Собрать (`:GoBuild`) |
| `<leader>gt` / `<leader>HGo` | Тесты пакета (`:GoTest`) |
| `<leader>gl` / `<leader>HGl` | golangci-lint (`:GoLint`) |
| `<leader>gv` / `<leader>HGv` | Уязвимости (`:GoVulnCheck`) |
| `<leader>gm` | Моки (`:GoMockGen`) |
| `<leader>HGe` | Авто-if-err (`:GoIfErr`) |
| `<leader>HGj` | JSON → struct (`:GoJson2Struct`) |
| `<leader>HGi` | json-теги на struct |
| `<leader>HGs` | Заполнить struct |
| `<leader>HGm` | `:GoImpl` |

**Умный Go (как в VSCode).** `<leader>HGS` — «формочка»: пикер struct'ов
(красивый через dressing), вставляется сниппет со ВСЕМИ полями, курсор прыгает
по значениям `<Tab>`, дефолты — нулевые значения Go по типу поля.
`<leader>HGf` — то же для struct'а под курсором. Сниппет `gstr` в
автодополнении — динамическая формочка ближайшего struct'а. Описания всех
Go-сниппетов в меню — по-русски (`dstring`). Модули: `lua/config/go_extras.lua`,
`lua/config/go_snips.lua`.

**Английский по словам (учим язык).** Модуль `lua/config/gloss.lua`.
Выдели фразу или предложение в визуальном режиме и нажми `K`. Откроется окно по центру:
1. исходный английский текст;
2. перевод всей фразы;
3. разбор по словам в порядке текста. Для каждого слова: само слово, **транскрипция**
   (как читается, в IPA, например `/rʌn/`), **часть речи**, **перевод слова**, и ниже
   «значение» — первое определение из словаря по-английски и по-русски.

Слово под курсором — `<leader>Kw`. Команда `:Gloss` делает то же для строк диапазона.
Закрыть окно: `q` или `Esc`.

Источники: перевод фразы и слов — `ru_util` (DeepL, если задан `DEEPL_API_KEY`;
иначе Google/MyMemory). Транскрипция, часть речи и значение — бесплатный словарь
`dictionaryapi.dev` (ключа не нужно, нужен `curl`).

Честно о грамматике: это не полный разбор времён и падежей. Часть речи и значение
берутся из словаря; для форм вроде `ran` словарь обычно пишет «past tense of run».
Слова переводятся без контекста фразы («bank» даст «банк»), смысл всей фразы — в
строке «Перевод фразы». За раз разбирается до 40 слов. Если словаря нет (нет сети
или слова там нет), на месте транскрипции и части речи стоит «—»; перевод слова
всё равно показывается.

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

Связка **vim-dadbod + dadbod-ui + dadbod-completion**:

| Клавиша | Действие |
|---|---|
| `<leader>Hdu` / `<leader>Hdt` | Панель БД (открыть / toggle) |
| `<leader>Hda` | Добавить подключение (prompt: `postgres://user@host/db`) |
| `<leader>Hdf` | Автоподключение по БД текущего буфера |

Внутри панели: `dd` — выполнить запрос, автодополнение таблиц/колонок в SQL-буфере.
Quickfix по JSON/SQL — `nvim-jqx` (`<leader>jq`, `<leader>jx` — для JSON).

## 11. HTTP / gRPC / Protobuf (Kulala + proto-стек)

`mistweaverco/kulala.nvim` — RestClient прямо в nvim: файлы `*.http`, `*.rest`.
`<leader>Hur` — выполнить запрос под курсором; поддерживает **gRPC**
(`GRPC http://host:50051/pkg.Service/Method` в .http-файле). Скретчпад — `:KulalaScratchpad`.

### Protobuf: полный стек

| Слой | Что | Где |
|---|---|---|
| Подсветка/парсер | treesitter `proto` | `lua/plugins/treesitter.lua` (ensure) |
| LSP | `protols` (подсказки, диагностика, переходы) | `lua/config/servers.lua` (Mason ставит сам) |
| Форматтер | `buf format` через conform, фолбэк — LSP | `lua/plugins/format.lua` (`proto = { "buf" }`) |
| Линт/сборка/кодоген | `buf lint / build / generate` в плавающем окне | `<leader>Pl / Pb / Pg` (`toggleterm.lua`) |
| Сниппеты | `hdr` `svc` `msg` `rpc` `enum` `opt` | `lua/plugins/completions.lua` (LuaSnip, ft=proto) |
| gRPC-запросы | kulala (`GRPC …` в .http) | `<leader>Hur` |

Внешние бинари (один раз): `:MasonInstall buf protolint` (+ по желанию
`grpcurl` — https://github.com/fullstorydev/grpcurl для запросов из терминала).

## 12. Терминал

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

Отдельно `tele` (Telegram-TUI) живёт не здесь, а в `lua/config/telegram.lua` —
три способа открытия и уведомления внутри редактора, см. §23.

## 13. Git

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
  `SmoothCursor`, `nvim-colorizer`, `vim-illuminate`, `zen-mode` (`<leader>Huz`),
  `maximizer` (`<leader>Hum`), `alpha-nvim` (стартовый экран),
  `cellular-automaton` (`<leader>fL` — «код потёк», пасхалка),
  `pets.nvim` (питомец: `<leader>Hup`, `up/uo/ux`), `nvim-silicon`
  (скриншот кода `<leader>Hus`), `pomo.nvim` (помодоро `<leader>Hut/HuP`, `pt/ps/pp/pr`),
  `translate.nvim` (`<leader>tt/te`), `vim-spotify` (`<leader>so/sd`),
  `vim-numbertoggle`, `vim-highlighturl`, `undotree`-стиль истории через shada.

## 17. AI, Obsidian и прочее

* **AI** — `codecompanion.nvim`: `<leader>Hat` чат, `Hac` команда, `Hae` отправить
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

Файлы, открытые буферы: `<Tab>` / `<S-Tab>` (bufferline).
Показ нажатий на весь macOS (вне Neovim) — Hammerspoon.

### Запрос в Firefox
| Клавиша | Что делает |
|---|---|
| `<leader>Ab` | 🦊 Спросить запрос в Neovim и открыть Firefox с ответом |
| `<leader>Ab` (в выделении) | То же, с выделенным текстом в запросе |
| `:Ask текст` | То же из командной строки |

Префиксы сервиса в запросе: `P=текст` или `?P=текст` — Perplexity, `G=текст` или `?G=текст` — Google, `D=` — DuckDuckGo, `C=` — ChatGPT. Без префикса — сервис по умолчанию (Perplexity).

### Темы
| Клавиша / команда | Что делает |
|---|---|
| `<leader>uT` | 🎨 Меню тем: «Новая» или «Старая» |
| `:Theme new` / `:Theme classic` | Переключить тему из командной строки |

Выбор сохраняется между запусками (`stdpath("state")/theme.txt`).

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

Все пользовательские команды, которые создаёт конфиг (через `nvim_create_user_command`). Встроенные команды Neovim и команды плагинов (`:Lazy`, `:Mason`, `:Telescope`, `:Trouble`, `:ToggleTerm` и т. п.) сюда не входят — их описания в своих разделах и в `:help`.

| Команда | Что делает | Файл |
|---|---|---|
| `:EnvCheck` | Показать git/curl/tar и PATH этого nvim | `init.lua` |
| `:RuCheck` | Проверить доступность переводчиков (перевод ошибок/подсказок) | `init.lua` |
| `:Ask` | Открыть запрос в Firefox | `browser_ask.lua` |
| `:DiagRu` | — | `diag_ru.lua` |
| `:HoverRu` | — | `hover_ru.lua` |
| `:Gloss` | 📖 разбор по словам для выделенных строк (диапазон, например `:'<,'>Gloss`) | `gloss.lua` |
| `:Hud` | 🕐 плашка в правом верхнем углу (on\|off\|toggle\|refresh\|debug) | `hud.lua` |
| `:HudIp` | 🌐 какой IP показывать (lan\|public\|both\|off) или скрыть/показать (hide\|show\|toggle) | `hud.lua` |
| `:HudClock` | 🕐 12 или 24 часа | `hud.lua` |
| `:HudNow` | 🕐 опросить заново, не waiting таймеры | `hud.lua` |
| `:HudTz` | 🕐 смещение часового пояса (3 = МСК) | `hud.lua` |
| `:KeyShow` | Показ нажатий в Neovim | `keyshow.lua` |
| `:NotifyRu` | — | `notify_ru.lua` |
| `:Streak` | 🔥 огонёк за коммиты: отчёт (sync — пересчитать, reset — обнулить) | `streak.lua` |
| `:StreakRepo` | 🔥 вручную добавить репозиторий (обычно не нужно: находит сам) | `streak.lua` |
| `:StreakGoal` | 🔥 сколько коммитов зажигают огонёк | `streak.lua` |
| `:StreakHour` | 🔥 во сколько МСК день считается законченным | `streak.lua` |
| `:StreakNotify` | 🔥 сообщения о огоньках | `streak.lua` |
| `:Theme` | Выбрать тему: new \| classic (без аргумента — меню) | `themes.lua` |
| `:Habr` | Хабр: лента и чтение статьи | `webtools.lua` |
| `:Matrix` | Эффект «матрица» / «дождь» (cellular-automaton) | `matrix.lua` |
| `:Flex` | Эффект «матрица» / «дождь» (cellular-automaton) | `matrix.lua` |
| `:Tele` | ✈ tele: full \| panel \| chat \| <имя чата> | `telegram.lua` |
| `:TeleFull` | ✈ tele на весь экран | `telegram.lua` |
| `:TelePanel` | ✈ tele боковой панелью рядом с кодом | `telegram.lua` |
| `:TeleChat` | ✈ tele в маленьком окне, сразу на один чат | `telegram.lua` |
| `:TeleOpen` | ✈ вернуть окно tele | `telegram.lua` |
| `:TeleHide` | ✈ спрятать окно, процесс оставить живым | `telegram.lua` |
| `:TeleKill` | ✈ убить процесс tele | `telegram.lua` |
| `:TeleInbox` | ✈ буфер истории входящих | `telegram.lua` |
| `:TeleRead` | ✈ прочитать переписку чата, не открывая tele | `telegram.lua` |
| `:TeleChatPick` | ✈ то же, но чат выбирается списком | `telegram.lua` |
| `:TeleReply` | ✈ ответить в tele, не выходя из кода | `telegram.lua` |
| `:TeleReplyLast` | ✈ ответить в чат последнего уведомления | `telegram.lua` |
| `:TeleSend` | ✈ — | `telegram.lua` |
| `:TeleStart` | ✈ включить слежение за state.db | `telegram.lua` |
| `:TeleStop` | ✈ выключить слежение | `telegram.lua` |
| `:TeleToggle` | ✈ слежение вкл/выкл | `telegram.lua` |
| `:TeleDnd` | ✈ режим тишины | `telegram.lua` |
| `:TeleFocus` | ✈ всплывать только про эти чаты | `telegram.lua` |
| `:TeleIgnore` | ✈ не всплывать про эти чаты | `telegram.lua` |
| `:TeleTheme` | ✈ тема tele в палитре nvim (mocha \| black) | `telegram.lua` |
| `:TeleQuiet` | ✈ уведомления только в nvim, без уведомления ОС | `telegram.lua` |
| `:TeleBell` | ✈ гудок терминала на входящее | `telegram.lua` |
| `:TeleDb` | ✈ путь к state.db вручную | `telegram.lua` |
| `:TeleCheck` | ✈ что нашлось и что работает | `telegram.lua` |
| `:TeleStatus` | ✈ краткое состояние | `telegram.lua` |
| `:TeleTest` | ✈ показать, как будет выглядеть popup | `telegram.lua` |
| `:TeleDocs` | ✈ шпаргалка по клавишам и командам | `telegram.lua` |

Всего команд: **48** (из них `:Tele*` — 27).

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
| `giusgad/pets.nvim` | Питомец в редакторе (<leader>Hup) | pets.lua | да |
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

**Не закреплены в lazy-lock.json** (22): `avante-corp/avante.nvim`, `hrsh7th/cmp-cmdline`, `sindrets/diffview.nvim`, `willothy/flatten.nvim`, `rafamadriz/friendly-snippets`, `akinsho/git-conflict.nvim`, `folke/lazydev.nvim`, `onsails/lspkind.nvim`, `Bilal2453/luvit-meta`, `ColinKennedy/mega.cmdparse`, `ColinKennedy/mega.logging`, `nvim-mini/mini.ai`, `nvim-mini/mini.surround`, `catppuccin/nvim`, `kevinhwang91/nvim-bqf`, `RishabhRD/nvim-cheat.sh`, `kosayoda/nvim-lightbulb`, `mfussenegger/nvim-lint`, `chrisgrieser/nvim-spider`, `RishabhRD/popfix`, `Wansmer/treesj`, `mg979/vim-visual-multi`.

Что с этим делать на Mac: открыть `nvim`, выполнить `:Lazy sync` и затем `:Lazy restore`/коммит обновлённого `lazy-lock.json`. Пока lock не обновлён, новые плагины ставятся самой свежей версией и могут отличаться у разных машин.

Записей, которых нет в конфиге (удалённые плагины): `dressing.nvim`, `bufdelete.nvim` — остались в lock-файле, в конфиге не используются.

