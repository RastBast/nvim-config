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


def test_macos_nix_libiconv_macho_patch():
    with tempfile.TemporaryDirectory() as tmpdir:
        lua_dir = os.path.join(tmpdir, "lua")
        os.makedirs(lua_dir, exist_ok=True)
        for name in ("avante_templates", "avante_tokenizers", "avante_repo_map", "avante_html2md"):
            so_path = os.path.join(lua_dir, f"{name}.so")
            with open(so_path, "wb") as f:
                f.write(b"UNPATCHED_NIX_MACHO_" + name.encode("utf-8"))
            os.chmod(so_path, 0o555)  # read-only как после Nix-сборки!

        lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        g = lua.globals()
        g.ROOT = ROOT
        g.DIR = tmpdir
        lua.execute(
            r"""
            package.path = ROOT .. "/lua/?.lua;" .. ROOT .. "/lua/?/init.lua;" .. package.path
            SYS_CMDS = {}
            PATCHED_FILES = {}

            vim = {
              v = { shell_error = 0 },
              env = { HOME = "/Users/mi6" },
              trim = function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end,
              split = function(s, sep)
                local out = {}
                for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
                return out
              end,
              fn = {
                has = function() return 0 end,
                executable = function(bin)
                  return (bin == "otool" or bin == "install_name_tool" or bin == "codesign" or bin == "xattr") and 1 or 0
                end,
                system = function(cmd)
                  SYS_CMDS[#SYS_CMDS + 1] = table.concat(cmd, " ")
                  vim.v.shell_error = 0
                  if cmd[1] == "otool" and cmd[2] == "-L" then
                    local f = cmd[3]
                    local base = f:match("([^/]+)%.so$") or "avante_templates"
                    if PATCHED_FILES[f] then
                      return f .. ":\n\t@rpath/" .. base .. ".so (compatibility version 0.0.0, current version 0.0.0)\n\t/usr/lib/libiconv.2.dylib (compatibility version 7.0.0, current version 7.0.0)\n\t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1345.100.2)\n"
                    end
                    return f .. ":\n\t/nix/store/0000-" .. base .. "/lib/lib" .. base .. ".dylib (compatibility version 0.0.0, current version 0.0.0)\n\t/nix/store/fgrxz4hr8f71hkhsddbvk8nxadpg67bv-libiconv-115.100.1/lib/libiconv.2.dylib (compatibility version 9.0.0, current version 9.1.0)\n\t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1345.100.2)\n"
                  elseif cmd[1] == "install_name_tool" then
                    local target = cmd[#cmd]
                    -- Проверяем, что патч пишется во временную копию .patched (новый inode), а не поверх read-only файла!
                    local wf = io.open(target, "wb")
                    if not wf then
                      vim.v.shell_error = 1
                      return "Permission denied"
                    end
                    wf:write("PATCHED_MACHO_OK")
                    wf:close()
                    return ""
                  elseif cmd[1] == "codesign" then
                    return ""
                  end
                  return ""
                end,
              },
              uv = {
                os_uname = function() return { sysname = "Darwin", machine = "arm64" } end,
                fs_stat = function(p)
                  local f = io.open(p, "rb")
                  if f then f:close(); return { type = "file" } end
                  return nil
                end,
                fs_chmod = function(p, mode)
                  os.execute("chmod " .. string.format("%o", mode) .. " " .. string.format("%q", p))
                end,
              },
              loader = { reset = function() end },
            }

            local MOCK_EXPORTS = {
              avante_templates = { initialize = function() end, render = function() end },
              avante_tokenizers = { from_pretrained = function() end, encode = function() end },
              avante_repo_map = { stringify_definitions = function() end },
              avante_html2md = { fetch_md = function() end, html2md = function() end },
            }

            package.loadlib = function(file, sym)
              local rf = io.open(file, "rb")
              local content = rf and rf:read("*a") or ""
              if rf then rf:close() end
              if content ~= "PATCHED_MACHO_OK" then
                return nil, "dlopen(" .. file .. ", 0x0006): Library not loaded: /nix/store/fgrxz4hr8f71hkhsddbvk8nxadpg67bv-libiconv-115.100.1/lib/libiconv.2.dylib"
              end
              PATCHED_FILES[file] = true
              local modname = sym:match("^luaopen_(.+)$")
              return function() return MOCK_EXPORTS[modname] end
            end

            -- Подключаем загрузчик из package.preload/searchers для require("avante_*") после патча:
            table.insert(package.searchers or package.loaders, 1, function(modname)
              if MOCK_EXPORTS[modname] then
                local f = DIR .. "/lua/" .. modname .. ".so"
                local loader, err = package.loadlib(f, "luaopen_" .. modname)
                if not loader then return "\n\t" .. tostring(err) end
                return loader
              end
            end)

            local B = require("config.avante_build")
            PLAN = B.parse_otool_fixes(
              "/Users/mi6/avante_templates.so:\n\t/nix/store/000-avante_templates/lib/libavante_templates.dylib (compatibility version 0.0.0, current version 0.0.0)\n\t/nix/store/fgrxz4hr8f71hkhsddbvk8nxadpg67bv-libiconv-115.100.1/lib/libiconv.2.dylib (compatibility version 9.0.0, current version 9.1.0)\n",
              "avante_templates",
              function() return false end
            )
            ENSURE_OK, ENSURE_MSG = B.ensure_runtime(DIR)
            PATCHED_COUNT = B.darwin_patched_count
            """
        )

        check(
            lua.eval("PLAN.new_id") == "@rpath/avante_templates.so"
            and lua.eval("#PLAN.changes") == 1
            and lua.eval("PLAN.changes[1].new") == "/usr/lib/libiconv.2.dylib",
            "parse_otool_fixes заменяет /nix/store/.../libiconv.2.dylib → /usr/lib/libiconv.2.dylib и ставит @rpath id",
        )
        check(
            lua.eval("ENSURE_OK") is True and lua.eval("PATCHED_COUNT") == 4,
            "ensure_runtime на macOS автоматически патчит и переподписывает все 4 .so (включая read-only 0555) при ошибке /nix/store/.../libiconv.2.dylib",
        )
        used_codesign = lua.eval(
            r"""(function()
              local cs, it = 0, 0
              for _, c in ipairs(SYS_CMDS) do
                if c:find("^install_name_tool ") and c:find("%.so%.patched$") then it = it + 1 end
                if c:find("^codesign %-%-force %-%-sign %- ") and c:find("%.so%.patched$") then cs = cs + 1 end
              end
              return it == 4 and cs == 4
            end)()"""
        )
        check(used_codesign is True, "патч Mach-O идёт через .so.patched (новый inode) + codesign --force --sign - для Apple Silicon")


if __name__ == "__main__":
    test_lockfile_matches_tag()
    test_avante_commands_and_build()
    test_repo_map_and_sidebar_guards()
    test_nil_ls_conditional_enable()
    test_macos_nix_libiconv_macho_patch()
    print(f"\nпроверок: {checked}, провалов: {failed}")
    sys.exit(1 if failed else 0)
