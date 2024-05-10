
cd $HOME/src
curl -LsSO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
tar xfz nvim-linux64.tar.gz
ln -s $HOME/src/nvim-linux64/bin/nvim $HOME/.local/bin/nvim

unset PIP_REQUIRE_VIRTUALENV

cd $HOME
pip3 install --user pyright
