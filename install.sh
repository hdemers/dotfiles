#!/bin/bash

which git > /dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: Need git to clone the repository. Install git first."
    exit
fi


git clone https://github.com/hdemers/dotfiles.git $HOME/.dotfiles

cd $HOME/.dotfiles
./symlink --create-paths --overwrite-all
git submodule init && git submodule update

cd
