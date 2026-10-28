-- ========================================================================== --
--                       СВОРАЧИВАНИЕ КОДА (nvim-ufo)                          --
-- ========================================================================== --
-- ИСПРАВЛЕНО: ufo не работал вообще, потому что в init.lua стояло
-- foldenable=false + autocmd с `normal! zR` на каждый FileType.
-- Без foldenable сворачиваний не существует — zM/zR/ufo были бесполезны.
-- В init.lua теперь foldenable=true и foldlevel=99 (всё развёрнуто по
-- умолчанию, то есть визуально как раньше).
return {
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      -- Настройки для красивого вида (показывает количество скрытых строк)
      local handler = function(virtText, lnum, endLnum, width, truncate)
        local newVirtText = {}
        local suffix = ("  ⋯ %d lines "):format(endLnum - lnum)
        local targetWidth = width - vim.fn.strdisplaywidth(suffix)
        local curWidth = 0
        for _, chunk in ipairs(virtText) do
          local chunkText = chunk[1]
          local chunkWidth = vim.fn.strdisplaywidth(chunkText)
          if targetWidth > curWidth + chunkWidth then
            table.insert(newVirtText, chunk)
          else
            chunkText = truncate(chunkText, targetWidth - curWidth)
            table.insert(newVirtText, { chunkText, chunk[2] })
            break
          end
          curWidth = curWidth + chunkWidth
        end
        table.insert(newVirtText, { suffix, "MoreMsg" })
        return newVirtText
      end

      require("ufo").setup({
        fold_virt_text_handler = handler,
        provider_selector = function(_bufnr, _filetype, _buftype)
          return { "treesitter", "indent" } -- деревья синтаксиса, потом отступы
        end,
        preview = {
          win_config = { border = "rounded", winhighlight = "Normal:Folded" },
        },
      })

      -- ГОРЯЧИЕ КЛАВИШИ (как в IDE)
      vim.keymap.set("n", "zR", require("ufo").openAllFolds, { desc = "Развернуть всё" })
      vim.keymap.set("n", "zM", require("ufo").closeAllFolds, { desc = "Свернуть всё" })
      vim.keymap.set("n", "zr", require("ufo").openFoldsExceptKinds, { desc = "Развернуть, кроме…" })
      vim.keymap.set("n", "zm", require("ufo").closeFoldsWith, { desc = "Свернуть блоки" })
      -- Предпросмотр свёрнутого кода (как в VS Code при наведении)
      vim.keymap.set("n", "K", function()
        local winid = require("ufo").peekFoldedLinesUnderCursor()
        if not winid then vim.lsp.buf.hover() end
      end, { desc = "Предпросмотр свёрнутого блока" })
      -- Убран бесполезный `vim.keymap.set("n", "za", "za")` — он просто
      -- переназначал za саму на себя.
    end,
  },
}
