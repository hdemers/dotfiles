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
# Github copilot aliases

if command -v gh &> /dev/null; then
    if gh copilot --help &> /dev/null; then
        eval "$(gh copilot alias -- ${CURRENT_SHELL})"
    fi
fi

###############################################################################
# ZSH script to set the zellij tab title to the running command line, or the current directory 
function current_dir() {
    local current_dir=$PWD
    if [[ $current_dir == $HOME ]]; then
        current_dir="~"
    else
        current_dir=${current_dir##*/}
    fi
    
    echo $current_dir
}

function change_tab_title() {
    local title=$1
    command nohup zellij action rename-tab $title >/dev/null 2>&1
}

function set_tab_to_working_dir() {
    local result=$?
    local title=$(current_dir)
    # uncomment the following to show the exit code after a failed command
    # if [[ $result -gt 0 ]]; then
    #     title="$title [$result]" 
    # fi

    change_tab_title $title
}

function set_tab_to_command_line() {
    local cmdline=$1
    change_tab_title $cmdline
}

if [[ -n $ZELLIJ ]]; then
    add-zsh-hook precmd set_tab_to_working_dir
    # add-zsh-hook preexec set_tab_to_command_line
fi
