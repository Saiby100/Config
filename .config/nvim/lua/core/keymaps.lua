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
-- Switch the window to another buffer *before* deleting, so focus never lands
-- in NvimTree. Otherwise deleting the last editor buffer leaves NvimTree as the
-- only window, which trips the auto-quit autocmd in nvim-tree.lua and closes
-- all of Neovim.
local function close_buffer()
	local cur = vim.api.nvim_get_current_buf()
	local alt = vim.fn.bufnr("#")
	if alt ~= -1 and alt ~= cur and vim.fn.buflisted(alt) == 1 then
		vim.cmd("buffer #")
	else
		vim.cmd("bprevious")
	end
	-- Still on the buffer we're deleting → it was the only one; show the Alpha
	-- dashboard so the window survives with the home page instead of a blank buffer.
	local last_buffer = vim.api.nvim_get_current_buf() == cur
	if last_buffer then
		vim.cmd("enew")
	end
	vim.cmd("bdelete " .. cur)
	if last_buffer then
		require("alpha").start(false)
	end
end
map("n", "<leader>q", close_buffer, opts)

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
-- Y : copy a Claude-friendly file reference to the system clipboard
--   normal mode → @~/abs/path              (e.g. @~/Developer/Config/.../keymaps.lua)
--   visual mode → @~/abs/path L<start>-<end> (e.g. @~/Developer/Config/.../keymaps.lua L94-110)
-- The path is the absolute path with $HOME collapsed to '~' (the :~ modifier).
-- '~' is expanded by Claude's file reader, so the reference resolves from ANY
-- cwd/added directory — unlike a cwd-relative path — while leaking no username
-- and staying portable. The '@' is Claude Code's file-mention syntax: it
-- attaches the file to context up front, no Read round-trip. A space-separated
-- 'L<start>-<end>' suffix scopes the mention to the highlighted lines while
-- keeping the auto-attach, so both forms get the '@' prefix.
-- Overrides the default normal-mode Y (synonym for yy).
-- ------------------------------------------------------------------
local function yank_file_ref(with_range)
	local path = vim.fn.fnamemodify(vim.fn.expand("%:p"), ":~")
	if path == "" then
		vim.notify("No file path for this buffer", vim.log.levels.WARN)
		return
	end
	local ref
	if with_range then
		-- line("v") = visual anchor, line(".") = cursor; read while still in
		-- visual mode (marks '<'> aren't set until the selection is left).
		local a, b = vim.fn.line("v"), vim.fn.line(".")
		if a > b then a, b = b, a end
		ref = string.format("@%s L%d-%d", path, a, b)
	else
		ref = "@" .. path
	end
	vim.fn.setreg("+", ref)
	vim.notify("Copied " .. ref)
end

map("n", "Y", function() yank_file_ref(false) end, opts)
map("x", "Y", function()
	yank_file_ref(true)
	-- leave visual mode, matching the feel of a normal yank
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end, opts)

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
