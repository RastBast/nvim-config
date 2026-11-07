-- ========================================================================== --
--                       LSP: MASON + NVIM-LSPCONFIG                          --
-- ========================================================================== --
-- ИСПРАВЛЕНО:
--  1) В ensure_installed стояли gopls/ts_ls/bashls/dotls/lemminx/html/cssls,
--     но через vim.lsp.enable() включались только ts_ls, bashls, dotls и gopls.
--     То есть dotls/lemminx/html/cssls скачивались Mason'ом и НИКОГДА не
--     запускались. Теперь список один и он же включается.
--  2) require("cmp_nvim_lsp") падал, если nvim-cmp ещё не загрузился —
--     добавлена явная зависимость и pcall.
--  3) renamer.nvim (lua/plugins/renamer.lua) удалён: он заброшен, а
--     переименование делает встроенный vim.lsp.buf.rename() (Neovim 0.11+)
--     через snacks.picker (picker.ui_select в snacks.lua). Клавиши те же.
return {
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    opts = {
      ui = { border = "rounded" },
    },
  },

  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim" },
    event = { "BufReadPre", "BufNewFile" },
    opts = function()
      local servers = require("config.servers")
      return {
        ensure_installed = servers.mason,
        -- toolchain-серверы (Dart, Xcode, R…) Mason не ставит и не включает сам.
        -- В зафиксированной версии (lazy-lock.json) опция называется automatic_enable;
        -- старое automatic_installation там не поддерживается.
        automatic_enable = { exclude = servers.toolchain },
      }
    end,
  },

  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "mason-org/mason-lspconfig.nvim",
    },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
      local capabilities = ok and cmp_lsp.default_capabilities() or vim.lsp.protocol.make_client_capabilities()

      local servers = require("config.servers").all
      local custom = {
        gopls = {
          settings = {
            gopls = {
              completeUnimported = true,
              usePlaceholders = true,
              analyses = {
                unusedparams = true, unusedvariable = true, nilness = true,
                shadow = true, unusedwrite = true,
              },
              staticcheck = true,
              gofumpt = true,
              hoverKind = "FullDocumentation",
              semanticTokens = true,
              -- «▶ run test | debug test» и генерация над функциями, как в VS Code
              codelenses = {
                generate = true, gc_details = false, regenerate_cgo = true,
                run_govulncheck = true, test = true, tidy = true,
                upgrade_dependency = true, vendor = true,
              },
              -- inlay hints: включаются <leader>uh или <leader>gh (по умолчанию выключены)
              hints = {
                assignVariableTypes = true, compositeLiteralFields = true,
                compositeLiteralTypes = true, constantValues = true,
                functionTypeParameters = true, parameterNames = true,
                rangeVariableTypes = true,
              },
            },
          },
        },
        lua_ls = {
          settings = {
            Lua = {
              workspace = { checkThirdParty = false },
              diagnostics = { globals = { "vim" } },
              telemetry = { enable = false },
            },
          },
        },
      }

      -- Новый интерфейс Neovim 0.11+ (vim.lsp.config + vim.lsp.enable)
      local enabled = {}
      for _, name in ipairs(servers) do
        local cfg = vim.deepcopy(custom[name] or {})
        cfg.capabilities = capabilities
        vim.lsp.config(name, cfg)
        if name ~= "nil_ls" or vim.fn.executable("nil") == 1 then
          enabled[#enabled + 1] = name
        end
      end
      vim.lsp.enable(enabled)

      -- nil_ls не ставится Mason автоматически (пакет `nil` требует cargo).
      -- Если открыт .nix-файл, а бинарника `nil` нет — показываем короткую подсказку
      -- без спама и без аварийного падения LSP; если `nil` уже поставлен — включаем.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("UserNixLspHint", { clear = true }),
        pattern = "nix",
        once = true,
        callback = function()
          if vim.fn.executable("nil") == 1 then
            vim.lsp.enable("nil_ls")
            return
          end
          vim.schedule(function()
            if vim.fn.executable("nil") == 1 then return end
            vim.api.nvim_echo({ {
              "Nix LSP: бинарник `nil` не найден в PATH. Установи: brew install nil  или  nix profile install nixpkgs#nil (:EnvCheck)",
              "WarningMsg",
            } }, true, {})
          end)
        end,
      })

      -- Клавиши включаются при подключении сервера (а не глобально)
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspKeymaps", { clear = true }),
        callback = function(ev)
          local map = function(lhs, fn, desc, mode)
            vim.keymap.set(mode or { "n", "v" }, lhs, fn, { buffer = ev.buf, desc = desc })
          end
          map("K", vim.lsp.buf.hover, "📖 Документация", "n")
          map("<leader>ca", vim.lsp.buf.code_action, "💡 Действия кода")
          map("gd", vim.lsp.buf.definition, "🎯 К определению", "n")
          map("gD", vim.lsp.buf.declaration, "📌 К декларации", "n")
          map("gr", vim.lsp.buf.references, "🔗 Все ссылки", "n")
          map("gi", vim.lsp.buf.implementation, "🧩 К реализации", "n")
          map("<leader>rn", vim.lsp.buf.rename, "✏️ Переименовать", "n")
          map("<F2>", vim.lsp.buf.rename, "✏️ Переименовать", { "n", "i" })
          map("<leader>f", function() vim.lsp.buf.format({ async = true }) end, "🎨 Формат (LSP)")
          map("[d", function() vim.diagnostic.jump({ count = -1 }) end, "⬆ Пред. ошибка", "n")
          map("]d", function() vim.diagnostic.jump({ count = 1 }) end, "⬇ След. ошибка", "n")
          map("<leader>d", vim.diagnostic.open_float, "🩺 Диагностика строки", "n")

          -- Инлайновые подсказки (серые «a...:», «int», «[]int») НЕ включаем здесь:
          -- они выключены по умолчанию. Включить: <leader>uh, для Go также <leader>gh.
        end,
      })
    end,
  },

  -- Lua LSP специально для правки этого конфига (lazydev) — НОВОЕ
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "luvit-meta/library", words = { "vim%.uv" } },
        "lazy",
        "snacks",
      },
    },
  },
  { "Bilal2453/luvit-meta", lazy = true },
}
