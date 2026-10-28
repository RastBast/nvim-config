-- ========================================================================== --
--         GO-СНИППЕТЫ: KAFKA (segmentio/kafka-go) И ДРАЙВЕРЫ БАЗ ДАННЫХ        --
-- ========================================================================== --
-- Регистрируются рядом с go_snips (go-tools.lua). Префиксы:
--   gk…  — Kafka: продюсер, консьюмер-группа, конфиг с SASL/TLS
--   gdb… — database/sql: открытие подключения к конкретной СУБД
-- Импорты сниппеты НЕ добавляют — после раскрытия запусти goimports (<leader>cf).
local M = {}

function M.register()
  local ok, ls = pcall(require, "luasnip")
  if not ok then return end
  local s, t, i = ls.snippet, ls.text_node, ls.insert_node

  ls.add_snippets("go", {
    -- ───────── Kafka ─────────
    s("gkprod", {
      t({ "w := &kafka.Writer{", "\tAddr:     kafka.TCP(" }), i(1, '"localhost:9092"'), t(")"),
      t({ ",", "\tTopic:    " }), i(2, '"events"'),
      t({ ",", "\tBalancer: &kafka.LeastBytes{},", "\tAsync:    false, // true — пакетная отправка в фоне", "}", "defer w.Close()", "", "err := w.WriteMessages(ctx, kafka.Message{", "\tKey:   []byte(" }),
      i(3, '"key"'), t({ "),", "\tValue: []byte(" }), i(4, '"value"'), t({ "),", "})", "if err != nil {", "\treturn fmt.Errorf(\"kafka produce: %w\", err)", "}" }),
    }, { dstring = "Kafka: продюсер (kafka.Writer) и отправка сообщения" }),

    s("gkcons", {
      t({ "r := kafka.NewReader(kafka.ReaderConfig{", "\tBrokers: []string{" }), i(1, '"localhost:9092"'),
      t({ "},", "\tGroupID: " }), i(2, '"my-group"'), t({ ",", "\tTopic:   " }), i(3, '"events"'),
      t({ ",", "\tMinBytes: 10e3, // 10KB", "\tMaxBytes: 10e6, // 10MB", "})", "defer r.Close()", "", "for {", "\tm, err := r.FetchMessage(ctx)", "\tif err != nil {", "\t\tbreak // ctx отменён или ошибка брокера", "\t}", "\t// обработка: " }),
      i(0), t({ "", "\tif err := r.CommitMessages(ctx, m); err != nil {", "\t\tlog.Printf(\"commit: %v\", err)", "\t}", "}" }),
    }, { dstring = "Kafka: консьюмер-группа (FetchMessage + CommitMessages)" }),

    s("gkcfg", {
      t({ "dialer := &kafka.Dialer{", "\tTimeout:   10 * time.Second," }),
      t({ "", "\tDualStack: true," }),
      t({ "", "\tSASLMechanism: plain.Mechanism{", "\t\tUsername: " }), i(1, "os.Getenv(\"KAFKA_USER\")"),
      t({ ",", "\t\tPassword: " }), i(2, "os.Getenv(\"KAFKA_PASSWORD\")"),
      t({ ",", "\t}, // SASL/PLAIN (пакет github.com/segmentio/kafka-go/sasl/plain)", "\tTLS: &tls.Config{MinVersion: tls.VersionTLS12},", "}" }),
    }, { dstring = "Kafka: Dialer с SASL/PLAIN и TLS" }),

    -- ───────── Базы данных (database/sql) ─────────
    s("gdbsqlite", {
      t({ "db, err := sql.Open(\"sqlite\", " }), i(1, '"file:app.db?_pragma=busy_timeout(5000)"'), t({ ")", "if err != nil {", "\treturn err", "}", "defer db.Close()" }),
    }, { dstring = "БД: SQLite (modernc.org/sqlite — без CGO)" }),

    s("gdbmysql", {
      t({ "db, err := sql.Open(\"mysql\", " }), i(1, '"user:pass@tcp(localhost:3306)/app?parseTime=true"'), t({ ")", "if err != nil {", "\treturn err", "}", "defer db.Close()" }),
    }, { dstring = "БД: MySQL / MariaDB (github.com/go-sql-driver/mysql)" }),

    s("gdbpg", {
      t({ "db, err := sql.Open(\"pgx\", " }), i(1, '"postgres://user:pass@localhost:5432/app?sslmode=disable"'), t({ ")", "if err != nil {", "\treturn err", "}", "defer db.Close()" }),
    }, { dstring = "БД: PostgreSQL (github.com/jackc/pgx/v5/stdlib)" }),

    s("gdboracle", {
      t({ "db, err := sql.Open(\"oracle\", " }), i(1, '"oracle://user:pass@localhost:1521/service"'), t({ ")", "if err != nil {", "\treturn err", "}", "defer db.Close()" }),
    }, { dstring = "БД: Oracle (github.com/sijms/go-ora/v2, чистый Go)" }),

    s("gdbmssql", {
      t({ "db, err := sql.Open(\"sqlserver\", " }), i(1, '"sqlserver://user:pass@localhost:1433?database=app"'), t({ ")", "if err != nil {", "\treturn err", "}", "defer db.Close()" }),
    }, { dstring = "БД: SQL Server (github.com/microsoft/go-mssqldb)" }),

    s("gdbch", {
      t({ "db, err := sql.Open(\"clickhouse\", " }), i(1, '"clickhouse://user:pass@localhost:9000/app"'), t({ ")", "if err != nil {", "\treturn err", "}", "defer db.Close()" }),
    }, { dstring = "БД: ClickHouse (github.com/ClickHouse/clickhouse-go/v2)" }),
  })
end

return M
