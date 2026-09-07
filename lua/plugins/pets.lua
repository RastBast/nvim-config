-- ========================================================================== --
--                           ПИТОМЦЫ (pets.nvim)                              --
-- ========================================================================== --
-- ИСПРАВЛЕНО: `:PetsNew custom holli brown` — неверный вызов.
-- В lua/pets/commands.lua:
--   :PetsNew {name}                 — 1 аргумент, берёт default_pet/default_style
--   :PetsNewCustom {type} {style} {name} — 3 аргумента (кастомный питомец)
-- Трёхаргументный вызов через :PetsNew просто игнорировался/падал.
return {
  {
    "giusgad/pets.nvim",
    dependencies = { "giusgad/hologram.nvim", "MunifTanjim/nui.nvim" },
    cmd = { "PetsNew", "PetsNewCustom", "PetsList", "PetsKillAll", "PetsRemoveAll", "PetsPauseToggle", "PetsSleepToggle", "PetsHideToggle", "PetsIdleToggle" },
    keys = {
      { "<leader>up", "<cmd>PetsNewCustom dog brown holli<cr>", desc = "🐾 Призвать питомца" },
      { "<leader>uo", "<cmd>PetsSleepToggle<cr>", desc = "😴 Питомец: сон" },
      { "<leader>ux", "<cmd>PetsKillAll<cr>", desc = "💀 Убрать питомцев" },
    },
    opts = {
      row = 1,               -- позиция над статус-баром
      col = 0,
      default_pet = "dog",
      default_style = "brown",
      random = true,         -- случайный питомец по :PetsNew
      popup = { delay = 5000 },
    },
  },
}
