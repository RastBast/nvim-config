# Что исправлено в конфиге (2026-08-30)

## 2026-10-28 · Хэллоуин, markdown, avante, b → q, темы-оригиналы

- **avante:** `missing avante_templates` — нативные библиотеки не собирались. `build` теперь функция: сначала `build.sh` (готовые библиотеки из релиза), затем запасной `make` (нужен cargo). Вручную: `:Lazy build avante.nvim`.
- **Темы:** `VimEnter` убран, тема применяется сразу после `lazy.setup`. Пять полных схем — в оригинальном стиле и фоне. Добавлена 🎃 Halloween (чёрный фон, палитра).
- **Halloween в терминале:** `<leader>uH` / `:Halloween` — анимация с летучими мышами и призраком; `:Boo`; при выборе темы — уведомление с тыквой.
- **Клавиши:** `q` — назад к началу слова (spider), `b` — запись макросов.
- **Markdown:** `markdown-preview.nvim` (`<leader>mv`, `<leader>mV`, браузер, обновление на каждое изменение), `vim-markdown` (фолдинг `za`/`zc`).
- **Питомцы:** гофер перерисован; прогулка на всю нижнюю строку (`popup.width = "100%"`). Ходьба только по горизонтали — ограничение `pets.nvim`.
- **Шахматы:** клетка 6×3, фигуры глифами, окно 56×34.
- **Ghostty:** `scrollback-limit = 50000000` (байты, работает во всех версиях).

## 2026-10-28 · Ghostty, дерево файлов, темы без VimEnter, крупные шахматы

- **Ghostty:** ошибка `scrollback-limit-lines: unknown field` — ключа нет в старых версиях. Теперь
  `scrollback-limit = 50000000` (байты, работает везде). Из-за ошибки полноэкранный режим не включался.
- **Дерево файлов (nvim-tree):** фон `NvimTreeNormal`, `NvimTreeEndOfBuffer` и статусная строка
  теперь `#000000` во всех темах (раньше фон брала схема).
- **Темы:** убран `VimEnter` из `themes.setup()`. Вызов перенесён в `init.lua` после `lazy.setup`
  и страховочного `colorscheme`, сохранённая тема применяется сразу. У полных схем добавлен `priority = 1000`.
- **Шахматы:** клетка 6×3 символа, фигуры юникодными глифами ♔♕♖♗♘♙ / ♚♛♜♝♞♟, окно 56×34.
  Логика ходов не менялась (`chess_ui_smoke` 11/11, `chess_perft` 19/19).

## 2026-10-28 · Питомцы с картинками, шахматы, игры, картинки, история правок

**Питомцы.** Графика работает в Ghostty (Kitty graphics); Alacritty её не поддерживает — это и было причиной прежних проблем. Добавлены собственные виды: 🐹 гофер Харек (синий, Go), мемы 🐱 нян-кот, 🍞 тостер, 👻 призрак «бу». Спрайты — 128×88 PNG, генератор `tools/gen_pet_sprites.py`. Клавиши: `<leader>up` (меню), `ug`, `uy`, `ut`, `uG`; зеркала в `<leader>Hu…`. Исправлено для всех питомцев: кадры анимации читались в случайном порядке — теперь сортируются по номеру (`config/pets_custom.lua`). Умолчание `default_pet` стало `gopher` (было `dog`).

**Шахматы (`<leader>Xc`, `:Chess`).** Против ПК (5 уровней: Новичок, Лёгкий, Средний, Сильный, Мастер) и для двух игроков. Полные правила: рокировка, взятие на проходе, превращение, мат, пат, ничьи (50 ходов, повтор, недостаток материала). Отмена хода, переворот доски, история ходов. ИИ — negamax с альфа-бета и покоем на взятиях.
- Проверка: `tests/chess_perft.py` — perft совпадает с эталоном на 5 позициях (стартовая до глубины 4, Kiwipete до 3 и др.), мат и пат. `tests/chess_ui_smoke.py` — сценарий через заглушку `vim.*`: режим, ход, ответ ПК, отмена, превращение.

**Ещё две игры и одна вспомогательная.** Змейка (`<leader>Xs`, гофер-голова), тетрис (`<leader>Xt`), 2048 (`<leader>Xf`); меню `<leader>Xm`. Логика отделена от окна: `tests/games_logic.py`, 23 проверки.

**Чего не хватало (выбор сделан по необходимости).** Картинки в nvim через `snacks.image` (`<leader>Ii`, `<leader>If`); история правок `mbbill/undotree` (`<leader>v`); выравнивание `nvim-mini/mini.align` (`<leader>=`); запись через sudo (`:SudoWrite`, `<leader>qW`).

**Клавиши.** Все новые — под `<leader>`: `X*` игры, `I*` картинки, `v`, `=`, `qW`, `u*` питомцы; зеркала `<leader>HX…`, `<leader>HI…`, `<leader>HV`. Конфликт: `<leader>Hv` занят Go (`Hvc`), поэтому undotree в `HV`. `<leader>un` занят уведомлениями, поэтому нян-кот — `uy`.

**Документация.** DOCS.md: новые §41 (игры), §42 (питомцы и картинки), §43 (история, выравнивание, sudo); полный список перенесён в §44 (452 записи); команды §25 (61), плагины §26. Справка `<leader>?`: группа `g12_games_tools.lua`; `g2`/`g3` обновлены для `<leader>up`/`<leader>Hup`. `all_keymaps.txt` дополнен.

**Что не проверено.** Живой nvim в песочнице не запускался (его нет). Проверено: синтаксис всех Lua-файлов, тесты логики и UI-заглушкой, загрузка модулей. Визуал питомцев, шахматной доски и `:SudoWrite` нужно посмотреть в Ghostty на Mac.

## 2026-10-28 · Ghostty без рамок, 7 тем, быстрое перемещение, палитра команд

**Ghostty: полный экран без рамок.** В `macos/ghostty/config` добавлено: `window-decoration = none`,
`macos-titlebar-style = hidden`, `macos-window-buttons = hidden`, `fullscreen = non-native`,
`macos-non-native-fullscreen = true`. Вкладки (`macos-titlebar-style = tabs`) убраны: они оставляли
заголовок окна и не работают в полноэкранном режиме без рамок. Все ключи и значения сверены с
исходниками Ghostty (`src/config/Config.zig`, `src/input/Binding.zig`); действия `keybind` — с перечнем `Action`.
- Исправлено: ошибка `scrollback-limit-lines: unknown field` — этого ключа нет в старых версиях Ghostty.
  Теперь `scrollback-limit = 50000000` (байты, ~50 МБ), он работает во всех версиях. Из-за ошибки конфиг
  не применялся целиком, поэтому полноэкранный режим не включался.

**Семь цветовых тем, `<leader>uT` и `:Theme <имя>`.** Было две темы-оверлея на catppuccin. Теперь:
«Новая» и «Старая» (как были) и пять полных схем: `tokyonight` (Tokyo Night night), `gruvbox`,
`kanagawa` (wave), `rosepine` (moon), `carbonfox`. Полные схемы — отдельные плагины с `lazy = true`,
грузятся при выборе через `require("lazy").load`. Стартовая тема включается на `VimEnter`, потому что
`themes.setup()` вызывается до `lazy.setup()`. Фон у всех тем принудительно `#000000` (требование пользователя).
- Новые плагины добавлены в `lua/plugins/colorscheme.lua` и `lazy-lock.json` (commit SHA из GitHub API).
- Если схема не загрузилась — ERROR «Запусти :Lazy sync».

**Быстрое перемещение (новые клавиши).**
- `H` / `L` — в начало / конец строки (в визуальном — растягивают выделение). Экранные H и L заменены.
- `n` / `N` — поиск с центрированием строки (`nzzzv`, `Nzzzv`).
- `<M-1>`…`<M-4>` и `<leader>h3`/`<leader>h4` — файлы из Harpoon одним нажатием.
- `[b` / `]b` — предыдущая / следующая вкладка (буфер) в bufferline.
- Раздел доки «Быстрое перемещение: текст, файлы, вкладки». `<C-d>`/`<C-u>` уже делает neoscroll, не дублировалось.

**Палитра команд `<leader><Space>`** (`lua/config/cmd_palette.lua`). Все пользовательские команды с описанием
из `nvim_get_commands()`. Команды без аргументов запускаются сразу, с аргументами — подставляется `:Имя `.
Новые команды появляются сами. Парные поиски: `<leader>fc` и `<leader>fk` (Telescope) — тоже динамические.

**Справка и документация.** Новая группа `lua/config/keydocs/g11_moves.lua` (15 записей), подключена в
`keydoc.lua`. `<leader>uT` в `g1_editor.lua` обновлён под 7 тем. Счётчик справки: 425 (389 + 36 БД).
DOCS.md (раздел «Быстрое перемещение», §6, §26, §41, Ghostty, Темы), INSTALL.md (§1.1, §5.1),
`all_keymaps.txt` обновлены.

**Проверка.** Синтаксис 121 Lua-файла (lupa). Поведение тем и палитры — 37 тестов с заглушками `vim.*`
(все прошли). Конфиг Ghostty — 37 строк без ошибок по `Config.zig`. Не проверено в sandbox: живой
Neovim и Ghostty на Mac.

## 2026-10-28 · Универсальный ИИ (Groq), Ghostty, Go как в GoLand, перевод K

**Единая точка входа для ИИ — `lua/config/ai_api.lua`.** Один реестр провайдеров
(Groq, Gemini, OpenAI, OpenRouter, Mistral, DeepSeek, Kimi, Ollama, свой сервис через
`AI_BASE_URL`), один вызов (OpenAI-совместимый `/chat/completions`), ключи только из
переменных окружения. Groq — обязательный провайдер конфига.
- Новые команды: `:AiProvider [id]` (меню без аргумента), `:AiStatus` (только имена переменных),
  `:AiAsk [вопрос]`. Клавиши: `<leader>Ap` (выбор провайдера), `<leader>Aq` (быстрый вопрос).
- Перевод `K` (`lua/config/gloss.lua`) переведён на эту точку входа; формат строк, кеш и
  словарный запасной путь не менялись.
- avante получает провайдеров из реестра (через `__inherited_from = "openai"`), по умолчанию —
  `AI_PROVIDER`, иначе Gemini. CodeCompanion — адаптеры Groq и «свой сервис».
- Сохранено: `GEMINI_ENDPOINT`, `GEMINI_PROXY`, `GEMINI_INSECURE` (PROXY.md) — Gemini в реестре
  читает их, как раньше.
- Модель Groq по умолчанию — `openai/gpt-oss-120b`. `llama-3.3-70b-versatile` и `qwen3-32b`
  выведены Groq (см. console.groq.com/docs/deprecations), поэтому старая модель по умолчанию убрана.
- Инструкция для fish (`set -Ux GROQ_API_KEY "…"`) — INSTALL.md §4.6, DOCS.md §39. Ключ в репозиторий не пишется.

**Перевод `K`: грамматика появляется сразу.** Окно перерисовывается (`redraw`) сразу после
ответа ИИ или словаря. Раньше обновление применялось только после следующего нажатия клавиши.

**Ghostty — основной терминал.** Конфиг `macos/ghostty/config`: фон `#000000`, палитра
пользователя, выделение и свечение `#0d00ff`, `macos-option-as-alt = true`.
Навигация по панелям: `ctrl+shift+h/j/k/l` (как hjkl в nvim), размер — `ctrl+shift+alt+hjkl`,
`cmd+d` / `cmd+shift+d` — делить, `cmd+shift+enter` — зум панели, `ctrl+shift+e` — выровнять.
Почему не `cmd+h`: это системное «Скрыть». Установка — INSTALL.md §1.1.

**Go как в GoLand — `lua/config/go_ide.lua`.** Меню `<leader>gi` (зеркало `<leader>HGi`, `:GoIde`)
и клавиши: `gT` тест для функции (gotests или каркас), `gC` конструктор `New<Тип>`, `gD` godoc,
`ga` файл ↔ `_test.go`, `go` импорты, `gr` запуск пакета, `gx` извлечь выделение (визуал).
Меню объединяет уже существующие функции (`:GoIfErr`, `:GoImpl`, `:GoAddTag`, формочка struct,
тест под курсором, references, rename, code action) — без дублирования. Проверено на дубли:
`go_extras.lua`, `go-tools.lua`, `go_snips.lua`, `go_infra_snips.lua` — конфликтов клавиш нет.

**Справка и документация.** Новая группа `lua/config/keydocs/g10_ai_go.lua` (11 клавиш);
подпись `<leader>Hat` исправлена (была «Чат с Kimi»). В `DOCS.md`: §6, §12 (Ghostty), §17, §22,
§25 (команды, 55), §28 (Go IDE), §38 (исправление K), §39 (ИИ), §41. `all_keymaps.txt`: 410 записей
(справка 374 = 363 keydocs + 11 зеркал `<leader>HU…`, БД 36) — счётчик пересчитан по `keydocs` и `tui_tools`.

**Проверка.** Синтаксис всех изменённых Lua — загрузка через lupa. Логика — 78 тестов
с заглушками `vim.*` (выбор провайдера, ключ не попадает в argv curl, ошибки HTTP,
Gemini-прокси, перерисовка `K`, генерация Go-кода по фиктивным узлам treesitter).
В sandbox нет nvim, go, gotests и ghostty — живой запуск на Mac не выполнялся.

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

## Часть 10: скрыть IP в углу

* **`<leader>Huo`** — скрыть / показать IP в правом верхнем углу HUD. Время и заряд остаются. Пока IP скрыт, публичный адрес по сети не запрашивается.
* **`:HudIp hide | show | toggle`** — то же из командной строки. Прежние режимы `lan | public | both | off` работают как раньше.
* `<leader>Hui` по-прежнему циклически переключает режимы IP (lan → public → both → off).
* Исправлено: клавиша `HWi` из группы «🧰 Утилиты» вызывала `:HudIp toggle`, которого не существовало. Она удалена, её функцию теперь выполняет `<leader>Huo`.

### Предупреждение «Origin has changed» в :Lazy
После переименования репозиториев (часть 9) lazy видит, что плагин склонирован со старого адреса. Это одноразово. Выполните `:Lazy update avante.nvim kulala.nvim mason.nvim mason-lspconfig.nvim mini.ai mini.animate mini.diff mini.surround nvim-colorizer.lua` (или просто `:Lazy update`). Lazy переклонирует каталоги с нового адреса.

## Часть 11: перевод на `K` и DeepL

### Причина, почему на `K` не было перевода
* **`noice.nvim` перехватывал `K`.** По умолчанию noice подменяет `vim.lsp.buf.hover` своей функцией и показывает подсказку в собственном окне, мимо `vim.lsp.util.open_floating_preview`. Перехват перевода (`lua/config/hover_ru.lua`) стоит именно на `open_floating_preview`, поэтому на `K` он не срабатывал вообще.
* Исправлено: в `lua/plugins/noice.lua` добавлено `lsp.hover = { enabled = false }`. `K` теперь идёт штатным путём, и перевод показывается сразу. Окно noice для `K` больше не используется; остальные функции noice (уведомления, командная строка, сообщения) не затронуты.
* Проверено по исходникам upstream `folke/noice.nvim` (`lua/noice/lsp/init.lua`, строки 19–20: `if Config.options.lsp.hover.enabled then vim.lsp.buf.hover = M.hover`).

### DeepL: хост по ключу
* Раньше запрос шёл только на `api-free.deepl.com`. Pro-ключ (без суффикса `:fx`) на этом хосте отказывал, и перевод молча уходил на Google.
* Теперь хост выбирается по ключу: суффикс `:fx` → `api-free.deepl.com`, иначе → `api.deepl.com`.
* Ключ по-прежнему берётся только из `DEEPL_API_KEY` и передаётся curl через stdin. В файлы и git он не пишется.

### Как подключить DeepL (для пользователя)
1. Ключ: личный кабинет DeepL → Account → API keys. Free-ключ оканчивается на `:fx`.
2. В fish (вы используете fish): `set -Ux DEEPL_API_KEY "ваш_ключ"`. Переменная сохранится, открыть новый терминал и запустить `nvim` из него.
3. Если nvim запускается из Dock или Spotlight, fish-переменные туда не попадают. Тогда выполните `launchctl setenv DEEPL_API_KEY "ваш_ключ"` (действует до перезагрузки) и перезапустите nvim.
4. Проверка: в nvim `:RuCheck`. Строка DeepL должна показать «работает → «…»» с переводом, а не «пропущен: не задан DEEPL_API_KEY» или «недоступен».
5. Если ключ уже когда-либо отправлялся в чат или файл, перевыпустите его в кабинете DeepL и обновите переменную.

### Проверки
* luacheck: синтаксических ошибок (E) нет; новых предупреждений нет.
* kd_check: 317 записей справки, дубль только `b|n` (Super Mode).
* Не проверено: живой `nvim` и реальные запросы к DeepL/Google. В песочнице сеть до переводчиков недоступна.

### Hammerspoon: мёртвая переменная
* `macos/hammerspoon/init.lua`: удалена `pillText`. Её значение нигде не читалось; текст плашки хранится в элементе холста, а скрытие выполняет таймер. Поведение не меняется.

### Решения пользователя
* **`<leader>tD`** (документация символа в боковом окне справа): оставлена. Описание в справке (`g6_missing.lua`) проверено по коду; добавлена строка в `DOCS.md`.
* **Огонёк**: допущение «создание ветки = активность» подтверждено пользователем, оставлено как есть. Коммит и новая ветка за день считаются активностью.

## Часть 12: баги из живой установки, навигация по панелям и показ нажатий

### Исправлено
* **`Invalid terminal direction` (terminal.lua:466) при полноэкранном Telegram** (`<leader>mf`, `:TeleFull`). В `telegram.lua` режим `full` имел `direction = "editor"`, а toggleterm знает только `float`, `horizontal`, `vertical`, `tab`. Теперь `full = { direction = "tab" }`: терминал открывается во всю ширину и высоту в отдельной вкладке.
* **`E5108 Invalid 'split': Expected Lua string` (telegram.lua:640)**. `nvim_open_win(..., { split = true })`: параметр `split` принимает строку (`"below"`, `"right"` и т. д.). Исправлено в трёх местах (инбокс, список, окно сообщения): `split = "below"`.
* В `keymaps.lua` восстановлено правильное экранирование `"<C-\\><C-n>"` (моя промежуточная правка сломала строку, `luacheck` поймал это как синтаксическую ошибку `011`).

### Навигация по панелям
* **`<leader>Wf`** — фокус в дерево файлов (открывает, если закрыто).
* **`<leader>Wc`** — фокус обратно в код (предыдущее окно или первое окно с файлом).
* **`<leader>Wt`** — фокус в терминал (снизу или плавающий; если его нет, открывает снизу).
* **`<leader>Wo`** / **`<leader>Wx`** — оставить только текущее окно / закрыть его.
* **`<C-h/j/k/l>`** теперь при входе в терминал сразу включают режим ввода. Ctrl-h и Ctrl-j в терминале не перехватываются: в shell это backspace и перенос строки.
* Подсказки: группа `<leader>W` видна в всплывающем меню сразу после пробела. Все клавиши есть в справке (`<leader>?`).

### Показ нажатий в Neovim
* **`<leader>kk`** или **`:KeyShow`** — включить / выключить строку нажатых клавиш внизу экрана (`lua/config/keyshow.lua`).
* Учитываются только клавиши, набранные вручную: макросы и маппинги не попадают в строку.
* Клавиша гаснет через ~1.5 с. Показываются не больше 10 последних.
* Системный показ на весь macOS (вне Neovim) остаётся в Hammerspoon, как и было подтверждено.

### Проверки
* luacheck: синтаксических ошибок (E, 011) нет. Новых предупреждений нет.
* Справка: 323 записи (добавлены 6 новых клавиш `<leader>W*` и `<leader>kk`), дубль только `b|n` (Super Mode).
* Не проверено: живой запуск Neovim, фокус в дерево и обратно, поведение `vim.on_key` на macOS. Проверьте `<leader>Wf/Wc/Wt` и `<leader>kk` у себя.

## Часть 13: подписи в меню <leader> и цвета

### Подписи (скриншот меню `<leader>`)
* У групп `A, P, a, b, g, h, j, n, o, p, q, r, s, t, u, x` не было названий, в меню стояло «+7 keymaps». Добавлены названия (`lua/plugins/which-key.lua`).
* `<leader>e` показывала «NvimTreeToggle»: у клавиши не было описания. Теперь «🌲 Дерево файлов: вкл/выкл».
* `<leader>qs` (восстановить сессию проекта) тоже без описания. Исправлено.

### Цвета (скриншот-пример)
* Фон `#000000` → `#061115` (почти чёрный с холодным оттенком, не резкий).
* Номер текущей строки: неоново-зелёный `#00ff00` → тёплый золотой `#d8b878`.
* Синтаксис взят из примера: ключевые слова сиреневые, функции голубые, строки золотые, числа оранжевые, переменные песочные, типы голубые. Палитра в `init.lua` (таблица `P`).
* Подсказки which-key: клавиша коралловая, группа голубая, описание светлое, разделители тусклые.
* Функции оставлены подчёркнутыми, как было. Если хотите без подчёркивания, скажите.

### Проверки
* luacheck: синтаксических ошибок нет.
* Не проверено в живом Neovim: итоговый вид. Цвета подобраны по пикселям скриншота, но интерфейс может выглядеть по-другому в вашем терминале.

## Часть 14: цвета «на чёрном» и запрос в Firefox

### Цвета
* Фон остался тёмным (`#061115`), без белого и без анимаций.
* `#0d00ff` — синее свечение: рамки плавающих окон и разделители, выделение (Visual), поиск (Search, IncSearch), разделители which-key.
* Цвета стали ярче и немного «кислотнее»: ключевые слова электрически-фиолетовые, строки и номер текущей строки кислотно-лаймовые (`#d4ff3a`), функции яркие синие, типы циановые, числа янтарные, параметры розовые.
* Палитра одна, в таблице `P` в `init.lua`. Фон в `colorscheme.lua` и `init.lua` согласован.

### Запрос в Firefox
* **`<leader>Ab`** — Neovim спрашивает запрос, открывает Firefox с ответом. Из выделения (`v` и `<leader>Ab`) подставляет выделенный текст.
* **`:Ask текст`** — то же из командной строки.
* По умолчанию сервис Perplexity (ответ с источниками). Другие в `lua/config/browser_ask.lua` (`M.engine`): duckduckgo, google, chatgpt.
* На macOS Firefox открывается через `open -a Firefox`; на Linux через `firefox`.

### Проверки
* luacheck: синтаксических ошибок нет.
* Не проверено в живом Neovim и в Firefox: формат ссылки `?q=` у сервиса может измениться. Если ответ не подставляется, поправьте URL в `ENGINES`.

### Выбор сервиса префиксом
* В начале запроса: `P=текст` или `?P=текст` → Perplexity; `G=текст` или `?G=текст` → Google. Регистр не важен.
* Дополнительно: `D=` → DuckDuckGo, `C=` → ChatGPT.
* Без префикса используется сервис по умолчанию (`M.engine`, сейчас Perplexity).
* Разбор проверен на шаблоне Lua: `P=`, `?P=`, `?g=`, обычный текст, пустой запрос после префикса.

## Часть 15: палитра пользователя, чёрный фон, переменные ≠ строки

* Палитра по выбору пользователя: фиолетовый `#6902de`, оранжевый `#ff9500`, чёрный `#000000`, зелёный `#2bff00`, красный `#ff0000`, жёлтый `#fffb00`, голубой `#00eeff`.
* **Фон строго чёрный** `#000000`: окна, меню, плавающие панели, статусная строка.
* **Go: переменные отличаются от строк.** Переменные и поля — зелёные, строки в кавычках — жёлтые. Параметры — оранжевые курсивом.
* Ключевые слова — красные, функции — голубые (с подчёркиванием, как было), типы — оранжевые, числа и константы — фиолетовые жирным.
* Номер текущей строки оранжевый, остальные номера фиолетовые. Подсказки which-key: клавиша красная, группа голубая.
* Синее свечение `#0d00ff` на рамках, выделении и поиске сохранено.

### Проверки
* luacheck: синтаксических ошибок нет.
* Контраст фиолетового `#6902de` на чёрном около 2.7:1. Для комментариев и номеров строк это приемлемо, но для текста кода он слабее остальных. Если нужно, константы можно перевести на голубой или оранжевый.
* Не проверено в живом Neovim: итоговый вид в терминале.

## Часть 16: выбор темы в Neovim (две темы)

* **`<leader>uT`** или **`:Theme`** — меню тем (через `vim.ui.select`, то есть через snacks.picker). Текущая отмечена точкой.
* **`:Theme new`** / **`:Theme classic`** — переключение из командной строки. Имена подсказываются по Tab.
* Выбор сохраняется в `stdpath("state")/theme.txt` и применяется при следующем запуске.
* **«Новая»** — текущая: чёрный фон `#000000`, палитра пользователя, синее свечение `#0d00ff`.
* **«Старая»** — прежние цвета: фон `#000000`, неоново-зелёный номер строки `#00ff00`, функции фиолетовые `#c792ea` с подчёркиванием, переменные лаймовые `#c3e88d`. Взято из коммита `338f31f`, то есть до правок цветов.
* Обе темы строятся на catppuccin-mocha. Цвета задаются в `lua/config/themes.lua`. Блок ColorScheme из `init.lua` перенесён туда, а из `colorscheme.lua` убраны дублирующие `custom_highlights`.

### Проверки
* luacheck: синтаксических ошибок нет.
* Логика проверена на заглушке `vim`: переключение, сохранение в файл, загрузка при старте, предупреждение для неизвестной темы, команда и клавиша зарегистрированы.
* Не проверено в живом Neovim: внешний вид каждой темы и работа snacks.picker в меню.


## Часть 17: GitHub, GitLab и Хабр прямо в Neovim

* **`<leader>Gh`** — GitHub: `gh dash` (дашборд PR и issues) в плавающем терминале, как `tele`. Если нет `gh` или расширения `dlvhdr/gh-dash`, показывает команду установки и не открывает терминал.
* **`<leader>Gl`** — GitLab: `glab-tui` (merge requests и issues GitLab, работает поверх `glab`) в плавающем терминале. Имя утилиты задаётся константой `GITLAB_BIN` в `lua/config/webtools.lua`; альтернатива — `gitlab-tui`.
* **`<leader>Gb`** и **`:Habr`** — читалка Хабра. Список свежих статей берётся из RSS `habr.com/ru/rss/articles/`, `vim.ui.select` выбирает статью. Текст берётся из JSON API (`/kek/v2/articles/{id}/?fl=ru&hl=ru`, поле `textHtml`) и открывается во вкладке scratch-буфера в markdown. `q` закрывает вкладку, `o` открывает статью в браузере.
* Конвертация HTML в текст: `pandoc`, если установлен; иначе встроенный конвертер на Lua (абзацы, заголовки, списки, `<pre>`, HTML-сущности).
* Группа `<leader>G` («🐙 GitHub · 🦊 GitLab · 📰 Хабр») видна в which-key и справке `<leader>?`. Подсказки установки добавлены в `termcmd.hints`.
* Модуль: `lua/config/webtools.lua`, подключён в `init.lua`.

### Проверки
* Синтаксис всех изменённых Lua-файлов проверен через `load` (luacheck из pip не ставится в sandbox).
* RSS-разбор и HTML→текст проверены на вымышленных примерах: заголовки с CDATA, даты, сущности, списки, `<pre>`.
* Не проверено: живой запрос к habr.com и `gh`, `glab-tui` с вашими токенами. Sandbox не ходит на habr.com напрямую. Проверяется на Mac: `:Habr`, `<leader>Gb`, `<leader>Gh`, `<leader>Gl`.
* Вход в GitHub и GitLab нужен один раз: `gh auth login` и `glab auth login`.

## Часть 18: Mason (cmake) и полная документация

* **Mason: `failed to install cmake` исправлен.** Имя `cmake` в mason-lspconfig соответствует пакету `cmake-language-server`. Он ставится из PyPI, версия 0.1.11 требует Python `<3.14`. На новом Python установка падала. Заменён на `neocmake` (бинарник neocmakelsp из GitHub, не зависит от Python). Файл: `lua/config/languages.lua`.
* **DOCS.md обновлён:**
  * §6 «Таблица горячих клавиш» пересобрана из исходников: 296 клавиш, режимы, группы which-key, Super Mode, автодополнение, буферные клавиши (telegram, Habr, справка), клавиши `<leader>D…` по СУБД. Старая таблица не содержала новых клавиш.
  * §4 структура: убраны несуществующие `options.lua` и `autocmds.lua`, перечислены все модули `lua/config`.
  * §18 языки и LSP: таблица из `languages.lua`, отдельно — что ставит Mason, а что нет (форматтеры вручную).
  * §19: строки про cmake и про удалённые dressing/bufdelete.
  * §22: честно описано, как проверялось и что не проверено (живой nvim не запускался).
  * §25 (новый): все пользовательские команды, 48 штук, включая 28 `:Tele*`.
  * §26 (новый): все плагины из спецификаций (110 репозиториев), назначение и наличие в `lazy-lock.json`.
* **`all_keymaps.txt`** (корень) пересобран из того же списка: 353 строки.
* **Справка `<leader>?` дополнена:** `<leader>HuM`, `<Tab>`/`<S-Tab>` (буферы), `iu`/`au` (treesitter-unit), `<C-\>` (терминал), `<CR>` и `<C-n>` в режиме вставки. Описания `iu`/`au` сверены с README плагина.

### Найдено при сверке, но не исправлено
* **lazy-lock.json не содержит 22 плагина** из спецификаций (например, `diffview.nvim`, `nvim-lint`, `treesj`, `lspkind.nvim`, `avante.nvim`, `git-conflict.nvim`). Их версии не зафиксированы. Нужен `:Lazy sync` на Mac и коммит обновлённого lock-файла.
* В lock-файле остались записи `dressing.nvim` и `bufdelete.nvim`, которых уже нет в конфиге.

### Проверки
* Синтаксис всех 113 `.lua` файлов (через `load`, lupa): ошибок нет, маркеров конфликта нет.
* Покрытие справки: каждая клавиша из §6 есть в `keydocs`, кроме составных подписей вроде `<C-b> / <C-f>` и текста «q / <Esc>» (описаны в своих строках).
* Не проверено: живой запуск nvim, `:Mason` на Mac (после исправления cmake), работа пикеров и внешний вид.

## Часть 19: проверка плагинов и LSP по `:Lazy`

* По выводу `:Lazy` все плагины из §26 загружены или ждут триггера. Недостающих нет. `nvim-spotify` отключён осознанно.
* Все 44 имени LSP из `languages.lua` есть в актуальном `nvim-lspconfig` (`lsp/<имя>.lua`).
* Сверка с реестром Mason: `metals` (Scala) в реестре **нет**, а стоял в `lsp`. Mason пытался бы его поставить и падал бы. Перенесён в `toolchain` (установка: `cs install metals`, Coursier). Файл: `lua/config/languages.lua`, §18 DOCS.md.
* `dartls` и `sourcekit` тоже без пакета Mason, но они уже в `toolchain`, это ожидаемо.
* В выводе `:Lazy` видно `Updated (1): nvim-lspconfig`. После обновления на Mac `lazy-lock.json` меняется. Его нужно закоммитить вместе с конфигом.

## Часть 20: английский по словам (`K` в визуальном режиме)

* Новый модуль `lua/config/gloss.lua` (подключён в `init.lua`, группа `<leader>K` в which-key).
* Выделил фразу в визуальном режиме и нажал `K`: окно с исходным текстом, переводом фразы и разбором по словам в формате `- **слово** [транскрипция] — «перевод» (часть речи, грамматика)`. С `GEMINI_API_KEY` разбор делает ИИ с учётом контекста. Без ключа — словарь + таблица IPA→кириллица. Закрывается `q` или `Esc`.
* `<leader>Kw` — то же для слова под курсором. `:Gloss` — для диапазона строк.
* Перевод: `ru_util` (DeepL через `DEEPL_API_KEY`, иначе Google/MyMemory). Транскрипция, часть речи и значение: `dictionaryapi.dev` без ключа. Не найдено — «—».
* Ограничения: грамматика — это часть речи и значение из словаря, а не разбор времён и падежей. Слова переводятся без контекста фразы. Не больше 40 слов за раз. Ответ по-русски и транскрипция в IPA, без русской транслитерации.
* Клавиша `K` в визуальном режиме раньше не была занята. Обычный `K` (подсказка hover и предпросмотр сворачивания) не менялся.
* Документация: `DOCS.md` §4 (структура), §6 (визуал `K`, `<leader>Kw`), §8 (абзац про перевод рядом с «Русский в подсказках»), §25 (`:Gloss`). Справка `keydocs/g8_utils.lua` дополнена.
* Проверено: синтаксис (lupa), токенизация, лимит слов, разбор ответа словаря (в т.ч. неизвестное слово), вывод разбора. Не проверено: само окно в живом nvim и запрос к dictionaryapi.dev (sandbox не пускает на этот хост).

## Часть 21: TUI-утилиты в Neovim (`<leader>U`) и исправление номеров терминалов

* Новый модуль `lua/config/tui_tools.lua`, группа `<leader>U`. Утилиты открываются в плавающем терминале, как Tele:
  `Uk` k9s · `Ur` iredis · `Uc` redis-cli · `Up` pgcli · `Ul` lazysql · `Ud` lazydocker · `Ui` dive · `Ub` btop · `Ua` ktea.
  `Uu` — меню всех утилит (`:Tui`), `Uh` — проверка установки (`:TuiCheck`).
* Подключения из переменных окружения: `NVIM_REDIS_URL` (iredis, redis-cli), `NVIM_DB_PG` (pgcli, та же переменная, что у `<leader>Dp`). Пароли в файлы не пишутся.
* **Исправлена ошибка:** номера терминалов toggleterm задавались вручную и совпадали. `k9s` и `gh dash` оба были 120, `kubectl pods` и GitLab — 121. Теперь `config/termcmd.lua` выдаёт номер по самой команде (одна команда — один терминал). Вызовы `termcmd.make(cmd, id, title)` не меняются, второй аргумент игнорируется.
* Справка: `lua/config/keydocs/g9_tui.lua`, подключена в `keydoc.lua`.
* Проверено через lupa: подстановка URL, меню, проверка установки, номера терминалов, dive. Не проверено: открытие окон в живом nvim, сами утилиты на Mac.

## Часть 22: полная документация по технологиям и всем клавишам

* `DOCS.md` дополнен разделами **§27–§41**: указатель по технологиям; Go; PostgreSQL и другие БД; Redis; Docker; Kubernetes; Kafka; Protobuf и gRPC; HTTP (kulala); Git, GitHub и GitLab; терминал и TUI; переводы; ИИ; мессенджеры; полный список клавиш. В разделах 8–13 добавлены ссылки «Подробно по технологии».
* Таблицы клавиш в технологических разделах собраны из `lua/config/keydocs/` (тот же источник, что и `<leader>?`). Каждая клавиша сверена с записью справки. Клавиши БД (`<leader>D…`) — из `db_menu.lua`.
* §41 содержит все **399** записей: 363 из справки (включая зеркала `<leader>HU…`, которые создаёт цикл в `tui_tools.lua`) и 36 клавиш `<leader>D<СУБД><действие>`.
* §25 пересобран: **51** команда `:`, из них **27** `:Tele*`. Пустые описания заполнены: `:DiagRu`, `:HoverRu`, `:NotifyRu`, `:RuCheck`, `:EnvCheck`, `:Flex`, `:Matrix`.
* §6: добавлены таблицы «TUI-утилиты» и «перевод по словам».
* Исправлены неверные клавиши в старом тексте: `<leader>HGb/HGo/HGl/HGv/HGe/HGj/HGi/HGs/HGm` (заменены на `<leader>gb`, `<leader>gt`, `<leader>gl`, `<leader>gv`, `<leader>gm`, `<leader>Hgt` и др.), `<leader>Du` → `<leader>du`, `<leader>Hur` → `<leader>rr`/`<leader>Hrr`, `<leader>Huz/Hus/Hut/HuP` → `<leader>z`, `<leader>sc`, `<leader>pt/ps/pp/pr`. Упоминание `dressing` в пояснениях о стеке — только как «удалён».
* Убрано несуществующее `:KulalaScratchpad` (в `kulala.lua` такой команды нет).
* Комментарий в `notify_ru.lua` ссылался на удалённую клавишу `<leader>HGb`; исправлен на «сборку Go».
* `all_keymaps.txt` пересобран (399 записей, с описаниями в DOCS §41).
* Проверено: `check_docs_keys.py` по `lua/` (427 уникальных обозначений в DOCS). Оставшиеся «не найдено» — составные обозначения (`<leader>tt/te`, `<leader>Pl / Pb / Pg`), пояснения «не существуют» и зеркала `<leader>HU…`, которые создаёт цикл. Все они ожидаемы. Числа и порядок разделов проверены после сборки.
* Не проверено: живой запуск nvim в sandbox; описания клавиш внутри `k9s`, `lazydocker`, `btop` (по памяти, не по README).
