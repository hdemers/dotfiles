###############################################################################
#
# Function definitions


tailf() {
    # tail -f with color (through batcat)
    tail -f $1 | bat --paging=never -l log
}

installkernel() {
    # Install an ipython kernel.
    if ! pip list | grep ipykernel; then
        pip install ipykernel
    fi
    python -m ipykernel install --user --name $(basename $VIRTUAL_ENV) --display-name $(basename $VIRTUAL_ENV)
}

releasemsg() {
    # Outputs a message suitable for a release description. This script
    # optionally takes a FROM tag and a TO tag as command line parameter to
    # diff from. The release message will include commits from $FROM to $TO if
    # provided. FROM defaults to the latest tag on the *current* branch and TO
    # defaults to HEAD.
    if [ -z "$1" ]
    then
        FROM=$(git tag --sort=taggerdate | tail -n1)
    else
        FROM=$1
    fi

    if [ -z "$2" ]
    then
        TO=HEAD
    else
        TO=$2
    fi

    repo=$(git config --get remote.origin.url | cut -d : -f 2 | cut -d . -f 1)
    URL="https://github.com/${repo}/commit"
    git log --reverse $FROM..$TO --no-merges --format="**%s (%h)**%n%n%b%n"
}

ntfy() {
    message=$1

    curl -s \
        "${@:2}" \
        -d "${message}" \
        ntfy.sh/hdemers \
        > /dev/null
}

notify() {
    error_code=$?

    cmd=$(history | tail -n1 | sed -e 's/^\s*[0-9]\+\s*//;s/[;&|]\s*notify$//')

    if [ ${error_code} -eq 0 ]; then
        ntfy "${cmd}" -H "X-Title: Success" -H "Tags: heavy_check_mark"
    else
        ntfy "${cmd}" -H "X-Title: Fail" -H "Tags: x"
    fi
    return $error_code
}

# 1. Search for text in files using Ripgrep
# 2. Interactively narrow down the list using fzf
# 3. Open the file in Vim
rfv() {
    # If there are no argument provided to this function, exit with a proper
    # error message.
    if [ -z "$1" ]; then
        echo "Usage: rfv <search term>"
        return 1
    fi
    rg \
        --color=always \
        --no-ignore \
        --line-number \
        --no-heading \
        --smart-case \
        --hidden \
        "${*}" \
            | \
        fzf --ansi \
        --color='hl:#268BD2,hl+:reverse' \
        --delimiter=: \
        --preview='bat \
            --force-colorization {1} \
            --highlight-line {2} \
            --style=numbers,changes \
            --theme=OneHalfDark' \
        --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
        --bind='enter:become(vim {1} +{2})' \
        --bind='ctrl-x:execute(rm {1})'
}

# CTRL-R - Paste the selected command from history into the command line
custom-atuin-history-widget() {
  local selected num
  setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2> /dev/null
  selected=( $(atuin history list --reverse false --format "{time} \t {duration} \t {command}" \
      | tspin \
      | fzf -d '|' --bind 'enter:execute(echo {3})+abort' --ansi --delimiter='\t') )
  local ret=$?
  if [ -n "$selected" ]; then
    num=$selected[1]
    if [ -n "$num" ]; then
      zle vi-fetch-history -n $num
    fi
  fi
  zle reset-prompt
  return $ret
}
zle     -N            custom-atuin-history-widget
bindkey -M emacs '^R' custom-atuin-history-widget
bindkey -M vicmd '^R' custom-atuin-history-widget
bindkey -M viins '^R' custom-atuin-history-widget


checkoutworktree() {
    # Checkout a worktree from a branch
    if [ -z "$1" ]; then
        echo "Usage: checkoutworktree <branch>"
        return 1
    fi

    # Check there is a worktrees directory in the current directory.
    if [ ! -d worktrees ]; then
        echo "No worktrees directory found. Please create one first."
        return 1
    fi

    local branch=$1

    # If the `branch` does not start with origin/, prepend it.
    if [[ ! $branch == origin/* ]]; then
        branch="origin/${branch}"
    fi

    echo 'Checking out worktree for branch:' ${branch}
    echo ${branch} | awk -F'/' '{print $2}' | xargs -I {} git worktree add --track -b {} worktrees/{} origin/{}
}
