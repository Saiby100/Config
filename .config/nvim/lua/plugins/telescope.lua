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
    { "<leader>w", "<cmd>Telescope buffers initial_mode=normal<CR>",    desc = "Buffers" },
  },
  config = function()
    local telescope = require("telescope")
    local actions = require("telescope.actions")

    telescope.setup({
      defaults = {
        -- nvim-treesitter `main` branch dropped the parsers.ft_to_lang API that
        -- telescope 0.1.x previewers call, so disable TS preview highlighting.
        preview = { treesitter = false },
        -- VS Code quickOpen nav: ctrl+j/k next/prev
        mappings = {
          i = {
            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,
          },
        },
        file_ignore_patterns = { "node_modules", "dist/", "%.git/" },
        vimgrep_arguments = {
          "rg", "--color=never", "--no-heading", "--with-filename",
          "--line-number", "--column", "--smart-case",
        },
      },
      pickers = {
        -- Sort buffers by most recently used so the last opened is on top.
        buffers = {
          sort_mru = true,
          -- Telescope ships actions.delete_buffer but binds nothing to it, so
          -- wire dd (normal) / <C-d> (insert) to close the highlighted buffer.
          mappings = {
            n = { ["dd"] = actions.delete_buffer },
            i = { ["<C-d>"] = actions.delete_buffer },
          },
        },
        -- rg/fd respect .gitignore by default, so gitignored files like .env
        -- never show up (`hidden = true` only adds non-ignored dotfiles). A
        -- positive rg glob can't be added to whitelist them: it acts as a
        -- restrictive filter and hides everything else. So union two passes:
        --   1. normal listing (respects .gitignore) + --hidden for dotfiles
        --   2. --no-ignore listing restricted to .env files, to force them in
        -- node_modules/, dist/, etc. stay hidden (.gitignore + the
        -- file_ignore_patterns above), while .env / .env.* always appear.
        find_files = {
          find_command = {
            "sh",
            "-c",
            table.concat({
              "rg --files --hidden --glob '!**/.git/*'",
              "rg --files --no-ignore --glob '!**/.git/*' --glob '**/.env' --glob '**/.env.*'",
            }, "; ") .. " | sort -u",
          },
        },
      },
    })

    pcall(telescope.load_extension, "fzf")
  end,
}
