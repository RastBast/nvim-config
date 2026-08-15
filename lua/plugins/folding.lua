return {
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
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
            curWidth = curWidth + vim.fn.strdisplaywidth(chunkText)
            break
          end
          curWidth = curWidth + chunkWidth
        end
        table.insert(newVirtText, { suffix, "MoreMsg" })
        return newVirtText
      end

      require("ufo").setup({
        fold_virt_text_handler = handler,
        provider_selector = function(bufnr, filetype, buftype)
          return { "lsp", "indent" } -- Сначала пробуем LSP, потом отступы
        end,
      })

      -- ГОРЯЧИЕ КЛАВИШИ (как в IDE)
      vim.keymap.set("n", "zR", require("ufo").openAllFolds, { desc = "Открыть всё" })
      vim.keymap.set("n", "zM", require("ufo").closeAllFolds, { desc = "Свернуть всё" })
      vim.keymap.set("n", "za", "za", { desc = "Переключить блок под курсором" })
    end,
  },
}

