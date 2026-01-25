###############################################################################
# broot
#
if [ -f "$HOME/.config/broot/launcher/bash/br" ]; then
    source $HOME/.config/broot/launcher/bash/br
fi

################################################################################
# direnv
#
if command -v direnv &> /dev/null; then
    eval "$(direnv hook $CURRENT_SHELL)"
fi

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
    # Normally the below arguments --disable-up-arrow --disable-ctrl-r should work, but they don't anymore.
    # I now need to set the environment variable ATUIN_NOBIND to true.
    export ATUIN_NOBIND="true"
    eval "$(atuin init $CURRENT_SHELL --disable-up-arrow --disable-ctrl-r)"
else
    echo "Atuin is not installed, shell history won't be captured."
fi

###############################################################################
# Zellij Zsh hook
#
if [[ "$CURRENT_SHELL" = "zsh" && -n "$ZELLIJ" ]]; then
    function set_tab_to_working_dir() {
        local title=$PWD

        if [[ $title == $HOME ]]; then
            title="~"
        else
            title=${title##*/}
        fi

        command nohup zellij action rename-tab $title >/dev/null 2>&1
    }

    add-zsh-hook precmd set_tab_to_working_dir
fi
