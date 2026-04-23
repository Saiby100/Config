return {
	"akinsho/toggleterm.nvim",
	version = "*",
	keys = {
		{ "<C-A-p>", mode = { "n", "t" } },
		{ "<leader>t2", "<cmd>2ToggleTerm direction=float<CR>", mode = { "n", "t" }, desc = "Second terminal" },
	},
	cmd = { "ToggleTerm", "TermExec" },
	opts = {
		size = 20,
		hide_numbers = true,
		open_mapping = [[<C-A-p>]],
		shell = vim.o.shell,
		direction = "float",
		float_opts = {
			border = "curved",
			winblend = 3,
			highlights = {
				border = "Normal",
				background = "Normal",
			},
		},
	},
}
