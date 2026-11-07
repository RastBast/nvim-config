#!/usr/bin/env python3
"""Тесты раздела ошибок <leader>x с 2 макросами:
  1) <leader>xe (:ErrorLast10) — последние 10 ошибок Neovim
  2) <leader>xj (:ErrorLog)    — полный журнал ошибок Neovim
и проверка отсутствия конфликта с <leader>xl (Trouble loclist)."""
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
    lua.execute(
        r"""
        package.path = ROOT .. "/lua/?.lua;" .. ROOT .. "/lua/?/init.lua;" .. package.path

        MAPS = {}
        BUF_MAPS = {}
        CMDS = {}
        BUF_LINES = {}
        REGS = {}

        local function tbl_extend(_, a, b)
          local out = {}
          for k, v in pairs(a or {}) do out[k] = v end
          for k, v in pairs(b or {}) do out[k] = v end
          return out
        end

        vim = {
          v = { errmsg = "" },
          o = { columns = 120, lines = 40 },
          bo = setmetatable({}, { __index = function(t, k) local b = {}; rawset(t, k, b); return b end }),
          wo = setmetatable({}, { __index = function(t, k) local w = {}; rawset(t, k, w); return w end }),
          log = { levels = { INFO = 2, WARN = 3, ERROR = 4 } },
          trim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end,
          tbl_extend = tbl_extend,
          notify = function() end,
          fn = {
            setreg = function(reg, val) REGS[reg] = val end,
          },
          api = {
            nvim_create_augroup = function(name) return name end,
            nvim_create_autocmd = function() end,
            nvim_create_user_command = function(name, fn) CMDS[name] = fn end,
            nvim_list_uis = function() return { { width = 120, height = 40 } } end,
            nvim_create_buf = function() return 10 end,
            nvim_buf_is_valid = function() return true end,
            nvim_buf_set_lines = function(_, _, _, _, lines) BUF_LINES = lines end,
            nvim_open_win = function() return 20 end,
            nvim_win_is_valid = function() return true end,
            nvim_win_set_config = function() end,
            nvim_set_current_win = function() end,
            nvim_win_close = function() end,
            nvim_echo = function() end,
            nvim_exec2 = function(cmd)
              if cmd == "messages" then
                return {
                  output = table.concat({
                    "обычная строка без ошибки",
                    "E5108: Error executing lua test.lua:7: boom",
                    "stack traceback:",
                    "\ttest.lua:7: in function 'run'",
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

        -- Генерируем 12 ошибок через vim.notify + дубль подряд + 1 через v:errmsg + 1 из :messages = 14 уникальных
        for i = 1, 12 do
          vim.notify(string.format("Ошибка плагина #%02d", i), vim.log.levels.ERROR, { title = "plugin" })
        end
        -- Повтор последней ошибки (должен склеиться в ×2, не вытесняя предыдущие!)
        vim.notify("Ошибка плагина #12", vim.log.levels.ERROR, { title = "plugin" })
        -- WARN не должен попадать в ошибки:
        vim.notify("Просто предупреждение", vim.log.levels.WARN)
        -- Ошибка командной строки в v:errmsg:
        vim.v.errmsg = "E492: Not an editor command: FooBar"

        CMDS.ErrorLast10()
        LAST10_TEXT = table.concat(BUF_LINES, "\n")

        CMDS.ErrorLog()
        FULL_LOG_TEXT = table.concat(BUF_LINES, "\n")

        -- Переключение Tab внутри окна (из log обратно в last10):
        BUF_MAPS["<Tab>"]()
        TAB_TEXT = table.concat(BUF_LINES, "\n")

        -- Копирование в системный буфер обмена:
        BUF_MAPS["y"]()

        -- Очистка сеансового буфера:
        EH.clear()
        """
    )

    maps = lua.eval("MAPS")
    check("<leader>xe" in maps, "макрос 1 (<leader>xe) зарегистрирован для последних 10 ошибок")
    check("<leader>xj" in maps, "макрос 2 (<leader>xj) зарегистрирован для полного журнала ошибок")
    check("<leader>Hxe" in maps and "<leader>Hxj" in maps, "зеркала <leader>Hxe и <leader>Hxj зарегистрированы в главном меню")
    check("<leader>xl" not in maps, "<leader>xl НЕ перезаписан (сохранён за Trouble Location List)")

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


if __name__ == "__main__":
    main()
    print(f"\nпроверок: {checked}, провалов: {failed}")
    sys.exit(1 if failed else 0)
