-- ========================================================================== --
--   РУССКИЕ GO-СНИППЕТЫ + «ФОРМОЧКА» gstr (поля подставляются из struct'а)   --
-- ========================================================================== --
-- Описание сниппетов (dstring) — на русском: в меню автодополнения видно
-- по-русски, что делает сниппет.
-- gstr — динамический: при раскрытии берёт ближайший struct над курсором
-- и разворачивается в «формочку» со всеми полями и нулевыми значениями,
-- курсор прыгает по полям (<Tab>/<S-Tab>). Выбор любого struct'а —
-- <leader>HGS (пикер), автодополнение полей — <leader>HGf.
local M = {}

function M.register()
  local ok, ls = pcall(require, "luasnip")
  if not ok then
    return
  end
  local s, t, i, d = ls.snippet, ls.text_node, ls.insert_node, ls.dynamic_node
  local sn = ls.sn

  local function form_nodes()
    local ge = require("config.go_extras")
    local name = ge.nearest_struct()
    if not name then
      return sn(nil, { t("// struct не найден: <leader>HGS или проверь парсер go") })
    end
    local fields = ge.fields_of(name)
    if #fields == 0 then
      return sn(nil, { t(name .. "{}") })
    end
    local nodes = { t(name .. " {") }
    for idx, f in ipairs(fields) do
      local zero = ge.zero_for(f.type)
      nodes[#nodes + 1] = t({ "", "\t" .. f.name .. ": " })
      nodes[#nodes + 1] = i(idx + 1, zero or "")
      nodes[#nodes + 1] = t(",")
    end
    nodes[#nodes + 1] = t({ "", "}" })
    return sn(nil, nodes)
  end

  ls.add_snippets("go", {
    s("gmain", {
      t({ "func main() {", "\t" }),
      i(1, "// код"),
      t({ "", "}" }),
    }, { dstring = "Главная функция main()" }),
    s("gfunc", {
      t("func "), i(1, "name"), t("("), i(2, ""), t(") "), i(3, "error"),
      t({ " {", "\t" }), i(4), t({ "", "}" }),
    }, { dstring = "Функция с сигнатурой и error" }),
    s("giferr", {
      t({ "if err != nil {", "\treturn " }), i(1, "fmt.Errorf(\"контекст: %w\", err)"),
      t({ "", "}" }),
    }, { dstring = "Проверка if err != nil с возвратом" }),
    s("gtest", {
      t("func Test"), i(1, "Name"), t("(t *testing.T) {\n\t"), i(2), t({ "", "}" }),
    }, { dstring = "Тестовая функция TestX(t *testing.T)" }),
    s("gsrv", {
      t({ "srv := &http.Server{", "\tAddr:    " }), i(1, '":8080"'),
      t(",\n\tHandler: "), i(2, "mux"), t(",\n}"),
    }, { dstring = "Каркас http.Server (микросервис)" }),
    s("gstr", { d(1, form_nodes, {}) }, { dstring = "Формочка struct: поля с нулевыми значениями" }),
  })
end

return M
