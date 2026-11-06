#!/usr/bin/env python3
"""Регрессии жизненного цикла Avante: гонки, блокировка чата, повторная сборка.

Симулирует загруженный lazy.nvim плагин и незавершённую фоновую сборку под LuaJIT;
проверяет реальные колбэки config.avante_runtime, а не только текст спецификации.
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
local function key(mode, lhs) return mode .. ":" .. lhs end
MAPS, NOTES, CMDS = {}, {}, {}
vim.fn.maparg = function(lhs, mode, _, dict)
  local m = MAPS[key(mode, lhs)]
  if dict then return m or {} end
  return m and "mapped" or ""
end
vim.keymap.set = function(modes, lhs, rhs, opts)
  if type(modes) == "string" then modes = {modes} end
  for _, mode in ipairs(modes) do MAPS[key(mode, lhs)] = {rhs=rhs, desc=opts and opts.desc} end
end
vim.keymap.del = function(mode, lhs) MAPS[key(mode, lhs)] = nil end
vim.cmd = function(s) LAST_CMD = s end
vim.version = function() return {major=0, minor=12, patch=0} end

function RESET(o)
  MAPS, NOTES, CMDS, LAST_CMD = {}, {}, {}, nil
  BUILDS, PENDING, SETUP_COUNT, ASK_COUNT, TOGGLE_COUNT, EDIT_COUNT, HISTORY_COUNT = 0, nil, 0, 0, 0, 0, 0
  RUNTIME_OK, REV, CHECK_REASON = o.ready or false, o.revision or "abc123", o.reason or "missing avante_templates"
  GUARD_OK, NATIVE_OK = not o.guard_error, not o.native_error
  if o.no_git then REV = nil end
  package.loaded["config.avante_repo_map"] = {
    invalid_cache_count = 0,
    install = function() if not GUARD_OK then error('cache guard error') end end,
    native_ready = function() return NATIVE_OK, NATIVE_OK and nil or 'repo map not ready' end,
  }
  B = {
    TAG="v0.4.8", COMMIT="abc123",
    plugin_dir=function() return "/fallback" end,
    lib_file=function(dir) return dir .. "/lua/avante_templates.so" end,
    revision=function() return REV, REV and nil or "git не найден" end,
    revision_error=function(r) return "wrong " .. r .. ": :Lazy update avante.nvim и перезапусти" end,
    check=function() return RUNTIME_OK, RUNTIME_OK and "все библиотеки загружаются" or CHECK_REASON end,
    runtime_check=function() return RUNTIME_OK, RUNTIME_OK and "готово" or CHECK_REASON end,
    build=function(dir, callback, options)
      BUILDS = BUILDS + 1; PENDING = callback; BUILD_DIR = dir; BUILD_FORCE = options.force; BUILD_SOURCE = options.source
    end,
  }
  AV = {
    setup=function(opts)
      SETUP_COUNT = SETUP_COUNT + 1
      BEFORE_SETUP_MAP = MAPS[key("n", "<leader>Aa")]
      if o.setup_error then error("setup error") end
      if not MAPS[key("n", opts.mappings.ask)] then
        vim.keymap.set("n", opts.mappings.ask, function() API.ask() end, {desc="real avante"})
      end
    end,
    toggle_sidebar=function() TOGGLE_COUNT = TOGGLE_COUNT + 1 end,
    open_sidebar=function() TOGGLE_COUNT = TOGGLE_COUNT + 1 end,
  }
  API = {
    ask=function() ASK_COUNT = ASK_COUNT + 1; return "asked" end,
    edit=function() EDIT_COUNT = EDIT_COUNT + 1 end,
    select_history=function() HISTORY_COUNT = HISTORY_COUNT + 1 end,
    build=function() return "upstream build" end,
  }
  package.loaded["config.avante_build"] = B
  package.loaded["avante"] = AV
  package.loaded["avante.api"] = API
  package.loaded["config.avante_runtime"] = nil
  package.loaded["config.avante_commands"] = nil
  require("config.avante_commands").setup()
  OPTS = { mappings = {
    ask="<leader>Aa", new_ask="<leader>An", zen_mode="<leader>Az",
    edit="<leader>Ae", toggle={default="<leader>At"},
  } }
  if o.existing then MAPS[key("n", "<leader>Aa")] = {desc="user mapping", rhs=function() end} end
  -- Как upstream plugin/avante.lua: команда каждый раз обращается к avante.api.
  CMDS.AvanteAsk = function() API.ask() end
  CMDS.AvanteChat = function() API.ask({ask=false}) end
  CMDS.AvanteEdit = function() API.edit() end
  CMDS.AvanteToggle = function() AV.toggle_sidebar() end
  CMDS.AvanteHistory = function() API.select_history() end
  require("config.avante_runtime").setup({dir="/custom lazy/avante.nvim"}, OPTS)
end
function COMPLETE(ok, msg)
  local cb = PENDING; PENDING = nil
  if not cb then error("нет ожидающей сборки") end
  cb(ok, msg or (ok and "готово" or "сеть недоступна"))
end
function LAST_NOTE() return #NOTES > 0 and NOTES[#NOTES].msg or "" end
function MAP(mode, lhs) return MAPS[key(mode, lhs)] end
'''


def main():
    rt, kind = _lua.runtime()
    print("Парсер:", kind)
    with open(os.path.join(_lua.ROOT, "tests", "lua_stubs.lua"), encoding="utf-8") as fh:
        rt.execute(fh.read())
    rt.execute(PRELUDE)

    def run(s):
        rt.execute(s)

    run("vim.fn.has = function() return 0 end; NOTES = {}; require('config.avante_runtime').warn_unsupported()")
    check("на старом Neovim предупреждение показывается вне отключённого плагина",
          "требует Neovim 0.12+" in rt.eval("LAST_NOTE()"))
    run("vim.fn.has = function() return 1 end; NOTES = {}; require('config.avante_runtime').warn_unsupported()")
    check("на поддерживаемом Neovim предупреждения нет", rt.eval("#NOTES") == 0)

    run("RESET{ready=true}")
    check("готовые библиотеки: setup один раз, скачивание не начинается",
          rt.eval("SETUP_COUNT") == 1 and rt.eval("BUILDS") == 0)
    run("CMDS.AvanteAsk(); CMDS.AvanteToggle(); CMDS.AvanteEdit(); CMDS.AvanteHistory()")
    check("готовый плагин: команды работают без изменения поведения",
          all(rt.eval(x) == 1 for x in ("ASK_COUNT", "TOGGLE_COUNT", "EDIT_COUNT", "HISTORY_COUNT")))
    check("сохранён маппинг объяснения Ax", rt.eval("MAP('n', '<leader>Ax') ~= nil") is True)
    check("команды диагностики и починки зарегистрированы", rt.eval("CMDS.AvanteStatus ~= nil and CMDS.AvanteRebuild ~= nil") is True)

    run("RESET{ready=false}")
    check("до завершения сборки setup не запускается", rt.eval("SETUP_COUNT") == 0 and rt.eval("BUILDS") == 1)
    check("используется фактический каталог плагина", rt.eval("BUILD_DIR") == "/custom lazy/avante.nvim")
    run("CMDS.AvanteAsk(); CMDS.AvanteChat(); CMDS.AvanteEdit(); CMDS.AvanteToggle(); CMDS.AvanteHistory()")
    check("пока сборка идёт, команды не открывают чат и не вызывают API",
          all(rt.eval(x) == 0 for x in ("ASK_COUNT", "TOGGLE_COUNT", "EDIT_COUNT", "HISTORY_COUNT")))
    check("вместо traceback понятный статус", "сборка библиотек" in rt.eval("LAST_NOTE()"))
    run("MAP('n', '<leader>Aa').rhs()")
    check("обычная клавиша Aa во время сборки тоже сообщает статус", "сборка библиотек" in rt.eval("LAST_NOTE()"))
    run("CMDS.AvanteRebuild()")
    check("повторный rebuild не запускает параллельную сборку", rt.eval("BUILDS") == 1 and "уже выполняется" in rt.eval("LAST_NOTE()"))
    run("RUNTIME_OK = true; COMPLETE(true)")
    check("после сборки setup вызывается один раз", rt.eval("SETUP_COUNT") == 1)
    check("временный маппинг удалён до настройки avante", rt.eval("BEFORE_SETUP_MAP") is None)
    check("на его месте появился настоящий маппинг", rt.eval("MAP('n','<leader>Aa').desc") == "real avante")
    run("CMDS.AvanteAsk(); CMDS.AvanteToggle()")
    check("после сборки чат открывается в том же сеансе", rt.eval("ASK_COUNT") == 1 and rt.eval("TOGGLE_COUNT") == 1)

    run("RESET{ready=false}; COMPLETE(false, 'HTTP 404')")
    check("неудачная сборка: setup не вызывается, есть причина", rt.eval("SETUP_COUNT") == 0 and "HTTP 404" in rt.eval("LAST_NOTE()"))
    run("CMDS.AvanteAsk()")
    check("после ошибки попытка чата не падает, повторяет причину", rt.eval("ASK_COUNT") == 0 and "HTTP 404" in rt.eval("LAST_NOTE()"))
    run("CMDS.AvanteStatus()")
    check("диагностика включает фактический каталог и причину", "/custom lazy/avante.nvim" in rt.eval("LAST_NOTE()") and "HTTP 404" in rt.eval("LAST_NOTE()"))
    run("CMDS.AvanteRebuild()")
    check("ручная команда действительно форсирует повторную сборку", rt.eval("BUILDS") == 2 and rt.eval("BUILD_FORCE") is True)
    run("RUNTIME_OK = true; COMPLETE(true)")
    check("после повторной сборки чат включается", rt.eval("SETUP_COUNT") == 1)

    run("RESET{ready=true}; CMDS.AvanteRebuild()")
    check("ручная пересборка готового avante принудительна", rt.eval("BUILDS") == 1 and rt.eval("BUILD_FORCE") is True)
    run("COMPLETE(true); CMDS.AvanteStatus()")
    check("при замене загруженных библиотек требуется перезапуск",
          rt.eval("SETUP_COUNT") == 1 and "Перезапусти Neovim" in rt.eval("LAST_NOTE()"))
    run("CMDS.AvanteAsk()")
    check("уже загруженный чат продолжает работать после пересборки", rt.eval("ASK_COUNT") == 1)
    run("RESET{ready=true}; CMDS.AvanteRebuild(); COMPLETE(false, 'make failed'); CMDS.AvanteAsk()")
    check("неудачная ручная пересборка не отключает текущий чат", rt.eval("ASK_COUNT") == 1 and rt.eval("SETUP_COUNT") == 1)

    run("RESET{ready=false, revision='old'}")
    check("несовпадающая версия: авто-сборка и setup не запускаются",
          rt.eval("BUILDS") == 0 and rt.eval("SETUP_COUNT") == 0 and ":Lazy update avante.nvim" in rt.eval("LAST_NOTE()"))
    run("CMDS.AvanteAsk()")
    check("при несовпадении версии чат заблокирован", rt.eval("ASK_COUNT") == 0)
    run("REV='abc123'; CMDS.AvanteRebuild(); RUNTIME_OK=true; COMPLETE(true)")
    check("обновлённый checkout в старом сеансе требует перезапуска", rt.eval("SETUP_COUNT") == 0 and "Перезапусти" in rt.eval("LAST_NOTE()"))

    run("RESET{ready=false, existing=true}")
    check("пользовательская клавиша не перезаписывается при сборке", rt.eval("MAP('n','<leader>Aa').desc") == "user mapping")
    run("RUNTIME_OK=true; COMPLETE(true)")
    check("пользовательская клавиша не удаляется после сборки", rt.eval("MAP('n','<leader>Aa').desc") == "user mapping")
    run("RESET{ready=false}; MAP('n','<leader>Aa').desc='user changed during build'; RUNTIME_OK=true; COMPLETE(true)")
    check("чужая замена временного маппинга не удаляется", rt.eval("MAP('n','<leader>Aa').desc") == "user changed during build")

    run("RESET{ready=true}; API.build({source=true})")
    check(":AvanteBuild source=true идёт через управляемую сборку и проверку версии",
          rt.eval("BUILDS") == 1 and rt.eval("BUILD_FORCE") is True and rt.eval("BUILD_SOURCE") is True)
    run("RESET{ready=true}; API.build({source=false})")
    check(":AvanteBuild без source не использует upstream build.sh с другим тегом",
          rt.eval("BUILDS") == 1 and rt.eval("BUILD_SOURCE") is False)
    run("RESET{ready=true, guard_error=true}; CMDS.AvanteAsk()")
    check("при ошибке защиты кеша setup и чат заблокированы",
          rt.eval("SETUP_COUNT") == 0 and rt.eval("ASK_COUNT") == 0 and "cache guard error" in rt.eval("LAST_NOTE()"))
    run("RESET{ready=true, native_error=true}; CMDS.AvanteAsk()")
    check("если внутренний repo_map не загрузился, setup и чат заблокированы",
          rt.eval("SETUP_COUNT") == 0 and rt.eval("ASK_COUNT") == 0 and "repo map not ready" in rt.eval("LAST_NOTE()"))
    run("RESET{ready=false}; RUNTIME_OK=false; COMPLETE(true)")
    check("скачивание без работающего require не включает avante", rt.eval("SETUP_COUNT") == 0 and "не удалось загрузить" in rt.eval("LAST_NOTE()"))
    run("RESET{ready=true, setup_error=true}")
    check("ошибка setup не разблокирует чат", rt.eval("SETUP_COUNT") == 1 and "setup error" in rt.eval("LAST_NOTE()"))
    run("CMDS.AvanteAsk()")
    check("после ошибки setup API остаётся защищённым", rt.eval("ASK_COUNT") == 0)

    failed = sum(1 for _, ok in checks if not ok)
    print(f"\nпроверок: {len(checks)}, провалов: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
