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
    -- ---- VS Code / GoLand-подобные сниппеты (go_pro) ----
    s("gtt", {
      t("func Test"), i(1, "Name"), t({ "(t *testing.T) {", "\ttests := []struct {", "\t\tname string", "\t\tin   " }),
      i(2, "int"), t({ "", "\t\twant " }), i(3, "int"), t({ "", "\t}{", "\t\t{name: \"базовый случай\", in: " }),
      i(4, "1"), t(", want: "), i(5, "1"),
      t({ "},", "\t}", "\tfor _, tc := range tests {", "\t\tt.Run(tc.name, func(t *testing.T) {", "\t\t\tgot := " }),
      i(6, "f(tc.in)"), t({ "", "\t\t\tif got != tc.want {", "\t\t\t\tt.Errorf(\"got %v, want %v\", got, tc.want)", "\t\t\t}", "\t\t})", "\t}", "}" }),
    }, { dstring = "Table-driven тест: срез кейсов и t.Run (стандарт Go-сообщества)" }),
    s("gbench", {
      t("func Benchmark"), i(1, "Name"), t({ "(b *testing.B) {", "\tfor range b.N {", "\t\t" }), i(2, "// код"), t({ "", "\t}", "}" }),
    }, { dstring = "Бенчмарк BenchmarkX(b *testing.B) с циклом b.N" }),
    s("gerrs", {
      t("var target "), i(1, "*MyErr"), t({ "", "if errors.As(err, &target) {", "\t" }), i(2, "// обработка"), t({ "", "}" }),
    }, { dstring = "errors.As: достать конкретный тип ошибки из цепочки" }),
    s("ggo", {
      t({ "var wg sync.WaitGroup", "for " }), i(1, "_, item"), t(" := range "), i(2, "items"),
      t({ " {", "\twg.Add(1)", "\tgo func() {", "\t\tdefer wg.Done()", "\t\t" }), i(3, "// работа"), t({ "", "\t}()", "}", "wg.Wait()" }),
    }, { dstring = "Горутина на каждый элемент и sync.WaitGroup для ожидания" }),
    s("gmu", {
      t("type "), i(1, "Counter"), t({ " struct {", "\tmu sync.Mutex", "\t" }), i(2, "n int"),
      t({ "", "}", "", "func (c *" }), i(3, "Counter"), t(") "), i(4, "Inc"), t({ "() {", "\tc.mu.Lock()", "\tdefer c.mu.Unlock()", "\t" }),
      i(5, "c.n++"), t({ "", "}" }),
    }, { dstring = "Struct с sync.Mutex и методом под блокировкой (потокобезопасно)" }),
    s("gctx", {
      t("func "), i(1, "name"), t("(ctx context.Context) error {"),
      t({ "", "\tselect {", "\tcase <-ctx.Done():", "\t\treturn ctx.Err()", "\tdefault:", "\t}", "\t" }),
      i(2), t({ "", "\treturn nil", "}" }),
    }, { dstring = "Функция с context.Context и проверкой отмены" }),
    s("gfor", {
      t("for "), i(1, "i"), t(", "), i(2, "v"), t(" := range "), i(3, "items"), t({ " {", "\t" }), i(4), t({ "", "}" }),
    }, { dstring = "for range с индексом и значением" }),
    s("gswitch", {
      t("switch v := "), i(1, "x"), t({ ".(type) {", "case " }), i(2, "int"), t({ ":", "\t" }), i(3),
      t({ "", "default:", "\t" }), i(4), t({ "", "}" }),
    }, { dstring = "Type switch: switch v := x.(type) с case и default" }),
    s("gdefer", {
      t({ "defer func() {", "\tif cerr := " }), i(1, "f"),
      t({ ".Close(); cerr != nil && err == nil {", "\t\terr = cerr", "\t}", "}()" }),
    }, { dstring = "defer: закрыть ресурс и не потерять ошибку Close (нужен именованный err)" }),
    s("glog", {
      t({ "logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))", "slog.SetDefault(logger)" }),
    }, { dstring = "Структурированный лог log/slog в JSON (stdout)" }),
    s("gjson", {
      t("type "), i(1, "Item"),
      t({ " struct {", "\tID   int    `json:\"id\"`", "\tName string `json:\"name,omitempty\"`", "}" }),
    }, { dstring = "Struct с json-тегами (поле name — omitempty)" }),
    s("gexample", {
      t("func Example"), i(1, "Name"), t({ "() {", "\t" }), i(2), t({ "", "\t// Output:", "}" }),
    }, { dstring = "Example-тест: проверяется по блоку // Output:" }),
    s("ghttp", {
      t("func "), i(1, "handle"), t({ "(w http.ResponseWriter, r *http.Request) {", "\t" }), i(2), t({ "", "}" }),
    }, { dstring = "HTTP-обработчик (w http.ResponseWriter, r *http.Request)" }),
    s("gselect", {
      t({ "select {", "case <-time.After(" }), i(1, "5 * time.Second"), t({ "):", "\treturn " }),
      i(2, "errors.New(\"таймаут\")"), t({ "", "case <-ctx.Done():", "\treturn ctx.Err()", "}" }),
    }, { dstring = "select: таймаут или отмена контекста" }),
  })
end

return M
