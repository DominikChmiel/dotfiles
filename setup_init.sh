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
ln -s $(pwd)/.Xressources ~/.Xressources
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
