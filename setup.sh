#!/bin/bash
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.config"

ln -sf "$REPO_DIR/.zshenv" "$HOME/.zshenv"
ln -sf "$REPO_DIR/.tmux.conf" "$HOME/.tmux.conf"

# Claude Code writes into ~/.claude (caches, backups, settings it mutates), so
# only link the statusline script — settings.json is left as a live file.
mkdir -p "$HOME/.claude"
ln -sf "$REPO_DIR/.claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
for dir in nvim zsh ghostty lazygit; do
  rm -rf "$HOME/.config/$dir"
  ln -s "$REPO_DIR/.config/$dir" "$HOME/.config/$dir"
done

# macOS lazygit ignores ~/.config and reads from ~/Library/Application Support,
# so point that path at the same tracked config (Linux uses the loop above).
if [ "$(uname)" = "Darwin" ]; then
  LG_MAC_DIR="$HOME/Library/Application Support/lazygit"
  mkdir -p "$LG_MAC_DIR"
  ln -sf "$REPO_DIR/.config/lazygit/config.yml" "$LG_MAC_DIR/config.yml"
fi

echo "Symlinks created."

# Telescope shells out to ripgrep for both find_files and live_grep, so without
# `rg` on PATH every picker comes back empty.
if command -v brew >/dev/null && ! command -v rg >/dev/null; then
  brew install ripgrep
fi

# nvim-treesitter's `main` branch compiles parsers by shelling out to the
# `tree-sitter` CLI (the old `master` branch built them directly with cc).
# Homebrew split this out of the library-only `tree-sitter` formula, so without
# `tree-sitter-cli` no parsers compile and syntax highlighting silently fails.
if command -v brew >/dev/null && ! command -v tree-sitter >/dev/null; then
  brew install tree-sitter-cli
fi

# Lazygit's config pipes diffs through `delta` for syntax-highlighted,
# word-level review. Without it on PATH, lazygit falls back to raw diffs.
if command -v brew >/dev/null && ! command -v delta >/dev/null; then
  brew install git-delta
fi

# Install the tmux plugin manager (TPM) and the plugins declared in .tmux.conf.
# Without this, the theme and vim-tmux-navigator silently do nothing.
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi
"$TPM_DIR/bin/install_plugins"

# tmux only reads ~/.tmux.conf when the server starts, so reload any running
# server to pick up the freshly linked config.
if command -v tmux >/dev/null && tmux info >/dev/null 2>&1; then
  tmux source-file "$HOME/.tmux.conf"
  echo "Reloaded running tmux server."
fi

echo "Done."
