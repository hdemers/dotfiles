# vim: filetype=bash


###############################################################################
# Linux Brew
# This needs to come first in order to find all commands installed via brew.
# If directory linuxbrew exists eval the following
if [ -d "/home/linuxbrew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Set the EDITOR environment variable to use neovim if it exists else vim.
if [[ -x "$(command -v nvim)" ]]; then
    export EDITOR=nvim
else
    unset EDITOR
fi

# Set various PATH
export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/local/bin:$PATH
# export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
# export PATH=$HOME/.cargo/bin:$PATH
# export PATH=$HOME/go/bin:$PATH

# export CPATH=$CPATH:$HOME/.local/include
# export LIBRARY_PATH=$LIBRARY_PATH:$HOME/.local/lib
# export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HOME/.local/lib

### rbenv path
# export RBENV_ROOT="$HOME/.rbenv"
# if [ -d "$RBENV_ROOT" ]; then
#   export PATH="$RBENV_ROOT/bin:${PATH}"
#   eval "$(rbenv init -)"
# fi

# GrubHub project directory
export GRUBHUB_DIR=$HOME/Projets/grubhub

# Bat theme (https://github.com/sharkdp/bat#highlighting-theme)
export BAT_THEME="Dracula"

# Set the default R lib path
export R_LIBS_USER=$HOME/.local/lib/R
# Set the AWS profile for use with S3 only, but only if it's not already set.
if [ -z "$AWS_PROFILE" ]; then
    export AWS_PROFILE=s3-access
fi

# Set environment variable CURRENT_SHELL to the name of the current shell
CURRENT_SHELL=$(ps -ho cmd -p $$ | cut -d ' ' -f 1)
export CURRENT_SHELL=${CURRENT_SHELL#-}

shell_cmd=$(ps -ho cmd -p $$ | cut -d ' ' -f 1)
if [[ $shell_cmd == *"zsh"* ]]; then
  export CURRENT_SHELL="zsh"
elif [[ $shell_cmd == *"bash"* ]]; then
  export CURRENT_SHELL="bash"
else
  echo "No match found"
fi

# Try to execute the command `secret` and if there are no error, execute the following.
if [[ -x "$(command -v secret)" ]]; then
    eval "$(secret export ~/.secrets-conf.yaml)"
fi

# Check we have google-chrome installed and set the BROWSER environment variable
if [[ -x "$(command -v google-chrome)" ]]; then
    export BROWSER=$(which google-chrome)
fi

export DBX_CONTAINER_NAME=ubuntu
export DISTROBOX_NAME=$DBX_CONTAINER_NAME

export MQTTUI_USERNAME=mqtt-user
export PLAID_USER=hdemers

export UV_LINK_MODE=symlink

export UV_CACHE_DIR=/var/home/hdemers/.cache/uv
