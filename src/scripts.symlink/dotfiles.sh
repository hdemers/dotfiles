# Download and install dotfiles
wget https://raw.githubusercontent.com/hdemers/dotfiles/master/install.sh
source install.sh

# I'm unable to execute this vim command here without interrupting this
# script. Very weird. I'm aliasing a command to it instead.
echo 'alias vs="vim +PlugInstall +qall"' >> \$HOME/.bashrc
