#!/bin/bash
# Setting -x: every command will be echoed.
set -x

sudo apt-get update
sudo apt-get --yes install python-pip python-dev git
sudo pip install virtualenvwrapper
export WORKON_HOME=$HOME/.virtualenvs
mkdir -p $WORKON_HOME
source /usr/local/bin/virtualenvwrapper.sh
mkvirtualenv default
pip install fabric
git clone https://github.com/hdemers/dotfiles.git $HOME/.dotfiles
cd $HOME/.dotfiles
fab symlink
git submodule init && git submodule update
