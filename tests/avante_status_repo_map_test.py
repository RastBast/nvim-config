#!/usr/bin/env python3
"""Проверка исправлений Avante (:AvanteStatus без E492, все 4 .so библиотеки,
сброс lazy.core.cache, защита repo_map от vim.NIL/userdata и защита AvanteInput),
а также условного включения nil_ls только при наличии бинарника nil."""
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


def test_lockfile_matches_tag():
    with open(os.path.join(ROOT, "lazy-lock.json"), "r", encoding="utf-8") as f:
        lock = json.load(f)
    av = lock.get("avante.nvim", {})
    check(
        av.get("commit") == "079d964ea88bff4953996ee26d31314df5dc757f",
        "lazy-lock.json закрепляет avante.nvim ровно на коммите тега v0.4.8",
    )


def test_avante_commands_and_build():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ROOT = ROOT
    lua.execute(
        r"""
        package.path = ROOT .. "/lua/?.lua;" .. ROOT .. "/lua/?/init.lua;" .. package.path
        ECHOES = {}
        CMDS = {}
        CACHE_RESETS = 0
        LOADER_RESETS = 0
        HAS_012 = 0
        EXISTING_FILES = {}

        package.loaded["lazy.core.cache"] = {
          reset = function() CACHE_RESETS = CACHE_RESETS + 1 end,
        }

        vim = {
          fn = {
            has = function(f) return f == "nvim-0.12" and HAS_012 or 0 end,
            stdpath = function(kind) return "/mock/" .. kind end,
            executable = function() return 1 end,
            isdirectory = function() return 1 end,
            mkdir = function() end,
          },
          api = {
            nvim_create_user_command = function(name, fn, opts)
              CMDS[name] = { fn = fn, opts = opts }
            end,
            nvim_echo = function(chunks)
              local parts = {}
              for _, c in ipairs(chunks) do parts[#parts + 1] = c[1] end
              ECHOES[#ECHOES + 1] = table.concat(parts, "")
            end,
            nvim_list_uis = function() return {} end,
          },
          uv = {
            fs_stat = function(p) return EXISTING_FILES[p] and { type = "file" } or nil end,
            os_uname = function() return { sysname = "Darwin", machine = "arm64" } end,
          },
          loader = {
            reset = function() LOADER_RESETS = LOADER_RESETS + 1 end,
          },
          version = function() return { major = 0, minor = 12, patch = 0 } end,
        }

        local cmds = require("config.avante_commands")
        cmds.setup()
        """
    )

    cmds = lua.eval("CMDS")
    check("AvanteStatus" in cmds, ":AvanteStatus зарегистрирована сразу при старте")
    check("AvanteRebuild" in cmds, ":AvanteRebuild зарегистрирована сразу при старте")

    lua.execute("CMDS.AvanteStatus.fn()")
    last_echo = lua.eval("ECHOES[#ECHOES]")
    check("Статус Avante" in last_echo and "0.12+" in last_echo, ":AvanteStatus на Neovim <0.12 выводит понятную сводку без E492")

    lua.execute(
        r"""
        HAS_012 = 1
        BOUND_CALLED = 0
        package.loaded["lazy.core.config"] = {
          plugins = { ["avante.nvim"] = { dir = "/plug/avante.nvim", _ = { installed = true } } },
        }
        package.loaded["lazy"] = {
          load = function()
            require("config.avante_commands").bind(
              function() BOUND_CALLED = BOUND_CALLED + 1 end,
              function() end
            )
          end,
        }
        CMDS.AvanteStatus.fn()
        """
    )
    check(lua.eval("BOUND_CALLED") == 1, ":AvanteStatus подгружает плагин через lazy.load и вызывает боевой обработчик")

    # Проверяем refresh_loader и проверку всех 4 библиотек в avante_build
    lua.execute(
        r"""
        -- Подменяем package.loadlib, чтобы проверить и dlopen, и экспорты всех 4 библиотек:
        local MOCK_EXPORTS = {
          avante_templates = { initialize = function() end, render = function() end },
          avante_tokenizers = { from_pretrained = function() end, encode = function() end },
          avante_repo_map = { stringify_definitions = function() end },
          avante_html2md = { fetch_md = function() end, html2md = function() end },
        }
        package.loadlib = function(file, sym)
          if not EXISTING_FILES[file] then return nil, "file missing" end
          local modname = sym:match("^luaopen_(.+)$")
          return function() return MOCK_EXPORTS[modname] end
        end

        local B = require("config.avante_build")
        package.loaded.avante_repo_map = false -- имитируем неудачную прошлую загрузку (boolean sentinel)
        B.refresh_loader("/plug/avante.nvim")
        ALL_OK_EMPTY = select(1, B.check_all_libs("/plug/avante.nvim"))
        EXISTING_FILES["/plug/avante.nvim/lua/avante_templates.so"] = true
        EXISTING_FILES["/plug/avante.nvim/lua/avante_tokenizers.so"] = true
        EXISTING_FILES["/plug/avante.nvim/lua/avante_repo_map.so"] = true
        ALL_OK_PARTIAL, MISSING_MSG = B.check_all_libs("/plug/avante.nvim")
        EXISTING_FILES["/plug/avante.nvim/lua/avante_html2md.so"] = true
        ALL_OK_FOUR = select(1, B.check_all_libs("/plug/avante.nvim"))
        """
    )
    check(lua.eval("CACHE_RESETS") >= 1, "refresh_loader сбрасывает lazy.core.cache")
    check(lua.eval("LOADER_RESETS") >= 1, "refresh_loader сбрасывает vim.loader")
    check(lua.eval("package.loaded.avante_repo_map == nil"), "refresh_loader очищает битый sentinel в package.loaded")
    check(lua.eval("package.cpath:find('/plug/avante.nvim/lua/?.so', 1, true) ~= nil"), "refresh_loader добавляет lua/?.so в package.cpath")
    check(lua.eval("ALL_OK_PARTIAL") is False and "avante_html2md" in lua.eval("MISSING_MSG"), "check_all_libs ловит отсутствие любой из 4 библиотек")
    check(lua.eval("ALL_OK_FOUR") is True, "check_all_libs подтверждает наличие и экспорты всех 4 .so библиотек")


def test_repo_map_and_sidebar_guards():
    with tempfile.TemporaryDirectory() as tmpdir:
        bad_file = os.path.join(tmpdir, "proj.lua.repo_map.json")
        good_file = os.path.join(tmpdir, "ok.go.repo_map.json")
        with open(bad_file, "w", encoding="utf-8") as f:
            f.write("null")
        with open(good_file, "w", encoding="utf-8") as f:
            json.dump([{"path": "main.go", "lang": "go", "defs": "func main()"}], f)

        lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        g = lua.globals()
        g.ROOT = ROOT
        g.TMP = tmpdir
        lua.execute(
            r"""
            package.path = ROOT .. "/lua/?.lua;" .. ROOT .. "/lua/?/init.lua;" .. package.path
            local files = { "proj.lua.repo_map.json", "ok.go.repo_map.json" }
            local sentinel = newproxy(false) -- настоящий LuaJIT userdata как vim.NIL!

            vim = {
              NIL = sentinel,
              fn = { stdpath = function() return TMP end },
              json = {
                decode = function(raw)
                  if raw == "null" then return sentinel end
                  if raw:find("main.go", 1, true) then
                    return { { path = "main.go", lang = "go", defs = "func main()" } }
                  end
                  error("bad json")
                end,
              },
              uv = {
                fs_scandir = function()
                  local i = 0
                  return { next = function() i = i + 1; return files[i], "file" end }
                end,
                fs_scandir_next = function(h) return h.next() end,
              },
            }

            SAVED = {}
            TEMPLATES_AVAILABLE = false
            HINT_CRASHED = false

            package.loaded["avante.path"] = {
              available = function() return TEMPLATES_AVAILABLE end,
              repo_map = {
                load = function() return sentinel end, -- имитируем битый null → userdata!
                save = function(_, _, data) SAVED[#SAVED + 1] = data end,
              },
            }
            package.loaded["avante.repo_map"] = {
              _get_repo_map = function()
                local loaded = package.loaded["avante.path"].repo_map.load()
                if loaded and next(loaded) ~= nil then return loaded end
                return {}
              end,
              get_repo_map = function() return {} end,
              show = function() return "SHOWN" end,
            }
            package.loaded["avante.sidebar"] = {
              initialize_token_count = function() error("Make sure to build avante (missing avante_templates)") end,
              show_input_hint = function() error("Make sure to build avante (missing avante_templates)") end,
              close_input_hint = function() CLOSED_HINT = true end,
            }

            local guard = require("config.avante_repo_map")
            REMOVED = guard.clean_disk_cache(TMP)
            READY = true
            STATUS_SHOWN = 0
            guard.install(function() return READY end, function() STATUS_SHOWN = STATUS_SHOWN + 1 end)

            -- Проверяем, что userdata больше НЕ попадает в next(repo_map) на строке 112!
            LOAD_RES = package.loaded["avante.path"].repo_map.load()
            MAP_RES = package.loaded["avante.repo_map"]._get_repo_map()

            -- Проверяем блокировку записи nil / userdata в кеш:
            package.loaded["avante.path"].repo_map.save("/p", "go", nil)
            package.loaded["avante.path"].repo_map.save("/p", "go", sentinel)
            package.loaded["avante.path"].repo_map.save("/p", "go", { { path = "a.go", lang = "go", defs = "type A" } })

            -- Проверяем защиту Sidebar при ModeChanged / WinEnter когда avante_templates недоступен:
            local sb = { close_input_hint = function() CLOSED_HINT = true end }
            package.loaded["avante.sidebar"].initialize_token_count(sb)
            package.loaded["avante.sidebar"].show_input_hint(sb)
            TOKEN_COUNT_FALLBACK = sb.token_count
            """
        )

        check(lua.eval("REMOVED") == 1, "clean_disk_cache удаляет испорченный *.repo_map.json с null")
        check(not os.path.exists(bad_file) and os.path.exists(good_file), "валидный *.repo_map.json сохранён, битый удалён с диска")
        check(lua.eval("LOAD_RES == nil"), "Path.repo_map.load отсекает vim.NIL (userdata) и возвращает nil")
        check(lua.eval("type(MAP_RES) == 'table'"), "RepoMap._get_repo_map не падает на next(userdata)")
        check(lua.eval("#SAVED") == 1, "Path.repo_map.save записывает только валидный массив определений")
        check(lua.eval("TOKEN_COUNT_FALLBACK") == 0 and lua.eval("CLOSED_HINT") is True, "Sidebar не роняет ModeChanged/WinEnter при отсутствии avante_templates")


def test_nil_ls_conditional_enable():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ROOT = ROOT
    lua.execute(
        r"""
        package.path = ROOT .. "/lua/?.lua;" .. ROOT .. "/lua/?/init.lua;" .. package.path
        NIL_EXEC = 0
        ENABLED_LISTS = {}
        AUTOCMDS = {}

        package.loaded["mason"] = { setup = function() end }
        package.loaded["mason-lspconfig"] = { setup = function() end }
        package.loaded["cmp_nvim_lsp"] = { default_capabilities = function() return {} end }

        local function deepcopy(v)
          if type(v) ~= "table" then return v end
          local out = {}
          for k, val in pairs(v) do out[k] = deepcopy(val) end
          return out
        end

        vim = {
          deepcopy = deepcopy,
          fn = {
            executable = function(bin) return (bin == "nil" and NIL_EXEC == 1) and 1 or 0 end,
          },
          lsp = {
            protocol = { make_client_capabilities = function() return {} end },
            config = function() end,
            enable = function(arg) ENABLED_LISTS[#ENABLED_LISTS + 1] = arg end,
            buf = {},
          },
          diagnostic = { jump = function() end, open_float = function() end },
          keymap = { set = function() end },
          api = {
            nvim_create_augroup = function(n) return n end,
            nvim_create_autocmd = function(ev, opts) AUTOCMDS[#AUTOCMDS + 1] = { ev = ev, opts = opts } end,
            nvim_echo = function() end,
          },
          schedule = function(fn) fn() end,
        }

        local specs = dofile(ROOT .. "/lua/plugins/lsp-config.lua")
        local lsp_spec = specs[3]

        NIL_EXEC = 0
        lsp_spec.config()
        WITHOUT_NIL = ENABLED_LISTS[#ENABLED_LISTS]

        NIL_EXEC = 1
        lsp_spec.config()
        WITH_NIL = ENABLED_LISTS[#ENABLED_LISTS]

        local function has_srv(list, target)
          for _, v in ipairs(list) do if v == target then return true end end
          return false
        end
        HAS_WITHOUT = has_srv(WITHOUT_NIL, "nil_ls")
        HAS_WITH = has_srv(WITH_NIL, "nil_ls")
        """
    )
    check(lua.eval("HAS_WITHOUT") is False, "без бинарника nil в PATH сервер nil_ls НЕ передаётся в vim.lsp.enable")
    check(lua.eval("HAS_WITH") is True, "при наличии бинарника nil в PATH сервер nil_ls включается в vim.lsp.enable")


if __name__ == "__main__":
    test_lockfile_matches_tag()
    test_avante_commands_and_build()
    test_repo_map_and_sidebar_guards()
    test_nil_ls_conditional_enable()
    print(f"\nпроверок: {checked}, провалов: {failed}")
    sys.exit(1 if failed else 0)
