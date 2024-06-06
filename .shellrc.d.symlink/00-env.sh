# vim: filetype=bash

# Set the EDITOR environment variable to use neovim if it exists else vim.
if [[ -x "$(command -v nvim)" ]]; then
    export EDITOR=nvim
else
    export EDITOR=vim
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

# Check if the USER environment variable is not equal to 'sagemaker-user'
if [ "$USER" != "sagemaker-user" ]; then
    # There's no virtuelenv on SageMaker, so that's useless there.
    export PIP_REQUIRE_VIRTUALENV=true
fi
# For the functions defined in .bash_aliases
export SLACK_API_URL=https://slack.com/api

# GrubHub project directory
export GRUBHUB_DIR=$HOME/Projets/grubhub

# Bat theme (https://github.com/sharkdp/bat#highlighting-theme)
export BAT_THEME="Dracula"

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

# If the secret-tool command exists, set our token.
if [[ -x "$(command -v secret-tool)" ]]; then
    export GITHUB_TOKEN=$(secret-tool lookup github token)
fi

# Check we have google-chrome installed and set the BROWSER environment variable
if [[ -x "$(command -v google-chrome)" ]]; then
    export BROWSER=$(which google-chrome)
fi
