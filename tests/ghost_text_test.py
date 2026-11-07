#!/usr/bin/env python3
"""Тесты Inline Suggestions / Ghost Text (призрачный текст ТОЛЬКО на Google Gemini):
- включено по умолчанию (M.enabled == true);
- мгновенное выключение / включение через хоткеи <leader>AG и <leader>ui (:GhostTextToggle);
- жёсткая привязка ТОЛЬКО к провайдеру gemini (даже при активном OpenRouter/Groq не шлёт код никуда, кроме Gemini);
- защита секретных файлов (.env, .pem, .key, *secret*);
- отрисовка extmark, принятие слова (<M-w>) и принятие целиком (<Tab> / <M-l>), скрытие (<C-]>).
"""
import os
import sys

from lupa.luajit21 import LuaRuntime

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
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        f"""
        package.path = {ROOT!r} .. "/lua/?.lua;" .. {ROOT!r} .. "/lua/?/init.lua;" .. package.path

        MAPS = {{}}
        CMDS = {{}}
        ECHOES = {{}}
        NOTICES = {{}}
        EXTMARKS = {{}}
        NEXT_MARK_ID = 0
        CUR_BUF = 1
        CUR_POS = {{ 1, 14 }}
        CUR_MODE = "i"
        BUF_LINES = {{
          [1] = {{ "func add(a, b ", "}}" }},
        }}
        BUF_NAMES = {{
          [1] = "/tmp/project/main.go",
          [2] = "/tmp/project/.env.production",
        }}
        BUF_FT = {{
          [1] = "go",
          [2] = "sh",
        }}

        local bo_mt = {{
          __index = function(_, b)
            return {{
              buftype = "",
              modifiable = true,
              filetype = BUF_FT[b] or "go",
            }}
          end,
        }}

        vim = {{
          env = {{}},
          g = {{}},
          bo = setmetatable({{}}, bo_mt),
          log = {{ levels = {{ INFO = 1, WARN = 2, ERROR = 3 }} }},
          trim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end,
          startswith = function(s, p) return type(s) == "string" and s:sub(1, #p) == p end,
          endswith = function(s, su) return su == "" or (type(s) == "string" and s:sub(-#su) == su) end,
          split = function(s, sep)
            local out = {{}}
            local start = 1
            while true do
              local i, j = s:find(sep, start, true)
              if not i then
                out[#out + 1] = s:sub(start)
                break
              end
              out[#out + 1] = s:sub(start, i - 1)
              start = j + 1
            end
            return out
          end,
          list_slice = function(tbl, s, e)
            local out = {{}}
            for i = s or 1, e or #tbl do out[#out + 1] = tbl[i] end
            return out
          end,
          list_extend = function(dst, src)
            for _, v in ipairs(src) do dst[#dst + 1] = v end
            return dst
          end,
          schedule = function(fn) fn() end,
          schedule_wrap = function(fn) return fn end,
          defer_fn = function(fn) fn() end,
          notify = function(msg, lvl) NOTICES[#NOTICES + 1] = {{ msg = msg, lvl = lvl }} end,
          cmd = function(_) end,
          json = {{
            encode = function(_) return "{{}}" end,
            decode = function(_) return {{}} end,
          }},
          fn = {{
            mode = function() return CUR_MODE end,
            executable = function(_) return 1 end,
            setenv = function(_, _) end,
            fnamemodify = function(p, _) return p:match("([^/]+)$") or p end,
            stdpath = function(_) return "/tmp" end,
          }},
          api = {{
            nvim_create_namespace = function(_) return 77 end,
            nvim_set_hl = function() end,
            nvim_echo = function(chunks)
              if chunks and chunks[1] then ECHOES[#ECHOES + 1] = chunks[1][1] end
            end,
            nvim_create_augroup = function(_, _) return 1 end,
            nvim_create_autocmd = function(_, _) return 1 end,
            nvim_create_user_command = function(name, fn, _)
              CMDS[name] = fn
            end,
            nvim_buf_is_valid = function(b) return BUF_LINES[b] ~= nil or b == 2 end,
            nvim_list_bufs = function() return {{ 1, 2 }} end,
            nvim_get_current_buf = function() return CUR_BUF end,
            nvim_buf_get_name = function(b) return BUF_NAMES[b] or "" end,
            nvim_buf_line_count = function(b) return #(BUF_LINES[b] or {{}}) end,
            nvim_buf_get_lines = function(b, s, e, _)
              local src = BUF_LINES[b] or {{}}
              local last = e == -1 and #src or math.min(#src, e)
              local out = {{}}
              for i = s + 1, last do out[#out + 1] = src[i] end
              return out
            end,
            nvim_buf_set_lines = function(b, s, e, _, repl)
              local src = BUF_LINES[b] or {{}}
              local last = e == -1 and #src or e
              local res = {{}}
              for i = 1, s do res[#res + 1] = src[i] end
              for _, v in ipairs(repl) do res[#res + 1] = v end
              for i = last + 1, #src do res[#res + 1] = src[i] end
              BUF_LINES[b] = res
            end,
            nvim_win_get_cursor = function(_) return {{ CUR_POS[1], CUR_POS[2] }} end,
            nvim_win_set_cursor = function(_, pos) CUR_POS = {{ pos[1], pos[2] }} end,
            nvim_buf_set_extmark = function(b, _, row, col, opts)
              NEXT_MARK_ID = NEXT_MARK_ID + 1
              EXTMARKS[b] = EXTMARKS[b] or {{}}
              EXTMARKS[b][NEXT_MARK_ID] = {{ row = row, col = col, opts = opts }}
              return NEXT_MARK_ID
            end,
            nvim_buf_get_extmarks = function(b, _, _, _, _)
              local out = {{}}
              for id, m in pairs(EXTMARKS[b] or {{}}) do
                out[#out + 1] = {{ id, m.row, m.col }}
              end
              return out
            end,
            nvim_buf_clear_namespace = function(b, _, _, _)
              EXTMARKS[b] = {{}}
            end,
            nvim_replace_termcodes = function(s) return s end,
            nvim_feedkeys = function() end,
          }},
          keymap = {{
            set = function(mode, lhs, rhs, _)
              MAPS[tostring(mode) .. ":" .. lhs] = rhs
            end,
          }},
        }}

        local AI = require("config.ai_api")
        CHAT_CALLS = {{}}
        AI.chat = function(messages, opts, cb)
          CHAT_CALLS[#CHAT_CALLS + 1] = {{ messages = messages, opts = opts }}
          cb("```go\\nint) int {{\\n\\treturn a + b\\n}}\\n```", nil, {{ id = opts.provider }})
          return {{ kill = function() end }}
        end

        GT = require("config.ghost_text")
        GT.setup()
        """
    )

    check(lua.eval("GT.enabled") is True, "Ghost Text включён по умолчанию при старте Neovim")
    check(
        lua.eval('MAPS["n:<leader>AG"] ~= nil and MAPS["n:<leader>ui"] ~= nil and MAPS["i:<M-l>"] ~= nil and MAPS["i:<M-w>"] ~= nil'),
        "хоткеи <leader>AG, <leader>ui, <M-l>, <M-w> зарегистрированы",
    )
    check(
        lua.eval('CMDS.GhostTextToggle ~= nil and CMDS.GhostText ~= nil and CMDS.GhostTextSuggest ~= nil'),
        "команды :GhostTextToggle, :GhostText, :GhostTextSuggest зарегистрированы",
    )

    # 1. СТРОГАЯ ИЗОЛЯЦИЯ НА GEMINI: заданы ключи OpenRouter и Groq, выбран openrouter, НО нет ключа Gemini -> 0 запросов!
    lua.execute(
        """
        vim.g.ai_provider = "openrouter"
        vim.env.AI_PROVIDER = "groq"
        vim.env.AVANTE_PROVIDER = "openrouter-free"
        vim.env.OPENROUTER_API_KEY = "sk-or-valid-key-123"
        vim.env.GROQ_API_KEY = "gsk-valid-key-123"
        vim.env.AVANTE_GEMINI_API_KEY = nil
        vim.env.GEMINI_API_KEY = nil
        vim.env.GOOGLE_API_KEY = nil
        GT.request_suggestion({ manual = false })
        """
    )
    check(
        lua.eval("#CHAT_CALLS") == 0,
        "при активных OpenRouter/Groq без ключа Gemini Ghost Text НЕ отправляет ни одного запроса",
    )

    # 2. Задаём прямой ключ Gemini (даже при глобально выбранном OpenRouter!) -> запрос уходит ТОЛЬКО в provider="gemini"!
    lua.execute(
        """
        vim.env.AVANTE_GEMINI_API_KEY = "AIzaDirectKeyForGhostText999"
        GT.request_suggestion({ manual = false })
        """
    )
    check(
        lua.eval('#CHAT_CALLS == 1 and CHAT_CALLS[1].opts.provider == "gemini"'),
        "даже при выбранном чате OpenRouter/Groq Ghost Text вызывает СТРОГО провайдер gemini",
    )
    check(
        lua.eval("GT.is_visible(1)") is True,
        "после ответа Gemini призрачная подсказка отрисована через extmark",
    )
    check(
        lua.eval('GT.lualine_component() == "👻 Gemini"'),
        "индикатор Lualine показывает 👻 Gemini при включённом режиме и наличии ключа",
    )

    # 3. Принятие одного слова (<M-w>) + затем принятие остатка целиком (<M-l>):
    lua.execute('MAPS["i:<M-w>"]()')
    check(
        lua.eval('BUF_LINES[1][1] == "func add(a, b int"') and lua.eval("GT.is_visible(1)") is True,
        "<M-w> принимает только первое слово подсказки и оставляет остаток Ghost Text на месте",
    )
    lua.execute('MAPS["i:<M-l>"]()')
    check(
        lua.eval(r'BUF_LINES[1][1] == "func add(a, b int) int {" and BUF_LINES[1][2] == "\treturn a + b" and GT.is_visible(1) == false'),
        "<M-l> принимает многострочный остаток подсказки целиком и убирает extmark",
    )

    # 4. Переключение ВЫКЛ / ВКЛ через хоткеи <leader>AG и <leader>ui:
    lua.execute(
        """
        GT.render(1, 1, 5, "test")
        MAPS["n:<leader>AG"]()
        """
    )
    check(
        lua.eval('GT.enabled == false and GT.is_visible(1) == false and GT.lualine_component() == "👻 off"'),
        "нажатие <leader>AG мгновенно выключает Ghost Text и очищает текущую подсказку",
    )
    lua.execute(
        """
        GT.request_suggestion({ manual = false })
        """
    )
    check(
        lua.eval("#CHAT_CALLS") == 1,
        "в выключенном состоянии авто-запросы Ghost Text не отправляются",
    )
    lua.execute('MAPS["n:<leader>ui"]()')
    check(
        lua.eval('GT.enabled == true and GT.lualine_component() == "👻 Gemini"'),
        "повторное нажатие хоткея (<leader>ui) включает Ghost Text обратно",
    )

    # 5. Защита файлов с секретами (.env, .pem, .key):
    check(
        lua.eval('GT.is_sensitive_file("/app/.env") and GT.is_sensitive_file("/app/cert.pem") and not GT.is_eligible_buf(2)') is True,
        "секретные файлы (.env, .pem, .key) заблокированы от отправки в Ghost Text",
    )


if __name__ == "__main__":
    main()
    print(f"\nпроверок: {checked}, провалов: {failed}")
    sys.exit(1 if failed else 0)
