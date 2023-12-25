mkdir -p $HOME/src
cd $HOME/src
curl -LsSO https://github.com/aristocratos/btop/releases/download/v1.2.13/btop-x86_64-linux-musl.tbz
tar xf btop-x86_64-linux-musl.tbz
cd btop
env PREFIX=$HOME/.local make install

