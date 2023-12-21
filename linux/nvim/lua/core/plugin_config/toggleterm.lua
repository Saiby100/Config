local status_ok, toggleterm = pcall(require, "toggleterm")
if not status_ok then
	return
end

toggleterm.setup({
	size = 20,
	hide_numbers = true,
	open_mapping = [[<C-p>]],
	shell = vim.o.shell,
	direction = "float",
	float_opts = {
		border = "curved",
		winblend = 3,
		highlights = {
			border = "Normal",
			background = "Normal",
		}
	}
})

