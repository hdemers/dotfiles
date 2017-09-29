#!/bin/bash

which git > /dev/null
if [ $? -ne 0 ]; then
    echo "Installing git..."
    sudo apt-get --yes install git
fi


git clone https://github.com/hdemers/dotfiles.git $HOME/.dotfiles

cd $HOME/.dotfiles
./symlink --create-paths --overwrite-all

cd

# Install all vim plugins
vim +PlugInstall +qall
