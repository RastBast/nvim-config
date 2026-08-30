-- ========================================================================== --
--                            TOGGLETERM                                      --
-- ========================================================================== --
-- ИСПРАВЛЕНО В ЭТОЙ РЕВИЗИИ:
--  1) E492 «Not an editor command: ToggleTerm» — плагин грузился лениво
--     (только через keys), а команды терминала вызывались ещё и из which-key
--     набором <leader>HT*, про который lazy не знал → команда исполнялась
--     ДО загрузки плагина. Теперь lazy = false: toggleterm загружается при
--     старте, и :ToggleTerm / :ToggleTermToggleAll существуют всегда,
--     хоть с клавиш, хоть вручную из командной строки.
--  2) Дублирующий набор <leader>HT* удалён из which-key.lua — терминал
--     живёт только на <leader>T* (и <C-\>).
--  3) Вместо skanehira/docker.vim (он НЕ поддерживает Neovim и всегда падает
--     с «please use vim...») Docker живёт здесь же: lazydocker и docker CLI
--     в маленьком плавающем окне — <leader>dc / dp / di / dn.
--     Подсветка Dockerfile — ekalinin/Dockerfile.vim (см. docker-cli.lua).
--  4) shade_terminals выключен: терминал больше не тонируется в странный
--     цвет («зелёная панель») и выглядит как обычный fish в alacritty.

local function docker_term(cmd, id, title)
  return function()
    local bin = cmd:match("^(%S+)")
    if vim.fn.executable(bin) == 0 then
      vim.notify(
        ("Команда «%s» не найдена в PATH.\nПоставь: lazydocker — https://github.com/jesseduffield/lazydocker\n(или пакетным менеджером: brew / apt / yay / nix)"):format(bin),
        vim.log.levels.WARN
      )
      return
    end
    local Terminal = require("toggleterm.terminal").Terminal
    Terminal:new({
      cmd = cmd,
      direction = "float",
      id = id,
      name = title,
      close_on_exit = true,
      float_opts = {
        border = "curved",
        width = math.floor(vim.o.columns * 0.85),
        height = math.floor(vim.o.lines * 0.8),
      },
    }):toggle()
  end
end

return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    lazy = false, -- грузим при старте: команды терминала должны быть всегда
    keys = {
      { "<c-\\>", desc = "📟 Переключить терминал" },
      { "<leader>Tt", "<cmd>ToggleTerm direction=float<cr>", desc = "📟 Плавающий терминал" },
      { "<leader>Th", "<cmd>ToggleTerm direction=horizontal size=15<cr>", desc = "📟 Терминал снизу" },
      { "<leader>Tv", "<cmd>ToggleTerm direction=vertical size=60<cr>", desc = "📟 Терминал справа" },
      { "<leader>Ta", "<cmd>ToggleTermToggleAll<cr>", desc = "❎ Показать/скрыть все терминалы" },
      -- 🐳 Docker в маленьком окне (вместо мёртвого docker.vim)
      { "<leader>dc", docker_term("lazydocker", 100, "docker"), desc = "🐳 Docker: lazydocker (TUI)" },
      { "<leader>dp", docker_term("docker ps -a", 101, "docker ps"), desc = "🐳 Docker: контейнеры" },
      { "<leader>di", docker_term("docker images", 102, "docker images"), desc = "🐳 Docker: образы" },
      { "<leader>dn", docker_term("docker network ls", 103, "docker networks"), desc = "🐳 Docker: сети" },
    },
    config = function()
      require("toggleterm").setup({
        size = function(term)
          if term.direction == "horizontal" then return 15 end
          if term.direction == "vertical" then return math.floor(vim.o.columns * 0.4) end
          return 20
        end,
        open_mapping = [[<c-\>]],   -- <C-\> открывает/переключает терминал
        hide_numbers = true,        -- скрыть номера строк в терминале
        shade_terminals = false,    -- НЕ тонировать фон (fish выглядит как в alacritty)
        start_in_insert = true,
        insert_mappings = true,
        terminal_mappings = true,
        persist_size = true,
        direction = "float",
        close_on_exit = true,
        shell = vim.o.shell,        -- твой fish
        float_opts = {
          border = "curved",
          width = math.floor(vim.o.columns * 0.8),
          height = math.floor(vim.o.lines * 0.6),
          winblend = 10,
        },
      })

      local map = vim.keymap.set

      -- Отправить текущую строку / визуальный блок в активный терминал
      map("n", "<leader>Tl", "<cmd>ToggleTermSendCurrentLine<CR>", { desc = "➡ Строку в терминал" })
      map("v", "<leader>Tl", "<cmd>ToggleTermSendVisualSelection<CR>", { desc = "➡ Выделение в терминал" })

      -- Быстрый git status в отдельном терминале
      map("n", "<leader>Tg", function()
        require("toggleterm").exec("git status", 9)
      end, { desc = "🌿 git status" })

      -- Ленивый git — прямо в терминале toggleterm
      map("n", "<leader>TG", function()
        require("toggleterm").exec("lazygit", 10)
      end, { desc = "🌿 lazygit в терминале" })
    end,
  },
}
