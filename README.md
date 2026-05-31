# Config

Dotfiles managed via symlinks. Run `setup.sh` to link everything into place.

## Dependencies

Install these before running the setup script.

### macOS (Homebrew)

```sh
brew install neovim tmux lazygit ghostty
brew install --cask font-jetbrains-mono-nerd-font
```

### Linux (apt)

```sh
sudo apt install neovim tmux zsh
```

- [Lazygit](https://github.com/jesseduffield/lazygit#installation) — install from GitHub releases or your distro's package manager
- [Ghostty](https://ghostty.org/) — see official install instructions
- [JetBrainsMono Nerd Font](https://www.nerdfonts.com/font-downloads) — used by Ghostty

### Shared

- [tpm](https://github.com/tmux-plugins/tpm) — tmux plugin manager:
  ```sh
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  ```
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — CLI for Claude

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

After linking, install tmux plugins with `prefix + I` inside tmux.

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
