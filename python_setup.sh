# This is a very basic Python environment setup script.
# It installs virtualenvwrapper locally, create a virtualenv and install some
# basic python packages. But first, it installs my dotfiles.


# Download and install my dotfiles
wget https://raw.github.com/hdemers/dotfiles/master/install.sh
bash install.sh

# Install and create a virtualenv
pip install --user virtualenvwrapper
source $HOME/.local/bin/virtualenvwrapper.sh
mkvirtualenv venv

# Upgrade pip and install some python libraries
pip install -U pip
pip install ipython
pip install jupyter
pip install pandas

