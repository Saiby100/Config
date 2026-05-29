return {
	"nvim-treesitter/nvim-treesitter",
	branch = "master",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter.configs").setup({
			ensure_installed = {
				"c", "lua", "python",
				"javascript", "typescript", "tsx",
				"java", "kotlin",
				"html", "css", "bash",
				"json", "jsonc", "yaml",
				"markdown", "markdown_inline",
			},
			auto_install = true,
			highlight = { enable = true },
			indent = { enable = true },
		})
	end,
}
