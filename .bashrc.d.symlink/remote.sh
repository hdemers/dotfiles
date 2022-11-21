###############################################################################
#
# Functions to ease dealing with remote machines

install_dotfiles() {
    # Minimal installation of a remote host
    sshnohost $1 << EOF
    # Download and install dotfiles
    wget https://raw.githubusercontent.com/hdemers/dotfiles/master/install.sh
    source install.sh

    # I'm unable to execute this vim command here without interrupting this
    # script. Very weird. I'm aliasing a command to it instead.
    echo 'alias vs="vim +PlugInstall +qall"' >> \$HOME/.bashrc
EOF
}

tmux_install() {
    # Install tmux (and libevent) on host identified by the first argument
    sshnohost $1 << EOF
    cd \$HOME
    # Create the installation directory
    export DIR=\$HOME/.local
    export SRC=\$HOME/src
    mkdir -p \$DIR
    mkdir -p \$SRC

    # Download libevent, ncurses and tmux
    cd \$SRC
    wget https://github.com/libevent/libevent/releases/download/release-2.1.8-stable/libevent-2.1.8-stable.tar.gz
    wget https://github.com/tmux/tmux/releases/download/3.0a/tmux-3.0a.tar.gz
    wget https://invisible-mirror.net/archives/ncurses/ncurses-6.2.tar.gz

    # Untar archives
    tar xfz libevent-2.1.8-stable.tar.gz
    tar xfz tmux-3.0a.tar.gz
    tar xfz ncurses-6.2.tar.gz

    # Compile and install libevent
    cd \$SRC/libevent-2.1.8-stable
    ./configure --prefix=\$DIR --disable-shared
    make -j install

    # Compile and install ncurses
    cd \$SRC/ncurses-6.2
    ./configure --prefix=\$DIR --disable-shared
    make -j install

    # Compile and install tmux
    cd \$SRC/tmux-3.0a
    ./configure --prefix=\$DIR CFLAGS="-I\$DIR/include -I\$DIR/include/ncurses" LDFLAGS="-L\$DIR/lib"
    make -j install

    echo 'export PATH=\$PATH:\$HOME/.local/bin' >> \$HOME/.bashrc
EOF
}

remote_setup() {
    install_dotfiles $1
    tmux_install $1
    ssh $1
}

ec2_instance_from_tag() {
    # Set variables for instance ID and public IP retrieved using tag name

    if [ $# -eq 0 ]; then
        echo "ERROR: You must provide an instance name"
        return 1
    fi
    ec2_instance_id=`aws ec2 describe-instances \
        --filters "Name=tag-value,Values=$1" \
        --query "Reservations[*].Instances[*].[InstanceId]" --output=text`

    ec2_instance_public_ip=`aws ec2 describe-instances \
        --instance-ids $ec2_instance_id \
        --query "Reservations[*].Instances[*].PublicIpAddress" --output=text`

    ec2_instance_private_ip=`aws ec2 describe-instances \
        --instance-ids $ec2_instance_id \
        --query "Reservations[*].Instances[*].PrivateIpAddress" --output=text`
}

stop_ec2() {
    if [ $# -eq 0 ]; then
        echo "ERROR: You must provide an instance name"
        return 1
    fi
    # Retrieve instance ID and public IP using tag name
    ec2_instance_from_tag $1
    # Stop instance
    aws ec2 stop-instances --instance-ids $ec2_instance_id
    # TODO: Remove Slack reminder
    #wget -q -O - "$SLACK_API_URL/users.info?token=$SLACK_TOKEN&user=U0763TLKD" >/dev/null 2>&1
}

start_ec2() {
    if [ $# -eq 0 ]; then
        echo "ERROR: You must provide an instance name"
        return 1
    fi
    # Retrieve instance ID and public IP using tag name
    ec2_instance_from_tag $1
    # Start instance
    aws ec2 start-instances --instance-ids $ec2_instance_id
    #slack_remind_me 'to stop the EC2 machine' 'today at 17:00'
}
