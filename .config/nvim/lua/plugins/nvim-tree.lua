return {
	"nvim-tree/nvim-tree.lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	keys = {
		{ "<leader>e", ":NvimTreeToggle<CR>", desc = "Toggle NvimTree" },
		-- Snap the tree root back to the directory Neovim was started in
		-- (~/Developer) after update_root has followed you into a project.
		{
			"<leader>E",
			function()
				require("nvim-tree.api").tree.change_root(vim.loop.cwd())
			end,
			desc = "NvimTree: root back to cwd",
		},
	},
	config = function()
		require("nvim-tree").setup({
			disable_netrw = true,
			hijack_netrw = true,
			view = {
				width = 30,
				side = "left",
				preserve_window_proportions = true,
			},
			renderer = {
				indent_markers = { enable = true },
				-- Collapse single-child folder chains (a/b/c) onto one line to cut
				-- vertical clutter when browsing deep project trees.
				group_empty = true,
				icons = {
					glyphs = {
						folder = {
							arrow_closed = "›",
							arrow_open = "⌄",
						},
					},
				},
				highlight_git = "name",
				highlight_opened_files = "name",
			},
			filters = {
				custom = { "^dist$", "^node_modules$" },
				dotfiles = false,
			},
			git = {
				enable = true,
				ignore = false,
			},
			actions = {
				open_file = {
					quit_on_open = false,
					-- Don't snap the tree back to its configured width when opening a
					-- file — keep whatever width it's been manually resized to.
					resize_window = false,
					window_picker = { enable = true },
				},
			},
			-- With Neovim opened in ~/Developer the tree would otherwise show
			-- every project at once. update_root snaps the tree root to the
			-- focused file's project root, so opening a file (e.g. via Telescope)
			-- collapses the view down to just that project. <leader>E resets the
			-- root back to ~/Developer. Neovim's cwd is left at ~/Developer (root
			-- not synced), so cross-project Telescope searches still see everything.
			update_focused_file = {
				enable = true,
				update_root = true,
			},
		})

		-- Persist a manually-resized tree width for the whole session. nvim-tree
		-- only remembers widths set via its own resize commands, so a mouse-drag
		-- or <C-w>> is otherwise forgotten when the tree is toggled/reloaded.
		-- Capture the tree window's width whenever it changes and feed it back so
		-- it becomes the remembered width. Feeding back the same width is a no-op
		-- inside nvim-tree, so this doesn't loop.
		local tree_api = require("nvim-tree.api")
		vim.api.nvim_create_autocmd("WinResized", {
			callback = function()
				for _, win in ipairs(vim.v.event.windows or {}) do
					if vim.api.nvim_win_is_valid(win) then
						local buf = vim.api.nvim_win_get_buf(win)
						if vim.bo[buf].filetype == "NvimTree" then
							tree_api.tree.resize({ absolute = vim.api.nvim_win_get_width(win) })
						end
					end
				end
			end,
		})

		local function is_modified_buffer_open(buffers)
			for _, v in pairs(buffers) do
				if v.name:match("NvimTree_") == nil then
					return true
				end
			end
			return false
		end

		vim.api.nvim_create_autocmd("BufEnter", {
			nested = true,
			callback = function()
				if
					#vim.api.nvim_list_wins() == 1
					and vim.api.nvim_buf_get_name(0):match("NvimTree_") ~= nil
					and is_modified_buffer_open(vim.fn.getbufinfo({ bufmodified = 1 })) == false
				then
					vim.cmd("quit")
				end
			end,
		})
	end,
}
