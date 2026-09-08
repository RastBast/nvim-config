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

      -- Видна ли inline-подсказка avante.nvim (призрак-текст в буфере)?
      -- Позволяет принимать ИИ-подсказку по <Tab> в общей цепочке:
      -- меню cmp → сниппеты → ИИ-подсказка → обычный Tab.
      local function avante_suggestion_visible()
        local ok, ns = pcall(vim.api.nvim_create_namespace, "avante_suggestion")
        if not ok then
          return false
        end
        return #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) > 0
      end

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
          -- Прыжки по плейсхолдерам сниппетов + принятие ИИ-подсказки
          -- (avante/Gemini): меню cmp → сниппеты → ИИ-подсказка → Tab
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            elseif avante_suggestion_visible() then
              vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes("<Plug>(AvanteSuggestionAccept)", true, false, true),
                "n",
                false
              )
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

      -- ================================================================== --
      --  РУССКИЙ В ОКНЕ ДОКУМЕНТАЦИИ АВТОДОПОЛНЕНИЯ (скрин «Snippet for …») --
      -- ================================================================== --
      -- Через кеш ru_util: переводилось раньше (или в прошлый сеанс) —
      -- сразу русский; первый раз — английский + кеш греется фоном.
      local RU = require("config.ru_util")
      local ok_e, entry_mod = pcall(require, "cmp.entry")
      if ok_e and entry_mod and entry_mod.get_documentation then
        local orig_doc = entry_mod.get_documentation
        entry_mod.get_documentation = function(self)
          local docs = orig_doc(self)
          local text = type(docs) == "table" and table.concat(docs, "\n") or docs
          if type(text) ~= "string" or not text:match("%a%a%a") then
            return docs
          end
          -- весь текст целиком уже переводился
          local tr = RU.translate_cached(text)
          if tr then
            return vim.split(tr, "\n")
          end
          -- код (```-блок с сигнатурой) НЕ переводим: собираем из частей
          local parts = RU.split_md(text)
          local all_cached = true
          for _, p in ipairs(parts) do
            if not p.code and p.text:match("%a%a%a") and not RU.translate_cached(p.text) then
              all_cached = false
              break
            end
          end
          if all_cached and #parts > 1 then
            local out = {}
            for _, p in ipairs(parts) do
              out[#out + 1] = p.code and p.text or (RU.translate_cached(p.text) or p.text)
            end
            return vim.split(table.concat(out, "\n"), "\n")
          end
          -- первый раз: оригинал + греем кеш по частям
          for _, p in ipairs(parts) do
            if not p.code and p.text:match("%a%a%a") then
              RU.translate(p.text, function() end)
            end
          end
          return docs
        end
      end
    end,
  },
}
