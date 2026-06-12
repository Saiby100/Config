return {
	-- Talks to the Claude Code CLI over the same WebSocket/MCP protocol the
	-- official VS Code / JetBrains extensions use, so it reuses the existing
	-- `claude` install + auth — no API key. Opens Claude Code in a terminal
	-- split and shares the current buffer / visual selection as context.
	"coder/claudecode.nvim",
	-- snacks.nvim is optional (fancier terminal); we use the built-in native
	-- terminal provider instead to avoid pulling in an extra dependency.
	opts = {
		terminal = {
			provider = "native",
		},
		-- After sending a selection, jump focus into the Claude panel (opening
		-- it first if needed). This is what makes the visual-mode <leader>o
		-- below "focus the panel with the highlighted text".
		focus_after_send = true,
	},
	-- `keys` makes this lazy-load on first use; nothing runs until <leader>a*.
	keys = {
		{ "<leader>a", nil, desc = "AI/Claude Code" },
		-- Primary toggle. The behaviour splits by mode, which doubles as the
		-- "is text highlighted?" check:
		--   * normal mode (no selection)  -> simple show/hide toggle of the panel
		--   * visual mode (has selection) -> send selection + focus the panel,
		--     opening it first if it isn't already up (focus_after_send above).
		{ "<leader>o", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude panel" },
		{ "<leader>o", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection + focus Claude" },
		{ "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
		{ "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
		{ "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
		{ "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
		{ "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
		-- Push the current buffer into Claude's context.
		{ "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
		-- Send the visual selection (the code you're looking at) to Claude.
		{ "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },
		-- From the file tree, add the file under the cursor to Claude's context.
		{
			"<leader>as",
			"<cmd>ClaudeCodeTreeAdd<cr>",
			desc = "Add file from tree",
			ft = { "NvimTree" },
		},
		-- When Claude proposes an edit it opens a diff; accept / reject it.
		{ "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept Claude diff" },
		{ "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Reject Claude diff" },
	},
}
