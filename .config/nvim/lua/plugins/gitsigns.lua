return {
	"lewis6991/gitsigns.nvim",
	event = "BufReadPre",
	opts = {
		current_line_blame = true,
		current_line_blame_opts = {
			delay = 300,
		},
		on_attach = function(bufnr)
			local gs = require("gitsigns")
			local function map(mode, lhs, rhs, desc)
				vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
			end

			-- Navigate between changes
			map("n", "]c", function() gs.nav_hunk("next") end, "Next git change")
			map("n", "[c", function() gs.nav_hunk("prev") end, "Prev git change")

			-- See the previous value (VS Code-style)
			map("n", "<leader>gp", gs.preview_hunk, "Preview change (popup)")
			map("n", "<leader>gi", gs.preview_hunk_inline, "Preview change inline")
			map("n", "<leader>go", gs.toggle_deleted, "Toggle old/deleted lines")
			map("n", "<leader>gd", gs.diffthis, "Side-by-side diff vs git")

			-- Stage / reset changes
			map("n", "<leader>gs", gs.stage_hunk, "Stage change")
			map("n", "<leader>gr", gs.reset_hunk, "Reset change")
			map("v", "<leader>gs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage selection")
			map("v", "<leader>gr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset selection")

			-- Blame the current line in a popup
			map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
		end,
	},
}
