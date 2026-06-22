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
-- <leader>gg : toggle lazygit in a floating terminal
-- Runs lazygit *inside* this Neovim session (the long-lived host) instead of
-- the other way around, so the editor session is never lost. Hiding the window
-- (rather than killing the buffer) keeps the lazygit process running, so
-- reopening lands on the exact same state. When lazygit is launched from here,
-- Neovim sets $NVIM; the lazygit config pins `os.editPreset: nvim-remote`, which
-- routes its `e` (edit) command through `nvim --server $NVIM --remote` — files
-- open as buffers in THIS session, not a nested nvim. (Pinning is required: left
-- to auto-detect, lazygit picks the plain `nvim` preset from $EDITOR and nests.
-- The preset's built-in fallback keeps the shell `lg` alias working standalone.)
-- ------------------------------------------------------------------
local lazygit = { buf = -1, win = -1 }

-- Geometry for the float, recomputed from the *current* editor size. Shared by
-- the initial open and the VimResized handler so the two never drift.
local function lazygit_geometry()
	local w = math.floor(vim.o.columns * 0.9)
	local h = math.floor(vim.o.lines * 0.9)
	return {
		relative = "editor",
		width = w,
		height = h,
		col = math.floor((vim.o.columns - w) / 2),
		row = math.floor((vim.o.lines - h) / 2),
	}
end

local function lazygit_float(buf)
	local cfg = lazygit_geometry()
	cfg.style = "minimal"
	cfg.border = "rounded"
	return vim.api.nvim_open_win(buf, true, cfg)
end

-- Resize the float to match the editor whenever the host is resized (e.g.
-- resizing the tmux/terminal pane fires VimResized). Without this the float
-- keeps the dimensions it was opened with and stays small after a grow.
vim.api.nvim_create_autocmd("VimResized", {
	callback = function()
		if vim.api.nvim_win_is_valid(lazygit.win) then
			vim.api.nvim_win_set_config(lazygit.win, lazygit_geometry())
		end
	end,
})

local function toggle_lazygit()
	if vim.api.nvim_win_is_valid(lazygit.win) then
		vim.api.nvim_win_hide(lazygit.win) -- hide, keep lazygit running
		lazygit.win = -1
		return
	end
	if vim.api.nvim_buf_is_valid(lazygit.buf) then
		lazygit.win = lazygit_float(lazygit.buf) -- reopen existing session
	else
		lazygit.buf = vim.api.nvim_create_buf(false, true)
		lazygit.win = lazygit_float(lazygit.buf)
		vim.fn.jobstart("lazygit", {
			term = true,
			on_exit = function()
				-- Close the float *before* deleting its buffer. Deleting the
				-- buffer alone doesn't reliably tear down the window — Neovim
				-- often swaps in a fresh empty buffer to keep the window alive,
				-- leaving a blank float hovering over the editor.
				if vim.api.nvim_win_is_valid(lazygit.win) then
					vim.api.nvim_win_close(lazygit.win, true)
				end
				if vim.api.nvim_buf_is_valid(lazygit.buf) then
					vim.api.nvim_buf_delete(lazygit.buf, { force = true })
				end
				lazygit.buf, lazygit.win = -1, -1
			end,
		})
		-- Re-enter terminal mode whenever focus lands on the lazygit buffer, so
		-- every key (incl. j/k) is sent to lazygit instead of moving Neovim's
		-- cursor in terminal-normal mode. Scoped to this buffer only.
		vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
			buffer = lazygit.buf,
			callback = function()
				if vim.api.nvim_get_current_buf() == lazygit.buf then
					vim.cmd("startinsert")
				end
			end,
		})
		-- lazygit uses <Esc> to close popups/inputs, so drop the shell-terminal
		-- <Esc><Esc> escape map (set in autocmds.lua's TermOpen) for this buffer
		-- — otherwise Esc gets swallowed/exits terminal mode instead. Deferred
		-- so it runs after TermOpen has installed the map.
		vim.schedule(function()
			pcall(vim.keymap.del, "t", "<Esc><Esc>", { buffer = lazygit.buf })
		end)
		-- Restore tmux pane navigation from inside the float. The buffer sits in
		-- terminal-insert mode (above), where the global normal-mode
		-- <C-h/j/k/l> → TmuxNavigate maps don't apply — so the keys would
		-- otherwise be swallowed by lazygit. The float is fullscreen with no
		-- nvim splits to move between, so switch the tmux pane directly rather
		-- than via TmuxNavigate (whose wincmd logic would drop focus into the
		-- editor behind the float). No-op when nvim runs outside tmux.
		for key, dir in pairs({ ["<C-h>"] = "L", ["<C-j>"] = "D", ["<C-k>"] = "U", ["<C-l>"] = "R" }) do
			vim.keymap.set("t", key, function()
				if vim.env.TMUX then
					vim.fn.system("tmux select-pane -" .. dir)
				end
			end, { buffer = lazygit.buf, desc = "Navigate tmux pane " .. dir })
		end
	end
	-- Schedule the initial enter: on first open the terminal isn't attached yet
	-- in this tick, so startinsert would no-op without the defer.
	vim.schedule(function()
		if vim.api.nvim_win_is_valid(lazygit.win) then
			vim.api.nvim_set_current_win(lazygit.win)
			vim.cmd("startinsert")
		end
	end)
end

map("n", "<leader>gg", toggle_lazygit, { desc = "Toggle lazygit" })

-- ------------------------------------------------------------------
-- Fixup for lazygit's `e` (see lazygit/config.yml). lazygit runs in the float,
-- so the float is nvim's *current* window when its `--remote {{filename}}` edit
-- arrives — the file gets dropped into the cramped, minimal-style float instead
-- of the editor. lazygit then calls this via `--remote-expr`: the float now
-- shows the just-opened file, so we grab that buffer, restore the lazygit
-- terminal into the float and hide it (keeping lazygit running, ready to
-- reopen), then show the file in whatever real window we land on — so it opens
-- like a normal buffer and joins the buffer list (telescope, :ls, etc.).
-- Scheduled so the window work runs outside the --remote-expr eval context.
-- ------------------------------------------------------------------
function _G._lazygit_fixup(line)
	vim.schedule(function()
		local win = lazygit.win
		if not vim.api.nvim_win_is_valid(win) then
			return
		end
		local file_buf = vim.api.nvim_win_get_buf(win)
		-- The float swapped to the file buffer; put the lazygit terminal back so
		-- reopening the float lands on lazygit, not this file.
		if vim.api.nvim_buf_is_valid(lazygit.buf) then
			vim.api.nvim_win_set_buf(win, lazygit.buf)
		end
		vim.api.nvim_win_hide(win) -- hide, keep lazygit running
		lazygit.win = -1
		vim.api.nvim_set_current_buf(file_buf) -- show the file in a real window
		if line and line > 0 then
			pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
		end
	end)
end

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
