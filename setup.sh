#!/bin/bash
read -p "Do you want to update first? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
	sudo apt-get update
	sudo apt-get upgrade
fi
for install in system i3 vim tmux ssh zsh; do
	/bin/bash $install/setup
done
