#!/usr/bin/env python3
"""Прототип Mermaid: сохранность буферов, меню, узлы/стрелки, отмены и гонки.

Использует реальные функции модуля на LuaJIT и модель API Neovim. На диск ничего
не записывает. Проверка с настоящим nvim — в architecture_nvim_smoke.py.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402

checks = []


def check(name, cond, extra=""):
    checks.append((name, bool(cond)))
    print(("OK   " if cond else "FAIL ") + name + ("" if cond or not extra else f"   [{extra}]"))


PRELUDE = r'''
BUFFERS, DISK, CURRENT, NEXT_BUF = {}, {}, 1, 1
INPUT, SELECT = nil, nil
EDIT_FAIL, PREVIEW_FAIL, PREVIEW_COUNT = false, false, 0
POST_EDIT_CHANGE = false
vim.bo = setmetatable({}, {
  __index = function(_, key)
    if type(key) == "number" then return BUFFERS[key].bo end
    return BUFFERS[CURRENT].bo[key]
  end,
})
vim.fn.fnamemodify = function(path) if path:sub(1,1) == "/" then return path end return "/project/" .. path end
vim.fn.expand = function(path) if path == "~" then return "/home/test" end return path end
vim.fn.bufnr = function(path)
  for id, buf in pairs(BUFFERS) do if buf.name == path and buf.valid then return id end end
  return -1
end
vim.uv.fs_lstat = function(path) return DISK[path] and {type="file"} or nil end
vim.api.nvim_get_current_buf = function() return CURRENT end
vim.api.nvim_list_bufs = function() local out = {}; for b in pairs(BUFFERS) do out[#out + 1] = b end; return out end
vim.api.nvim_buf_get_name = function(b) return BUFFERS[b].name end
vim.api.nvim_buf_is_valid = function(b) return BUFFERS[b] and BUFFERS[b].valid or false end
vim.api.nvim_buf_is_loaded = function(b) return BUFFERS[b] and BUFFERS[b].loaded or false end
vim.api.nvim_buf_get_lines = function(b, first, last)
  local lines, out = BUFFERS[b].lines, {}
  if last < 0 then last = #lines end
  for i = first + 1, math.min(last, #lines) do out[#out + 1] = lines[i] end
  return out
end
vim.api.nvim_buf_set_lines = function(b, first, last, _, replacement)
  local buf, out = BUFFERS[b], {}
  if not buf.bo.modifiable then error("not modifiable") end
  if last < 0 then last = #buf.lines end
  for i = 1, first do out[#out + 1] = buf.lines[i] end
  for _, line in ipairs(replacement) do out[#out + 1] = line end
  for i = last + 1, #buf.lines do out[#out + 1] = buf.lines[i] end
  if #out == 0 then out = {""} end
  buf.lines, buf.bo.modified = out, true
end
vim.cmd = {
  edit = function(o)
    if EDIT_FAIL then error("E37: unsaved buffer") end
    local name = o.args[1]
    local id = vim.fn.bufnr(name)
    if id < 0 then
      NEXT_BUF = NEXT_BUF + 1; id = NEXT_BUF
      local content = DISK[name] or {""}
      local copied = {}; for _, line in ipairs(content) do copied[#copied + 1] = line end
      BUFFERS[id] = {name=name, lines=copied, valid=true, loaded=true, bo={filetype="markdown", modifiable=true, modified=false}}
    end
    CURRENT = id
    if POST_EDIT_CHANGE then BUFFERS[id].lines = {"user data"}; BUFFERS[id].bo.modified = true end
  end,
  MarkdownPreview = function()
    if PREVIEW_FAIL then error("E492: no preview") end
    PREVIEW_COUNT = PREVIEW_COUNT + 1
  end,
}
vim.ui = {
  input = function(opts, cb) INPUT = {opts=opts, cb=cb} end,
  select = function(items, opts, cb) SELECT = {items=items, opts=opts, cb=cb} end,
}
function ANSWER_INPUT(value) local x=INPUT; INPUT=nil; assert(x, "no input"); x.cb(value) end
function ANSWER_SELECT(n) local x=SELECT; SELECT=nil; assert(x, "no selection"); x.cb(n and x.items[n] or nil) end
function CURRENT_LINES() return table.concat(BUFFERS[CURRENT].lines, "\n") end
function LINES(b) return table.concat(BUFFERS[b].lines, "\n") end
function LAST_NOTE() return #NOTES > 0 and NOTES[#NOTES].msg or "" end
function RESET()
  BUFFERS = {[1]={name="", lines={""}, valid=true, loaded=true, bo={filetype="markdown", modifiable=true, modified=false}}}
  DISK, CURRENT, NEXT_BUF, NOTES, CMDS, KEYS = {}, 1, 1, {}, {}, {}
  INPUT, SELECT, EDIT_FAIL, PREVIEW_FAIL, PREVIEW_COUNT, POST_EDIT_CHANGE = nil, nil, false, false, 0, false
  package.loaded["config.architecture"] = nil
  A = require("config.architecture")
  A.setup()
end
'''


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    with open(os.path.join(_lua.ROOT, "tests", "lua_stubs.lua"), encoding="utf-8") as fh:
        rt.execute(fh.read())
    rt.execute(PRELUDE)

    def run(s):
        rt.execute(s)

    run("RESET()")
    check("все команды и меню зарегистрированы", rt.eval("CMDS.ArchNew and CMDS.ArchMenu and CMDS.ArchInsert and CMDS.ArchNode and CMDS.ArchLink and CMDS.ArchPreview") is not None)
    check("клавиша меню mA существует", rt.eval("KEYS[1].lhs") == "<leader>mA")
    run("A.new('/project/arch with space.md')")
    text = rt.eval("CURRENT_LINES()")
    check("новый файл: шаблон Mermaid в буфере", "```mermaid\ngraph LR" in text and 'N1["Клиент"]' in text)
    check("новый файл не записывается автоматически", rt.eval("DISK['/project/arch with space.md']") is None and rt.eval("BUFFERS[CURRENT].bo.modified") is True)
    check("имя файла с пробелами не потеряно", rt.eval("BUFFERS[CURRENT].name") == "/project/arch with space.md")
    run("A.new('/project/arch with space.md')")
    check("повторный вызов не перезаписывает незаписанный буфер", rt.eval("CURRENT_LINES()") == text and "без изменений" in rt.eval("LAST_NOTE()"))

    run("RESET(); DISK['/project/existing.md']={'# Мой текст','важное'}; A.new('/project/existing.md')")
    check("существующий файл не меняется", rt.eval("CURRENT_LINES()") == "# Мой текст\nважное" and rt.eval("BUFFERS[CURRENT].bo.modified") is False)
    run("A.insert()")
    check("схема добавлена в конец существующего markdown", rt.eval("CURRENT_LINES()").startswith("# Мой текст\nважное\n\n<!-- nvim-architecture:start -->"))
    before = rt.eval("CURRENT_LINES()")
    run("A.insert()")
    check("повторные маркеры не вставляются", rt.eval("CURRENT_LINES()") == before and "уже есть" in rt.eval("LAST_NOTE()"))

    run("RESET(); POST_EDIT_CHANGE=true; A.new('/project/new.md')")
    check("автокоманда, изменившая буфер при открытии, не затёрта", rt.eval("CURRENT_LINES()") == "user data" and "ничего не перезаписано" in rt.eval("LAST_NOTE()"))
    run("RESET(); EDIT_FAIL=true; A.new('/project/new.md')")
    check("ошибка открытия не уничтожает предыдущий буфер", rt.eval("CURRENT_LINES()") == "" and "E37" in rt.eval("LAST_NOTE()"))
    run("RESET(); A.new(); ANSWER_INPUT(nil)")
    check("отмена выбора файла ничего не создаёт", rt.eval("NEXT_BUF") == 1)
    run("RESET(); A.new(); ANSWER_INPUT('~/diagram.md')")
    check("путь ~ разворачивается безопасно", rt.eval("BUFFERS[CURRENT].name") == "/home/test/diagram.md")

    run("RESET(); A.new('architecture.md'); A.add_node(); ANSWER_INPUT('Auth \"OAuth\" | #<team>&')")
    text = rt.eval("CURRENT_LINES()")
    check("узел получает следующий ID и Mermaid-экранирование",
          'N4["Auth #quot;OAuth#quot; #124; #35;#60;team#62;#38;"]' in text, text)
    run("A.add_node(); ANSWER_INPUT('  ')")
    check("пустое имя узла отклоняется", rt.eval("CURRENT_LINES()") == text and "пустым" in rt.eval("LAST_NOTE()"))
    run("A.add_node(); ANSWER_INPUT(nil)")
    check("отмена ввода не меняет буфер", rt.eval("CURRENT_LINES()") == text)
    run("A.add_link(); ANSWER_SELECT(1); ANSWER_SELECT(4); ANSWER_INPUT('HTTPS | API')")
    text2 = rt.eval("CURRENT_LINES()")
    check("направленная связь с подписью создана", 'N1 -->|"HTTPS #124; API"| N4' in text2, text2)
    run("A.add_link(); ANSWER_SELECT(2); ANSWER_SELECT(1); ANSWER_INPUT('')")
    check("пустая подпись создаёт обычную стрелку", "N2 --> N1" in rt.eval("CURRENT_LINES()"))
    run("A.add_link(); ANSWER_SELECT(nil)")
    check("отмена выбора связи не повреждает буфер", rt.eval("SELECT") is None)

    # Изменение или закрытие буфера между вопросами не должно добавить стрелку.
    run("RESET(); A.new('architecture.md'); A.add_link(); ANSWER_SELECT(1); ANSWER_SELECT(2)")
    run("for i,l in ipairs(BUFFERS[CURRENT].lines) do if l:find('N1%[') then BUFFERS[CURRENT].lines[i]='  N1[\"Другой\"]' end end")
    before = rt.eval("CURRENT_LINES()")
    run("ANSWER_INPUT('new link')")
    check("переименованный компонент не соединяется по старому выбору", rt.eval("CURRENT_LINES()") == before and "изменился" in rt.eval("LAST_NOTE()"))
    run("RESET(); A.new('architecture.md'); A.add_node(); BUFFERS[CURRENT].valid=false; ANSWER_INPUT('lost')")
    check("закрытый буфер в асинхронном callback не вызывает ошибки", "буфер закрыт" in rt.eval("LAST_NOTE()"))

    run("RESET(); BUFFERS[1].lines={'# обычный Markdown'}; A.add_node()")
    check("чужой Markdown не модифицируется без маркеров", rt.eval("CURRENT_LINES()") == "# обычный Markdown" and ":ArchInsert" in rt.eval("LAST_NOTE()"))
    run("RESET(); A.new('architecture.md'); table.insert(BUFFERS[CURRENT].lines, '<!-- nvim-architecture:start -->'); A.add_node()")
    check("повторные маркеры отклоняются", "нужен один блок" in rt.eval("LAST_NOTE()"))
    run("RESET(); A.new('architecture.md'); BUFFERS[CURRENT].bo.modifiable=false; A.add_node()")
    check("readonly-буфер не изменяется", "нельзя редактировать" in rt.eval("LAST_NOTE()"))
    run("RESET(); BUFFERS[1].bo.filetype='lua'; A.insert()")
    check("схема не вставляется в исходный код вместо Markdown", "Markdown" in rt.eval("LAST_NOTE()"))
    run("RESET(); A.preview()")
    check("превью вызывает MarkdownPreview", rt.eval("PREVIEW_COUNT") == 1)
    run("PREVIEW_FAIL=true; A.preview()")
    check("отсутствие превью даёт инструкцию", ":Lazy build markdown-preview.nvim" in rt.eval("LAST_NOTE()"))
    run("RESET(); A.menu()")
    check("в меню есть интерактивная схема, локальный анализ и Mermaid", rt.eval("#SELECT.items") == 9)

    failed = sum(1 for _, ok in checks if not ok)
    print(f"\nпроверок: {len(checks)}, провалов: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
