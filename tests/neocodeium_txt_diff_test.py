#!/usr/bin/env python3
"""Комплексные тесты:
1. Codeium / NeoCodeium (вкл по умолчанию, выключение/включение хоткеем <leader>AG / <leader>ui, защита .env).
2. Скрытие размышлений ИИ (<think>, Thought content, Gemini thought=true) по умолчанию + тумблер <leader>Ah.
3. Отправка файла с любым расширением ЯП в формате .txt (<leader>AF и <leader>AT) + просмотр изменений целого файла как в git (<leader>AD: цветной git-diff + поханочное применение + переключение Tab в side-by-side vimdiff).
"""
import json
import os
import sys
import tempfile

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
    with open(os.path.join(ROOT, "lazy-lock.json"), encoding="utf-8") as f:
        lock = json.load(f)
    check(
        "neocodeium" in lock and len(lock["neocodeium"].get("commit", "")) == 40,
        "lazy-lock.json фиксирует monkoose/neocodeium по точному SHA коммита",
    )

    with tempfile.TemporaryDirectory() as tmpdir:
        lua = LuaRuntime(unpack_returned_tuples=True)
        g = lua.globals()

        def py_json_encode(val):
            def from_lua(v):
                if v is None or isinstance(v, (bool, int, float, str)):
                    return v
                keys = list(v.keys())
                if not keys:
                    return []
                if all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
                    return [from_lua(v[i]) for i in range(1, len(keys) + 1)]
                return {str(k): from_lua(v[k]) for k in keys}

            return json.dumps(from_lua(val), ensure_ascii=False)

        def py_json_decode(raw):
            data = json.loads(raw)

            def to_lua(v):
                if isinstance(v, dict):
                    t = lua.table()
                    for k, val in v.items():
                        t[k] = to_lua(val)
                    return t
                if isinstance(v, list):
                    t = lua.table()
                    for idx, val in enumerate(v, 1):
                        t[idx] = to_lua(val)
                    return t
                return v

            return to_lua(data)

        g.PY_JSON_ENCODE = py_json_encode
        g.PY_JSON_DECODE = py_json_decode
        g.TMP = tmpdir

        lua.execute(
            rf"""
            package.path = {ROOT!r} .. "/lua/?.lua;" .. {ROOT!r} .. "/lua/?/init.lua;" .. package.path

            MAPS = {{}}
            BUF_MAPS = {{}}
            CMDS = {{}}
            VIM_CMDS = {{}}
            NEXT_BUF = 10
            NEXT_WIN = 20
            CUR_BUF = 1
            CUR_WIN = 1

            BUFS = {{
              [1] = {{
                name = TMP .. "/shaders/lighting.wgsl",
                ft = "wgsl",
                bt = "",
                modifiable = true,
                lines = {{
                  "fn calc_light(x: f32) -> f32 {{",
                  "  let base = x * 0.5;",
                  "  return base;",
                  "}}",
                  "",
                  "fn helper() -> i32 {{",
                  "  return 1;",
                  "}}",
                }},
              }},
              [2] = {{
                name = TMP .. "/.env.secret",
                ft = "sh",
                bt = "",
                modifiable = true,
                lines = {{ "API_KEY=123" }},
              }},
            }}
            WINS = {{
              [1] = {{ buf = 1, cursor = {{ 1, 0 }} }},
            }}

            local bo_mt = {{
              __index = function(_, b)
                local info = BUFS[b]
                if not info then return {{ buftype = "", modifiable = true, filetype = "" }} end
                return setmetatable({{}}, {{
                  __index = function(_, k)
                    if k == "filetype" then return info.ft end
                    if k == "buftype" then return info.bt end
                    if k == "modifiable" then return info.modifiable end
                    return info[k]
                  end,
                  __newindex = function(_, k, v)
                    if k == "filetype" then info.ft = v
                    elseif k == "buftype" then info.bt = v
                    elseif k == "modifiable" then info.modifiable = v
                    else info[k] = v end
                  end,
                }})
              end,
            }}

            vim = {{
              env = {{}},
              g = {{}},
              o = {{ columns = 140, lines = 42 }},
              bo = setmetatable({{}}, bo_mt),
              wo = setmetatable({{}}, {{ __index = function() return {{}} end }}),
              log = {{ levels = {{ INFO = 1, WARN = 2, ERROR = 3 }} }},
              trim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end,
              deepcopy = function(t)
                if type(t) ~= "table" then return t end
                local r = {{}}
                for k, v in pairs(t) do r[k] = v end
                return r
              end,
              tbl_extend = function(_, a, b)
                local r = {{}}
                for k, v in pairs(a or {{}}) do r[k] = v end
                for k, v in pairs(b or {{}}) do r[k] = v end
                return r
              end,
              list_extend = function(dst, src)
                for _, v in ipairs(src or {{}}) do dst[#dst + 1] = v end
                return dst
              end,
              schedule = function(fn) fn() end,
              notify = function() end,
              cmd = function(c)
                VIM_CMDS[#VIM_CMDS + 1] = c
                if c == "rightbelow vsplit" then
                  NEXT_WIN = NEXT_WIN + 1
                  WINS[NEXT_WIN] = {{ buf = CUR_BUF, cursor = {{ 1, 0 }} }}
                  CUR_WIN = NEXT_WIN
                end
              end,
              json = {{
                encode = function(v) return PY_JSON_ENCODE(v) end,
                decode = function(s) return PY_JSON_DECODE(s) end,
              }},
              ui = {{
                input = function(_, cb) cb("Увеличь множитель света и верни 2 в helper") end,
                select = function() end,
              }},
              fn = {{
                has = function() return 1 end,
                mode = function() return "i" end,
                stdpath = function(_) return TMP end,
                mkdir = function(p, _) os.execute("mkdir -p " .. string.format("%q", p)) end,
                executable = function(_) return 1 end,
                setenv = function() end,
              }},
              api = {{
                nvim_create_namespace = function(_) return 11 end,
                nvim_echo = function() end,
                nvim_create_augroup = function() return 1 end,
                nvim_create_autocmd = function() return 1 end,
                nvim_create_user_command = function(name, fn, _) CMDS[name] = fn end,
                nvim_list_uis = function() return {{ {{}} }} end,
                nvim_list_wins = function()
                  local out = {{}}
                  for w, _ in pairs(WINS) do out[#out + 1] = w end
                  table.sort(out)
                  return out
                end,
                nvim_get_current_win = function() return CUR_WIN end,
                nvim_set_current_win = function(w)
                  if WINS[w] then CUR_WIN = w; CUR_BUF = WINS[w].buf end
                end,
                nvim_win_is_valid = function(w) return WINS[w] ~= nil end,
                nvim_win_get_buf = function(w) return WINS[w] and WINS[w].buf or 1 end,
                nvim_win_set_buf = function(w, b)
                  if WINS[w] then WINS[w].buf = b end
                  if w == CUR_WIN then CUR_BUF = b end
                end,
                nvim_open_win = function(b, enter, _)
                  NEXT_WIN = NEXT_WIN + 1
                  WINS[NEXT_WIN] = {{ buf = b, cursor = {{ 1, 0 }} }}
                  if enter then CUR_WIN = NEXT_WIN; CUR_BUF = b end
                  return NEXT_WIN
                end,
                nvim_win_close = function(w, _)
                  WINS[w] = nil
                  if CUR_WIN == w then CUR_WIN = 1; CUR_BUF = WINS[1] and WINS[1].buf or 1 end
                end,
                nvim_win_get_cursor = function(w)
                  local ww = (w == 0 or not w) and CUR_WIN or w
                  return (WINS[ww] and WINS[ww].cursor) or {{ 1, 0 }}
                end,
                nvim_win_set_cursor = function(w, pos)
                  local ww = (w == 0 or not w) and CUR_WIN or w
                  if WINS[ww] then WINS[ww].cursor = {{ pos[1], pos[2] }} end
                end,
                nvim_create_buf = function(_, _)
                  NEXT_BUF = NEXT_BUF + 1
                  BUFS[NEXT_BUF] = {{ name = "", ft = "", bt = "", modifiable = true, lines = {{}} }}
                  return NEXT_BUF
                end,
                nvim_buf_is_valid = function(b) return BUFS[b] ~= nil end,
                nvim_list_bufs = function()
                  local out = {{}}
                  for b, _ in pairs(BUFS) do out[#out + 1] = b end
                  table.sort(out)
                  return out
                end,
                nvim_get_current_buf = function() return CUR_BUF end,
                nvim_buf_get_name = function(b) return BUFS[b] and BUFS[b].name or "" end,
                nvim_buf_set_name = function(b, nm) if BUFS[b] then BUFS[b].name = nm end end,
                nvim_buf_get_lines = function(b, s, e, _)
                  local src = (BUFS[b] and BUFS[b].lines) or {{}}
                  local last = e == -1 and #src or math.min(#src, e)
                  local out = {{}}
                  for i = s + 1, last do out[#out + 1] = src[i] end
                  return out
                end,
                nvim_buf_set_lines = function(b, s, e, _, repl)
                  local src = (BUFS[b] and BUFS[b].lines) or {{}}
                  local last = e == -1 and #src or e
                  local res = {{}}
                  for i = 1, s do res[#res + 1] = src[i] end
                  for _, v in ipairs(repl) do res[#res + 1] = v end
                  for i = last + 1, #src do res[#res + 1] = src[i] end
                  if BUFS[b] then BUFS[b].lines = res end
                end,
                nvim_buf_clear_namespace = function() end,
                nvim_buf_add_highlight = function() end,
                nvim_replace_termcodes = function(s) return s end,
                nvim_feedkeys = function() end,
              }},
              keymap = {{
                set = function(mode, lhs, rhs, opts)
                  if opts and opts.buffer then
                    BUF_MAPS[opts.buffer] = BUF_MAPS[opts.buffer] or {{}}
                    BUF_MAPS[opts.buffer][lhs] = rhs
                  else
                    MAPS[tostring(mode) .. ":" .. lhs] = rhs
                  end
                end,
              }},
            }}

            -- Стаб плагина neocodeium:
            NC_ACCEPT_CALLED, NC_WORD_CALLED, NC_DISABLED = 0, 0, false
            package.loaded["neocodeium"] = {{
              visible = function() return true end,
              accept = function() NC_ACCEPT_CALLED = NC_ACCEPT_CALLED + 1 end,
              accept_word = function() NC_WORD_CALLED = NC_WORD_CALLED + 1 end,
              accept_line = function() end,
              clear = function() end,
              cycle_or_complete = function() end,
              get_status = function() return NC_DISABLED and 1 or 0, 0 end,
            }}
            package.loaded["neocodeium.commands"] = {{
              enable = function() NC_DISABLED = false end,
              disable = function() NC_DISABLED = true end,
            }}

            NC_UI = require("config.neocodeium_ui")
            NC_UI.setup()
            NC_SPEC = require("plugins.neocodeium")[1]

            TH = require("config.ai_thinking")
            TH.setup()

            FTXT = require("config.ai_file_txt")
            FTXT.setup()
            """
        )

        # --- 1. ТЕСТЫ NEOCODEIUM ---
        check(
            lua.eval("NC_UI.enabled == true and NC_SPEC.opts().enabled == true"),
            "Codeium / NeoCodeium включён по умолчанию при старте",
        )
        check(
            lua.eval("NC_UI.filter_buf(1) == true and NC_UI.filter_buf(2) == false"),
            "фильтр Codeium разрешает обычный код и блокирует секретный .env файл",
        )
        lua.execute('MAPS["i:<M-w>"](); MAPS["i:<M-l>"]()')
        check(
            lua.eval("NC_WORD_CALLED == 1 and NC_ACCEPT_CALLED == 1"),
            "хоткеи <M-w> (слово) и <M-l> (принять целиком) управляют NeoCodeium",
        )
        lua.execute('MAPS["n:<leader>AG"]()')
        check(
            lua.eval('NC_UI.enabled == false and NC_DISABLED == true and NC_UI.lualine_component() == "⚡ Codeium:off"'),
            "нажатие <leader>AG мгновенно выключает Codeium / NeoCodeium",
        )
        lua.execute('MAPS["n:<leader>ui"]()')
        check(
            lua.eval('NC_UI.enabled == true and NC_DISABLED == false and NC_UI.lualine_component() == "⚡ Codeium"'),
            "нажатие <leader>ui включает Codeium / NeoCodeium обратно",
        )

        # --- 2. ТЕСТЫ СКРЫТИЯ РАЗМЫШЛЕНИЙ ИИ ---
        check(
            lua.eval("TH.is_enabled() == false"),
            "размышления ИИ скрыты по умолчанию (только чистый ответ)",
        )
        check(
            lua.eval(
                r'''TH.strip("<think>\nСначала подумаю про типы...\n</think>\nГотовый ответ!") == "Готовый ответ!"'''
            ),
            "strip() полностью вырезает <think>...</think> и оставляет только ответ",
        )
        check(
            lua.eval(
                r'''TH.strip("<thinking>Ещё думаю без закрывающего тега...") == ""'''
            ),
            "strip() скрывает незакрытый потоковый блок <thinking>... во время стриминга",
        )

        # Проверяем перехват рендера Avante и thought=true у Gemini:
        lua.execute(
            r"""
            package.loaded["avante.history.render"] = {
              message_to_lines = function(msg)
                local out = {}
                for _, item in ipairs(msg.message.content) do
                  if item.type == "thinking" then
                    out[#out + 1] = "THOUGHT:" .. item.thinking
                  elseif item.type == "text" then
                    out[#out + 1] = "TEXT:" .. item.text
                  end
                end
                return out
              end,
            }
            GEMINI_RECEIVED_PARTS = nil
            package.loaded["avante.providers"] = {
              openai = {
                add_thinking_message = function() OPENAI_THINK_CALLED = true end,
                add_reasoning_message = function() OPENAI_REASON_CALLED = true end,
                add_text_message = function(_, _, txt) OPENAI_LAST_TEXT = txt end,
              },
              gemini = {
                parse_response = function(_, _, data_stream)
                  local d = vim.json.decode(data_stream)
                  GEMINI_RECEIVED_PARTS = d.candidates[1].content.parts
                end,
              },
            }
            TH.install_avante_hooks()

            local sample_msg = {
              message = {
                role = "assistant",
                content = {
                  { type = "thinking", thinking = "Внутренние рассуждения" },
                  { type = "text", text = "<think>Скрытая мысль</think>\nЧистый код ответа" },
                },
              },
            }
            RENDERED_DEFAULT = package.loaded["avante.history.render"].message_to_lines(sample_msg)
            package.loaded["avante.providers"].openai:add_thinking_message({}, "думаю", "generating", {})
            package.loaded["avante.providers"].gemini:parse_response(
              {},
              '{"candidates":[{"content":{"parts":[{"thought":true,"text":"secret thought"},{"text":"Чистый ответ Gemini"}]},"finishReason":"STOP"}]}',
              nil,
              {}
            )

            -- Включаем показ размышлений тумблером <leader>Ah и проверяем обратное переключение:
            MAPS["n:<leader>Ah"]()
            RENDERED_WITH_TOGGLE = package.loaded["avante.history.render"].message_to_lines(sample_msg)
            MAPS["n:<leader>Ah"]()
            """
        )
        check(
            lua.eval('#RENDERED_DEFAULT == 1 and RENDERED_DEFAULT[1] == "TEXT:Чистый код ответа"'),
            "в чате Avante скрыты блоки Thought content и <think>, остаётся только ответ",
        )
        check(
            lua.eval("OPENAI_THINK_CALLED == nil and #GEMINI_RECEIVED_PARTS == 1 and GEMINI_RECEIVED_PARTS[1].text == 'Чистый ответ Gemini'"),
            "перехватчики Avante блокируют Gemini thought=true и OpenAI/OpenRouter reasoning_content",
        )
        check(
            lua.eval("#RENDERED_WITH_TOGGLE == 2 and TH.is_enabled() == false"),
            "хоткей <leader>Ah позволяет при необходимости включить и снова скрыть размышления",
        )

        # --- 3. ТЕСТЫ ОТПРАВКИ ФАЙЛА КАК .TXT + GIT-DIFF ИЗМЕНЕНИЙ ---
        lua.execute(
            r"""
            local AI = require("config.ai_api")
            SENT_PAYLOAD = nil
            AI.chat = function(messages, _, cb)
              SENT_PAYLOAD = messages[2].content
              cb(
                "<think>Поменяю коэффициенты в файле lighting.wgsl</think>\n```wgsl\nfn calc_light(x: f32) -> f32 {\n  let base = x * 2.0;\n  return base;\n}\n\nfn helper() -> i32 {\n  return 2;\n}\n```",
                nil,
                { id = "gemini" }
              )
            end

            -- Сценарий 1: <leader>AF (:AiFileTxt) — отправляет .wgsl как lighting_wgsl.txt и открывает git-diff!
            CUR_WIN = 1; CUR_BUF = 1
            MAPS["n:<leader>AF"]()
            DIFF_BUF = CUR_BUF
            DIFF_TEXT_INITIAL = table.concat(BUFS[DIFF_BUF].lines, "\n")
            """
        )
        sent_payload = lua.eval("SENT_PAYLOAD")
        diff_initial = lua.eval("DIFF_TEXT_INITIAL")
        check(
            "TXT_FILENAME: lighting_wgsl.txt" in sent_payload and "fn calc_light" in sent_payload,
            "<leader>AF сериализует буфер с редким расширением (.wgsl) в чистый файл lighting_wgsl.txt",
        )
        check(
            "@@" in diff_initial
            and "-   let base = x * 0.5;" in diff_initial
            and "+   let base = x * 2.0;" in diff_initial
            and "[+2 добавлено  /  -2 удалено  ·  ханков: 1]" in diff_initial,
            "после ответа ИИ открывается цветной git-diff с ханками (+ / -) и точной статистикой",
        )

        # Применяем ТОЛЬКО первый ханк клавишей `y`, затем остаток клавишей `<CR>`!
        lua.execute(
            r"""
            -- Для честной проверки 2 отдельных ханков раздвинем строки > 7 строк контекста:
            CUR_WIN = 1; CUR_BUF = 1
            BUFS[1].lines = {
              "fn calc_light(x: f32) -> f32 {",
              "  let base = x * 0.5;",
              "  return base;",
              "}",
              "// 1",
              "// 2",
              "// 3",
              "// 4",
              "// 5",
              "// 6",
              "// 7",
              "// 8",
              "fn helper() -> i32 {",
              "  return 1;",
              "}",
            }
            local new_multi = {
              "fn calc_light(x: f32) -> f32 {",
              "  let base = x * 2.0;",
              "  return base;",
              "}",
              "// 1",
              "// 2",
              "// 3",
              "// 4",
              "// 5",
              "// 6",
              "// 7",
              "// 8",
              "fn helper() -> i32 {",
              "  return 2;",
              "}",
            }
            FTXT.open_git_diff(1, new_multi, { title = "lighting_wgsl.txt" })
            local dbuf = CUR_BUF
            -- Применяем только 1-й ханк клавишей `y`:
            BUF_MAPS[dbuf]["y"]()
            AFTER_FIRST_HUNK_LINE2 = BUFS[1].lines[2]
            AFTER_FIRST_HUNK_LINE14 = BUFS[1].lines[14]
            -- Переключаемся по `Tab` в двухоконный side-by-side vimdiff и принимаем остаток по `<CR>`:
            BUF_MAPS[dbuf]["<Tab>"]()
            local split_ai_buf = CUR_BUF
            BUF_MAPS[split_ai_buf]["<CR>"]()
            FINAL_LINE14 = BUFS[1].lines[14]
            """
        )
        check(
            lua.eval('AFTER_FIRST_HUNK_LINE2 == "  let base = x * 2.0;" and AFTER_FIRST_HUNK_LINE14 == "  return 1;"'),
            "клавиша y в окне git-diff применяет только выбранный ханк, не трогая остальные",
        )
        check(
            lua.eval('FINAL_LINE14 == "  return 2;"') and "diffthis" in list(lua.eval("VIM_CMDS").values()),
            "клавиша Tab переключает в двухоконный vimdiff бок-о-бок, а Enter принимает весь файл",
        )

        # Сценарий 2 (<leader>AT — прикрепить .txt в чат Avante) + <leader>AD (git-diff из ответа чата Avante):
        lua.execute(
            r"""
            AV_SELECTED = { TMP .. "/shaders/lighting.wgsl" }
            HANDLER_PRESERVED = true
            package.loaded["avante"] = {
              is_sidebar_open = function() return true end,
              get = function()
                return {
                  file_selector = {
                    selected_filepaths = AV_SELECTED,
                    event_handlers = { update = { function() end } },
                    remove_selected_file = function(self_fs, p)
                      for i = #self_fs.selected_filepaths, 1, -1 do
                        if self_fs.selected_filepaths[i] == p then
                          table.remove(self_fs.selected_filepaths, i)
                        end
                      end
                    end,
                    add_selected_file = function(self_fs, p)
                      if not self_fs.event_handlers.update then HANDLER_PRESERVED = false end
                      self_fs.selected_filepaths[#self_fs.selected_filepaths + 1] = p
                    end,
                  },
                  chat_history = {
                    messages = {
                      {
                        turn_id = "t1",
                        message = {
                          role = "assistant",
                          content = "<think>Думаю</think>\nВот обновлённый файл целиком:\n```wgsl\nfn calc_light(x: f32) -> f32 {\n  return x * 10.0;\n}\n```",
                        },
                      },
                    },
                  },
                }
              end,
            }
            CUR_WIN = 1; CUR_BUF = 1
            ATTACHED_TXT_PATH = FTXT.attach_txt_to_avante()
            MAPS["n:<leader>AD"]()
            CHAT_DIFF_TEXT = table.concat(BUFS[CUR_BUF].lines, "\n")
            """
        )
        check(
            lua.eval('#AV_SELECTED == 1 and AV_SELECTED[1]:match("lighting_wgsl%.txt$") ~= nil and HANDLER_PRESERVED == true'),
            "<leader>AT заменяет исходный .wgsl в Selected files чата Avante на чистый lighting_wgsl.txt",
        )
        check(
            "+   return x * 10.0;" in lua.eval("CHAT_DIFF_TEXT"),
            "<leader>AD извлекает изменённый целый файл из ответа чата Avante и открывает git-diff",
        )


if __name__ == "__main__":
    main()
    print(f"\nпроверок: {checked}, провалов: {failed}")
    sys.exit(1 if failed else 0)
