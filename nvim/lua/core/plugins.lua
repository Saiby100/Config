return require('packer').startup(function()
	use 'wbthomason/packer.nvim'

	use 'nvim-tree/nvim-tree.lua'
	use 'nvim-tree/nvim-web-devicons'
	use { 'catppuccin/nvim', as = "catppuccin" }
	use 'nvim-treesitter/nvim-treesitter'
end)

