#!/bin/bash

# Initializes submodules
git submodule init
git submodule update

# Path replacements
sed 's|{{projectdir}}|'$(pwd)'|g' i3/i3blocks.conf.src > i3/i3blocks.conf


# Creates all necessary links to link this repository into the environment
ln -s $(pwd)/.wgetrc ~/.wgetrc
ln -s $(pwd)/.bashrc ~/.bashrc
ln -s $(pwd)/.nanorc ~/.nanorc
ln -s $(pwd)/.Xresources ~/.Xresources
ln -s $(pwd)/.dircolors ~/.dircolors
ln -s $(pwd)/.face ~/.face
ln -s $(pwd)/.face ~/.face.icon

# Plasma integration of i3
mkdir -p ~/.config/plasma-workspace/env

ln -s $(pwd)/wm.sh ~/.config/plasma-workspace/env

# Configuration of i3
mkdir -p ~/.config/i3

ln -s $(pwd)/i3/config ~/.config/i3/config
ln -s $(pwd)/i3/i3blocks.conf ~/.config/i3/i3blocks.conf


mkdir -p ~/.config/rofi

ln -s $(pwd)/rofi ~/.config/rofi

# Path in rofi theme (onlv works for rofi-git/rofi.v >= 1.4)
sed 's|ROFI_OPTIONS=(-width -11 -location 3 -hide-scrollbar -bw 2)|ROFI_OPTIONS=(-width -11 -location 3 -hide-scrollbar -bw 2 -theme ~/.config/rofi/android_notification.rasi)|g' \
	i3blocks-contrib/shutdown_menu/shutdown_menu > shutdown_menu.bak
mv shutdown_menu.bak i3blocks-contrib/shutdown_menu/shutdown_menu