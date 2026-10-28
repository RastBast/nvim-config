# macOS: клавиатура на всю систему и 9 слотов буфера обмена

Всё это работает **вне Neovim**. Neovim-часть — в `lua/config/yank_ring.lua` и `lua/config/keydoc.lua`.

## 1. Визуализация нажатий

Две независимые утилиты, можно поставить одну или обе.

### KeyCastr — текст сочетаний
```sh
brew install --cask keycastr
```
Запустить, в System Settings → Privacy & Security → **Input Monitoring** включить KeyCastr.
Показывает нажатые клавиши текстом (например `⌘⇧P`) поверх всех окон.

### Hammerspoon — экранная ANSI-клавиатура (`hammerspoon/init.lua`)
```sh
brew install --cask hammerspoon
mkdir -p ~/.hammerspoon
ln -sf "$PWD/hammerspoon/init.lua" ~/.hammerspoon/init.lua   # из каталога macos/ репозитория
```
Запустить Hammerspoon, выдать ему **Accessibility** (System Settings → Privacy & Security → Accessibility),
затем **Reload Config** из меню Hammerspoon.

- `⌃⌥⌘K` — показать/спрятать оверлей;
- сверху плашка последнего сочетания, снизу клавиатура с подсветкой нажатых клавиш;
- конфиг не меняет клавиши: события только читаются (`eventtap` возвращает `false`).

> Оверлей не перехватывает ввод. Если в конфиге появятся свои горячие клавиши, они будут
> работать как обычно, оверлей их лишь покажет.

## 2. Буфер обмена: 9 слотов

Нужно «9 регистров и в Neovim, и на macOS». Соответствие:

| Что | Neovim | macOS (Maccy) |
|---|---|---|
| Последнее копирование | `p` | ⌘V |
| 1–9 последних копирований | `"1p` … `"9p` | `⌘1` … `⌘9` в окне Maccy |
| Список всех 9 | `<leader>yr` | `⌘⇧C` (окно Maccy) |

Neovim: `yy`/`yiw`/`y…` кладут текст в `"1`, предыдущие сдвигаются в `"2`…`"9`.
Удаления Vim (многострочные `d`) тоже заполняют `"1`…`"9` — это штатное поведение Vim.

### Maccy — история системного буфера
```sh
brew install --cask maccy
defaults write org.p0deje.Maccy historySize 9   # хранить 9 последних записей
```
Открыть окно: `⌘⇧C` (по умолчанию, меняется в настройках Maccy). В окне `⌘1`…`⌘9` вставляют первые 9 записей.
Проверьте в настройках Maccy раздел «Ignore»: пароли из менеджеров лучше не сохранять.

## 3. Что проверить после установки

- KeyCastr и Hammerspoon не показывают ничего → проверить Input Monitoring / Accessibility.
- В Neovim `<leader>?` + клавиши → текст справки; `<leader>?m` → режим справки (объяснять вместо выполнения).
