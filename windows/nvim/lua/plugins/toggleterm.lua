return {
	"akinsho/toggleterm.nvim",
	version = "*",
	keys = { { "<C-p>", mode = { "n", "t" } } },
	cmd = { "ToggleTerm", "TermExec" },
	opts = {
		size = 20,
		hide_numbers = true,
		open_mapping = [[<C-p>]],
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
