cd $HOME
# Create the installation directory
export DIR=$HOME/.local
export SRC=$HOME/src
mkdir -p $DIR
mkdir -p $SRC

# Download libevent, ncurses and tmux
cd $SRC
curl -LsSO https://github.com/libevent/libevent/releases/download/release-2.1.8-stable/libevent-2.1.8-stable.tar.gz
curl -LsSO https://github.com/tmux/tmux/releases/download/3.3a/tmux-3.3a.tar.gz
curl -LsSO https://invisible-mirror.net/archives/ncurses/ncurses-6.2.tar.gz

# Untar archives
tar xfz libevent-2.1.8-stable.tar.gz
tar xfz tmux-3.3a.tar.gz
tar xfz ncurses-6.2.tar.gz

# Compile and install libevent
cd $SRC/libevent-2.1.8-stable
./configure --prefix=$DIR --disable-shared
make -j install

# Compile and install ncurses
cd $SRC/ncurses-6.2
./configure --prefix=$DIR --disable-shared
make -j install

# Compile and install tmux
cd $SRC/tmux-3.3a
./configure --prefix=$DIR CFLAGS="-I$DIR/include -I$DIR/include/ncurses" LDFLAGS="-L$DIR/lib"
make -j install

echo 'export PATH=$PATH:$HOME/.local/bin' >> $HOME/.bashrc

