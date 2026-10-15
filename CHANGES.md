# Что исправлено в конфиге (2026-08-30)
## 2026-10-15 · Telegram-мост: консольный `tele` внутри Neovim (добавлено)

Новый модуль `lua/config/telegram.lua` (подключён строкой в `init.lua`, плагином
не является — `tele` это внешний бинарник). Даёт три способа открыть tele
(весь экран / боковая панель / маленький float на один чат), уведомления о новых
сообщениях прямо в редакторе, ленту входящих, чтение переписки без TUI и ответ
в чат «не отходя от кода».

| Решение | Почему именно так |
|---|---|
| Уведомления — pollingом `state.db`, а не сокетом/CLI | у tele нет ни того, ни другого: `cmd/tele/main.go` знает только `--config/-e/--trace/--version/--theme-*`, resident daemon обещан в v2.0. Пишет он в SQLite пачками раз в 2 с (`persistFlushInterval`) — наш шаг опроса тот же, быстрее всё равно не узнать |
| Новое = **рост `unread_count`** | `last_message` меняется и от собственных сообщений, и от отметки «прочитано»; только unread-дельта означает «входящее, которого ты не видел». Заодно бесплатно получили `is_muted` (мьют Telegram) и `unread_mentions_count` (@mention будит даже в мьюте) |
| Свой popup, а не `vim.notify` | в `init.lua` стоит фильтр, выбрасывающий всё кроме ERROR: `vim.notify(WARN)` молча исчезает. Обращаемся к `notify.nvim`/`Snacks.notifier` напрямую + есть собственный float. Тем же путём идут и предупреждения моста («нет sqlite3», «БД занята») |
| «Ответить» = печать клавиш в PTY | nvim_chan_send по `b:terminal_job_id`: `Esc → i → текст → Enter`, и `Esc → 1 → /чат → Enter → 2` для перехода к чату. Штатные клавиши tele, никаких правок самого tele |
| Один процесс на три режима | tele держит эксклюзивный lock на `state_dir` (`statedir.Acquire`), второй экземпляр умирает с «tele is already running». Переключается геометрия окна, а не процесс; `:TeleHide` закрывает окно, но буфер жив → PTY жив → уведомления по-прежнему идут |
| `:TeleTheme` вместо «разберись сам» | у tele вшит `catppuccin-macchiato` и есть `base:`; генерируем `nvim-mocha.yml` в точной палитре mocha (как `colorscheme.lua`) + вариант `black` под `Normal = #000000` из `init.lua` |
| Правка `~/.config/tele/config.yml` точечная, с `.bak` | конфиг принадлежит другому приложению: меняем/вставляем только нужные строки, комментарии tele сохраняет, перед записью — копия `config.yml.bak` |
| «Только чат, без списков» = `:TeleRead` | сам tele hide-ить панели не умеет (`internal/ui/layout/layout.go` делит ширину на sidebar+chat всегда), поэтому чистый вид делаем у себя из кэша, а `<leader>mc` — быстрый прыжок в float |

Проверка: модуль исполнялся настоящим Lua с заглушкой `vim` (фейковые ФС и
`sqlite3`) — 121 проверка, в т.ч. дифф снимков, фильтры, перенос в popup и четыре
формы правки `config.yml`. Три бага найдены и исправлены по ходу: `modifiable=false`
до `set_lines` (E21 в `:TeleRead`), потеря WARN фильтром `init.lua`, и ложный
префикс автора в личных чатах («Иван: привет» под заголовком «Иван Петров»).


Проверка проводилась не «на глаз»: конфиг исполнялся настоящим Lua-движком
(Lua 5.4+ через lupa) с подменённым API `vim`, а каждый плагин был склонирован
и его команды/модули/опции сверялись с исходниками.

## Критичное (конфиг не работал)

| Где | Было | Стало |
|---|---|---|
| `init.lua` | `git clone ... "https://github.com" --branch=stable` — lazy.nvim **не устанавливался вообще** | `https://github.com/folke/lazy.nvim.git` + понятная ошибка при провале |
| `init.lua` | `vim.lsp.util.make_position_params()` без аргументов → в Neovim 0.11+ `validate('position_encoding', ..., 'string')` **падает** | кодировка берётся из клиента: `make_position_params(0, client.offset_encoding)` |
| `treesitter.lua` | `pcall(require, "nvim-treesitter.configs")` — в ветке `main` такого модуля нет, pcall молча глушил ошибку → **подсветка не работала**, а с ней и кастомные цвета `@keyword`/`@function` из `init.lua` | новый API: `require("nvim-treesitter").install({...})` + `vim.treesitter.start()` по FileType |
| `init.lua` + `folding.lua` | `foldenable=false` + `normal! zR` на каждый FileType → **nvim-ufo не мог работать физически** | `foldenable=true`, `foldlevel=99` (визуально так же — всё развёрнуто), ufo живой |
| `init.lua` | файла темы не было: `colorscheme <colors_name or "habamax">` → всегда habamax | добавлен `catppuccin/nvim` (mocha) |
| `config/keymaps.lua` | файл **никто не подключал** — мёртвый код | `require("config.keymaps")` в `init.lua`, конфликты убраны |

## Команды, которых не существует (проверено grep'ом по исходникам плагинов)

| Было | Реальность | Стало |
|---|---|---|
| `GoVulncheck` | в go.nvim команда `GoVulnCheck` (регистр!) | `GoVulnCheck` |
| `GoJson2Struct` | есть только `GoJson` | `GoJson` |
| `GoDoMock` | нет ни в gopher, ни в go.nvim | `GoMockGen` |
| `CodeCompanionSend` | команды нет; реальные: CodeCompanion, CodeCompanionChat, CodeCompanionActions, CodeCompanionCmd, CodeCompanionCLI, CodeCompanionCodeReview | `CodeCompanion` |
| `PomoStart` / `PomoStop` / `PomodoroStart` / `PomodoroStop` | у pomo.nvim команды `TimerStart`, `TimerStop`, `TimerPause`, … | `TimerStart 25m Work` / `TimerStop Work` |
| `Pets` + `PetsNew custom holli brown` | есть `PetsNew {name}` и `PetsNewCustom {type} {style} {name}` | `PetsNew holli` / `PetsNewCustom dog brown holli` |
| `TroubleToggle` | в trouble v3 удалена | `Trouble diagnostics toggle` |
| `ToggleTermCloseAll` | есть `ToggleTermToggleAll` | `ToggleTermToggleAll` |
| `ToggleTermSetSize 15` | такой команды нет, размер — параметр | `:ToggleTerm size=15 direction=horizontal` |
| `NvimTreeCreate` | у nvim-tree 12 команд, такой нет | `NvimTreeFindFileToggle` + клавиша `a` в дереве |
| `DBUI AddConnection`, `DBUI ExecuteQuery` | есть `DBUIAddConnection`, подкоманды `ExecuteQuery` нет | `DBUIAddConnection` / `DBUIFindBuffer` |
| `KulalaRun` | команды нет, только `KulalaDiagnostics` | `require('kulala').run()` |
| `Telescope todo` | пикер называется `todo-comments` | `TodoTelescope` |
| `DockerLogs`, `DockerKill` | у docker.vim: `DockerContainerLogs`, kill-команды нет | `DockerContainerLogs` |
| `require('noice').toggle()` | в API noice нет `toggle` | переключатель `vim.g.minianimate_disable` |
| `require('harpoon.mark')` / `harpoon.ui.nav_file` | это API harpoon v1, а в спеке закреплена ветка **harpoon2** | `require('harpoon'):list():add()`, `:select(1)`, `harpoon.ui:toggle_quick_menu(list)` |
| `MoveHLine` | у move.nvim: `MoveLine`, `MoveBlock`, `MoveWord`, `MoveHChar`, `MoveHBlock` | `MoveWord` / `MoveHBlock` |
| `require('pomo').get_status()` | такой функции нет → lualine падал на каждой отрисовке | `pomo.get_first_to_finish()` (официальный пример из README pomo) |
| `require('nvim-spotify.status')` | модуля нет, статус в поле `.status` | `require('nvim-spotify').status:listen()` |
| `toggleterm.get_or_create_term()` / `.next()` / `.prev()` | таких функций в модуле нет → `<leader>gs`, `<leader>tn`, `<leader>tp` падали | `toggleterm.exec(cmd, id)` |
| `Snacks.rename()` | модуль не вызываемый, точка входа `rename_file()` | `Snacks.rename.rename_file()` |

## Опции, которых не существует (молча игнорировались)

* `translate.nvim`: ключ `output_option` не существует (есть `preset.output.split`), а у split нет поля `size` и `position` принимает только `top`/`bottom` → настройки не применялись.
* `conform.nvim`: `lsp_fallback = true` → нужно `lsp_format = "fallback"`.
* `SmoothCursor`: `flyin_column` не существует; `type` принимает только `default|exp|matrix` (`fancy` включается через `fancy.enable`).
* `nvim-dap-docker`: `host` и `container_filters` не существуют — конфиг только `docker = { path, builder, standalone }`.
* `codecompanion.nvim`: `display.diff.provider = "mini_diff"` не существует; адаптеры живут в `adapters.http` (а `kimi` уже встроен); `strategies` — устаревшее имя для `interactions`; `prompt_library` больше не хранит промпты.
* `fidget.nvim`: опечатка `spinnner` → `spinner`.

## Дубли спецификаций (lazy.nvim склеивает их, и выживает только один `config`)

* `ray-x/go.nvim` — в `go-tools.lua` и `go-security.lua` → объединено в один файл, `go-security.lua` удалён.
* `stevearc/aerial.nvim` — в `aerial.lua` и `json-pro.lua` → владелец `aerial.lua`.
* `eandrju/cellular-automaton.nvim` — в `fidget.lua` и `matrix.lua` → владелец `matrix.lua`.

## Конфликты клавиш (было 12, стало 0)

* `<leader>h` (Hydra) глушил `<leader>ha/hh/h1/h2` (harpoon) → Hydra на `<leader>M`.
* `<M-j>`/`<M-k>` объявлялись трижды (init, keymaps, move.nvim) → перенос строк в move.nvim, ресайз по высоте на `<C-Up>/<C-Down>`.
* `<Tab>`/`<S-Tab>` — и в init, и в bufferline → осталось в bufferline.
* `<leader>nh` — и nohlsearch, и история черновиков → черновики на `<leader>nS`.
* `<leader>tf`/`<leader>ts>` — neotest и toggleterm → терминал переехал на `<leader>T*` и `<leader>HT*`.
* `<leader>fL` — в fidget и matrix → осталось в matrix.
* `<leader>t` (translate) пересекался с `<leader>tr` (neotest) → translate на `<leader>tt`.
* `<leader>Ht` был объявлен **три раза** (Go-тесты, группа «Тесты», группа «Терминал») → одна группа, Go-тесты на `<leader>HGo`, терминал на `<leader>HT`.

## Удалённые плагины и почему

* `folke/bigfile.nvim` — репозитория больше нет (GitHub отвечает 404, плагин переехал в snacks.nvim). Заменён на `snacks.nvim` с `bigfile`.
* `utilyre/barbecue.nvim` — архивен (archived=true, последний коммит 2024-08-20). Заменён на `SmiteshP/nvim-navic` + `winbar`.
* `hrsh7th/nvim-insx` — пресет `standard` дублировал autopairs (двойные скобки).
* `filipdutescu/renamer.nvim` — заброшен; переименование делает встроенный `vim.lsp.buf.rename()` (Neovim 0.11+) через dressing.nvim. Клавиши `<leader>rn` и `<F2>` сохранены.
* `olexsmir/gopher.nvim` — его `build` содержал `go install ://github.com`, а команды `GoIfErr`/`GoImpl`/`GoNew` конфликтовали с go.nvim. Всё нужное есть в go.nvim (`GoIfErr`, `GoImpl`, `GoAddTag`, `GoMockGen`, `GoTestsAll`).
* `scratch.lua` объединён со `snacks.lua`.

## Новые плагины

* `catppuccin/nvim` — тема (её просто не было).
* `folke/lazydev.nvim` + `Bilal2453/luvit-meta` — LSP и типы для правки этого конфига.
* `SmiteshP/nvim-navic` — хлебные крошки в `winbar` (замена barbecue).
* `echasnovski/mini.surround` + `echasnovski/mini.ai` — окружения и текстовые объекты (`sa`, `sd`, `sr`, `vi(`, `vaf`).
* `kevinhwang91/nvim-bqf` — quickfix с предпросмотром.
* `rafamadriz/friendly-snippets`, `hrsh7th/cmp-cmdline` — сниппеты и автодополнение команд.
* `folke/snacks.nvim` — bigfile, черновики, подсветка слова под курсором, быстрый `quickfile`.

## Прочее

* Список LSP-серверов вынесен в `lua/config/servers.lua` и используется и Mason'ом, и `vim.lsp.enable()`. Раньше `dotls`/`lemminx`/`html`/`cssls` скачивались, но никогда не запускались.
* LSP-клавиши навешиваются на `LspAttach` (буферные), добавлены `gr`, `gi`, `gD`, `]d`/`[d`, `<leader>d`, инлайновые подсказки.
* Spotify включается только если в системе есть `spt` (`enabled = vim.fn.executable("spt") == 1`), иначе падал хост.
* `all_keymaps.txt` перегенерирован из реального конфига (117 маппингов).
* `lazy-lock.json` очищен от записей удалённых плагинов.

## Чем это проверялось

1. **Исполнение конфига**: все 71 файл `lua/plugins/*.lua` + `init.lua` + `lua/config/keymaps.lua` исполнялись настоящим Lua-интерпретатором с мок-`vim` (запускались `init`/`opts`/`config`/`keys`). Результат: **0 ошибок, 0 конфликтов клавиш, 0 дублей спецификаций**.
2. **Сверка с исходниками**: 104 репозитория плагинов склонированы, для каждой команды из конфига проверено её объявление (`nvim_create_user_command` / `command!`), для каждого `require()` — наличие модуля, для каждого `require("X").Y()` — наличие функции.
3. **Проверка API Neovim** по исходникам Neovim (клон 0.13.0-dev): `vim.lsp.buf_request` существует, `make_position_params(win, position_encoding)` требует кодировку, `convert_input_to_markdown_lines(input, contents)` жив.

Чего проверить **нельзя** в этой среде: запуск настоящего `nvim` (хосты релизов GitHub недоступны), поэтому установка парсеров Treesitter, Mason-пакетов и работа внешних бинарников (`jq`, `spt`, `lazygit`, `silicon`, `goimports`) проверялись только по их наличию в API плагинов, а не вживую.
