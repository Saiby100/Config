-- Leader
vim.g.mapleader = " "

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- ------------------------------------------------------------------
-- Window switching (ctrl+h/j/k/l) — matches VS Code navigateLeft/etc
-- ------------------------------------------------------------------
map("n", "<C-h>", "<C-w>h", opts)
map("n", "<C-l>", "<C-w>l", opts)
map("n", "<C-k>", "<C-w>k", opts)
map("n", "<C-j>", "<C-w>j", opts)

-- Insert-mode cursor movement (ctrl+h/j/k/l)
map("i", "<C-h>", "<Left>", opts)
map("i", "<C-l>", "<Right>", opts)
map("i", "<C-k>", "<Up>", opts)
map("i", "<C-j>", "<Down>", opts)

-- Split screen
map("n", "<leader>S", ":vsp<CR>", opts)

-- Prevent pasted-over text from replacing the register (vim.visualModeKeyBindings p→P)
map("x", "p", '"_dP', opts)

-- ------------------------------------------------------------------
-- VS Code vim insertModeKeyBindings
-- ------------------------------------------------------------------
map("i", "jj", "<Esc>", opts)

-- ------------------------------------------------------------------
-- VS Code vim visualModeKeyBindings
-- ------------------------------------------------------------------
map("v", ">", ">gv", opts)          -- reselect after indent
map("v", "<", "<gv", opts)
map("v", "<leader>s", ":sort<CR>", opts)

-- ------------------------------------------------------------------
-- VS Code vim normalModeKeyBindingsNonRecursive
-- ------------------------------------------------------------------
map("n", "<C-n>", ":nohlsearch<CR>", opts)                    -- clear search highlight
map("n", "<leader>d", vim.lsp.buf.definition, opts)           -- revealDefinition

-- ------------------------------------------------------------------
-- VS Code keybindings.json (non-vim) — ported to buffers/windows
-- ------------------------------------------------------------------
-- alt+h/l : prev/next editor  →  next/prev buffer
map("n", "<A-l>", ":bnext<CR>", opts)
map("n", "<A-h>", ":bprevious<CR>", opts)

-- <leader>q : close active editor  →  delete buffer
-- (Ctrl+q is taken by tmux's kill-pane binding, so it never reaches Neovim.)
map("n", "<leader>q", ":bdelete<CR>", opts)

-- alt+j/k : scrollLineDown / scrollLineUp
map({ "n", "v" }, "<A-j>", "<C-e>", opts)
map({ "n", "v" }, "<A-k>", "<C-y>", opts)

-- shift+alt+k/j : increase/decrease view size (height)
map("n", "<A-S-k>", ":resize +2<CR>", opts)
map("n", "<A-S-j>", ":resize -2<CR>", opts)

-- alt+shift+h/l : resize pane left/right (width)
map("n", "<A-S-h>", ":vertical resize -5<CR>", opts)
map("n", "<A-S-l>", ":vertical resize +5<CR>", opts)

-- Toggle tmux pane zoom
map("n", "<leader>m", function() vim.fn.system("tmux resize-pane -Z") end, opts)

-- ------------------------------------------------------------------
-- Toggle comment with Ctrl+/ (VS Code editor.action.commentLine)
-- Uses Neovim's built-in commenter (gcc/gc). Terminals send Ctrl+/ as
-- 0x1f (<C-_>); newer Neovim also recognizes <C-/>, so bind both.
-- ------------------------------------------------------------------
local comment_opts = { remap = true, silent = true }
for _, key in ipairs({ "<C-_>", "<C-/>" }) do
	map("n", key, "gcc", comment_opts)               -- current line
	map("x", key, "gc", comment_opts)                -- selection
	map("i", key, "<Esc>gccA", comment_opts)         -- current line, stay in insert
end
