#!/usr/bin/env python3
"""Комплексные тесты визуальной архитектуры C4, умного скана и ИИ-архитектора:
  - модель architecture.json v2 (C4 parent_id, contracts, scoped_view roll-up, Mermaid subgraph);
  - умный скан Go + .proto (gRPC) + OpenAPI + SQL-миграции (FK + SQL-запросы) + LSP workspace/symbol;
  - реальный C4-скан репозитория nvim-config (контейнеры lua/config, lua/plugins, lua/games);
  - интерактивная доска :ArchBoard (C4-зум l/h, сдвиг L, переход Enter к коду);
  - ИИ-архитектор (:ArchAiDraft и поиск циклов :ArchAiReview);
  - веб-холст assets/architecture_editor.html (C4, /api/ai-draft, /api/ai-review)."""
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
        AI_FLOATS = {}

        package.loaded["config.ai_api"] = {
          resolve = function() return { id = "mock", name = "MockArchAI" } end,
          chat = function(messages, opts, cb)
            cb("### Рекомендации\nРазорвать цикл через шину событий.", nil, { name = "MockArchAI" })
          end,
          chat_json = function(messages, opts, cb)
            cb({
              title = "ИИ-Маркетплейс",
              direction = "LR",
              nodes = {
                { id = "gw", label = "API Gateway", kind = "gateway", contracts = { "POST /checkout" } },
                { id = "pay", label = "Payments", kind = "service", tech = "Go" },
                { id = "pay_stripe", label = "Stripe Adapter", kind = "worker", parent_id = "pay" },
              },
              edges = {
                { from = "gw", to = "pay_stripe", label = "gRPC", kind = "sync" },
              },
            }, nil, { name = "MockArchAI" })
          end,
          float = function(title, text)
            AI_FLOATS[#AI_FLOATS + 1] = { title = title, text = text }
          end,
        }

        vim = {
          o = { columns = 130, lines = 42 },
          bo = setmetatable({}, { __index = function(t, k) local b = {}; rawset(t, k, b); return b end }),
          wo = setmetatable({}, { __index = function(t, k) local w = {}; rawset(t, k, w); return w end }),
          log = { levels = { INFO = 2, WARN = 3, ERROR = 4 } },
          trim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end,
          pesc = function(s) return (tostring(s):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) end,
          schedule = function(fn) fn() end,
          notify = function() end,
          uri_to_fname = function(uri) return (uri:gsub("^file://", "")) end,
          lsp = {
            get_clients = function()
              return {
                {
                  name = "gopls",
                  request = function(self, method, params, cb)
                    cb(nil, {
                      { name = "OrderRepository", uri = "file://" .. TMP .. "/internal/orders/service.go" },
                    })
                  end,
                },
              }
            end,
          },
          cmd = function(c)
            local p = c:match("^edit%s+(.+)$")
            if p then EDITED_FILE = p end
          end,
          json = {
            decode = function(raw) return PY_JSON_DECODE(raw) end,
            encode = function() return "{}" end,
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
        os.makedirs(os.path.join(tmpdir, "cmd", "api"), exist_ok=True)
        os.makedirs(os.path.join(tmpdir, "internal", "orders"), exist_ok=True)
        os.makedirs(os.path.join(tmpdir, "proto"), exist_ok=True)
        os.makedirs(os.path.join(tmpdir, "migrations"), exist_ok=True)

        with open(os.path.join(tmpdir, "go.mod"), "w", encoding="utf-8") as f:
            f.write("module example.com/shop\n\ngo 1.23\n")
        with open(os.path.join(tmpdir, "cmd", "api", "main.go"), "w", encoding="utf-8") as f:
            f.write('package main\nimport "example.com/shop/internal/orders"\nfunc main() { _ = orders.New() }\n')
        with open(os.path.join(tmpdir, "internal", "orders", "service.go"), "w", encoding="utf-8") as f:
            f.write(
                'package orders\n'
                'func Register(r Router, cli OrderServiceClient) {\n'
                '  r.Post("/v1/orders", nil)\n'
                '  _ = cli.CreateOrder\n'
                '  _ = "SELECT id, total FROM orders WHERE user_id = $1"\n'
                '}\n'
                'func New() int { return 1 }\n'
            )
        with open(os.path.join(tmpdir, "proto", "orders.proto"), "w", encoding="utf-8") as f:
            f.write(
                'syntax = "proto3";\npackage shop.v1;\n'
                'service OrderService {\n'
                '  rpc CreateOrder (CreateOrderReq) returns (CreateOrderResp);\n'
                '}\n'
            )
        with open(os.path.join(tmpdir, "openapi.yaml"), "w", encoding="utf-8") as f:
            f.write("openapi: 3.0.3\npaths:\n  /v1/orders:\n    post: {}\n")
        with open(os.path.join(tmpdir, "migrations", "001_init.sql"), "w", encoding="utf-8") as f:
            f.write(
                "CREATE TABLE users (id BIGSERIAL PRIMARY KEY);\n"
                "CREATE TABLE orders (id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id));\n"
                "CREATE TABLE IF NOT EXISTS payments (id BIGSERIAL PRIMARY KEY, order_id BIGINT REFERENCES orders(id));\n"
            )
        with open(os.path.join(tmpdir, "docker-compose.yml"), "w", encoding="utf-8") as f:
            f.write("services:\n  db:\n    image: postgres:16\n  cache:\n    image: redis:7\n")

        lua = make_lua_env(tmpdir)
        lua.execute(
            r"""
            local Arch = require("config.architecture")
            local Model = require("config.architecture_model")
            local Scan = require("config.architecture_scan")
            local Board = require("config.architecture_board")
            local AIArch = require("config.architecture_ai")

            Arch.setup()

            -- 1. Базовая модель и Mermaid/Markdown:
            local doc = Model.default_doc("Тестовая система")
            Model.upsert_node(doc, { id = "billing", label = "Billing", kind = "service", path = "internal/orders", tech = "Go" })
            Model.add_edge(doc, "api_gateway", "billing", "gRPC", "sync")
            Model.add_edge(doc, "billing", "event_bus", "InvoicePaid", "async")
            Model.add_edge(doc, "billing", "primary_db", "SQL", "data")
            MMD = Model.to_mermaid(doc)
            MD = Model.to_markdown(doc)

            -- 2. Умный скан Go + .proto + OpenAPI + SQL + docker-compose + LSP:
            GO_DOC = Scan.scan_project(TMP)
            Scan.enrich_from_lsp(GO_DOC, TMP, function(updated, added)
              LSP_ADDED = added
              GO_DOC = updated
            end)

            -- Проверяем C4 проекцию на верхнем уровне и внутри postgres_db:
            ROOT_VIEW = Model.scoped_view(GO_DOC, "")
            DB_VIEW = Model.scoped_view(GO_DOC, "postgres_db")

            local orders_node = Model.find_node(GO_DOC, "internal_orders")
            ORDERS_CONTRACTS = table.concat(orders_node and orders_node.contracts or {}, " | ")
            local grpc_node = Model.find_node(GO_DOC, "grpc_orderservice")
            GRPC_CONTRACTS = table.concat(grpc_node and grpc_node.contracts or {}, " | ")

            -- 3. Проверяем C4-скан реального репозитория nvim-config:
            NVIM_DOC = Scan.scan_project(ROOT)
            NVIM_ROOT_VIEW = Model.scoped_view(NVIM_DOC, "")
            NVIM_CONFIG_VIEW = Model.scoped_view(NVIM_DOC, "c4_lua_config")

            -- 4. Навигация C4 на доске :ArchBoard (вход в postgres_db через l и выход через h):
            local paths = Model.default_paths(TMP)
            Model.save_file(paths.json, GO_DOC)
            Board.open(TMP, "")
            BOARD_ROOT_TEXT = table.concat(BUF_LINES, "\n")

            -- Переводим выбор на postgres_db и входим внутрь клавишей `l`:
            for i = 1, 12 do
              local text_now = table.concat(BUF_LINES, "\n")
              if text_now:find("Выбран [^\n]-PostgreSQL") then break end
              BUF_MAPS["j"]()
            end
            BUF_MAPS["l"]()
            BOARD_DB_ZOOM_TEXT = table.concat(BUF_LINES, "\n")
            BUF_MAPS["h"]()
            BOARD_AFTER_ZOOM_OUT = table.concat(BUF_LINES, "\n")
            BUF_MAPS["<CR>"]()

            -- 5. Проверяем детектор циклов и ИИ-ревью + ИИ-генерацию (:ArchAiDraft / :ArchAiReview):
            local cyc_doc = Model.normalize({
              title = "Цикличная схема",
              nodes = {
                { id = "svc_a", label = "A", kind = "service" },
                { id = "svc_b", label = "B", kind = "service" },
                { id = "svc_c", label = "C", kind = "service" },
              },
              edges = {
                { from = "svc_a", to = "svc_b" },
                { from = "svc_b", to = "svc_c" },
                { from = "svc_c", to = "svc_a" },
              },
            })
            Model.save_file(paths.json, cyc_doc)
            AIArch.review(TMP, function(rep) REVIEW_REPORT = rep end)

            AIArch.draft("Сделай схему маркетплейса", TMP, function(drafted)
              DRAFTED_DOC = drafted
              DRAFTED_ROOT_VIEW = Model.scoped_view(drafted, "")
            end)
            """
        )

        maps = lua.eval("MAPS")
        cmds = lua.eval("CMDS")
        check(
            all(k in cmds for k in ("ArchBoard", "ArchWeb", "ArchScan", "ArchLspScan", "ArchAiDraft", "ArchAiReview")),
            "все команды :Arch* (включая ArchLspScan, ArchAiDraft, ArchAiReview) зарегистрированы",
        )
        check(
            all(k in maps for k in ("<leader>mAb", "<leader>mAw", "<leader>mAs", "<leader>mAl", "<leader>mAd", "<leader>mAr", "<leader>Haa")),
            "все клавиши <leader>mA* и <leader>Haa зарегистрированы",
        )
        check("<leader>a" not in maps, "одиночная клавиша <leader>a НЕ затронута (сохранена за Aerial)")

        mmd = lua.eval("MMD")
        md = lua.eval("MD")
        check('api_gateway -- "gRPC" --> billing' in mmd and 'billing -. "InvoicePaid" .-> event_bus' in mmd and 'billing == "SQL" ==> primary_db' in mmd, "Mermaid рисует стрелки sync/async/data")
        check("Каталог компонентов" in md and "Контракты / API" in md, "Markdown-экспорт включает таблицу контрактов и C4-контейнеров")

        orders_contracts = lua.eval("ORDERS_CONTRACTS")
        grpc_contracts = lua.eval("GRPC_CONTRACTS")
        check("POST /v1/orders" in orders_contracts and "sym OrderRepository" in orders_contracts, "умный скан извлекает HTTP-маршрут и LSP workspace/symbol в контракты сервиса")
        check("rpc CreateOrder(CreateOrderReq) → CreateOrderResp" in grpc_contracts, "умный скан .proto извлекает gRPC-сервис и сигнатуру rpc")
        check(lua.eval("#DB_VIEW.nodes") == 3 and lua.eval("#DB_VIEW.edges") == 2, "SQL-миграции создают таблицы users, orders и payments внутри C4-контейнера БД со связями FK")

        # Проверяем, что на верхнем уровне C4 связь internal_orders -> tbl_orders агрегировалась в internal_orders -> postgres_db!
        has_rollup = lua.eval(
            r"""(function()
              for _, e in ipairs(ROOT_VIEW.edges) do
                if e.from == "internal_orders" and e.to == "postgres_db" and e.label:find("SQL: orders", 1, true) then
                  return true
                end
              end
              return false
            end)()"""
        )
        check(has_rollup is True, "проекция C4 агрегирует запрос к вложенной таблице orders в стрелку internal/orders ══▶ PostgreSQL на уровне системы")

        check(4 <= lua.eval("#NVIM_ROOT_VIEW.nodes") <= 6 and lua.eval("#NVIM_CONFIG_VIEW.nodes") >= 25, "C4-скан nvim-config группирует 140+ файлов в чистые контейнеры верхнего уровня с детализацией внутри")

        zoom_text = lua.eval("BOARD_DB_ZOOM_TEXT")
        out_text = lua.eval("BOARD_AFTER_ZOOM_OUT")
        check("table orders" in zoom_text and "table users" in zoom_text, "нажатие l на доске :ArchBoard проваливается внутрь C4-контейнера PostgreSQL")
        check("Вся система" in out_text and "internal/orders" in out_text, "нажатие h на доске :ArchBoard возвращает на верхний C4-уровень")
        check(lua.eval("EDITED_FILE") is not None, "нажатие Enter на доске :ArchBoard открывает файл/папку выбранного компонента")

        review_rep = lua.eval("REVIEW_REPORT")
        check("svc_a ──▶ svc_b ──▶ svc_c ──▶ svc_a" in review_rep and "MockArchAI" in review_rep, ":ArchAiReview находит точный цикл зависимостей и добавляет рекомендации ИИ")

        check(lua.eval("DRAFTED_DOC.title") == "ИИ-Маркетплейс" and lua.eval("#DRAFTED_ROOT_VIEW.edges") == 1, ":ArchAiDraft генерирует C4-схему через ИИ и агрегирует вложенные связи")

        html_path = os.path.join(ROOT, "assets", "architecture_editor.html")
        with open(html_path, "r", encoding="utf-8") as f:
            html = f.read()
        check(
            all(tok in html for tok in ("/api/ai-draft", "/api/ai-review", "scopedView", "dblclick")),
            "assets/architecture_editor.html поддерживает C4-зум, ИИ-генерацию и ИИ-ревью",
        )


if __name__ == "__main__":
    main()
    print(f"\nпроверок: {checked}, провалов: {failed}")
    sys.exit(1 if failed else 0)
