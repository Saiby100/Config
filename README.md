# Config

Dotfiles managed via symlinks. Run `setup.sh` to link everything into place.

## Dependencies

Install these before running the setup script.

### macOS (Homebrew)

```sh
brew install neovim tmux lazygit ghostty ripgrep tree-sitter-cli
brew install --cask font-jetbrains-mono-nerd-font
```

### Linux (apt)

```sh
sudo apt install neovim tmux zsh ripgrep
# tree-sitter CLI: cargo install tree-sitter-cli (or npm install -g tree-sitter-cli)
```

- [Lazygit](https://github.com/jesseduffield/lazygit#installation) — install from GitHub releases or your distro's package manager
- [Ghostty](https://ghostty.org/) — see official install instructions
- [JetBrainsMono Nerd Font](https://www.nerdfonts.com/font-downloads) — used by Ghostty
- [ripgrep](https://github.com/BurntSushi/ripgrep) — required by Telescope's `find_files` and `live_grep`; without it the pickers return no results
- [tree-sitter CLI](https://github.com/tree-sitter/tree-sitter) — nvim-treesitter's `main` branch compiles parsers with it; without it syntax highlighting silently fails

### Shared

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — CLI for Claude

> tmux's plugin manager (tpm) is cloned and its plugins installed automatically by `setup.sh`.

## Setup

```sh
git clone <repo-url> ~/Developer/Config
cd ~/Developer/Config
./setup.sh
```

This creates symlinks for:

| Target | Symlink |
|---|---|
| `.zshenv` | `~/.zshenv` |
| `.tmux.conf` | `~/.tmux.conf` |
| `.config/nvim` | `~/.config/nvim` |
| `.config/zsh` | `~/.config/zsh` |
| `.config/ghostty` | `~/.config/ghostty` |

`setup.sh` also clones tpm, installs the tmux plugins, and reloads any running
tmux server — so the config (including the theme and vim-tmux-navigator) takes
effect without a manual `prefix + I` or server restart.

## Structure

```
.zshenv                        # Points ZDOTDIR to ~/.config/zsh
.tmux.conf                     # Tmux config (prefix: Ctrl+Space)
.claude/                       # Claude Code settings
.config/
  ghostty/config               # Terminal (One Dark Two, JetBrainsMono Nerd Font)
  nvim/                        # Neovim (lazy.nvim, onedark, LSP, telescope)
  zsh/
    .zshrc                     # Shell config (prompt, history, completions)
    .zsh/aliasrc               # Aliases and shortcuts
keybinds.ahk                   # AutoHotKey remaps (Windows)
```

## Key Aliases

| Alias | Command |
|---|---|
| `lg` | `lazygit` |
| `cc` | `claude` |
| `ref` | Re-source `.zshrc` |
| `zrc` | Edit `.zshrc` in nvim |
| `zal` | Edit `aliasrc` in nvim |
| `wp` | `cd ~/Developer` |
