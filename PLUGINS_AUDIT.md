# Аудит плагинов: что уже есть, что добавить, что не нужно

Дата: 2026-10-15. Проверено по `lua/plugins/*.lua` (поиск по имени репозитория).
Статусы: ✅ уже есть · ➕ добавить · ❓ нужно решение · ⛔ не добавлять (дубль или бессмысленно).

## ✅ Уже есть (ничего не ставим)

| Из вашего списка | Что стоит в конфиге | Файл |
|---|---|---|
| folke/todo-comments.nvim | todo-comments | `todo.lua` |
| stevearc/dressing.nvim | dressing | `dressing.lua` |
| rcarriga/nvim-notify | nvim-notify (+ noice) | `notify.lua`, `noice.lua` |
| ThePrimeagen/harpoon | harpoon | `harpoon.lua` |
| windwp/nvim-ts-autotag | nvim-ts-autotag | `autotag.lua` |
| numToStr/Comment.nvim | Comment.nvim | `comment.lua` |
| stevearc/aerial.nvim (вместо simrat39/symbols-outline) | aerial | `aerial.lua` |
| SmiteshP/nvim-navic (вместо LunarVim/breadcrumbs) | nvim-navic | `navic.lua` |
| williamboman/mason.nvim | mason | `lsp-config.lua` |
| neovim/nvim-lspconfig | nvim-lspconfig | `lsp-config.lua` |
| j-hui/fidget.nvim | fidget | `fidget.lua` |
| mfussenegger/nvim-dap, rcarriga/nvim-dap-ui | dap + dap-ui | `dap.lua` |
| stevearc/conform.nvim | conform | `format.lua` |
| folke/trouble.nvim | trouble | `trouble.lua` |
| lewis6991/gitsigns.nvim | gitsigns | `gitsigns.lua` |
| kdheepak/lazygit.nvim | lazygit | `lazygit.lua` |
| epwalsh/obsidian.nvim | obsidian | `obsidian.lua` |
| yetone/avante.nvim | avante | `avante.lua` |
| MeanderingProgrammer/render-markdown.nvim | render-markdown | `markdown.lua`, `avante.lua` |
| akinsho/toggleterm.nvim | toggleterm | `toggleterm.lua` |
| michaelrommel/nvim-silicon (вместо code-shot) | nvim-silicon | `silicon.lua` |
| echasnovski/mini.surround (вместо kylechui/nvim-surround) | mini.surround | `mini.lua` |
| echasnovski/mini.diff (частично закрывает diffview) | mini.diff | `ai.lua`, `mini.lua` |
| MunifTanjim/nui.nvim, nvim-treesitter, nvim-web-devicons | зависимости | несколько |
| `vim.opt.termguicolors = true` | уже в настройках | `init.lua`, строка 27 |

## ➕ Добавлено (решение пользователя: «все 10»; flatten и cheat.sh тоже)

Статус: добавлено в конфиг, проверено по исходникам плагинов и харнессом (без запуска Neovim).
Файлы: `lint.lua`, `lightbulb.lua`, `spider.lua`, `treesj.lua`, `visual-multi.lua`,
`diffview.lua`, `git-conflict.lua`, `cheatsheet.lua`, `flatten.lua`, `completions.lua` (lspkind).
Клавиши: `<leader>cl`, `<leader>cj/cs/cJ`, `<leader>Hgv/Hgf/Hgq`, `<leader>Hgm…`, `<leader>Hk…`.

| Плагин | Зачем | Примечание |
|---|---|---|
| mfussenegger/nvim-lint | асинхронные линтеры (в конфиге есть только форматтеры) | нужны линтеры для языков из `languages.lua` |
| onsails/lspkind.nvim | иконки типов в автодополнении | подключить к `cmp`, сейчас иконок нет |
| kosayoda/nvim-lightbulb | лампочка, если есть code action | нужен LSP с code actions |
| chrisgrieser/nvim-spider | умные `w`/`e`/`b` с учётом CamelCase и snake_case | переопределяет клавиши движения |
| Wansmer/treesj | разделить/собрать строку (список, аргументы) | клавиша `<leader>j…` свободна? проверить при добавлении |
| mg979/vim-visual-multi | много курсоров | `<C-n>` в normal-режиме, в insert не конфликтует с cmp |
| sindrets/diffview.nvim | сравнение веток, история файла, конфликты | дополняет gitsigns |
| akinsho/git-conflict.nvim | подсветка и выбор мерж-конфликтов | дополняет diffview |
| RishabhRD/nvim-cheat.sh | шпаргалки cheat.sh в окне | нужен `curl` и интернет |
| willothy/flatten.nvim | `nvim` внутри терминала открывает файл в родительском Neovim | нужен только если часто запускаете `nvim` в toggleterm |

## ❓ Нужно ваше решение

| Плагин | Почему вопрос |
|---|---|
| rustaceanvim | заменяет `rust_analyzer` из lspconfig. Нужен ли вам Rust? (сейчас `rust` в `languages.lua`) |
| pmizio/typescript-tools.nvim | заменяет `ts_ls`. Пишете ли вы TS/JS часто? |
| nvim-neorg/neorg | дублирует obsidian.nvim (заметки). Оставить только obsidian? |
| peek.nvim или markdown-preview.nvim | предпросмотр Markdown в браузере. Какой нужен? |
| milanglacier/yaspeller.nvim | нужна ли русская орфография? Требует внешние утилиты |
| Ovinghand/compiler.nvim | запуск/сборка в один клик. Какие проекты собирать? |
| nvim-tmux-navigation | только если вы используете tmux. Используете? |
| octo.nvim | PR и issues прямо в Neovim. Нужен `gh` (есть на машине?) |
| nvim-telescope/telescope-file-browser | у вас уже есть nvim-tree. Нужен второй файловый менеджер? |

## ⛔ Не добавлять (дубли или бессмысленно)

| Плагин | Причина |
|---|---|
| nvim-lua/none-ls | conform + nvim-lint делают то же самое, а none-ls добавит ещё один слой |
| NeogitOrg/neogit | дубль lazygit, который уже есть |
| vidocqh/data-viewer.nvim | дубль vim-dadbod-ui (`<leader>D`) |
| cbochs/grapple.nvim | дубль harpoon |
| termim.nvim, vim-floaterm | дубли toggleterm |
| linrongbin16/git-filer.nvim | узкая задача, без практической пользы для вас |
| code-shot/nvim | дубль nvim-silicon |
| kylechui/nvim-surround | дубль mini.surround |
| simrat39/symbols-outline.nvim, LunarVim/breadcrumbs.nvim | дубли aerial и navic |

## Заметка про «указатели на типы» (как в VS Code)

Наведение на слово с типом и документацией уже делает `K` (LSP hover, `hover_ru.lua` переводит
его на русский). Если вам нужно, чтобы подсказка появлялась сама при паузе курсора, это отдельное
решение: настроить автопоказ hover или добавить плагин. Вопрос в общем списке уточнений.
