return {
  {
    "michaelrommel/nvim-silicon",
    lazy = true,
    cmd = "Silicon",
    opts = {
      -- Шрифты (исправлено для мака)
      font = "JetBrainsMono Nerd Font;Apple Color Emoji;Symbols Nerd Font",
      
      -- Цвета и тема
      background = "#000000",
      theme = "gruvbox-dark",
      
      -- Настройки вывода
      to_clipboard = true,
      output = function()
        return "~/Desktop/code_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".png"
      end,

      -- ДИЗАЙН (Исправлено под новую версию silicon)
      shadow_blur_radius = 10,    -- Было shadow_blur
      shadow_color = "#555555",
      pad_horiz = 20,
      pad_vert = 20,
    },
    config = function(_, opts)
      require("nvim-silicon").setup(opts)
      
      -- Клавиша для скриншота
      vim.keymap.set("v", "<leader>sc", function()
        -- Тихий запуск без лишних варнингов
        pcall(vim.cmd, "Silicon")
      end, { desc = "📸 Скриншот Silicon" })
    end
  }
}

