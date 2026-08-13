-- Inline search scoping for the Telescope file & grep pickers.
--
-- Both <C-p> (find files) and <leader>f (live grep) take the directory /
-- file-type scope in the SAME prompt as the query, split on " :: ":
--
--   src *.ts :: Button     -> dir "src", type *.ts, searching "Button"
--   *.md :: TODO           -> all *.md files, searching "TODO"
--   Button                 -> no scope, searching "Button"
--
-- The scope half is remembered for the rest of the Neovim session: each picker
-- opens pre-filled with "<last scope> :: " and the cursor after it, so you keep
-- the scope by just typing your query, or edit/clear it inline. A fresh Neovim
-- resets it. The prompt is authoritative — whatever scope you leave in it when
-- you close is what the next launch pre-fills.
--
-- Scope grammar (whitespace-separated tokens, left of " :: "):
--   * the LEADING tokens with no glob metachar (* ? [) are search directories;
--     the first token that HAS a metachar starts the file-type globs, and every
--     token from there on is a glob — so "dirs come first, then types"
--   * multiple dirs become multiple rg search roots (all searched together);
--     multiple globs OR together (rg --glob), so several types are active at once
--   * with no leading dir the whole project is searched; with no glob all types
--     match. Paths may be absolute, ~/… or ../… — rg searches each as a root.
--
-- e.g.  src lib :: TODO          -> dirs src + lib, all types, searching "TODO"
--       src *.ts *.tsx :: Button -> dir src, only *.ts/*.tsx, searching "Button"
--       *.md :: draft            -> all *.md anywhere, searching "draft"
--
-- " :: " is the separator (not "|") because "|" is rg's regex alternation, so a
-- grep like "foo | bar" would misparse; "std::vector" has no surrounding spaces
-- so real "::" tokens don't collide.
--
-- <Tab> completes a directory into the scope half: it opens a fuzzy picker over
-- every directory in the project and writes the pick back into the prompt,
-- keeping the query. Shell-style — a partial dir name under the cursor seeds
-- the picker and is replaced; a trailing space (or a glob last) adds a dir.
local SEP = " :: "

-- Session-remembered scope text (the raw left-of-SEP string, e.g. "src *.ts").
local last_scope = ""

-- Split a full prompt into (scope_str, query) on the first SEP. No SEP => the
-- whole prompt is the query and there's no scope.
local function split_input(prompt)
  local s, e = prompt:find(SEP, 1, true)
  if s then
    return vim.trim(prompt:sub(1, s - 1)), prompt:sub(e + 1)
  end
  return "", prompt
end

-- Parse a scope string into (dirs, globs) using the grammar above: leading
-- plain tokens are directories, then the first glob-metachar token flips into
-- glob mode and everything after is a file-type glob. Returns a (possibly
-- empty) dirs list and a globs list or nil.
local function parse_scope(scope_str)
  local dirs, globs = {}, {}
  local in_globs = false
  for tok in scope_str:gmatch("%S+") do
    if not in_globs and tok:find("[%*%?%[]") then
      in_globs = true
    end
    if in_globs then
      globs[#globs + 1] = tok
    else
      dirs[#dirs + 1] = vim.fn.expand(tok)
    end
  end
  return dirs, (#globs > 0 and globs or nil)
end

-- Pre-fill for a freshly opened picker: remembered scope + separator (cursor
-- lands at the end, ready for the query), or empty when there's no scope.
local function prefill()
  return last_scope ~= "" and (last_scope .. SEP) or ""
end

-- Build the `rg --files` command for find_files. With a file-type filter we run
-- a single positive-glob pass; with no filter we union a normal (gitignore-
-- respecting) listing with a forced .env listing, so .env / .env.* always show
-- while node_modules/, dist/, etc. stay hidden. Each dir in `dirs` becomes an
-- rg search root; an empty list means search the cwd.
local function files_command(dirs, globs)
  local d = ""
  for _, dir in ipairs(dirs) do
    d = d .. " " .. vim.fn.shellescape(dir)
  end
  if globs then
    local gs = {}
    for _, g in ipairs(globs) do
      gs[#gs + 1] = "--glob " .. vim.fn.shellescape(g)
    end
    return {
      "sh",
      "-c",
      "rg --files --hidden --glob '!**/.git/*' " .. table.concat(gs, " ") .. d .. " | sort -u",
    }
  end
  return {
    "sh",
    "-c",
    table.concat({
      "rg --files --hidden --glob '!**/.git/*'" .. d,
      "rg --files --no-ignore --glob '!**/.git/*' --glob '**/.env' --glob '**/.env.*'" .. d,
    }, "; ") .. " | sort -u",
  }
end

-- Directory listing for <Tab> completion, relative to Neovim's cwd (the job
-- inherits it). There's no `fd` here, so the dirs come from `rg --files`, which
-- means the listing inherits rg's gitignore handling for free (no node_modules/,
-- dist/, .git/) at the cost of omitting directories that contain no files at
-- all. awk emits every ancestor prefix of each path, not just the immediate
-- parent, so a dir holding only subdirs still shows up. Output is ordered
-- shallowest-first (depth, then name) — that's the order you see before typing,
-- since every entry ties on score with an empty prompt.
local function dirs_command()
  return {
    "sh",
    "-c",
    "rg --files --hidden --glob '!**/.git/*' "
      .. "| awk -F/ '{ p = \"\"; for (i = 1; i < NF; i++) "
      .. "{ p = (i == 1 ? $i : p \"/\" $i); print (i - 1) \" \" p } }' "
      .. "| sort -u -k1,1n -k2 | cut -d' ' -f2-",
  }
end

-- How much each level of nesting costs a directory in the ranking. Applied as a
-- multiplier, so it's a thumb on the scale rather than a hard ordering: a much
-- better fuzzy match deeper down still beats a weak shallow one, but between
-- comparable matches the one nearer the cwd wins. Raise it to favour shallow
-- results harder.
local DEPTH_PENALTY = 0.25

-- The dir picker's sorter: the configured fuzzy sorter (fzf-native, when the
-- extension loaded) plus a penalty for nesting depth. Telescope scores are
-- "lower is better" — fzf-native returns 1/fzf_score — and a non-positive score
-- means "no match, drop it", so only positive scores get scaled.
local function dir_sorter()
  local sorter = require("telescope.config").values.generic_sorter({})
  local score = sorter.scoring_function
  sorter.scoring_function = function(self, prompt, line, entry, cb_add, cb_filter)
    local s = score(self, prompt, line, entry, cb_add, cb_filter)
    if type(s) ~= "number" or s <= 0 then
      return s
    end
    local depth = select(2, line:gsub("/", ""))
    return s * (1 + depth * DEPTH_PENALTY)
  end
  return sorter
end

-- <Tab>: fuzzy-pick a directory into the scope half of the prompt.
--
-- Telescope can't stack pickers, so this closes the calling picker, runs the
-- directory picker, and then calls `relaunch` (find_files / live_grep) with the
-- rebuilt prompt as default_text. Cancelling relaunches with the prompt as it
-- was, so <Tab><Esc> costs nothing.
local function complete_dir(prompt_bufnr, relaunch)
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")

  local prompt = action_state.get_current_line()
  local s, e = prompt:find(SEP, 1, true)
  -- Deliberately un-trimmed: trailing whitespace is the "add another dir"
  -- signal, exactly as in shell completion.
  local left = s and prompt:sub(1, s - 1) or ""
  local query = s and prompt:sub(e + 1) or prompt

  -- Re-tokenise the scope by the same dirs-then-globs rule as parse_scope, but
  -- keeping the raw tokens since they go back into the prompt as text.
  local dirtoks, globtoks = {}, {}
  for tok in left:gmatch("%S+") do
    if #globtoks > 0 or tok:find("[%*%?%[]") then
      globtoks[#globtoks + 1] = tok
    else
      dirtoks[#dirtoks + 1] = tok
    end
  end

  -- The last dir token is a partial name to complete unless the prompt ends in
  -- whitespace, or a glob token follows it (then we're appending a new dir).
  local seed = ""
  if left ~= "" and not left:match("%s$") and #globtoks == 0 and #dirtoks > 0 then
    seed = table.remove(dirtoks)
  end

  local function reopen(dir)
    if dir then
      dirtoks[#dirtoks + 1] = dir
      local toks = {}
      vim.list_extend(toks, dirtoks)
      vim.list_extend(toks, globtoks)
      last_scope = table.concat(toks, " ")
      vim.schedule(function()
        relaunch(prefill() .. query)
      end)
    else
      vim.schedule(function()
        relaunch(prompt)
      end)
    end
  end

  actions.close(prompt_bufnr)
  pickers
    .new({}, {
      prompt_title = "Scope Directory  (<Tab> completes)",
      default_text = seed,
      finder = finders.new_oneshot_job(dirs_command(), {}),
      sorter = dir_sorter(),
      attach_mappings = function(dir_bufnr, map)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(dir_bufnr)
          reopen(entry and (entry.value or entry[1]))
        end)
        -- Cancelling has to go back to the original picker too, or the query
        -- typed before <Tab> is lost.
        local function cancel()
          actions.close(dir_bufnr)
          reopen(nil)
        end
        map({ "i", "n" }, "<Esc>", cancel)
        map("i", "<C-c>", cancel)
        return true
      end,
    })
    :find()
end

-- <C-p>: find files. The oneshot listing is rebuilt only when the scope half
-- changes (via updated_finder); the query half is handed to the sorter alone so
-- filename fuzzy-matching keeps working.
local function find_files(default_text)
  local builtin = require("telescope.builtin")
  local finders = require("telescope.finders")
  local make_entry = require("telescope.make_entry")

  local dirs0, globs0 = parse_scope(last_scope)
  local prev_scope = last_scope

  builtin.find_files({
    prompt_title = "Find Files  (scope :: query)",
    default_text = default_text or prefill(),
    -- Initial listing honours the pre-filled scope.
    find_command = function()
      return files_command(dirs0, globs0)
    end,
    on_input_filter_cb = function(prompt)
      local scope_str, query = split_input(prompt)
      last_scope = scope_str
      local result = { prompt = query }
      if scope_str ~= prev_scope then
        prev_scope = scope_str
        local dirs, globs = parse_scope(scope_str)
        result.updated_finder =
          finders.new_oneshot_job(files_command(dirs, globs), { entry_maker = make_entry.gen_from_file({}) })
      end
      return result
    end,
    attach_mappings = function(_, map)
      map({ "i", "n" }, "<Tab>", function(bufnr)
        complete_dir(bufnr, find_files)
      end)
      return true
    end,
  })
end

-- <leader>f: live grep. A job finder rebuilds the rg command every keystroke,
-- turning the scope half into --glob / search-root args and passing the query
-- half as the rg pattern. Sorter is highlighter_only so rg does the filtering.
local function live_grep(default_text)
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local sorters = require("telescope.sorters")
  local make_entry = require("telescope.make_entry")
  local conf = require("telescope.config").values

  local opts = { cwd = vim.loop.cwd() }

  local grepper = finders.new_job(function(prompt)
    if not prompt or prompt == "" then
      return nil
    end
    local scope_str, query = split_input(prompt)
    last_scope = scope_str
    if query == "" then
      return nil
    end
    local dirs, globs = parse_scope(scope_str)
    -- Start from the configured vimgrep args (first element is "rg") so the
    -- picker's grep flags stay in one place; deepcopy since new_job mutates it.
    local cmd = vim.deepcopy(conf.vimgrep_arguments)
    if globs then
      for _, g in ipairs(globs) do
        cmd[#cmd + 1] = "--glob=" .. g
      end
    end
    cmd[#cmd + 1] = "--"
    cmd[#cmd + 1] = query
    for _, dir in ipairs(dirs) do
      cmd[#cmd + 1] = dir
    end
    return cmd
  end, make_entry.gen_from_vimgrep(opts), nil, opts.cwd)

  pickers
    .new(opts, {
      prompt_title = "Live Grep  (scope :: query)",
      default_text = default_text or prefill(),
      finder = grepper,
      previewer = conf.grep_previewer(opts),
      sorter = sorters.highlighter_only(opts),
      attach_mappings = function(_, map)
        map({ "i", "n" }, "<Tab>", function(bufnr)
          complete_dir(bufnr, live_grep)
        end)
        return true
      end,
    })
    :find()
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
    { "<C-p>",     find_files,                                       desc = "Find files" },
    -- <leader>f findInFiles
    { "<leader>f", live_grep,                                        desc = "Grep files" },
    { "<leader>w", "<cmd>Telescope buffers initial_mode=normal<CR>", desc = "Buffers" },
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
        -- Drop the "> " prompt prefix. It's a read-only region of the Vim
        -- prompt buffer, so in normal mode the cursor snags on it and d/x/c are
        -- blocked when a selection sits over it. With no prefix the whole prompt
        -- line is editable text and normal-mode edits work everywhere.
        prompt_prefix = "",
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
      },
    })

    pcall(telescope.load_extension, "fzf")
  end,
}
