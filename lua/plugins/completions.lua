-- ========================================================================== --
--                    АВТОДОПОЛНЕНИЕ (nvim-cmp + LuaSnip)                     --
-- ========================================================================== --
-- ИСПРАВЛЕНО / ДОБАВЛЕНО:
--  * <C-n>/<C-p> для навигации по списку — раньше выбор работал только
--    через <CR>, а по списку ходить было нечем.
--  * <Tab>/<S-Tab> для прыжков по плейсхолдерам сниппетов.
--  * rafamadriz/friendly-snippets — готовые сниппеты (НОВОЕ).
--  * Источник vim-dadbod-completion объявлен как зависимость, иначе cmp
--    ругался "source not found" в sql-файлах.
return {
  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
      "kristijanhusak/vim-dadbod-completion",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      -- Подгружаем готовые сниппеты (friendly-snippets)
      pcall(require("luasnip.loaders.from_vscode").lazy_load)

      -- ================================================================== --
      --  🧊 Сниппеты Protobuf/gRPC (ft=proto): hdr/svc/msg/rpc/enum/opt     --
      -- ================================================================== --
      local s, t, i = luasnip.snippet, luasnip.text_node, luasnip.insert_node
      luasnip.add_snippets("proto", {
        s("hdr", { -- каркас нового .proto
          t({ 'syntax = "proto3";', "", "package " }), i(1, "app.v1"),
          t({ "", "", 'option go_package = "' }), i(2, "github.com/org/repo/gen/go/app/v1;appv1"),
          t({ '";', "" }),
        }),
        s("svc", { -- сервис с одним rpc
          t("service "), i(1, "UserService"), t({ " {", "  rpc " }), i(2, "GetUser"),
          t("("), i(3, "GetUserRequest"), t(") returns ("), i(4, "GetUserResponse"),
          t({ ");", "}" }),
        }),
        s("msg", { t("message "), i(1, "User"), t({ " {", "  " }), i(2, "string id = 1;"), t({ "", "}" }) }),
        s("rpc", { t("rpc "), i(1, "Method"), t("("), i(2, "Req"), t(") returns ("), i(3, "Resp"), t(");") }),
        s("enum", { t("enum "), i(1, "Status"), t({ " {", "  " }), i(2, "STATUS_UNSPECIFIED = 0;"), t({ "", "}" }) }),
        s("opt", { t('option go_package = "'), i(1, "gen/go/app/v1"), t('";') }),
      })

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        completion = { completeopt = "menu,menuone,noinsert" },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
          ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
          -- Прыжки по плейсхолдерам сниппетов
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 1000 },
          { name = "luasnip", priority = 750 },
          { name = "path", priority = 500 },
        }, {
          { name = "buffer", priority = 250 },
        }),
      })

      -- Автодополнение команд Neovim в cmdline
      cmp.setup.cmdline({ ":", "/" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
      })
    end,
  },
}
