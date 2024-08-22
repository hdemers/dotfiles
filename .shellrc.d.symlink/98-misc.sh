###############################################################################
# broot
#
if [ -f "$HOME/.config/broot/launcher/bash/br" ]; then
    source $HOME/.config/broot/launcher/bash/br
fi

# Activate direnv
if command -v direnv &> /dev/null; then
    eval "$(direnv hook $CURRENT_SHELL)"
fi

###############################################################################
# pyenv
#
# export PYENV_ROOT="$HOME/.pyenv"
# command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
# eval "$(pyenv init -)"

# Load pyenv-virtualenv
# eval "$(pyenv virtualenv-init -)"


###############################################################################
# Atuin
#
# If the shell is bash, load the bash-preexec script (download if it doesn't exists).
if [ "$CURRENT_SHELL" = "bash" ]; then
    if [ ! -f ~/.bash-preexec.sh ]; then
        curl https://raw.githubusercontent.com/rcaloras/bash-preexec/master/bash-preexec.sh -o ~/.bash-preexec.sh
    fi
    [[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh
fi

if [ -x "$(command -v atuin)" ]; then
    eval "$(atuin init $CURRENT_SHELL --disable-up-arrow)"
else
    echo "Atuin is not installed, shell history won't be captured."
fi

# Source Ryn
. "$HOME/.rye/env"
