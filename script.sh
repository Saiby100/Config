#!/bin/bash

#Declare paths
CONFIG_PATH="$HOME/.config"
ZSH_PATH="$CONFIG_PATH/zsh"
NVIM_PATH="$CONFIG_PATH/nvim"
CLAUDE_PATH="$HOME/.claude"

#Get user input
echo "Using Windows? [y/n]"
read opt

echo "Backup or Restore [b/r]? "
read option

backup() {
    mkdir -p "$1/zsh/.zsh"
    cp -vf "$HOME/.zshenv" "$1"
    cp -vf "$ZSH_PATH/.zshrc" "$1/zsh/"
    cp -vf "$ZSH_PATH/.p10k.zsh" "$1/zsh/"
    cp -vf "$ZSH_PATH/.zsh/aliasrc" "$1/zsh/.zsh/"

    mkdir -p "$1/nvim"
    cp -vf "$NVIM_PATH/init.lua" "$1/nvim/"
    cp -vf "$NVIM_PATH/lazy-lock.json" "$1/nvim/"
    rsync -av --delete --exclude='.DS_Store' "$NVIM_PATH/lua" "$1/nvim/"

    mkdir -p "$1/.claude"
    cp -vf "$CLAUDE_PATH/settings.json" "$1/.claude/"
    cp -vf "$CLAUDE_PATH/statusline-command.sh" "$1/.claude/"
}

restore() {
	mkdir -p "$ZSH_PATH/.zsh"
	cp -v "$1/.zshenv" "$HOME"
	cp -v "$1/zsh/.zshrc" "$ZSH_PATH/"
	cp -v "$1/zsh/.p10k.zsh" "$ZSH_PATH/"
	cp -v "$1/zsh/.zsh/aliasrc" "$ZSH_PATH/.zsh/"

	mkdir -p "$NVIM_PATH"
	cp -v "$1/nvim/init.lua" "$NVIM_PATH/"
	cp -v "$1/nvim/lazy-lock.json" "$NVIM_PATH/"
	cp -rv "$1/nvim/lua" "$NVIM_PATH/"

	mkdir -p "$CLAUDE_PATH"
	cp -v "$1/.claude/settings.json" "$CLAUDE_PATH/"
	cp -v "$1/.claude/statusline-command.sh" "$CLAUDE_PATH/"
}

if [ "$opt" = "y" ]; then
    AHK_PATH="$CONFIG_PATH/keybinds.ahk"
    WINDOWS_PATH="./windows"

    if [ "$option" = "b" ]; then
        echo "Backing up windows files..."
        backup $WINDOWS_PATH
        cp -v $AHK_PATH $WINDOWS_PATH
    else
        echo "Restoring windows files..."
        restore $WINDOWS_PATH
        cp -v $WINDOWS_PATH/keybinds.ahk $CONFIG_PATH
    fi

elif [ "$opt" = "n" ]; then
    LINUX_PATH="./linux"

    if [ "$option" = "b" ]; then
        echo "Backing up linux files..."
        backup $LINUX_PATH
    else
        echo "Restoring linux files..."
        restore $LINUX_PATH
    fi
else 
    echo "Invalid option for using windows"
fi

