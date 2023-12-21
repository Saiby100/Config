require'nvim-treesitter.configs'.setup {
	ensure_installed = { "c", "lua", "python", "javascript", "java", "typescript", "html", "css", "bash", "kotlin", "latex", "json" },

	sync_install = false,
	auto_install = true,
	highlight = { enable = true },
}
