#!/bin/bash

sudo apt-get --yes install git

git clone https://github.com/hdemers/dotfiles.git $HOME/.dotfiles

cd $HOME/.dotfiles
./symlink --create-paths --overwrite-all
git submodule init && git submodule update

cd
