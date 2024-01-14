#!/bin/bash

#Declare paths
CONFIG_PATH="$HOME/.config"
ZSH_PATH="$CONFIG_PATH/zsh"
NVIM_PATH="$CONFIG_PATH/nvim"

#Get user input
echo "Using Windows? [y/n]"
read opt

echo "Backup or Restore [b/r]? "
read option

backup() {
    cp -rvf $ZSH_PATH $1
    cp -rvf $HOME/.zshenv $1
    cp -rvf $NVIM_PATH $1
}

restore() {
	mkdir -p $CONFIG_PATH
	cp -v $1/.zshenv $HOME
	cp -rv $1/zsh $CONFIG_PATH
	cp -rv $1/nvim $CONFIG_PATH
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

