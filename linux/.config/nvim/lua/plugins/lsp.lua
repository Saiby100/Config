return {
	"VonHeikemen/lsp-zero.nvim",
	branch = "v2.x",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		-- LSP Support
		"neovim/nvim-lspconfig",
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",

		-- Autocompletion
		"hrsh7th/nvim-cmp",
		"hrsh7th/cmp-nvim-lsp",
		"hrsh7th/cmp-buffer",
		"hrsh7th/cmp-path",
		"saadparwaiz1/cmp_luasnip",
		"L3MON4D3/LuaSnip",
		"rafamadriz/friendly-snippets",
	},
	config = function()
		local lsp = require("lsp-zero").preset("recommended")

		lsp.ensure_installed({
			"ts_ls",   -- TypeScript / JavaScript
			"lua_ls",  -- Lua
			"html",    -- HTML
			"cssls",   -- CSS
			"jsonls",  -- JSON
			"yamlls",  -- YAML
			"bashls",  -- Bash
		})

		lsp.setup()

		-- ----- nvim-cmp (explicit setup) -----
		local cmp = require("cmp")
		local luasnip = require("luasnip")
		require("luasnip.loaders.from_vscode").lazy_load()

		vim.opt.completeopt = { "menu", "menuone", "noselect" }

		cmp.setup({
			snippet = {
				expand = function(args) luasnip.lsp_expand(args.body) end,
			},
			completion = {
				completeopt = "menu,menuone,noinsert",
			},
			window = {
				completion = cmp.config.window.bordered(),
				documentation = cmp.config.window.bordered(),
			},
			mapping = cmp.mapping.preset.insert({
				["<C-k>"]     = cmp.mapping.select_prev_item(),
				["<C-j>"]     = cmp.mapping.select_next_item(),
				["<C-Space>"] = cmp.mapping.complete(),
				["<C-e>"]     = cmp.mapping.abort(),
				["<CR>"]      = cmp.mapping.confirm({ select = false }),
				["<Tab>"]     = cmp.mapping.confirm({ select = true }),
			}),
			sources = cmp.config.sources({
				{ name = "nvim_lsp" },
				{ name = "luasnip" },
			}, {
				{ name = "buffer" },
				{ name = "path" },
			}),
		})
	end,
}
