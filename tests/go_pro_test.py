#!/usr/bin/env python3
"""Тесты Go PRO (lua/config/go_pro.lua и связанные файлы).

Три уровня:
  1) чистые функции в LuaJIT: поиск функции под курсором, сборка `go test`,
     экранирование shell;
  2) регистрация клавиш и меню через заглушки vim.*;
  3) инварианты конфигурации: команды go.nvim загружаются лениво (cmd = {…}),
     сниппеты уникальны, клавиши описаны в справке и DOCS.md, нет конфликтов.

Go в песочнице не установлен, поэтому реальный запуск `go test` здесь не
проверяется — только строки команд и логика выбора.

Запуск:  python3 tests/go_pro_test.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _lua  # noqa: E402

checks = []


def check(name, cond, extra=""):
    checks.append((name, bool(cond)))
    print(("OK   " if cond else "FAIL ") + name + ("" if cond or not extra else f"   [{extra}]"))


def read(rel):
    with open(os.path.join(_lua.ROOT, rel), encoding="utf-8") as fh:
        return fh.read()


NEW_KEYS_N = ["<leader>gh", "<leader>gL", "<leader>gR", "<leader>gB", "<leader>gc", "<leader>gM",
              "<leader>gn", "<leader>gS", "<leader>gE", "<leader>gG", "<leader>gp", "<leader>gA",
              "<leader>gV", "<leader>gH", "<leader>gO"]
NEW_KEYS_X = ["<leader>gJ"]
NEW_SNIPS = ["gtt", "gbench", "gerrs", "ggo", "gmu", "gctx", "gfor", "gswitch",
             "gdefer", "glog", "gjson", "gexample", "ghttp", "gselect"]

# Команды go.nvim, которые вызывает go_pro (проверены по закреплённому коммиту
# go.nvim 5c741a2 из lazy-lock.json: create_cmd в lua/go/commands.lua).
GO_NVIM_COMMANDS = {"GoCoverage", "GoModTidy", "GoGenerate", "GoFillSwitch", "GoGenReturn",
                    "GoGCDetails", "GoPkgOutline", "GoAddAllTest", "GoJson2Struct",
                    "GoAddTag", "GoImpl", "GoIfErr", "GoFillStruct", "GoVulnCheck"}

SAMPLE = """package svc
func Plain(a int) int {
	return a
}

func (s *Svc) Method(ctx context.Context) error {
	return nil
}

func GenericFn[T any](v T) T {
	return v
}
"""

PRELUDE = r'''
vim.bo = { filetype = "go" }
vim.lsp = {
  buf = { incoming_calls = function() end, outgoing_calls = function() end },
  codelens = { refresh = function() end, run = function() end },
  inlay_hint = { is_enabled = function() return false end, enable = function() end },
  get_client_by_id = function() return nil end,
}
vim.ui = { input = function(_, cb) cb("Order") end }
vim.api.nvim_win_get_cursor = function() return { 3, 0 } end
vim.api.nvim_buf_get_lines = function() return GO_LINES end
vim.fn.expand = function() return "/home/user/proj/svc" end
'''


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    with open(os.path.join(_lua.ROOT, "tests", "lua_stubs.lua"), encoding="utf-8") as fh:
        rt.execute(fh.read())
    rt.execute(PRELUDE)
    rt.execute("GO_LINES = {}")
    rt.execute("gp = require('config.go_pro')")

    # ------------------------------------------ 1. чистые функции ---
    lines_lua = "{" + ",".join('"' + ln.replace('\\', '\\\\').replace('"', '\\"').replace("\t", "\\t") + '"'
                              for ln in SAMPLE.split("\n")) + "}"
    rt.execute(f"S = {lines_lua}")
    check("func_name_at: тело обычной функции", rt.eval("(gp.func_name_at(S, 3))") == "Plain")
    check("func_name_at: метод (приёмник в скобках)", rt.eval("(gp.func_name_at(S, 8))") == "Method")
    check("func_name_at: дженерик func F[T any]", rt.eval("(gp.func_name_at(S, 12))") == "GenericFn")
    check("func_name_at: строка между функциями (после «}») — nil",
          rt.eval("(gp.func_name_at(S, 5))") is None)
    check("func_name_at: до первой функции — nil", rt.eval("(gp.func_name_at(S, 1))") is None)

    check("go test: пакет с -race",
          rt.eval("gp.go_test_cmd('/a/b', {race=true})") == "cd '/a/b' && go test -count=1 -race .")
    check("go test: один тест с -run и -v",
          rt.eval("gp.go_test_cmd('/p', {run='TestX'})") == "cd '/p' && go test -count=1 -run '^TestX$' -v .")
    check("go test: бенчмарк — -run ^$ и -bench с -benchmem",
          rt.eval("gp.go_test_cmd('/p', {bench='BenchmarkX'})")
          == "cd '/p' && go test -count=1 -run '^$' -bench '^BenchmarkX$' -benchmem .")
    check("go test: тест с -race",
          rt.eval("gp.go_test_cmd('/p', {race=true, run='TestY'})")
          == "cd '/p' && go test -count=1 -race -run '^TestY$' -v .")
    check("shell: одинарная кавычка в пути экранируется",
          rt.eval("gp._sq(\"it's\")") == "'it'\\''s'")
    check("shell: пробелы в пути не ломают команду",
          rt.eval("gp.go_test_cmd('/my dir', {})").startswith("cd '/my dir' && "))

    # ------------------------------------- 2. клавиши и меню через заглушки ---
    rt.execute("gp.setup()")
    bound_n = set(rt.eval("(function() local r = {} for _, k in ipairs(KEYS) do if k.mode == 'n' then r[#r+1] = k.lhs end end return table.concat(r, '\\n') end)()").split("\n"))
    bound_x = set(rt.eval("(function() local r = {} for _, k in ipairs(KEYS) do if k.mode == 'x' then r[#r+1] = k.lhs end end return table.concat(r, '\\n') end)()").split("\n"))
    for lhs in NEW_KEYS_N:
        check(f"клавиша {lhs} привязана (normal)", lhs in bound_n)
    for lhs in NEW_KEYS_X:
        check(f"клавиша {lhs} привязана (visual)", lhs in bound_x)

    n_menu = int(rt.eval("#gp.menu_items"))
    check("меню go_pro: 15+ пунктов", n_menu >= 15, str(n_menu))
    check("меню go_pro: у каждого пункта есть подпись и функция",
          rt.eval("(function() for _, it in ipairs(gp.menu_items) do if type(it.label) ~= 'string' or type(it.run) ~= 'function' then return false end end return true end)()"))

    # Поведение без Go-файла: не падает и не запускает терминал
    rt.execute("vim.bo = { filetype = 'lua' }")
    rt.execute("gp.race()")
    check("<leader>gR вне Go-файла: уведомление, без ошибки",
          "Открой Go-файл" in rt.eval("NOTES[#NOTES].msg"))
    rt.execute("vim.bo = { filetype = 'go' }")

    # ------------------------------------------- 3. инварианты конфигурации ---
    gopro = read("lua/config/go_pro.lua")
    tools = read("lua/plugins/go-tools.lua")
    cmd_block = tools[tools.index("cmd = {"):tools.index("},", tools.index("cmd = {"))]
    # команды go.nvim, которые go_pro вызывает: call("GoX") и vim.cmd("'<,'>GoJson2Struct …")
    used_cmds = set(re.findall(r'call\("(Go\w+)"', gopro))
    if "GoJson2Struct" in gopro:
        used_cmds.add("GoJson2Struct")
    check("go_pro: нашли вызовы команд go.nvim", len(used_cmds) >= 8, str(sorted(used_cmds)))
    missing_lazy = sorted(c for c in used_cmds if f'"{c}"' not in cmd_block)
    check("go_pro: все :Go-команды есть в cmd = {…} go-tools (иначе E492)",
          not missing_lazy, ", ".join(missing_lazy))
    check("go_pro: все команды — из проверенного списка go.nvim 5c741a2",
          not (used_cmds - GO_NVIM_COMMANDS), str(sorted(used_cmds - GO_NVIM_COMMANDS)))

    lsp = read("lua/plugins/lsp-config.lua")
    gopls_block = lsp[lsp.index("gopls = {"):lsp.index("lua_ls = {")]
    check("gopls: подсказки (hints) с параметрами и типами", "hints = {" in gopls_block and "parameterNames = true" in gopls_block)
    check("gopls: codelens — test/generate/tidy", "codelenses = {" in gopls_block and "test = true" in gopls_block and "tidy = true" in gopls_block)
    check("gopls: анализаторы shadow и unusedwrite", "shadow = true" in gopls_block and "unusedwrite = true" in gopls_block)
    check("inlay-подсказки НЕ включаются при подключении LSP (выключены по умолчанию)",
          "inlay_hint.enable(true" not in lsp)
    check("inlay-подсказки включаются только переключателем <leader>gh",
          'map("n", "<leader>gh", M.toggle_inlay' in read("lua/config/go_pro.lua"))
    check("gopls: исходные настройки сохранены (gofumpt, staticcheck, completeUnimported)",
          all(x in gopls_block for x in ("gofumpt = true", "staticcheck = true", "completeUnimported = true")))

    snips = read("lua/config/go_snips.lua")
    triggers = re.findall(r's\("([a-z_]+)"', snips)
    dup = sorted({t for t in triggers if triggers.count(t) > 1})
    check("сниппеты: триггеры уникальны в go_snips.lua", not dup, ", ".join(dup))
    for trig in NEW_SNIPS:
        check(f"сниппет {trig} есть и описан (dstring)",
              trig in triggers and re.search(rf's\("{trig}".*?dstring = "', snips, re.S) is not None)
    infra = read("lua/config/go_infra_snips.lua")
    infra_trig = set(re.findall(r's\("([a-z_]+)"', infra))
    check("сниппеты: новые не пересекаются с инфраструктурными (gdb*, gk*)",
          not (set(NEW_SNIPS) & infra_trig))

    init = read("init.lua")
    check("init.lua: go_pro.setup() вызывается", 'require("config.go_pro").setup()' in init)
    ide = read("lua/config/go_ide.lua")
    check("меню <leader>gi подмешивает go_pro.menu_items", 'require("config.go_pro").menu_items' in ide)

    kd = read("lua/config/keydocs/g10_ai_go.lua")
    docs = read("DOCS.md")
    for lhs in NEW_KEYS_N + NEW_KEYS_X:
        check(f"справка <leader>? описывает {lhs}", f'lhs = "{lhs}"' in kd)
    for lhs in NEW_KEYS_N + NEW_KEYS_X:
        check(f"DOCS.md описывает {lhs}", f"`{lhs}`" in docs)
    for trig in NEW_SNIPS:
        check(f"DOCS.md описывает сниппет {trig}", f"`{trig}`" in docs)

    # Конфликты: каждый <leader>g… должен быть привязан ровно в одном месте кода
    defs = {}
    for root, _, files in os.walk(os.path.join(_lua.ROOT, "lua")):
        if "keydocs" in root:
            continue
        for fn in files:
            if not fn.endswith(".lua"):
                continue
            path = os.path.join(root, fn)
            with open(path, encoding="utf-8") as fh:
                for line in fh:
                    if line.lstrip().startswith("--"):
                        continue
                    if "keymap.set" in line or re.search(r'\bmap\(', line) or re.search(r'\{\s*"<leader>g', line):
                        for lhs in re.findall(r'"(<leader>g[A-Za-z])"', line):
                            defs.setdefault(lhs, set()).add(os.path.relpath(path, _lua.ROOT))
    new_defs = {lhs: sorted(defs.get(lhs, [])) for lhs in NEW_KEYS_N + NEW_KEYS_X}
    clashes = {k: v for k, v in new_defs.items() if len(v) != 1}
    check("клавиши Go PRO: каждая привязана ровно в одном файле (нет конфликтов)",
          not clashes, str(clashes))

    failed = sum(1 for _, ok in checks if not ok)
    print(f"\nпроверок: {len(checks)}, провалов: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
