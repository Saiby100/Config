-- Session-scoped search filters shared by the file/grep pickers. Set via the
-- <leader>s map below; they live for the whole Neovim session and every
-- find_files / live_grep launch honours them until changed or cleared. The
-- active scope is surfaced in each picker's title bar, so it stays visible while
-- Telescope is open. scope.glob is a list of patterns (or nil) — multiple
-- positive rg globs OR together, so several file types can be active at once.
local scope = { dir = nil, glob = nil }

-- Append the current scope to a picker's base title, e.g.
--   "Find Files  [dir:src/  type:*.ts,*.tsx]"
local function scope_title(base)
  local tags = {}
  if scope.dir then
    table.insert(tags, "dir:" .. scope.dir)
  end
  if scope.glob then
    table.insert(tags, "type:" .. table.concat(scope.glob, ","))
  end
  if #tags == 0 then
    return base
  end
  return base .. "  [" .. table.concat(tags, "  ") .. "]"
end

-- Build the find_files command for the current scope. Passed as a *function* to
-- the picker (telescope calls it per launch), so it always reflects the latest
-- scope.dir / scope.glob.
--
-- rg/fd respect .gitignore by default, so gitignored files like .env never show
-- up (`hidden = true` only adds non-ignored dotfiles). A positive rg glob can't
-- be added to whitelist them: it acts as a restrictive filter and hides
-- everything else. So with no file-type filter we union two passes:
--   1. normal listing (respects .gitignore) + --hidden for dotfiles
--   2. --no-ignore listing restricted to .env files, to force them in
-- node_modules/, dist/, etc. stay hidden (.gitignore + file_ignore_patterns),
-- while .env / .env.* always appear.
--
-- When scope.glob is set the user has asked for specific file types, so the
-- positive-glob filter is exactly what we want — collapse to a single pass and
-- drop the .env union. Multiple globs become multiple --glob flags, which rg
-- OR's together. scope.dir, when set, becomes rg's search path; otherwise rg
-- searches the cwd.
local function find_command()
  local dir = scope.dir and (" " .. vim.fn.shellescape(scope.dir)) or ""
  if scope.glob then
    local globs = {}
    for _, g in ipairs(scope.glob) do
      table.insert(globs, "--glob " .. vim.fn.shellescape(g))
    end
    return {
      "sh",
      "-c",
      "rg --files --hidden --glob '!**/.git/*' "
        .. table.concat(globs, " ")
        .. dir
        .. " | sort -u",
    }
  end
  return {
    "sh",
    "-c",
    table.concat({
      "rg --files --hidden --glob '!**/.git/*'" .. dir,
      "rg --files --no-ignore --glob '!**/.git/*' --glob '**/.env' --glob '**/.env.*'" .. dir,
    }, "; ") .. " | sort -u",
  }
end

-- Picker launchers that stamp the scope into the title. find_files reads its
-- (scope-aware) find_command from the picker config; live_grep takes the scope
-- as call-time opts.
local function find_files()
  require("telescope.builtin").find_files({ prompt_title = scope_title("Find Files") })
end

local function live_grep()
  require("telescope.builtin").live_grep({
    prompt_title = scope_title("Live Grep"),
    search_dirs = scope.dir and { scope.dir } or nil,
    glob_pattern = scope.glob,
  })
end

-- A small floating single-line input, used in place of vim.ui.input for the
-- scope prompt. The built-in cmdline input can't show a selection, so the
-- existing scope can't be highlighted; this opens a real buffer pre-filled with
-- the current scope and selects it (Visual mode) so a single keystroke wipes or
-- rewrites it — `d`/`x` to drop the filter, `c` (or just retype) to replace it.
-- <Tab> does file-path completion for the path token, <CR> confirms, and
-- <Esc>/<C-c> cancels — returning nil like vim.ui.input, so the caller's
-- "cancel leaves scope untouched / blank clears" logic is unchanged.
local function scope_input(prompt, default, on_confirm)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { default })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = math.max(50, #default + 10),
    height = 1,
    style = "minimal",
    border = "rounded",
    title = " " .. prompt .. " ",
    title_pos = "left",
  })

  local answered = false
  local function finish(value)
    if answered then
      return
    end
    answered = true
    vim.cmd("stopinsert")
    pcall(vim.api.nvim_win_close, win, true)
    on_confirm(value)
  end

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = function()
      finish(nil)
    end,
  })

  local function map(modes, lhs, rhs, opts)
    vim.keymap.set(modes, lhs, rhs, vim.tbl_extend("force", { buffer = buf, nowait = true }, opts or {}))
  end
  map({ "n", "i", "v", "s" }, "<CR>", function()
    -- Join in case a Visual change left more than one line; the caller
    -- re-tokenises on whitespace anyway.
    finish(vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), " ")))
  end)
  map({ "n", "i", "v", "s" }, "<C-c>", function()
    finish(nil)
  end)
  -- Esc only cancels from normal mode, so a first Esc can drop Visual/Select
  -- back to normal for editing, and a second Esc cancels the prompt.
  map("n", "<Esc>", function()
    finish(nil)
  end)
  -- <Tab>/<S-Tab> drive built-in file-name completion (and cycle the menu).
  map("i", "<Tab>", function()
    return vim.fn.pumvisible() == 1 and "<C-n>" or "<C-x><C-f>"
  end, { expr = true })
  map("i", "<S-Tab>", function()
    return vim.fn.pumvisible() == 1 and "<C-p>" or ""
  end, { expr = true })

  -- Highlight the prefilled scope so it's ready to remove/replace; with nothing
  -- prefilled just start typing.
  if default ~= "" then
    vim.cmd("normal! gg0vg_")
  else
    vim.cmd("startinsert")
  end
end

-- Single <leader>s setter for the whole scope: one prompt takes a path and/or
-- file types, e.g. "src *.ts *.tsx". The input is authoritative — whatever you
-- submit fully replaces the previous scope, so anything you leave out is
-- cleared. Parsing rule:
--   * tokens are whitespace-separated
--   * if the FIRST token contains a glob metachar (* ? [) the input is treated
--     as types only (dir = whole project) — e.g. "*.ts" or "src/**/*.ts"
--   * otherwise the first token is the path and the rest are file-type globs
-- Submitting blank clears everything; cancelling (Esc) leaves the scope as-is.
-- The path may point outside the cwd (absolute, ~/…, or ../…) — rg searches it
-- as a root; matches just display relative to the cwd (so "../sib/foo.ts").
local function set_filter()
  -- Pre-fill with the current scope so it round-trips and can be edited.
  local default = scope.dir or ""
  if scope.glob then
    default = (default ~= "" and default .. " " or "") .. table.concat(scope.glob, " ")
  end
  scope_input(
    'Scope: <path> <types>  e.g. src *.ts *.tsx  (blank clears)',
    default,
    function(input)
      if input == nil then
        return
      end
      local tokens = {}
      for tok in input:gmatch("%S+") do
        table.insert(tokens, tok)
      end
      if #tokens == 0 then
        scope.dir, scope.glob = nil, nil
        vim.notify("Telescope scope cleared")
        return
      end
      -- First token is a glob (types only) if it carries a glob metachar;
      -- otherwise it's the search path and the remaining tokens are types.
      local start = 1
      if tokens[1]:find("[%*%?%[]") then
        scope.dir = nil
      else
        scope.dir = vim.fn.expand(tokens[1])
        start = 2
      end
      local globs = {}
      for i = start, #tokens do
        table.insert(globs, tokens[i])
      end
      scope.glob = #globs > 0 and globs or nil
      vim.notify(
        ("Telescope scope — dir: %s  types: %s"):format(
          scope.dir or "<project>",
          scope.glob and table.concat(scope.glob, ", ") or "<all>"
        )
      )
    end
  )
end

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
    { "<C-p>",      find_files,                                       desc = "Find files" },
    -- <leader>f findInFiles
    { "<leader>f",  live_grep,                                        desc = "Grep files" },
    { "<leader>w",  "<cmd>Telescope buffers initial_mode=normal<CR>", desc = "Buffers" },
    -- Session search scope: one prompt for path + file types (blank clears).
    { "<leader>s",  set_filter,                                       desc = "Telescope: set search scope" },
  },
  config = function()
    local telescope = require("telescope")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    -- Open the highlighted entry in the window Telescope was launched from,
    -- but keep the picker open and focused so you can open several files in
    -- one session (press <C-o> on a few entries, then <Esc> to close).
    local function open_keep_open(prompt_bufnr)
      local picker = action_state.get_current_picker(prompt_bufnr)
      local entry = action_state.get_selected_entry()
      if not entry then
        return
      end
      local filename = entry.path or entry.filename
      if not filename then
        return
      end
      -- Run :edit in the launch window without moving focus there. Switching
      -- focus out of the prompt makes Telescope auto-close itself, so instead
      -- nvim_win_call runs the edit with that window current and restores
      -- focus to the prompt afterward, keeping the picker open.
      vim.api.nvim_win_call(picker.original_win_id, function()
        vim.cmd("edit " .. vim.fn.fnameescape(filename))
      end)
    end

    telescope.setup({
      defaults = {
        -- nvim-treesitter `main` branch dropped the parsers.ft_to_lang API that
        -- telescope 0.1.x previewers call, so disable TS preview highlighting.
        preview = { treesitter = false },
        -- When an entry is wider than the window, truncate from the *left*
        -- (drop leading directories, prefix "…") so the filename on the right
        -- stays visible in a narrow pane.
        path_display = { "truncate" },
        -- VS Code quickOpen nav: ctrl+j/k next/prev
        mappings = {
          i = {
            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,
            -- Open file without closing the picker.
            ["<C-o>"] = open_keep_open,
          },
          n = {
            -- Open file without closing the picker.
            ["<C-o>"] = open_keep_open,
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
        -- find_command is the scope-aware function defined above; telescope
        -- calls it on each launch, so the active <leader>s* scope (dir + file
        -- type) is applied to find_files automatically.
        find_files = {
          find_command = find_command,
        },
      },
    })

    pcall(telescope.load_extension, "fzf")
  end,
}
