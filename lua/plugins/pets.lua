return {
  {
    "giusgad/pets.nvim",
    dependencies = { "giusgad/hologram.nvim", "MunifTanjim/nui.nvim" },
    cmd = { "PetsNew", "PetsNewCustom", "PetsList", "PetsKillAll", "PetsRemoveAll", "PetsPauseToggle", "PetsSleepToggle", "PetsHideToggle", "PetsIdleToggle" },
    -- init выполняется до загрузки плагина: если pets.nvim уже установлен,
    -- сразу подключаем наши спрайты (симлинки в media/).
    init = function()
      require("config.pets_custom").install_media()
    end,
    config = function(_, opts)
      -- порядок важен: медиа → preload типов → сортировка кадров → setup плагина
      require("config.pets_custom").setup()
      require("pets").setup(opts)
    end,
    keys = {
      { "<leader>up", function() require("config.pets_custom").menu() end, desc = "🐾 Питомец: выбрать и призвать" },
      { "<leader>ug", "<cmd>PetsNewCustom gopher blue Харек<cr>", desc = "🐹 Гофер Харек (синий, Go)" },
      { "<leader>uy", "<cmd>PetsNewCustom nyan classic Нян<cr>", desc = "🐱 Нян-кот (мем)" },
      { "<leader>ut", "<cmd>PetsNewCustom toaster silver Тостер<cr>", desc = "🍞 Тостер (мем)" },
      { "<leader>uG", "<cmd>PetsNewCustom ghost white Бу<cr>", desc = "👻 Призрак «бу» (мем)" },
      { "<leader>uo", "<cmd>PetsSleepToggle<cr>", desc = "😴 Питомец: сон" },
      { "<leader>ux", "<cmd>PetsKillAll<cr>", desc = "💀 Убрать питомцев" },
    },
    opts = {
      row = 1, -- позиция над статус-баром
      col = 0,
      default_pet = "gopher",
      default_style = "blue",
      random = true, -- случайный питомец по :PetsNew
      popup = { delay = 5000 },
    },
  },
}
