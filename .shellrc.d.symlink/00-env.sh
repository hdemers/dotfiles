# vim: filetype=bash

# Set the EDITOR environment variable to use neovim if it exists else vim.
if [[ -x "$(command -v nvim)" ]]; then
    export EDITOR=$HOME/.local/bin/nvim
else
    export EDITOR=/usr/bin/vim
fi

# Set various PATH
export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/local/bin:$PATH
export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
export PATH=$HOME/.cargo/bin:$PATH

export CPATH=$CPATH:$HOME/.local/include
export LIBRARY_PATH=$LIBRARY_PATH:$HOME/.local/lib
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HOME/.local/lib

# Virtualenvwrapper, cf. http://virtualenvwrapper.readthedocs.org
export WORKON_HOME=$HOME/.virtualenvs
export PROJECT_HOME=$HOME/Projets/grubhub
# Virtualenvwrapper can be installed globally or locally. Look into both to find
# it.
VIRTUALENVWRAPPER=`find \
    $HOME/.local/pipx/venvs/virtualenvwrapper \
    $HOME/.local/bin \
    /usr/local/bin \
    -name virtualenvwrapper.sh -print -quit 2> /dev/null`

if [[ "$VIRTUALENVWRAPPER" == *pipx* ]]; then
    export VIRTUALENVWRAPPER_PYTHON=$HOME/.local/pipx/venvs/virtualenvwrapper/bin/python
fi

if [ "$VIRTUALENVWRAPPER" ] && [ -f $VIRTUALENVWRAPPER ]; then
    source $VIRTUALENVWRAPPER
fi

### rbenv path
export RBENV_ROOT="$HOME/.rbenv"
if [ -d "$RBENV_ROOT" ]; then
  export PATH="$RBENV_ROOT/bin:${PATH}"
  eval "$(rbenv init -)"
fi

export R_LIBS_USER=~/.R/library

export PIP_REQUIRE_VIRTUALENV=true

# For the functions defined in .bash_aliases
export SLACK_API_URL=https://slack.com/api

# GrubHub project directory
export GRUBHUB_DIR=$HOME/Projets/grubhub

# Bat theme (https://github.com/sharkdp/bat#highlighting-theme)
export BAT_THEME="Solarized (dark)"

# Set the default R lib path
export R_LIBS_USER=$HOME/.local/lib/R

# Set the AWS profile for use with S3 only
export AWS_PROFILE=s3-access

if [[ -f "$HOME/.config/openai/api.txt" ]]; then
    export OPENAI_API_KEY=$(cat $HOME/.config/openai/api.txt)
fi

if [[ -f "$HOME/.config/jira/api-token.txt" ]]; then
    export JIRA_API_TOKEN=$(cat $HOME/.config/jira/api-token.txt)
    export JIRA_AUTH_TYPE=bearer
fi

# Set environment variable CURRENT_SHELL to the name of the current shell
CURRENT_SHELL=$(ps -ho cmd -p $$)
export CURRENT_SHELL=${CURRENT_SHELL#-}

export GITHUB_TOKEN=$(secret-tool lookup github token)
