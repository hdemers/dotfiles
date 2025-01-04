#!/usr/bin/env bash

# If the dotfiles directory does not already exists, clone it.
if [ ! -d $HOME/.dotfiles ]; then
    git clone https://github.com/hdemers/dotfiles.git $HOME/.dotfiles
fi

cd $HOME/.dotfiles
./symlink --create-paths --overwrite-all --backup-all

cd
