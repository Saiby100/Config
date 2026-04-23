# My-Config

## TODO

- [ ] Replace the backup/restore copy flow in `script.sh` with symlinks so the repo and live config stay in sync automatically.
  - `~/.config/nvim` → `~/Developer/Config/linux/nvim` (directory symlink)
  - `~/.config/zsh` → `~/Developer/Config/linux/zsh` (directory symlink; add `.zsh_history`, `.zsh_sessions/`, `.zcompdump` to `.gitignore`)
  - `~/.zshenv` → `~/Developer/Config/linux/.zshenv` (file symlink)
  - `~/.claude/settings.json` and `~/.claude/statusline-command.sh` → per-file symlinks into `~/Developer/Config/linux/.claude/` (don't symlink the whole `~/.claude` directory — it contains session/history state that shouldn't be committed)
  - Once symlinked, remove the relevant copy logic from `script.sh`; keep the Windows path as-is since symlinks don't translate cleanly.
