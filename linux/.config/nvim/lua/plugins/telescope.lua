return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
  },
  cmd = "Telescope",
  keys = {
    -- ctrl+p quickOpen
    { "<C-p>",     "<cmd>Telescope find_files<CR>", desc = "Find files" },
    -- <leader>f findInFiles
    { "<leader>f", "<cmd>Telescope live_grep<CR>",  desc = "Grep files" },
    { "<leader>b", "<cmd>Telescope buffers<CR>",    desc = "Buffers" },
  },
  config = function()
    local telescope = require("telescope")
    local actions = require("telescope.actions")

    telescope.setup({
      defaults = {
        -- VS Code quickOpen nav: ctrl+j/k next/prev
        mappings = {
          i = {
            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,
          },
        },
        file_ignore_patterns = { "node_modules", "dist", "%.git/" },
      },
      pickers = {
        find_files = { hidden = true },
      },
    })

    pcall(telescope.load_extension, "fzf")
  end,
}
