return {
	"iamcco/markdown-preview.nvim",
	build = "cd app && npm install",
	ft = { "markdown" },
	init = function()
		vim.g.mkdp_filetypes = { "markdown" }
	end,
	keys = {
		{ "<leader>p", ":MarkdownPreview<CR>", desc = "Markdown Preview" },
	},
}
