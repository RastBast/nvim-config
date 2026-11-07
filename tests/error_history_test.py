#!/usr/bin/env python3
"""Тесты раздела ошибок <leader>x:
  1) <leader>xe (:ErrorLast10) — последние 10 ошибок Neovim
  2) <leader>xj (:ErrorLog)    — полный журнал ошибок Neovim
  3) Счётчик ошибок ❗N для Lualine (пусто при 0)
  4) Переход Enter / gf на файл:строку из стектрейса (включая усечённые пути ...)
  5) Разбор выбранной ошибки через ИИ (клавиша a -> config.ai_api)"""
import os
import sys

from lupa import luajit21 as lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
checked = 0
failed = 0


def check(cond, msg):
    global checked, failed
    checked += 1
    if cond:
        print(f"OK   {msg}")
    else:
        failed += 1
        print(f"FAIL {msg}")


def main():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ROOT = ROOT
    g.PY_ISFILE = lambda p: os.path.isfile(p)
    g.PY_LISTDIR = lambda p: sorted(os.listdir(p)) if os.path.isdir(p) else []
    g.PY_ISDIR = lambda p: os.path.isdir(p)
    lua.execute(
        r"""
        package.path = ROOT .. "/lua/?.lua;" .. ROOT .. "/lua/?/init.lua;" .. package.path

        MAPS = {}
        BUF_MAPS = {}
        CMDS = {}
        BUF_LINES = {}
        REGS = {}
        EDITED_PATH = nil
        CURSOR_SET = nil
        CURSOR_ROW = 5
        AI_FLOATS = {}

        package.loaded["config.ai_api"] = {
          chat = function(messages, opts, cb)
            LAST_AI_PROMPT = messages[2].content
            cb("Причина: ошибка теста.\nИсправление: поправить строку.", nil, { name = "MockAI" })
          end,
          float = function(title, text)
            AI_FLOATS[#AI_FLOATS + 1] = { title = title, text = text }
          end,
        }

        local function tbl_extend(_, a, b)
          local out = {}
          for k, v in pairs(a or {}) do out[k] = v end
          for k, v in pairs(b or {}) do out[k] = v end
          return out
        end

        vim = {
          v = { errmsg = "" },
          o = { columns = 120, lines = 40 },
          env = { HOME = "/home/user" },
          bo = setmetatable({}, { __index = function(t, k) local b = {}; rawset(t, k, b); return b end }),
          wo = setmetatable({}, { __index = function(t, k) local w = {}; rawset(t, k, w); return w end }),
          log = { levels = { INFO = 2, WARN = 3, ERROR = 4 } },
          trim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end,
          tbl_extend = tbl_extend,
          notify = function() end,
          cmd = function(c)
            local p = c:match("^edit%s+(.+)$")
            if p then EDITED_PATH = p end
          end,
          fn = {
            setreg = function(reg, val) REGS[reg] = val end,
            getcwd = function() return ROOT end,
            stdpath = function() return ROOT end,
            filereadable = function(p) return PY_ISFILE(p) and 1 or 0 end,
            fnameescape = function(p) return p end,
            fnamemodify = function(p, mod)
              if mod == ":t" then return p:match("([^/]+)$") or p end
              return p
            end,
          },
          uv = {
            fs_scandir = function(dir)
              local py_list = PY_LISTDIR(dir)
              local items = {}
              for item in python.iter(py_list) do items[#items + 1] = item end
              local i = 0
              return {
                step = function()
                  i = i + 1
                  local name = items[i]
                  if not name then return nil end
                  return name, (PY_ISDIR(dir .. "/" .. name) and "directory" or "file")
                end,
              }
            end,
            fs_scandir_next = function(h) return h.step() end,
          },
          api = {
            nvim_create_augroup = function(name) return name end,
            nvim_create_autocmd = function() end,
            nvim_create_user_command = function(name, fn) CMDS[name] = fn end,
            nvim_list_uis = function() return { { width = 120, height = 40 } } end,
            nvim_create_buf = function() return 10 end,
            nvim_buf_is_valid = function() return true end,
            nvim_buf_set_lines = function(_, _, _, _, lines) BUF_LINES = lines end,
            nvim_buf_get_lines = function(_, s, e)
              return { BUF_LINES[s + 1] or "" }
            end,
            nvim_get_current_win = function() return 1 end,
            nvim_open_win = function() return 20 end,
            nvim_win_is_valid = function() return true end,
            nvim_win_set_config = function() end,
            nvim_set_current_win = function() end,
            nvim_win_get_cursor = function() return { CURSOR_ROW, 0 } end,
            nvim_win_set_cursor = function(_, pos) CURSOR_SET = pos end,
            nvim_win_close = function() end,
            nvim_echo = function() end,
            nvim_exec2 = function(cmd)
              if cmd == "messages" then
                return {
                  output = table.concat({
                    "обычная строка без ошибки",
                    "E5108: Error executing lua ...lua/config/architecture.lua:39: boom",
                    "stack traceback:",
                    "\t" .. ROOT .. "/init.lua:24: in main chunk",
                  }, "\n"),
                }
              end
              return { output = "" }
            end,
          },
          keymap = {
            set = function(mode, lhs, rhs, opts)
              if opts and opts.buffer then
                BUF_MAPS[lhs] = rhs
              else
                MAPS[lhs] = { mode = mode, rhs = rhs, desc = opts and opts.desc }
              end
            end,
          },
        }

        local EH = require("config.error_history")
        EH.setup()

        COMP_EMPTY = EH.component()

        for i = 1, 12 do
          vim.notify(string.format("Ошибка плагина #%02d", i), vim.log.levels.ERROR, { title = "plugin" })
        end
        vim.notify("Ошибка плагина #12", vim.log.levels.ERROR, { title = "plugin" })
        vim.notify("Просто предупреждение", vim.log.levels.WARN)
        vim.v.errmsg = "E492: Not an editor command: FooBar"

        COMP_ACTIVE = EH.component()

        CMDS.ErrorLast10()
        LAST10_TEXT = table.concat(BUF_LINES, "\n")

        -- Находим строку со стектрейсом init.lua:24 и нажимаем Enter для прыжка к файлу:строке!
        for idx, l in ipairs(BUF_LINES) do
          if l:find("init.lua:24", 1, true) then
            CURSOR_ROW = idx
            break
          end
        end
        BUF_MAPS["<CR>"]()

        -- Проверяем разбор усечённого Neovim пути `...lua/config/architecture.lua:39:`
        TRUNC_LOC = EH.parse_location("E5108: Lua: ...lua/config/architecture.lua:39: bad arg")

        -- Нажимаем клавишу `a` внутри окна ошибок для разбора через ИИ:
        BUF_MAPS["a"]()

        CMDS.ErrorLog()
        FULL_LOG_TEXT = table.concat(BUF_LINES, "\n")

        BUF_MAPS["<Tab>"]()
        TAB_TEXT = table.concat(BUF_LINES, "\n")

        BUF_MAPS["y"]()

        EH.clear()
        COMP_AFTER_CLEAR = EH.component()
        """
    )

    maps = lua.eval("MAPS")
    check("<leader>xe" in maps, "макрос 1 (<leader>xe) зарегистрирован для последних 10 ошибок")
    check("<leader>xj" in maps, "макрос 2 (<leader>xj) зарегистрирован для полного журнала ошибок")
    check("<leader>Hxe" in maps and "<leader>Hxj" in maps, "зеркала <leader>Hxe и <leader>Hxj зарегистрированы в главном меню")
    check("<leader>xl" not in maps, "<leader>xl НЕ перезаписан (сохранён за Trouble Location List)")

    check(lua.eval("COMP_EMPTY") == "", "индикатор Lualine пустой при 0 ошибок")
    check(lua.eval("COMP_ACTIVE") == "❗13", "индикатор Lualine показывает ❗13 при накопленных ошибках")
    check(lua.eval("COMP_AFTER_CLEAR") == "", "после очистки журнала индикатор Lualine снова пустой")

    last10 = lua.eval("LAST10_TEXT")
    full_log = lua.eval("FULL_LOG_TEXT")
    tab_text = lua.eval("TAB_TEXT")

    check("показано 10 из 14" in last10, ":ErrorLast10 показывает ровно 10 последних из 14 уникальных ошибок")
    check("Ошибка плагина #05" in last10 and "Ошибка плагина #04" not in last10, ":ErrorLast10 отсекает старые записи #01..#04")
    check("×2" in last10, "подряд идущие дубликаты склеиваются с пометкой ×2")
    check("Просто предупреждение" not in full_log, "WARN-сообщения не попадают в журнал ошибок")
    check("E492: Not an editor command: FooBar" in last10, "ошибки v:errmsg перехватываются")
    check("E5108: Error executing lua" in last10 and "stack traceback:" in last10, "многострочный stack traceback из :messages склеивается в одну запись")
    check("Ошибка плагина #01" in full_log and "Ошибка плагина #12" in full_log, ":ErrorLog показывает все 14 ошибок сеанса")
    check("Последние 10 ошибок" in tab_text, "клавиша Tab внутри окна переключает полный журнал ↔ последние 10")
    check("E492" in lua.eval("REGS['+']"), "клавиша y копирует показанные ошибки в системный буфер +")

    edited_path = lua.eval("EDITED_PATH")
    cursor_line = lua.eval("CURSOR_SET and CURSOR_SET[1]")
    check(edited_path == os.path.join(ROOT, "init.lua") and cursor_line == 24, "нажатие Enter в окне ошибок открывает точный файл и ставит курсор на строку стектрейса")

    trunc_path = lua.eval("TRUNC_LOC and TRUNC_LOC.path")
    trunc_line = lua.eval("TRUNC_LOC and TRUNC_LOC.line")
    check(trunc_path == os.path.join(ROOT, "lua/config/architecture.lua") and trunc_line == 39, "parse_location восстанавливает полный путь к файлу даже из усечённой записи `...`")

    check(lua.eval("#AI_FLOATS") == 1 and "MockAI" in lua.eval("AI_FLOATS[1].title"), "клавиша a в окне ошибок отправляет ошибку в config.ai_api и открывает разбор ИИ")

    with open(os.path.join(ROOT, "lua", "plugins", "lualine.lua"), "r", encoding="utf-8") as f:
        lualine_src = f.read()
    check("config.error_history" in lualine_src and "on_click" in lualine_src, "lualine.lua выводит кликабельный счётчик ошибок Neovim")


if __name__ == "__main__":
    main()
    print(f"\nпроверок: {checked}, провалов: {failed}")
    sys.exit(1 if failed else 0)
