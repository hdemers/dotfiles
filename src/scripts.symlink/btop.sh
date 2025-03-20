mkdir -p $HOME/src
cd $HOME/src
# Check the arch with uname -m

if [ "$(uname -m)" == "x86_64" ]; then
	curl -LsS https://github.com/aristocratos/btop/releases/download/v1.4.0/btop-x86_64-linux-musl.tbz -o btop.tbz
elif [ "$(uname -m)" == "aarch64" ]; then
	curl -LsS https://github.com/aristocratos/btop/releases/download/v1.4.0/btop-aarch64-linux-musl.tbz -o btop.tbz
else
	echo "btop binary architecture not implemented."
	exit 1
fi
tar xf btop.tbz
cd btop
env PREFIX=$HOME/.local make install

