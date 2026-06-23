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

-- Re-equalize splits when the outer window resizes (e.g. resizing a tmux
-- pane). Neovim absorbs the size change into one split instead of scaling
-- them proportionally, so splits look "stuck" without this.
vim.api.nvim_create_autocmd("VimResized", {
  command = "tabdo wincmd =",
})

-- Exit terminal mode with <Esc><Esc>
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function(ev)
    local opts = { buffer = ev.buf, silent = true }
    vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], opts)
  end,
})

-- Mirror tmux's active-pane background tint inside Neovim. tmux sets
-- window-active-style "bg=#283040" (.tmux.conf), but that can't show through
-- here because Neovim paints its own background over every cell. So react to
-- the forwarded focus events (focus-events on) and retint ourselves.
local active_bg = "#283040" -- tmux window-active-style
local inactive_bg = "#282c34" -- onedark "dark" default background
local function set_pane_bg(color)
  for _, group in ipairs({ "Normal", "NormalNC", "SignColumn", "LineNr", "EndOfBuffer" }) do
    local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
    hl.bg = color
    vim.api.nvim_set_hl(0, group, hl)
  end
end
vim.api.nvim_create_autocmd({ "FocusGained", "VimEnter" }, {
  callback = function()
    set_pane_bg(active_bg)
  end,
})
vim.api.nvim_create_autocmd("FocusLost", {
  callback = function()
    set_pane_bg(inactive_bg)
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
