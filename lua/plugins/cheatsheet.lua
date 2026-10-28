-- cheat.sh прямо в окне: шпаргалка по команде/языку (нужен интернет и curl).
-- Команды: :Cheat <запрос>, :CheatWithoutComments, :CheatList (поиск по всем).
return {
  {
    "RishabhRD/nvim-cheat.sh",
    dependencies = { "RishabhRD/popfix" },
    cmd = { "Cheat", "CheatWithoutComments", "CheatList", "CheatListWithoutComments" },
  },
}
