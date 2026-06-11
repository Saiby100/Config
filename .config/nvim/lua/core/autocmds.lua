-- Reload files changed outside of Neovim
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  command = "if mode() != 'c' | checktime | endif",
})

-- files.trimTrailingWhitespace + files.trimFinalNewlines
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    local cursor = vim.fn.getpos(".")
    vim.cmd([[silent! %s/\s\+$//e]])
    vim.cmd([[silent! %s/\($\n\s*\)\+\%$//e]])
    vim.fn.setpos(".", cursor)
  end,
})

-- Exit terminal mode with jj or <Esc><Esc> (mirrors insert-mode jj)
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function(ev)
    local opts = { buffer = ev.buf, silent = true }
    vim.keymap.set("t", "jj", [[<C-\><C-n>]], opts)
    vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], opts)
  end,
})

-- files.associations
vim.filetype.add({
  extension = {
    ["yaml.njk"] = "yaml",
    ["html.njk"] = "htmldjango",
  },
  pattern = {
    [".*%.yaml%.njk"] = "yaml",
    [".*%.html%.njk"] = "htmldjango",
  },
})

-- Nunjucks tags ({% ... %}) aren't valid YAML, so yamlls floods *.yaml.njk
-- buffers with parse errors. Hide diagnostics there; completion/hover keep
-- working since the server stays attached.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  pattern = "*.yaml.njk",
  callback = function(ev)
    vim.diagnostic.enable(false, { bufnr = ev.buf })
  end,
})
