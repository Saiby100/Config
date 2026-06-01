return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		local ts = require("nvim-treesitter")
		ts.setup()

		-- The `main` branch dropped `ensure_installed`/`auto_install` and no
		-- longer enables highlighting itself, so do both by hand: install any
		-- missing parsers, then start Neovim-native treesitter per filetype.
		local ensure_installed = {
			"c", "lua", "python",
			"javascript", "typescript", "tsx",
			"java", "kotlin",
			"html", "css", "bash",
			"json", "yaml",
			"markdown", "markdown_inline",
		}

		local installed = require("nvim-treesitter.config").get_installed("parsers")
		local missing = vim.tbl_filter(function(lang)
			return not vim.tbl_contains(installed, lang)
		end, ensure_installed)
		if #missing > 0 then
			ts.install(missing)
		end

		-- Highlighting is now provided by Neovim (`:h treesitter-highlight`).
		-- pcall guards filetypes without an installed/available parser.
		vim.api.nvim_create_autocmd("FileType", {
			callback = function(args)
				pcall(vim.treesitter.start, args.buf)
			end,
		})
	end,
}
