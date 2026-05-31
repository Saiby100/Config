return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter").setup({
			ensure_installed = {
				"c", "lua", "python",
				"javascript", "typescript", "tsx",
				"java", "kotlin",
				"html", "css", "bash",
				"json", "jsonc", "yaml",
				"markdown", "markdown_inline",
			},
			auto_install = true,
		})
	end,
}
