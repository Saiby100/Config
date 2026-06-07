return {
	"zbirenbaum/copilot.lua",
	cmd = "Copilot",
	event = "InsertEnter",
	opts = {
		-- Copilot's language server needs Node >= 22, but project work uses the
		-- Node 20 on PATH. Pin Copilot to a dedicated nvm-installed Node 22 so
		-- the rest of the environment is untouched. Glob keeps it working across
		-- Node 22 minor upgrades; install with `nvm install 22 --no-default`.
		copilot_node_command = vim.fn.expand("$HOME/.nvm/versions/node/v22*/bin/node"),
		-- Inline ghost-text suggestions, kept separate from nvim-cmp so the
		-- existing <Tab>/<CR> cmp mappings stay untouched.
		suggestion = {
			enabled = true,
			auto_trigger = true,
			keymap = {
				accept = "<M-l>",
				accept_word = "<M-w>",
				accept_line = "<M-j>",
				next = "<M-]>",
				prev = "<M-[>",
				dismiss = "<C-]>",
			},
		},
		-- Disabled: we use inline suggestions, not the panel or a cmp source.
		panel = { enabled = false },
	},
}
