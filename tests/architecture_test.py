#!/usr/bin/env python3
"""Тесты визуальной архитектуры приложения и связей:
  - модель architecture.json + экспорт Mermaid/Markdown;
  - авто-сканер Go + docker-compose и реального Lua-репозитория nvim-config;
  - доска :ArchBoard в Neovim (навигация, сдвиг, переход Enter к файлу);
  - команды :Arch*, клавиши <leader>mA* / <leader>Haa без конфликта с <leader>a (Aerial);
  - наличие веб-холста assets/architecture_editor.html."""
import json
import os
import sys
import tempfile

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


def make_lua_env(tmpdir):
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ROOT = ROOT
    g.TMP = tmpdir
    g.PY_LISTDIR = lambda p: sorted(os.listdir(p)) if os.path.isdir(p) else []
    g.PY_ISDIR = lambda p: os.path.isdir(p)
    g.PY_ISFILE = lambda p: os.path.isfile(p)
    g.PY_MKDIR = lambda p: os.makedirs(p, exist_ok=True)
    g.PY_CHARLEN = lambda s: len(str(s or ""))
    g.PY_CHARSUB = lambda s, start, length: str(s or "")[int(start): int(start) + int(length)]
    lua.execute(
        r"""
        package.path = ROOT .. "/lua/?.lua;" .. ROOT .. "/lua/?/init.lua;" .. package.path

        MAPS = {}
        BUF_MAPS = {}
        CMDS = {}
        BUF_LINES = {}
        EDITED_FILE = nil

        vim = {
          o = { columns = 130, lines = 42 },
          bo = setmetatable({}, { __index = function(t, k) local b = {}; rawset(t, k, b); return b end }),
          wo = setmetatable({}, { __index = function(t, k) local w = {}; rawset(t, k, w); return w end }),
          log = { levels = { INFO = 2, WARN = 3, ERROR = 4 } },
          trim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end,
          pesc = function(s) return (tostring(s):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) end,
          notify = function() end,
          cmd = function(c)
            local p = c:match("^edit%s+(.+)$")
            if p then EDITED_FILE = p end
          end,
          json = {
            decode = function(raw) return PY_JSON_DECODE(raw) end,
            encode = function(tbl) return "{}" end,
          },
          fs = {
            root = function() return TMP end,
          },
          fn = {
            getcwd = function() return TMP end,
            stdpath = function() return ROOT end,
            fnamemodify = function(p, mod)
              if mod == ":h" then return p:match("^(.*)/[^/]+$") or "." end
              if mod == ":t" then return p:match("([^/]+)$") or p end
              return p
            end,
            isdirectory = function(p) return PY_ISDIR(p) and 1 or 0 end,
            filereadable = function(p) return PY_ISFILE(p) and 1 or 0 end,
            mkdir = function(p) PY_MKDIR(p) end,
            fnameescape = function(p) return p end,
            strdisplaywidth = function(s) return PY_CHARLEN(tostring(s or "")) end,
            strcharpart = function(s, start, len) return PY_CHARSUB(tostring(s or ""), start, len) end,
          },
          uv = {
            fs_stat = function(p)
              if PY_ISDIR(p) then return { type = "directory" } end
              if PY_ISFILE(p) then return { type = "file" } end
              return nil
            end,
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
                  local full = dir .. "/" .. name
                  return name, (PY_ISDIR(full) and "directory" or "file")
                end,
              }
            end,
            fs_scandir_next = function(h) return h.step() end,
          },
          api = {
            nvim_create_user_command = function(name, fn) CMDS[name] = fn end,
            nvim_create_augroup = function(n) return n end,
            nvim_create_autocmd = function() end,
            nvim_list_uis = function() return { { width = 130, height = 42 } } end,
            nvim_create_buf = function() return 11 end,
            nvim_buf_is_valid = function() return true end,
            nvim_buf_set_lines = function(_, _, _, _, lines) BUF_LINES = lines end,
            nvim_create_namespace = function() return 1 end,
            nvim_buf_clear_namespace = function() end,
            nvim_buf_add_highlight = function() end,
            nvim_open_win = function() return 22 end,
            nvim_win_is_valid = function() return true end,
            nvim_win_set_config = function() end,
            nvim_set_current_win = function() end,
            nvim_win_close = function() end,
            nvim_echo = function() end,
          },
          keymap = {
            set = function(mode, lhs, rhs, opts)
              if opts and opts.buffer then
                BUF_MAPS[lhs] = rhs
              else
                MAPS[lhs] = { mode = mode, rhs = rhs }
              end
            end,
          },
        }
        """
    )

    def py_json_decode(raw):
        data = json.loads(raw)

        def to_lua(val):
            if isinstance(val, dict):
                t = lua.table()
                for k, v in val.items():
                    t[k] = to_lua(v)
                return t
            if isinstance(val, list):
                t = lua.table()
                for idx, v in enumerate(val, 1):
                    t[idx] = to_lua(v)
                return t
            return val

        return to_lua(data)

    g.PY_JSON_DECODE = py_json_decode
    return lua


def main():
    with tempfile.TemporaryDirectory() as tmpdir:
        # Создаём мини-проект на Go + docker-compose для проверки авто-сканера
        os.makedirs(os.path.join(tmpdir, "cmd", "api"), exist_ok=True)
        os.makedirs(os.path.join(tmpdir, "internal", "orders"), exist_ok=True)
        with open(os.path.join(tmpdir, "go.mod"), "w", encoding="utf-8") as f:
            f.write("module example.com/shop\n\ngo 1.23\n")
        with open(os.path.join(tmpdir, "cmd", "api", "main.go"), "w", encoding="utf-8") as f:
            f.write('package main\nimport "example.com/shop/internal/orders"\nfunc main() { _ = orders.New() }\n')
        with open(os.path.join(tmpdir, "internal", "orders", "service.go"), "w", encoding="utf-8") as f:
            f.write("package orders\nfunc New() int { return 1 }\n")
        with open(os.path.join(tmpdir, "docker-compose.yml"), "w", encoding="utf-8") as f:
            f.write("services:\n  db:\n    image: postgres:16\n  cache:\n    image: redis:7\n")

        lua = make_lua_env(tmpdir)
        lua.execute(
            r"""
            local Arch = require("config.architecture")
            local Model = require("config.architecture_model")
            local Scan = require("config.architecture_scan")
            local Board = require("config.architecture_board")

            Arch.setup()

            -- 1. Проверяем модель, связи разных типов и Mermaid/Markdown экспорт:
            local doc = Model.default_doc("Тестовая система")
            Model.upsert_node(doc, { id = "billing", label = "Billing", kind = "service", path = "internal/orders", tech = "Go" })
            Model.add_edge(doc, "api_gateway", "billing", "gRPC", "sync")
            Model.add_edge(doc, "billing", "event_bus", "InvoicePaid", "async")
            Model.add_edge(doc, "billing", "primary_db", "SQL", "data")
            MMD = Model.to_mermaid(doc)
            MD = Model.to_markdown(doc)

            local paths = Model.default_paths(TMP)
            Model.save_file(paths.json, doc)
            RELOADED = Model.load_file(paths.json)

            -- Удаление узла должно каскадно удалить его рёбра:
            Model.remove_node(RELOADED, "billing")
            EDGES_AFTER_REMOVE = #RELOADED.edges

            -- 2. Проверяем авто-сканер на Go + docker-compose проекте:
            GO_DOC = Scan.scan_project(TMP)

            -- 3. Проверяем авто-сканер на реальном Lua-репозитории этого nvim-config:
            NVIM_DOC = Scan.scan_project(ROOT)

            -- 4. Открываем интерактивную доску :ArchBoard и проверяем переход Enter к коду:
            Model.save_file(paths.json, GO_DOC)
            Board.open(TMP)
            BOARD_TEXT = table.concat(BUF_LINES, "\n")
            BUF_MAPS["L"]()
            BUF_MAPS["<CR>"]()
            """
        )

        maps = lua.eval("MAPS")
        cmds = lua.eval("CMDS")
        check("ArchBoard" in cmds and "ArchWeb" in cmds and "ArchScan" in cmds and "ArchMermaid" in cmds, "все команды :Arch* зарегистрированы")
        check("<leader>mAb" in maps and "<leader>mAw" in maps and "<leader>mAs" in maps and "<leader>Haa" in maps, "клавиши <leader>mA* и <leader>Haa зарегистрированы")
        check("<leader>a" not in maps, "одиночная клавиша <leader>a НЕ затронута (сохранена за Aerial)")

        mmd = lua.eval("MMD")
        md = lua.eval("MD")
        check('api_gateway -- "gRPC" --> billing' in mmd, "Mermaid рисует синхронную стрелку -->")
        check('billing -. "InvoicePaid" .-> event_bus' in mmd, "Mermaid рисует асинхронную пунктирную стрелку -.->")
        check('billing == "SQL" ==> primary_db' in mmd, "Mermaid рисует стрелку данных ==>")
        check("Каталог компонентов" in md and "```mermaid" in md, "Markdown-экспорт включает диаграмму и таблицу компонентов")
        check(lua.eval("EDGES_AFTER_REMOVE") == 4, "удаление узла каскадно очищает привязанные к нему связи")

        check(lua.eval("#GO_DOC.nodes") >= 4 and lua.eval("#GO_DOC.edges") >= 1, "авто-сканер находит cmd/api, internal/orders, PostgreSQL и Redis со связью import")
        check(lua.eval("#NVIM_DOC.nodes") >= 20 and lua.eval("#NVIM_DOC.edges") >= 15, "авто-сканер строит реальную граф-карту модулей и require этого nvim-config")

        board_text = lua.eval("BOARD_TEXT")
        edited = lua.eval("EDITED_FILE")
        check("cmd/api" in board_text and "internal/orders" in board_text, ":ArchBoard отображает слои и компоненты проекта на 2D-доске")
        check(edited is not None and ("cmd/api" in edited or "internal/orders" in edited or "docker-compose" in edited), "нажатие Enter на доске :ArchBoard открывает путь компонента в редакторе")

        html_path = os.path.join(ROOT, "assets", "architecture_editor.html")
        check(os.path.isfile(html_path), "файл браузерного редактора assets/architecture_editor.html существует")
        with open(html_path, "r", encoding="utf-8") as f:
            html = f.read()
        check("/api/architecture" in html and "/api/scan" in html and "/api/open-path" in html, "assets/architecture_editor.html подключён к API сохранения, авто-скана и открытия файлов в Neovim")


if __name__ == "__main__":
    main()
    print(f"\nпроверок: {checked}, провалов: {failed}")
    sys.exit(1 if failed else 0)
