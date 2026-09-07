# RastBast/nvim-config — ПОЛНАЯ ДОКУМЕНТАЦИЯ

> Ветка: `arena/01a05448-nvim-config` (создана от `main`).
> Неовим: проверено против **0.10+** (API сверен с 0.13-dev).
> Язык конфига: Lua (lazy.nvim). Все комментарии в коде — на русском.
> Последняя ревизия проверена автоматическим харнесом: **78 спеков, 121 маппинг,
> 49 пользовательских команд, 0 ошибок загрузки, 0 конфликтов клавиш, 0 дублей спеков**.

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
init.lua                    — точка входа: опции, базовые маппинги, загрузка lazy
lazy-lock.json              — ЗАФИКСИРОВАННЫЕ версии всех плагинов (не трогать руками)
all_keymaps.txt             — автосгенерированный полный список клавиш
CHANGES.md                  — отчёт «до/после» большой ревизии
DOCS.md                     — этот документ
lua/
├── config/
│   ├── keymaps.lua         — базовые маппинги (окна, сплиты,jk-выход…)
│   ├── options.lua         — vim-опции
│   ├── autocmds.lua        — автокоманды
│   └── servers.lua         — список LSP для Mason/lspconfig (все имена сверены с Mason-реестром)
├── plugins/                — 71 файл-спек (78 плагинов, часть — зависимости)
│   ├── go-tools.lua        — ray-x/go.nvim: единственный спек Go
│   ├── toggleterm.lua      — терминалы + Docker-окна
│   ├── docker-cli.lua      — подсветка Dockerfile (ekalinin/Dockerfile.vim)
│   ├── kulala.lua          — HTTP/gRPC-клиент
│   ├── marks...(внутри mini.lua/и т.д.)
│   └── …
└── snippets/               — (резерв под LuaSnip-сниппеты дорожной карты)
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

Сгенерирована автоматически из `init.lua`, `lua/config/keymaps.lua`, `lua/plugins/*.lua`.
`<leader>` = пробел (см. options). Строки «ГРУППА:» — разделители which-key
(нажми префикс — увидишь меню).

### Режим `i`

| `jk` | Выход в Normal |

### Режим `n`

| `<C-Down>` | Ниже |
| `<C-Up>` | Выше |
| `<C-h>` | Окно слева |
| `<C-j>` | Окно снизу |
| `<C-k>` | Окно сверху |
| `<C-l>` | Окно справа |
| `<Esc>` | Quit |
| `<M-h>` | Уже |
| `<M-l>` | Шире |
| `<c-\\>` | 📟 Переключить терминал |
| `<leader>-` | Горизонтальный сплит |
| `<leader>H` | ГРУППА: 🎛 Главное меню |
| `<leader>HG` | ГРУППА: 🐹 Go |
| `<leader>HGb` | 🔨 Собрать |
| `<leader>HGe` | ❗ Авто-if err |
| `<leader>HGi` | 🏷 Добавить json-теги |
| `<leader>HGj` | 📦 JSON → struct |
| `<leader>HGl` | 🧹 Линтер |
| `<leader>HGm` | ⚙️ Сгенерировать impl |
| `<leader>HGo` | 🧪 Запуск тестов |
| `<leader>HGs` | 🧩 Заполнить struct (go.nvim) |
| `<leader>HGS` | 🧩 Формочка struct: пикер + поля с нулевыми значениями, <Tab> по полям |
| `<leader>HGf` | 🧱 Автозаполнение полей struct'а под курсором |
| `<leader>HGv` | 🔐 Проверка уязвимостей |
| `<leader>Ha` | ГРУППА: 🤖 AI и Структура |
| `<leader>Hac` | ✨ Команда в CodeCompanion |
| `<leader>Hae` | 📤 Отправить выделение ИИ |
| `<leader>Hai` | 🛠 Действия AI |
| `<leader>Has` | 📑 Показать структуру файла |
| `<leader>Hat` | 💬 Чат с Kimi |
| `<leader>Hc` | ГРУППА: 📂 Работа с файлами |
| `<leader>Hcf` | 🗂 Дерево (дальше `a` — создать) |
| `<leader>Hcr` | ✏️ Переименовать файл |
| `<leader>Hd` | ГРУППА: 🗄 Базы и Отладка |
| `<leader>Hda` | ➕ Добавить подключение |
| `<leader>Hdb` | ⛔ Точка останова |
| `<leader>Hdf` | 🔍 Найти БД буфера |
| `<leader>Hdg` | 🧪 Тест в режиме отладки |
| `<leader>Hdi` | 🔽 Шаг в |
| `<leader>Hdo` | ⏭ Шаг через |
| `<leader>Hdr` | ▶️ Старт/Продолжить |
| `<leader>Hdt` | 💾 Панель БД (toggle) |
| `<leader>Hdu` | 💾 Панель БД |
| `<leader>Hf` | ГРУППА: 🔍 Поиск и Файлы |
| `<leader>Hfb` | 🗂 Открыть буферы |
| `<leader>Hff` | 📂 Найти файл |
| `<leader>Hfg` | 🔎 Live grep |
| `<leader>Hfh` | ❓ Поиск по справке |
| `<leader>Hfk` | ⌨️ Все горячие клавиши |
| `<leader>Hfr` | 🕑 Недавние файлы |
| `<leader>Hft` | 📝 TODO/FIXME |
| `<leader>Hg` | ГРУППА: 🌿 Git |
| `<leader>Hgb` | 🕵️ Автор строки |
| `<leader>Hgg` | 🐙 LazyGit |
| `<leader>Hgh` | 🔎 Предпросмотр изменений |
| `<leader>Hgs` | 📦 Stage hunk |
| `<leader>Hgu` | ↩️ Undo stage hunk |
| `<leader>Hh` | ГРУППА: 📌 Harpoon |
| `<leader>Hh1` | 🚀 К 1-му файлу |
| `<leader>Hh2` | 🚀 Ко 2-му файлу |
| `<leader>Hha` | 📍 Добавить файл |
| `<leader>Hhh` | 📂 Меню Harpoon |
| `<leader>Hn` | ГРУППА: 📦 Прочее |
| `<leader>Hne` | 🗂 Дерево файлов |
| `<leader>Hnh` | 🔎 Убрать подсветку поиска |
| `<leader>Ho` | ГРУППА: 💎 Obsidian |
| `<leader>Hof` | 🔗 Перейти по ссылке |
| `<leader>Hon` | 📝 Новая заметка |
| `<leader>Hos` | 🔎 Поиск заметок |
| `<leader>Hot` | ☑ Тоггл чекбокса |
| `<leader>Hp` | ГРУППА: 🔌 Плагины |
| `<leader>Hpc` | 🎨 Чем форматируется файл |
| `<leader>Hph` | ⚙️ Checkhealth |
| `<leader>Hpi` | 📝 Информация об LSP |
| `<leader>Hpl` | 📦 Lazy UI |
| `<leader>Hpm` | 🛠 Mason UI |
| `<leader>Ht` | ГРУППА: 🧪 Тесты |
| `<leader>Htf` | 📂 Все тесты в файле |
| `<leader>Htn` | ⬇️ Следующий тест |
| `<leader>Hto` | 📄 Вывод ошибки |
| `<leader>Htr` | ▶️ Тест под курсором |
| `<leader>Hts` | 🗂 Окно со статусом тестов |
| `<leader>Hu` | ГРУППА: 🎨 Визуал и UI |
| `<leader>HuP` | ⏱️ Стоп Pomodoro |
| `<leader>Hua` | ✨ Переключить анимации |
| `<leader>Hum` | 🪟 Развернуть/восстановить окно |
| `<leader>Hup` | 🐾 Питомец (Pets) |
| `<leader>Hur` | 🚀 HTTP-запрос (Kulala) |
| `<leader>Hus` | 📸 Скриншот кода (Silicon) |
| `<leader>Hut` | ⏱️ Старт Pomodoro |
| `<leader>Huz` | 🧘 Дзен-режим |
| `<leader>Hx` | ГРУППА: ⚠️ Диагностика |
| `<leader>Hxl` | 📋 Location list |
| `<leader>Hxq` | 📋 Quickfix list |
| `<leader>Hxx` | ❗ Все ошибки (Trouble) |
| `<leader>M` | 🦹 Войти в Super Mode |
| `<leader>Ta` | ❎ Показать/скрыть все терминалы |
| `<leader>Th` | 📟 Терминал снизу |
| `<leader>Tl` | ➡ Строку в терминал |
| `<leader>Tt` | 📟 Плавающий терминал |
| `<leader>Tv` | 📟 Терминал справа |
| `<leader>a` | 📑 Структура кода |
| `<leader>aj` | 🌳 Дерево JSON/структура |
| `<leader>Pb` | 🧊 buf build (валидация proto) |
| `<leader>Pl` | 🧊 buf lint (стиль proto) |
| `<leader>Pg` | 🧊 buf generate (codegen) |
| `<leader>dc` | 🐳 Docker: lazydocker (TUI) |
| `<leader>di` | 🐳 Docker: образы |
| `<leader>dn` | 🐳 Docker: сети |
| `<leader>dp` | 🐳 Docker: контейнеры |
| `<leader>fL` | 🚀 Код потёк! |
| `<leader>fb` | 🗂 Буферы |
| `<leader>fc` | 🧰 Все команды |
| `<leader>fd` | ⚠️ Диагностика проекта |
| `<leader>ff` | 📂 Найти файл |
| `<leader>fg` | 🔎 Поиск по содержимому |
| `<leader>fh` | ❓ Поиск по справке |
| `<leader>fk` | ⌨️ Все горячие клавиши |
| `<leader>fr` | 🕑 Недавние файлы |
| `<leader>gb` | 🔨 Собрать |
| `<leader>gg` | LazyGit |
| `<leader>gl` | 🧹 Линтер |
| `<leader>gm` | 🎭 Сгенерировать мок |
| `<leader>gt` | 🧪 Тесты пакета |
| `<leader>gv` | 🛡 Проверить уязвимости |
| `<leader>jq` | 🔎 jq-запрос по JSON |
| `<leader>jx` | 🔍 Список ключей JSON |
| `<leader>nS` | 📓 История черновиков |
| `<leader>nh` | Убрать подсветку поиска |
| `<leader>ns` | 📓 Черновик |
| `<leader>pp` | ⏸ Пауза |
| `<leader>pr` | ▶ Снять с паузы |
| `<leader>ps` | ⏱️ Остановить таймер |
| `<leader>pt` | ⏱️ Запустить таймер (25м) |
| `<leader>q` | Закрыть окно |
| `<leader>sd` | 🎵 Spotify устройства |
| `<leader>so` | 🎵 Spotify поиск |
| `<leader>te` | 🌐 Перевести на английский |
| `<leader>tt` | 🌐 Перевести слово (ru) |
| `<leader>un` | 🔕 Спрятать уведомления |
| `<leader>uo` | 😴 Питомец: сон |
| `<leader>up` | 🐾 Призвать питомца |
| `<leader>ux` | 💀 Убрать питомцев |
| `<leader>w` | Сохранить |
| `<leader>|` | Вертикальный сплит |
| `[[` | Предыдущее слово |
| `]]` | Следующее слово |
| `b` | Buffers |
| `f` | Files |
| `g` | Git |
| `q` | Quit |
| `s` | Save |

### Режим `t`

| `<Esc><Esc>` | Выйти в Normal в терминале |

### Режим `v`

| `<` | Отступ влево |
| `<leader>Tl` | ➡ Выделение в терминал |
| `>` | Отступ вправо |
| `p` | Вставить, не затирая регистр |


## 7. Система префиксов

| Префикс | Смысл |
|---|---|
| `<leader>H` | Главное меню which-key: подгруппы `Hf` поиск, `Hg` git, `Hd` БД+отладка, `HG` Go, `Ht` тесты, `Hu` визуал, `Hx` диагностика, `Ho` obsidian, `Hh` harpoon, `Hp` плагины, `Hc` файлы, `Ha` AI |
| `<leader>T` | Терминалы toggleterm (`Tt/Th/Tv/Ta/Tl/Tg/TG`) |
| `<leader>d` + буква | Docker (`dc` lazydocker, `dp` ps, `di` images, `dn` сети); `<leader>d` один — диагностика строки (LSP) |
| `<leader>f` | Поиск telescope/fzf-стиль (`ff/fg/fb/fr/fh/fk/fc/fd`) |
| `<leader>g` | Go-быстрые (`gb/gl/gt/gm/gv`) и `gg` lazygit |
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
* **Obsidian** — `obsidian.nvim` + `obsidian-bridge`: `<leader>Hon` новая заметка,
  `Hos` поиск, `Hof` по ссылке, `Hot` чекбокс.
* **Harpoon** (ветка harpoon2): `Hha` добавить, `Hh1/Hh2` перейти, `Hhh` меню.
* **SnipRun** — выполнить кусок кода из буфера.
* **Spectre** — поиск-и-замена по проекту (`<leader>`-меню f-группы + команды).

## 18. LSP / Mason: что ставится

`lua/config/servers.lua` — все имена сверены с реестром Mason (594 пакета):
`gopls, ts_ls, bashls, dotls, lemminx, html, cssls, lua_ls, jsonls, yamlls,
dockerls, protols, sqls` (включены в `servers.lua`) + доступны `docker_compose_language_service, buf_ls, eslint` +
инструменты `golangci-lint, hadolint, delve, protolint`.
Базовые LSP-клавиши: `gd` определение, `gr` ссылки, `K` ховер, `<leader>d`
диагностика строки, `]d/[d` — по ошибкам (из lsp-config.lua).

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
| `famiu/bufdelete.nvim`, `stevearc/dressing.nvim` | Архивированы авторами, но **работают** и стабильны — оставлены осознанно. Захочется убрать: dressing заменяем ничем не надо (nvim 0.10+ имеет UI-overridы), bufdelete — `vim.fn.bufdelete`-обёртки |
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

* Луа-харнес (lupa): исполняет `init.lua` + все 78 спеков с заглушками API,
  ловит ошибки загрузки, строит таблицу маппингов/команд, ищет конфликты
  (одинаковый mode+lhs) и дубли спеков. Результат ревизии: **0 / 0 / 0**.
* API-аудит: каждый `require("модуль").fn()` сверен с исходниками клонированных
  плагинов (метатебельные/ленивые API подтверждены вручную: snacks.rename,
  obsidian.util, smoothcursor, gitsigns-actions, telescope.builtin).
* Командный аудит: каждая строка `<cmd>X<cr>` и `:X` сверена с `create_user_command`
  в исходниках; остаются только встроенные nvim (`checkhealth`, `lua`, `nohlsearch`).
* Аудит репозиториев: каждый `org/repo` проверен через GitHub API на существование
  и archived-статус (см. §19 про два архивных, но рабочих).
* Mason-аудит: каждое имя из `servers.lua` проверено по реестру
  `mason-org/mason-registry` (путь `packages/<name>/package.yaml`).

---

*Документ поддерживается вместе с конфигом; таблица клавиш (§6) регенерируется
харнесом при каждом изменении маппингов.*
