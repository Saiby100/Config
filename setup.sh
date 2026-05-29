#!/bin/bash
REPO_DIR="$(cd "$(dirname "$0")/linux" && pwd)"

mkdir -p "$HOME/.config"

ln -sf "$REPO_DIR/.zshenv" "$HOME/.zshenv"
ln -sf "$REPO_DIR/.tmux.conf" "$HOME/.tmux.conf"
ln -sfn "$REPO_DIR/.config/nvim" "$HOME/.config/nvim"
ln -sfn "$REPO_DIR/.config/zsh" "$HOME/.config/zsh"
ln -sfn "$REPO_DIR/.config/ghostty" "$HOME/.config/ghostty"

echo "Symlinks created."
