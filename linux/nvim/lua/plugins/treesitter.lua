return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter").install({
			"c", "lua", "python", "javascript", "java", "typescript",
			"html", "css", "bash", "kotlin", "latex", "json",
		})

		vim.api.nvim_create_autocmd("FileType", {
			pattern = {
				"c", "lua", "python",
				"javascript", "javascriptreact",
				"java",
				"typescript", "typescriptreact",
				"html", "css",
				"bash", "sh",
				"kotlin",
				"tex", "latex", "plaintex",
				"json", "jsonc",
			},
			callback = function(args)
				local ft = args.match
				local lang = vim.treesitter.language.get_lang(ft) or ft
				if pcall(vim.treesitter.language.add, lang) then
					vim.treesitter.start(args.buf, lang)
					vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end
			end,
		})
	end,
}
