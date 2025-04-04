cd $HOME/src

arch=$(uname -m)

if [ "$arch" = "x86_64" ]; then
    curl -LsSO https://github.com/sharkdp/fd/releases/download/v10.2.0/fd-v10.2.0-x86_64-unknown-linux-gnu.tar.gz
    tar xfz fd-v10.2.0-x86_64-unknown-linux-gnu.tar.gz
    ln -s $HOME/src/fd-v10.2.0-x86_64-unknown-linux-gnu/fd $HOME/.local/bin/fd
elif [ "$arch" = "aarch64" ]; then
    curl -LsSO https://github.com/sharkdp/fd/releases/download/v10.2.0/fd-v10.2.0-aarch64-unknown-linux-gnu.tar.gz
    tar xfz fd-v10.2.0-aarch64-unknown-linux-gnu.tar.gz
    ln -s $HOME/src/fd-v10.2.0-aarch64-unknown-linux-gnu/fd $HOME/.local/bin/fd
fi
