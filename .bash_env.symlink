# vim: filetype=bash
export EDITOR=/usr/bin/vim

# Set various PATH
export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/local/bin:$PATH
export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
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
