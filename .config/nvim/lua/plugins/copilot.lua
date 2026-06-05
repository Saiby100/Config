return {
	"zbirenbaum/copilot.lua",
	cmd = "Copilot",
	event = "InsertEnter",
	opts = {
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
