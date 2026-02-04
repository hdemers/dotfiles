
cd $HOME/src

arch=$(uname -m)

if [ "$arch" = "x86_64" ]; then
    curl -LsSO https://github.com/neovim/neovim-releases/releases/download/v0.11.0/nvim-linux-x86_64.tar.gz
    tar xfz nvim-linux-x86_64.tar.gz
    ln -s $HOME/src/nvim-linux-x86_64/bin/nvim $HOME/.local/bin/nvim
elif [ "$arch" = "aarch64" ]; then
    curl -LsSO https://github.com/neovim/neovim/releases/download/v0.11.0/nvim-linux-arm64.tar.gz
    tar xfz nvim-linux-arm64.tar.gz
    ln -s $HOME/src/nvim-linux-arm64/bin/nvim $HOME/.local/bin/nvim
fi
