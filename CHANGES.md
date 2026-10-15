# Что исправлено в конфиге (2026-08-30)

## 2026-10-15 · Языки (≈45), каталог БД, K8s/Docker/Kafka под Go

**Языки — `lua/config/languages.lua`** — один список на LSP, Treesitter и форматтеры
(45 языков: Go, Python, Rust, C/C++, Java, Kotlin, Scala, C#, Ruby, PHP, Swift, Dart,
Elixir, Haskell, OCaml, Zig, R, Julia, Terraform, Nix, Vue, Svelte, GraphQL, TOML, LaTeX,
Typst, Clojure, Perl, CMake, Groovy, Markdown, …). Каждая строка проверена по исходникам:
имена LSP — nvim-lspconfig, парсеры — nvim-treesitter, форматтеры — conform.
- `servers.lua` / `lsp-config.lua`: Mason ставит только `lsp`; серверы с `toolchain`
  (csharp_ls, sourcekit/Xcode, dartls, hls/ghcup, ocamllsp/opam, r_language_server, julials, groovyls) включаются, только если бинарник
  уже в PATH. `automatic_installation` (мёртвая опция в зафиксированной версии) заменена на
  `automatic_enable = { exclude = toolchain }`.
- `treesitter.lua`: парсеры из таблицы (без дублей).
- `format.lua`: форматтеры из таблицы; записи, которые были, имеют приоритет.
  Исправлено: `sql = { "sqlformat" }` → `"sqlfluff"` (`sqlformat` в conform нет).

**Общий запуск утилит — `lua/config/termcmd.lua`**: `term_cmd` вынесен из `toggleterm.lua`,
теперь используется и там, и для K8s/Docker/Kafka. Нет утилиты в PATH → предупреждение
со ссылкой, без обходных путей.

**Базы данных — `lua/config/db_menu.lua`, каталог `<leader>D`**:
`<leader>D` → СУБД (`s` SQLite, `m` MySQL/MariaDB, `p` PostgreSQL, `o` Oracle,
`x` SQL Server, `c` ClickHouse) → команды этой СУБД:
`c` подключиться · `r` выполнить буфер (normal) / выделение (visual) · `t` таблицы ·
`d` описание таблицы · `n` новый SQL-буфер с подключением · `u` панель DBUI.
- URL: из переменных `NVIM_DB_SQLITE`, `NVIM_DB_MYSQL`, `NVIM_DB_PG`, `NVIM_DB_ORACLE`,
  `NVIM_DB_MSSQL`, `NVIM_DB_CLICKHOUSE`, либо спрашивается при первом обращении.
  Пароли в файлы не пишутся (только `vim.g.nvim_db_urls` на время сессии).
- Выполнение запросов — только в SQL-буфере (filetype `sql`); каталог и новые буферы работают из любого места.
- Клиенты (sqlite3, mysql, psql, sqlplus, sqlcmd, clickhouse) — системные; адаптеры
  vim-dadbod для всех шести есть (проверено по `autoload/db/adapter/`).

**Go-сниппеты — `lua/config/go_infra_snips.lua`**: Kafka (`gkprod` producer, `gkcons`
consumer group с CommitMessages, `gkcfg` Dialer с SASL/PLAIN и TLS — `segmentio/kafka-go`)
и драйверы `database/sql` (`gdbsqlite`, `gdbmysql`, `gdbpg`, `gdboracle`, `gdbmssql`, `gdbch`).

**Группа `<leader>HG` «🐹 Go: K8s · Docker · Kafka»**:
- `HGk` ☸ Kubernetes: `k9s`, `kubectl get pods`, `kubectl config get-contexts`
- `HGd` 🐳 Docker: `lazydocker`, `docker ps -a`, `docker images`
- `HGa` 📨 Kafka: `ktea` (TUI), `kafkactl get topics / consumer-groups / brokers`

Новых плагинов не добавлено (`lazy-lock.json` не меняется).

## 2026-10-15 · Подсказки <leader>H — как в main; HUD: день недели и число

**`lua/plugins/which-key.lua`** — структура, эмодзи и названия групп возвращены из `main`
(🎛 Главное меню, 🔍 Поиск и Файлы, 🌿 Git и Go, 🗄 Базы и Отладка, 🤖 AI и Структура,
💎 Obsidian, 🧪 Тесты, 🎨 Визуал и UI, 📌 Harpoon, 🔌 Плагины, ⚠️ Диагностика, 📦 Прочее,
📂 Создать файл/директорию). Отличия от `main` — только там, где клавиша в `main` не работала:

| Было в main | Стало | Почему |
|---|---|---|
| `<leader>Ht` = GoTest и группа «Тесты», и группа «Терминал» | GoTest → `<leader>Hgt` | `<leader>Ht` — группа; команда на том же префиксе не работает |
| Терминал `<leader>Htt/Hth/Htv/Htc` | Группа `<leader>T` (🖥 Терминал) — подписи к `<leader>T*` из `toggleterm.lua` | терминал живёт на `<leader>T*` |
| `GoVulncheck`, `GoTagAdd`, `Telescope todo`, `DBUI AddConnection`, `TroubleToggle`, `PomodoroStart/Stop`, `Pets`, `KulalaRun`, `harpoon.mark`, `CodeCompanionSend` | `GoVulnCheck`, `GoAddTag`, `TodoTelescope`, `DBUIAddConnection`, `Trouble diagnostics toggle`, `TimerStart/Stop`, `PetsNew holli`, `kulala.run()`, harpoon v2, `:CodeCompanion` | такой команды/API нет в актуальных версиях плагинов |
| `DBUI ExecuteQuery`, `NvimTreeCreate` | убраны | подкоманды нет; файл создаётся клавишей `a` в дереве |

Новые команды (помечены `✚`): `<leader>Hfc` команды Neovim, `Hfw` слово под курсором, `Hfm` метки,
`Hgd` diff файла, `Hgl` blame строки вкл/выкл, `Hgg` LazyGit, `Hdf` БД буфера, `Hac` CodeCompanion,
`Hpy` **Lazy sync**, `Hpc` ConformInfo, `Hxs` символы (Trouble), `Hxt` TODO (Trouble).

**`lua/config/hud.lua`** — рядом со временем показываются день недели и дата по МСК:
`🕐 Чт 15.10 · 8:48 PM`. Считается арифметикой (без `os.date`, как и время), опция `show_date`
(по умолчанию `true`). Проверено против `datetime` на 3008 метках времени, включая високосные годы.

## 2026-10-15 · Проход по багам: команды, API плагинов, логика переводчика

Сверка с исходниками плагинов (клоны `codecompanion`, `avante`, `conform`,
`go.nvim`, `neotest`, `obsidian`, `mini.nvim`, `nvim-treesitter`) и
юнит-тесты на Lua-рантайме. Найдены и исправлены ошибки, которые не давали
ошибок при старте, но ломали конкретные функции:

| Где | Было | Стало |
|---|---|---|
| `lua/plugins/ai.lua` | Промпт «Explain Code» лежал в `interactions` с `strategy` и `opts.mapping` — CodeCompanion такой промпт не регистрирует, а `mapping` не поддерживается | Перенесён в `prompt_library` (`interaction = "chat"`, `opts.alias = "explain"`); вызов `require("codecompanion").prompt("explain")` |
| `lua/plugins/ai.lua` | `<leader>Hae` в visual шёл через `<cmd>`: диапазон пустой, уходила одна строка | Строковый rhs `:CodeCompanion<cr>` — Vim дописывает `'<,'>` |
| `lua/plugins/ai.lua` | `api_key = os.getenv(...) or "MOONSHOT_API_KEY"`: CodeCompanion принимает здесь **имя** переменной; при заданном ключе уходило его значение как имя, при незаданном — строка `MOONSHOT_API_KEY` вместо ключа | `api_key = "MOONSHOT_API_KEY"` — CodeCompanion сам читает переменную |
| `lua/plugins/completions.lua` | Принятие ИИ-подсказки через `feedkeys("<Plug>(AvanteSuggestionAccept)", "n")` — режим `n` запрещает маппинги, `<Plug>` не срабатывал | Прямой вызов `require("avante").get()` → `sg:accept()` |
| `lua/plugins/format.lua` | `cmd = { "ConformInfo", "Format" }` — команды `:Format` в conform нет (E492) | `cmd = { "ConformInfo" }`, форматирование — `<leader>cf` |
| `lua/plugins/which-key.lua`, `go-tools.lua` | `<leader>HGj` → `<cmd>GoJson` — такой команды в go.nvim нет | `<cmd>GoJson2Struct<cr>` (в шапке исправлена запись «было/стало») |
| `lua/plugins/silicon.lua` | `<leader>sc` в visual: `vim.cmd("Silicon")` без диапазона | Строковый rhs `:Silicon<cr>` — снимается выделение |
| `lua/plugins/dadbod-ultimate.lua` | `db_ui_save_location = ~/.config/nvim/db_ui` — это git-репозиторий конфига; строки подключения с паролями попали бы в коммиты | `stdpath("data") .. "/db_ui"` (вне репозитория) |
| `lua/plugins/avante.lua` | `allow_insecure = vim.env.GEMINI_INSECURE ~= nil`: `GEMINI_INSECURE=0` тоже отключал проверку TLS | `== "1"` (как написано в INSTALL.md и PROXY.md) |
| `lua/plugins/mini.lua` | Кастомный текстобъект `f` был функцией, которая возвращала функцию-спек; `vif` / `vaf` ломались | `opts` — функция, `f = ai.gen_spec.treesitter({...})` |
| `lua/plugins/spotify.lua` | `<leader>sp/sn/sb/so/sd` ставились в `config` — до первого `:Spotify` клавиш не было | Объявлены в `keys` (lazy подгружает плагин сам) |
| `lua/config/hover_ru.lua`, `lua/config/diag_ru.lua` | Счётчик `pending` считался в цикле: если перевод первого куска был в кеше, колбэк шёл синхронно, `finish()` отдавал ответ LSP до перевода остальных кусков (остальные оставались по-английски) | Сначала собираются все куски, потом запускается перевод. Проверено тестом: старая версия — ошибка, новая — ок |
| `lua/config/telegram.lua` | `nvim_create_user_command(..., { range = "?" })` — недопустимое значение: Neovim падает с `E5113: Invalid 'range'` и `telegram.setup()` не доходит до конца (команды после `TeleSend` не создаются) | `range = true` (текущая строка или выделение) |
| `lua/plugins/avante.lua` | Не указана обязательная зависимость `ColinKennedy/mega.cmdparse` (и `mega.logging`): `module 'mega.cmdparse' not found` при загрузке avante на `VeryLazy` | Добавлена в `dependencies` (как в README avante) |
| `lua/config/hud.lua`, `lua/config/telegram.lua` (inbox, read_chat) | `vim.bo[buf].spell = false` — `spell` window-локальная опция; Neovim: `E5113 'buf' cannot be passed for window-local option 'spell'`, HUD падал при старте | `spell` ставится на окно: `vim.wo[win].spell = false` (после `nvim_open_win`) |

Заметки:
- `CHANGES.md` ранее утверждал, что `prompt_library` «больше не хранит промпты» —
  по документации CodeCompanion промпты как раз там (см. запись выше).
- `lazy-lock.json` не содержит 8 плагинов, добавленных позже (avante, mini.ai,
  mini.surround, lazydev, cmp-cmdline, friendly-snippets, nvim-bqf, luvit-meta).
  Lazy допишет их при `:Lazy sync`; вручную lock не редактировался.
- Проверка: синтаксис всех `.lua` (Lua-рантайм), поиск маркеров конфликта, дубли
  клавиш по всем `keymap.set` и `<leader>`-строкам, разрешение `require`
  для локальных модулей. Полный запуск Neovim в песочнице недоступен — поведение
  плагинов проверено по исходникам, а не запуском.
## 2026-10-15 · Отдел TG в which-key, 🕐 HUD в углу и 🔥 огонёк за коммиты (добавлено)

Два новых модуля — `lua/config/hud.lua` и `lua/config/streak.lua` (подключены
строками в конце `init.lua`, плагинами не являются) — и перенос подписей
Telegram в общую таблицу `lua/plugins/which-key.lua`. В правом верхнем углу
редактора теперь одна строка: время в Москве в 12-часовом формате с AM/PM,
заряд батареи Macа и IP; рядом `🔥N` — сколько дней подряд был хотя бы один
коммит. Сутки стрика закрываются в **03:00 МСК, а не в 00:00**.

| Где | Было | Стало |
|---|---|---|
| `lua/plugins/which-key.lua` | Telegram был россыпью `<leader>m*`, подписи жили только в `telegram.lua` (и их не было, если which-key ещё не загрузился) | отдельная **группа «TG ✈ Telegram (tele)»** + 17 desc-строк в общей таблице; `desc` без `rhs` — новых маппингов не появляется |
| `lua/plugins/maximizer.lua` | `<leader>m` = `MaximizerToggle` — тот же префикс, что и у группы TG: нажатие `<leader>m` ждало `timeoutlen` и молча разворачивало окно вместо меню | клавиша уехала на `<leader>Hum`, `<leader>m` отдан группе |
| `lua/plugins/which-key.lua` (`<leader>Hum`) | `<cmd>MaximizerToggle!<cr>` — bang у vim-maximizer **форсирует восстановление** раскладки, то есть клавиша ничего не разворачивала | `Hum` = `MaximizerToggle` (настоящий toggle), `HuM` = `MaximizerToggle!` (аварийно вернуть раскладку) |
| `config/hud.lua` | — | время: `os.time() + tz` и целочисленное деление, **не** `os.date("!%H:%M")` (в некоторых рантаймах `!` не понимают и возвращают `!` литералом, а без `!` считается по локали машины — в Хельсинки было бы хельсинкское время); минуты через `%02d`, иначе `7:5 PM` |
| `config/hud.lua` | `out:lower():find("charging")` для статуса батареи | «charging» — подстрока «dis**charging**» (и «Not charging» у Linux): разряжающийся ноутбук показывал ⚡. Сравниваем слово целиком: `out:match("(%a+)%s*;") == "charging"`, `charged` ≠ заряжается |
| `config/streak.lua` | `S.state.save_err = ok and nil or tostring(err)` | классическая ловушка Lua: при `ok == true` выходит `nil or «nil»`, т.е. строка «nil» вместо «ошибки нет». Только явный `if` |
| `config/streak.lua` | `melt()` сканировал `today-400 … today-1` | на первом запуске это «сжигало» ~400 дней, которых никогда не было (`💀 сгорело 400` вместо честного нуля). Сгорает только день с **записанным** нулём; невиданные дни помечает `melt_gaps()` и молча |
| `config/streak.lua` | `recompute()` обрывал серию, если сегодня ещё нет коммита | серия считается от вчера, когда сегодня не закрыто: утренний запуск не должен показывать `🔥0` и сжигать вчерашний день раньше 03:00 |
| `config/streak.lua` | `os.date("!%d.%m")` для подписей дней | свой `civil_from_days` (Хиннант) + русские названия дней/месяцев: дата не зависит от локали, «15 октября» не уезжает в «14 октября» |
| `lua/config/telegram.lua` | группа which-key называлась «✈ Telegram (tele)» | «TG ✈ Telegram (tele)» + `icon = "✈"` — имя отдела совпадает с общей таблицей, чтобы последнее зарегистрированное не перебивало label |

| Решение | Почему именно так |
|---|---|
| HUD = float, а не `statusline`/`virtual text` | статус-лайн тут глобальный (`laststatus=3`) и внизу; virtual text на первой строке сдвигает код и прыгает со скроллом. Float `relative=editor`, `focusable=false`, `style=minimal`, `zindex=60` |
| Плашка сама уходит, если рядом чужой float | проверка пересечения прямоугольников по `getwininfo()`, возврат по `WinClosed`/`WinEnter`/`VimResized`: окно tele размером в треть экрана не должен съедать половину строки HUD-а, а `:only` и `Ctrl-W o` не должны оставлять плашку пропавшей |
| `pmset -g batt`, а не `ioreg`/IOKit | `pmset` отдаёт и процент, и «AC Power», и оценку остатка — одним вызовом, без нативной зависимости. Linux-путь — sysfs (`/sys/class/power_supply/BAT*/capacity` + `status`). Нет источника — сегмент исчезает, а не врёт `0%` |
| IP: локальный **и** публичный, переключаются по `<leader>Hui` | «IP мой» неоднозначно: для AirDrop/SSH с другой машины нужен `192.168.x.x`, для «какой у меня белый адрес» — публичный. Локальный берётся с интерфейса **дефолтного маршрута** (`route -n get default` → `ipconfig getifaddr`), а не с `en0`: с доком и USB-сетевухой адрес живёт на `en5…en7` |
| Публичный IP — раз в 10 минут и через `curl --max-time 4` | это внешний запрос (и он же идёт через прокси, см. PROXY.md); при таймауте оставляем последний известный и честно помечаем его `~` |
| Коммиты считаем локальным `git log --pretty=%ct`, фильтр по времени — в Lua | `--since=YYYY-MM-DD` по-разному трактует часовой пояс в разных версиях git; `%ct` (unix-time) + сравнение чисел не оставляет двусмысленности. Работает офлайн, считает не запущенные ещё коммиты |
| `--branches`, не `--all` и не только HEAD | `--all` затягивает `stash` и `origin/*` (чужие коммиты засчитались бы), HEAD не видит коммит в боковой ветке |
| Граница суток — `floor((ts + tz - burn_hour*3600) / 86400)` | просили «сгорание в 3 часа ночи по МСК, а не в 00». МСК = UTC+3, переводов времени в РФ нет с 2014, поэтому 03:00 МСК == 00:00 UTC ровно и окно стрика = целые сутки UTC; формула при этом остаётся общей (проверено тестом на поясе с `tz=0`) |
| Огонёк пересчитывается one-shot таймером на границу, а не «раз в 5 минут» | уведомление «💀 сгорает в 03:00» должно приходить в 03:00, а не в 03:04 «когда следующий плановый опрос доберётся»; после срабатывания таймер перевешивается на следующие сутки |
| `melt` только по записанным дням + `streak.json` в `stdpath("data")` | журнал — единственная память между запусками; писать в `~/.config/nvim` нельзя (это git-репозиторий), в `stdpath("data")` — можно и переживает `git pull` |
| Сообщения стрика — мимо `vim.notify` | в `init.lua` фильтр, оставляющий только ERROR: `vim.notify(WARN)` исчезает молча. Идём в `notify.nvim`/`Snacks.notifier` напрямую, с `nvim_echo` в запасе |

Проверка: `lua/config/streak.lua` и `lua/config/hud.lua` исполнялись настоящим
Lua с заглушкой `vim` (фейковые ФС, `pmset`, `git`, `curl`, `getwininfo`) —
**154 проверки**, в т.ч. все граничные кейсы суток (`02:59:59` vs `03:00:00` в
разных поясах), разбор `pmset`/sysfs, геометрия плашки и обход чужих float-окон,
циклы `:HudIp`/`:HudClock`. Прошлые наборы проверок (121 + 26 для telegram-моста)
прошли и после правок `vim.system`-заглушки. `tools/check_config.sh` в этой
песочнице недоступен (`nvim` не установлен), поэтому синтаксис и конфликт-маркеры
проверялись обходом всех 86 Lua-файлов.

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

## Вторая итерация: части 4–7 (клавиатура macOS, буфер обмена, справка, перевод K)

Статус частей: 1 Discordo ✅ · 2 аудит плагинов ✅ · 3 плагины из «➕» ✅ · 4 клавиатура macOS ✅ · 5 кольцо буфера обмена ✅ · 6 справка по клавишам ✅ · 7 перевод подсказки K ✅.

* **Часть 4 — клавиатура на macOS (вне Neovim).** `macos/hammerspoon/init.lua`: экранная ANSI-клавиатура с подсветкой нажатых клавиш и плашка последнего сочетания; включается `⌃⌥⌘K`. Инструкция `macos/README.md`: KeyCastr (`brew install --cask keycastr`) и Hammerspoon (`brew install --cask hammerspoon`). Оверлей только читает события (eventtap возвращает `false`), клавиши не перехватывает.
* **Часть 5 — 9 регистров буфера обмена.** Neovim: `lua/config/yank_ring.lua` кладёт `y` в `"1`, предыдущие сдвигаются в `"2…"9`; `<leader>yr` и `<leader>Hbr` — выбор из списка. macOS: Maccy с `defaults write org.p0deje.Maccy historySize 9`, вставка ⌘1…⌘9 (см. `macos/README.md`).
* **Часть 6 — справка по клавишам.** `lua/config/keydoc.lua` и `lua/config/keydocs/g1…g5`. `<leader>?` + клавиши — текст справки, команда не выполняется (таймаут `timeoutlen` для клавиш, у которых есть более длинные варианты). `<leader>?m` — режим справки: назначенные клавиши объясняются вместо выполнения; выход — `Esc` или `<leader>?m`. В режим не попадают клавиши Super Mode (Hydra), `<Esc>` и сама справка. Клавиши БД строятся из `db_menu.keys()`, так что справка и меню не расходятся. Всего 282 пункта: 246 статических (пакеты по 40: шесть полных и один из 6) и 36 клавиш БД (6 СУБД × 6 действий).
* **Часть 7 — перевод подсказки K.** Перехват на `vim.lsp.util.open_floating_preview` при `focus_id == "textDocument/hover"` (в Neovim 0.12 `K` идёт мимо `handlers`). Кеш на диске — перевод сразу; без кеша окно открывается сразу, текст заменяется после перевода. Google-эндпоинты опрашиваются параллельно, MyMemory — только если оба упали.
* **Which-key:** под `<leader>H` добавлены «❓ Справка по клавишам» (`<leader>Hq?`, `<leader>Hqm`) и «📋 Буфер обмена и macOS» (`<leader>Hbr`, `<leader>Hbm`, `<leader>Hbk`). Харнесс: ВСЁ ОК, префиксных конфликтов нет.

### Проверка этой итерации
* Синтаксис всех изменённых Lua-файлов (lupa, Lua 5.5): 0 ошибок.
* Структура справки: у каждого пункта есть `lhs`, `name`, `doc`; дублей (`lhs`+режим) нет (hydra-клавиши не считаются).
* Покрытие: все клавиши из `keymaps.lua`, `*.lua` плагинов и which-key описаны, кроме префиксов групп (у них есть подписи в which-key) и служебной `<CR>` окна справки.
* Харнесс (`/tmp/t/harness.py`): ВСЁ ОК, which-key 166 записей.

### Не проверено
* Реальный запуск `nvim` и Hammerspoon/KeyCastr: в песочнице нет ни того, ни другого. Lua-синтаксис проверен, API Hammerspoon не запускался.
* `all_keymaps.txt`: генератора в репозитории нет, файл не перегенерирован. Актуальная справка — `<leader>?` и `lua/config/keydocs/`.

## DeepL как первый переводчик подсказок (ответ на вопрос о «втором движке»)

* `lua/config/ru_util.lua`: если задана переменная окружения `DEEPL_API_KEY`, перевод сначала идёт через DeepL (`api-free.deepl.com`, free-ключи заканчиваются на `:fx`). Если DeepL не ответил — как раньше: два Google параллельно, затем MyMemory.
* Ключ **не хранится в репозитории**. Заголовок с ключом передаётся curl через stdin (`-K -`), поэтому ключ не виден в списке процессов.
* `:RuCheck` показывает и DeepL (или «пропущен: не задан DEEPL_API_KEY»).
* Установка ключа (macOS/zsh): добавить в `~/.zshrc` строку `export DEEPL_API_KEY="…"` и перезапустить терминал. Neovim, запущенный из Dock/Spotlight, переменную из `~/.zshrc` не видит — тогда запускать `nvim` из терминала.

Проверка: `/tmp`-тест на заглушках `vim.system`/JSON (4 сценария: без ключа; DeepL отвечает; DeepL падает → Google; всё падает → nil; ключ не в argv). Реального запроса к DeepL из песочницы не было: хост api-free.deepl.com вне разрешённого списка.

## Вторая итерация: аудит и доделки (часть 8)

Статус частей: 1–7 ✅ (см. разделы выше). Этот раздел — проверка «что не доделано» и баги, найденные аудитом.

### Исправлено
* **`<leader>Hde` «🚀 Выполнить запрос»** — восстановлен. В прежней версии (и в `main`) он вызывал `DBUI ExecuteQuery`, но такой команды у vim-dadbod-ui нет (`:DBUI` не принимает аргументов). Теперь выполняет SQL-буфер через `:%DB` и только в буфере с `filetype=sql`.
* **`<leader>Tc` «❎ Закрыть все терминалы»** — восстановлен (в `main` был `<leader>Htc`). В toggleterm.nvim команды `ToggleTermCloseAll` **нет**, поэтому закрытие сделано через API плагина: `require("toggleterm.terminal").get_all(true)` + `shutdown()`. Учитываются и скрытые терминалы.
* **Переименованные репозитории плагинов** (GitHub-перенаправления работают, но спецификации обновлены): `echasnovski/mini.{ai,diff,surround,animate}` → `nvim-mini/*`; `williamboman/mason{,-lspconfig}.nvim` → `mason-org/*`; `yetone/avante.nvim` → `avante-corp/avante.nvim`; `NvChad/nvim-colorizer.lua` → `catgoose/nvim-colorizer.lua`; `mistweaverco/kulala.nvim` → `dont-be-evil-company/kulala.nvim`. Имена плагинов в lazy.nvim не менялись, `lazy-lock.json` не затронут.

### Добавлено в справку (раньше были рабочие клавиши без описания)
* `keydocs/g6_missing.lua` (40 записей): `<leader>bd`, `db`, `dt`, `du`, `dr`, `ft`, `ha`, `hh`, `h1`, `h2`, `ob`, `qs`, `r` (визуальный), `rr`, `tD`, `tf`, `tr`, `ts`, `to`, `ua`, `xx`, `z`, `nh`, все `<leader>A*` (Avante), `<F5>`, `<F10>`, `<F11>`, `gc`, `gcc`.
* `keydocs/g7_insert.lua` (16 записей): клавиши автодополнения и ИИ в режиме вставки (`<C-Space>`, `<C-b>`, `<C-f>`, `<C-e>`, `<C-p>`, `<Tab>`, `<M-l>`, `<M-]>`, `<M-[>`, `<C-]>`, `<C-s>`), `<C-c>` (CodeCompanion), выход из терминала `<C-\><C-n>`, а также `<leader>Hde` и `<leader>Tc`.
* Загрузчик `keydoc.lua` подключает обе группы.

### Проверки этой итерации
* Все Lua-файлы (включая `ru_util.lua` с DeepL): luacheck (mpeterv/luacheck, master, Lua 5.4), **ошибок синтаксиса нет**. Необъявленные глобальные: только ожидаемые `hs` (Hammerspoon), `Snacks` (создаётся плагином при загрузке) и `vim`.
* Все `require("config.*")` / `require("plugins.*")` (18 модулей) указывают на существующие файлы.
* Дублей глобальных клавиш (`vim.keymap.set` / `map` с одним режимом) нет.
* Устаревшие API не найдены: `get_active_clients`, `buf_get_clients`, `tbl_islist`, `lsp.diagnostic`, `goto_next`, `resolved_capabilities`, `setup_handlers`, `automatic_installation`. Использование `vim.loop` / `vim.highlight` — только с защитой (`vim.uv or vim.loop`).
* Библиотеки: 36 LSP-серверов (`neovim/nvim-lspconfig`), 45 парсеров Treesitter (`nvim-treesitter` ветка `main`, `vim.treesitter.start` вызывается явно), 31 форматтер (`stevearc/conform.nvim`). Все имена существуют. `automatic_enable` в `mason-lspconfig` — актуальная опция.
* Справка: 302 статических записи, дублей (`lhs`+режим) нет. Один пересечённый `b` — Super Mode (`hydra`), скрыт вне Super Mode.
* Логика DeepL (`ru_util.lua`): ключ — только через stdin curl; при неудаче DeepL — Google ×2 → MyMemory; `cb` вызывается ровно один раз.

### Не сделано / решения за пользователем
* **Архивные плагины** (только чтение, работают): `stevearc/dressing.nvim` (последний пуш 2025-02), `famiu/bufdelete.nvim` (2024-02). Возможная замена без новых зависимостей: `vim.ui.select` → `snacks.picker` (`picker.ui_select = true`), `<leader>bd` → `Snacks.bufdelete()`. Не менял без подтверждения.
* **Размер `<leader>Tv`**: в `main` было 40, в текущей версии 60 (без записи в журнале). Ожидает решения.
* **Избранные команды для подсказок**: 15 пользовательских команд без подсказок — `DiagRu`, `EnvCheck`, `Flex`, `HoverRu`, `HudClock`, `HudIp`, `HudNow`, `HudTz`, `Matrix`, `NotifyRu`, `RuCheck`, `StreakGoal`, `StreakHour`, `StreakNotify`, `StreakRepo`. Добавлять в `<leader>H` по выбору пользователя.
* **Реальный запуск `nvim`** в песочнице не проверен: релизы Neovim недоступны (`objects.githubusercontent.com` блокируется). Нужно `:checkhealth` и `:Lazy sync` (после переименований) на машине пользователя.

## Часть 9: огонёк сам, решения по архивным плагинам и утилиты

### Огонёк за коммиты — автоматически (`lua/config/streak.lua`)
* **Репозитории находятся сами**: при `BufEnter`/`DirChanged` определяется git-корень каталога (`git rev-parse --show-toplevel`), при старте сканируются папки `roots` (`~/code`, `~/projects`, `~/dev`, `~/Developer`, `~/src`… на 1–2 уровня). Найденное сохраняется в `streak.json` (`auto`). `:StreakRepo` больше не нужен.
* **Коммит и новая ветка пересчитываются сразу**: `fs_event` на `.git/logs` и `.git/refs/heads` + склейка через `debounce_ms` (800 мс). Не нужно ждать таймера 5 минут.
* **Новая ветка за день тоже зажигает огонёк** (`branch_counts = true`). Время создания берётся из первой строки reflog ветки (`.git/logs/refs/heads/<имя>`), учитываются только свои (по `user.email`). Поставьте `branch_counts = false`, если хотите только коммиты.
* **Триггеры без таймера**: возврат фокуса в nvim (`FocusGained`) и выход из терминала (`TermClose`: lazygit, git в toggleterm).
* Исправлено: `active_repos()` не вызывает `git` на каждом `BufEnter` (корень конфига кешируется); удалён ошибочный комментарий над `refresh_hud`; сообщение «нет репозитория» больше не предлагает `:StreakRepo`.
* Проверено на настоящем git: формат reflog (email и unix-время создания ветки) разбирается верно для `git branch` и `git switch -c`.

### Архивные плагины заменены (ответ на «решай сам»)
* `stevearc/dressing.nvim` (архив, 2025-02) → **удалён**. Выбор `vim.ui.select` теперь в **snacks.picker** (`picker = { enabled = true, ui_select = true }` в `snacks.lua`). Зависимость из avante убрана.
* `famiu/bufdelete.nvim` (архив, 2024-02) → **удалён**. `<leader>bd` → `Snacks.bufdelete()` (модуль уже в snacks.nvim).

### Остальные решения
* **`<leader>Tv` — размер 40** (как в `main`). Раньше здесь было 60 без записи в журнале.
* **Утилиты с клавишами**: группа **`<leader>HW` «🧰 Утилиты и диагностика»** (заглавная W — все строчные буквы под `<leader>H` заняты; прежнее утверждение «свободна только w» было ошибкой). Клавиши: `HWr` RuCheck, `HWh/HWd/HWn` переключатели HoverRu/DiagRu/NotifyRu, `HWe` EnvCheck, `HWm` Matrix, `HWt` HudNow, `HWi` HudIp toggle, `HWc/HWC` HudClock 24/12, `HWz` HudTz 3, `HWa/HWA` огонёк без/с уведомлениями, `HWg` StreakGoal 1, `HWb` StreakHour 3. Справка: `keydocs/g8_utils.lua`.

### Проверки
* luacheck (mpeterv/luacheck, Lua 5.4): синтаксических ошибок нет; необъявленных глобалей нет (кроме `hs`, `Snacks`, которые создаются средой или плагином).
* Справка: 317 статических записей; единственное пересечение — `b` (Super Mode, `hydra`), скрыто вне Super Mode.
* Межфайловых дублей клавиш `keymap.set` нет.
* Файлы `dressing.lua` и `bufdelete.lua` удалены; ссылок на `dressing`/`Bdelete` в коде нет.

### Не проверено
* Запуск настоящего `nvim`: в песочнице релизы Neovim недоступны. Нужно `:Lazy sync`, `:checkhealth`, затем `:Streak` и коммит в тестовом репозитории.
* `picker.ui_select` в snacks: поведение проверено по исходникам upstream, но не в живом Neovim (например, выбор структуры в `go_extras`).
