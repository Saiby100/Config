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

-- Prevent pasted-over text from replacing the register.
-- In Neovim, visual-mode P pastes over the selection without clobbering the
-- register. (The old "_dP trick broke at end-of-line: deleting the selection
-- moved the cursor onto the previous char, so P pasted in the wrong place.)
map("x", "p", "P", opts)

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
-- '~' is expanded by Claude's file reader, so the reference resolves from ANY
-- cwd — unlike a cwd-relative path — while leaking no username. The '@' is
-- Claude Code's file-mention syntax: it attaches the file to context up front,
-- no Read round-trip. Overrides the default normal-mode Y (synonym for yy).
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
-- Runs lazygit *inside* this Neovim session instead of the other way around,
-- so the editor session is never lost. Hiding the window (rather than killing
-- the buffer) keeps the lazygit process running, so reopening lands on the
-- exact same state. Neovim sets $NVIM when it launches lazygit; the lazygit
-- config pins `os.editPreset: nvim-remote` so its `e` opens files as buffers in
-- THIS session rather than a nested nvim (left to auto-detect it picks the
-- plain `nvim` preset from $EDITOR and nests).
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

-- Directory to launch lazygit in. Normally nil (inherit nvim's cwd), but when
-- the cwd isn't inside a git repo, fall back to the most recent repo from
-- lazygit's own state file. Started outside a repo, lazygit either prompts or
-- — even with `skip` — force-opens the recent-repos menu on top.
local function lazygit_cwd()
	if vim.fs.root(vim.fn.getcwd(), ".git") then
		return nil
	end
	local state = vim.fn.expand("~/Library/Application Support/lazygit/state.yml")
	local in_recents = false
	for _, line in ipairs(vim.fn.filereadable(state) == 1 and vim.fn.readfile(state) or {}) do
		if in_recents then
			local repo = line:match("^%s*-%s*(.-)%s*$")
			if not repo then
				break -- past the recentrepos list
			end
			if vim.fn.isdirectory(repo .. "/.git") == 1 or vim.fn.filereadable(repo .. "/.git") == 1 then
				return repo
			end
		elseif line:match("^recentrepos:") then
			in_recents = true
		end
	end
	return nil -- no usable recent repo; let lazygit handle it
end

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
			cwd = lazygit_cwd(),
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
		-- Restore tmux pane navigation from inside the float: the buffer sits in
		-- terminal-insert mode, where the global <C-h/j/k/l> maps don't apply. The
		-- float is fullscreen with no splits to move between, so switch the tmux
		-- pane directly rather than via TmuxNavigate (whose wincmd logic would drop
		-- focus into the editor behind the float). No-op outside tmux.
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
-- arrives, and the file lands in the cramped float. lazygit then calls this via
-- `--remote-expr`: grab the just-opened buffer, restore the lazygit terminal
-- into the float and hide it, then show the file in a real window so it joins
-- the buffer list. Scheduled to run outside the --remote-expr eval context.
-- ------------------------------------------------------------------
function _G._lazygit_fixup(line)
	vim.schedule(function()
		local win = lazygit.win
		if not vim.api.nvim_win_is_valid(win) then
			return
		end
		local file_buf = vim.api.nvim_win_get_buf(win)
		-- `--remote` uses :drop semantics: if the file was *already* open in a real
		-- window it jumps there and never touches the float, so the buffer we just
		-- read is lazygit's own terminal. Only re-home the buffer when the float
		-- actually got hijacked — otherwise we'd display the terminal in the editor.
		local hijacked = file_buf ~= lazygit.buf
		-- The float swapped to the file buffer; put the lazygit terminal back so
		-- reopening the float lands on lazygit, not this file.
		if hijacked and vim.api.nvim_buf_is_valid(lazygit.buf) then
			vim.api.nvim_win_set_buf(win, lazygit.buf)
		end
		vim.api.nvim_win_hide(win) -- hide, keep lazygit running
		lazygit.win = -1
		if hijacked then
			vim.api.nvim_set_current_buf(file_buf) -- show the file in a real window
		end
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
