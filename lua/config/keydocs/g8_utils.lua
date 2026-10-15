-- Группа 8: утилиты и огонёк под <leader>HW (🧰 Утилиты). Клавиши → команды.
-- Поля: { lhs, mode (по умолч. "n"), name, doc }
return {
  { lhs = "<leader>HWr", name = "Проверить переводчики", doc = "Показывает, какой переводчик сейчас отвечает: DeepL, Google или MyMemory (:RuCheck)." },
  { lhs = "<leader>HWh", name = "Перевод подсказок K вкл/выкл", doc = "Переключает перевод окна подсказки по K на русский (:HoverRu toggle)." },
  { lhs = "<leader>HWd", name = "Русские ошибки LSP вкл/выкл", doc = "Переключает перевод сообщений диагностики LSP на русский (:DiagRu toggle)." },
  { lhs = "<leader>HWn", name = "Русские уведомления вкл/выкл", doc = "Переключает перевод системных уведомлений Neovim (:NotifyRu toggle)." },
  { lhs = "<leader>HWe", name = "Проверка PATH и утилит", doc = "Показывает, видит ли Neovim git, curl, tar и какой PATH у него (:EnvCheck)." },
  { lhs = "<leader>HWm", name = "Дождь из символов", doc = "Запускает визуальный эффект «Матрица» из cellular-automaton (:Matrix)." },
  { lhs = "<leader>HWt", name = "Обновить часы и HUD", doc = "Немедленно пересчитывает время, заряд и IP в углу (:HudNow)." },
  { lhs = "<leader>HWi", name = "IP в углу вкл/выкл", doc = "Показывает или прячет IP в плашке HUD (:HudIp toggle)." },
  { lhs = "<leader>HWc", name = "Часы 24 часа", doc = "Формат времени в HUD — 24 часа (:HudClock 24)." },
  { lhs = "<leader>HWC", name = "Часы 12 часов", doc = "Формат времени в HUD — 12 часов (:HudClock 12)." },
  { lhs = "<leader>HWz", name = "Пояс UTC+3 (МСК)", doc = "Часовой пояс HUD = UTC+3, Москва (:HudTz 3)." },
  { lhs = "<leader>HWa", name = "Огонёк без уведомлений", doc = "Отключает сообщения о зажжённых и сгоревших огоньках (:StreakNotify off)." },
  { lhs = "<leader>HWA", name = "Огонёк с уведомлениями", doc = "Включает сообщения о огоньках (:StreakNotify on)." },
  { lhs = "<leader>HWg", name = "Огонёк: цель 1 в день", doc = "Огонёк зажигается от одного коммита или новой ветки за день (:StreakGoal 1)." },
  { lhs = "<leader>HWb", name = "Огонёк: сгорание в 03:00", doc = "Во сколько по Москве день считается законченным (:StreakHour 3)." },
}
