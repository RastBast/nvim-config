-- ========================================================================== --
--                 ЯЗЫКИ: ОДИН СПИСОК ДЛЯ LSP, TREESITTER, ФОРМАТТЕРОВ          --
-- ========================================================================== --
-- Каждая запись — один язык (≈40 штук). Из этого списка берут:
--   servers.lua    → LSP-серверы (Mason ставит только поле `lsp`)
--   treesitter.lua → парсеры подсветки (ensure_installed)
--   format.lua     → форматтеры conform по filetype
--
-- Поля:
--   ft         filetype Neovim (LaTeX = "tex", C# = "cs" в lspconfig, Terraform = "terraform")
--   parser     парсер nvim-treesitter (ставится автоматически)
--   lsp        LSP-серверы, которые ставит Mason
--   toolchain  LSP, которому нужен системный тулчейн (Dart SDK, Xcode, R, Julia,
--              OCaml/opam, Haskell/ghcup, .NET, Groovy). Включается, если бинарник
--              уже есть в PATH; Mason такие серверы НЕ ставит (иначе ошибка при старте).
--   fmt        форматтеры conform. Если бинарника нет — conform молча откатывается
--              на LSP-форматирование (lsp_format = "fallback"), ничего не ломается.
--
-- Go, Lua, JS/TS, bash, JSON/YAML, HTML/CSS, SQL, Docker, proto, XML, Graphviz,
-- Markdown — уже были в конфиге и сохранены здесь.
local M = {}

M.list = {
  -- ───────── уже были в конфиге ─────────
  { ft = "go", parser = "go", lsp = { "gopls" }, fmt = {} },
  { ft = "lua", parser = "lua", lsp = { "lua_ls" }, fmt = { "stylua" } },
  { ft = "javascript", parser = "javascript", lsp = { "ts_ls" }, fmt = { "prettier" } },
  { ft = "typescript", parser = "typescript", lsp = { "ts_ls" }, fmt = { "prettier" } },
  { ft = "sh", parser = "bash", lsp = { "bashls" }, fmt = { "shfmt" } },
  { ft = "json", parser = "json", lsp = { "jsonls" }, fmt = { "prettier" } },
  { ft = "yaml", parser = "yaml", lsp = { "yamlls" }, fmt = { "prettier" } },
  { ft = "html", parser = "html", lsp = { "html" }, fmt = { "prettier" } },
  { ft = "css", parser = "css", lsp = { "cssls" }, fmt = { "prettier" } },
  { ft = "sql", parser = "sql", lsp = { "sqls" }, fmt = { "sqlfluff" } },
  { ft = "dockerfile", parser = "dockerfile", lsp = { "dockerls" }, fmt = {} },
  { ft = "proto", parser = "proto", lsp = { "protols" }, fmt = { "buf" } },
  { ft = "xml", parser = "xml", lsp = { "lemminx" }, fmt = { "xmlformat" } },
  { ft = "dot", parser = "dot", lsp = { "dotls" }, fmt = {} },
  { ft = "markdown", parser = "markdown", lsp = { "marksman" }, fmt = { "prettier" } },

  -- ───────── новые: популярные ЯП ─────────
  { ft = "python", parser = "python", lsp = { "pyright", "ruff" }, fmt = { "ruff_format" } },
  { ft = "rust", parser = "rust", lsp = { "rust_analyzer" }, fmt = { "rustfmt" } },
  { ft = "c", parser = "c", lsp = { "clangd" }, fmt = { "clang-format" } },
  { ft = "cpp", parser = "cpp", lsp = { "clangd" }, fmt = { "clang-format" } },
  { ft = "java", parser = "java", lsp = { "jdtls" }, fmt = { "google-java-format" } },
  { ft = "kotlin", parser = "kotlin", lsp = { "kotlin_language_server" }, fmt = { "ktlint" } },
  -- metals нет в реестре Mason: ставится через coursier (cs install metals), поэтому toolchain
  { ft = "scala", parser = "scala", toolchain = { "metals" }, fmt = { "scalafmt" } },
  { ft = "cs", parser = "c_sharp", toolchain = { "csharp_ls" }, fmt = { "csharpier" } },
  { ft = "ruby", parser = "ruby", lsp = { "ruby_lsp" }, fmt = { "rubocop" } },
  { ft = "php", parser = "php", lsp = { "intelephense" }, fmt = { "php_cs_fixer" } },
  { ft = "swift", parser = "swift", toolchain = { "sourcekit" }, fmt = { "swiftformat" } },
  { ft = "dart", parser = "dart", toolchain = { "dartls" }, fmt = { "dart_format" } },
  { ft = "elixir", parser = "elixir", lsp = { "elixirls" }, fmt = { "mix" } },
  { ft = "haskell", parser = "haskell", toolchain = { "hls" }, fmt = { "ormolu" } },
  { ft = "ocaml", parser = "ocaml", toolchain = { "ocamllsp" }, fmt = { "ocamlformat" } },
  { ft = "zig", parser = "zig", lsp = { "zls" }, fmt = { "zigfmt" } },
  { ft = "r", parser = "r", toolchain = { "r_language_server" }, fmt = { "styler" } },
  { ft = "julia", parser = "julia", toolchain = { "julials" }, fmt = { "runic" } },
  { ft = "terraform", parser = "terraform", lsp = { "terraformls" }, fmt = { "terraform_fmt" } },
  -- nil собирается в Mason из исходников через cargo: используем установленный системно nil.
  { ft = "nix", parser = "nix", toolchain = { "nil_ls" }, fmt = { "nixfmt" } },
  { ft = "vue", parser = "vue", lsp = { "vue_ls" }, fmt = { "prettier" } },
  { ft = "svelte", parser = "svelte", lsp = { "svelte" }, fmt = { "prettier" } },
  { ft = "graphql", parser = "graphql", lsp = { "graphql" }, fmt = { "prettier" } },
  { ft = "toml", parser = "toml", lsp = { "taplo" }, fmt = { "taplo" } },
  { ft = "tex", parser = "latex", lsp = { "texlab" }, fmt = { "latexindent" } },
  { ft = "typst", parser = "typst", lsp = { "tinymist" }, fmt = { "typstyle" } },
  { ft = "clojure", parser = "clojure", lsp = { "clojure_lsp" }, fmt = { "cljfmt" } },
  { ft = "perl", parser = "perl", lsp = { "perlnavigator" }, fmt = { "perltidy" } },
  -- LSP: neocmake (neocmakelsp, готовый бинарник из GitHub). Не cmake-language-server:
  -- он на PyPI и поддерживает только Python < 3.14, поэтому Mason падал на новом Python.
  { ft = "cmake", parser = "cmake", lsp = { "neocmake" }, fmt = { "cmake_format" } },
  { ft = "groovy", parser = "groovy", toolchain = { "groovyls" }, fmt = {} },
}

local function add_unique(out, seen, names)
  for _, name in ipairs(names or {}) do
    if not seen[name] then
      seen[name] = true
      out[#out + 1] = name
    end
  end
end

--- LSP, которые Mason установит сам.
function M.mason_servers()
  local out, seen = {}, {}
  for _, l in ipairs(M.list) do add_unique(out, seen, l.lsp) end
  return out
end

--- LSP, которым нужен системный тулчейн (Mason их не трогает).
function M.toolchain_servers()
  local out, seen = {}, {}
  for _, l in ipairs(M.list) do add_unique(out, seen, l.toolchain) end
  return out
end

--- Все LSP-серверы (для vim.lsp.enable).
function M.servers()
  local out, seen = {}, {}
  for _, l in ipairs(M.list) do
    add_unique(out, seen, l.lsp)
    add_unique(out, seen, l.toolchain)
  end
  return out
end

--- Парсеры Treesitter.
function M.parsers()
  local out, seen = {}, {}
  for _, l in ipairs(M.list) do add_unique(out, seen, { l.parser }) end
  return out
end

--- Форматтеры conform: { [filetype] = { "formatter", ... } }.
function M.formatters()
  local out = {}
  for _, l in ipairs(M.list) do
    if l.fmt and #l.fmt > 0 then out[l.ft] = l.fmt end
  end
  return out
end

return M
