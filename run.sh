settings() {
	gsettings set org.gnome.shell.app-switcher current-workspace-only true #Only alt+tab in current workspace
	gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.4 #Dock opacity
}

update() {
	CONFIG_PATH="$HOME/.config"
	mkdir -p $CONFIG_PATH
	cp -v .zshenv $HOME
	cp -rv ./zsh $CONFIG_PATH
	cp -rv nvim $CONFIG_PATH
}

while getopts 'su' OPTION; do
	case "$OPTION" in
		s)
			settings
			;;
		u)
			update
			;;
		su)
			settings
			update
			;;
	esac
done
