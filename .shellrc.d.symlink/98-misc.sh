# Activate broot
source $HOME/.config/broot/launcher/bash/br

# Activate direnv
if command -v direnv &> /dev/null; then
    eval "$(direnv hook $CURRENT_SHELL)"
fi

# Load pyenv
# export PYENV_ROOT="$HOME/.pyenv"
# command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
# eval "$(pyenv init -)"

# Load pyenv-virtualenv
# eval "$(pyenv virtualenv-init -)"
