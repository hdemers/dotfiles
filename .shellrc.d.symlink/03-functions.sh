###############################################################################
#
# Function definitions


tailf() {
    # tail -f with color (through batcat)
    tail -f $1 | bat --paging=never -l log
}

installkernel() {
    if ! uv pip list | grep ipykernel; then
        uv pip install ipykernel
    fi
    local name=$(basename `pwd`)
    python -m ipykernel install --user --name ${name} --display-name ${name}
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
    message=$(git log --reverse $FROM..$TO --no-merges --format="**%s (%h)**%n%n%b%n")
    echo "$message"
    echo "$message" | wl-copy

}

ntfy() {
    message=$1

    curl -s \
        "${@:2}" \
        -d "${message}" \
        ntfy.sh/${NTFY_NEPTUNE_CHANNEL} \
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
        --glob !'*.{venv,ruff_cache,pytest_cache,mypy_cache,tox}' \
        --glob !'{__pycache__}' \
        --hidden \
        "${*}" \
            | \
        fzf --ansi \
        --color='hl:#268BD2,hl+:reverse' \
        --delimiter=: \
        --preview='bat \
            --force-colorization {1} \
            --highlight-line {2} \
            --style=numbers,changes' \
        --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
        --height 100% \
        --bind='enter:become(nvim {1} +{2})' \
        --bind='ctrl-x:execute(rm {1})'
}

# CTRL-R - Paste the selected command from history into the command line
custom-atuin-history-widget() {
  local selected
  setopt localoptions noglobsubst noposixbuiltins pipefail no_aliases 2> /dev/null
  selected=$(atuin search --reverse --format "{relativetime}\t{host}\t{command}" \
      | awk -F'\t' '{ 
          time=sprintf("%-5s", $1);
          host=sprintf("%-20s", $2);
          printf "\033[36m%s\033[0m\t\033[33m%s\033[0m\t%s\n", time, host, $3
        }' \
      | fzf --ansi --delimiter='\t' \
          --bind 'tab:execute-silent(echo paste)+abort' \
          --bind 'enter:execute-silent(echo execute)+abort' \
          --expect=tab,enter \
          )
  local ret=$?
  if [ -n "$selected" ]; then
    local key=$(head -1 <<< "$selected")
    local cmd=$(tail -n1 <<< "$selected")
    BUFFER="${cmd##*$'\t'}"
    if [[ "$key" == "enter" ]]; then
      zle accept-line
    fi
  fi
  zle reset-prompt
  return $ret
}

# Only works in Zsh
if [[ -n "$ZSH_VERSION" ]]; then
  zle -N custom-atuin-history-widget
  bindkey '^R' custom-atuin-history-widget
fi


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

rpq() {
    if ! command -v duckdb &> /dev/null; then
        echo "duckdb is not installed. Please install it first."
        return 1
    fi

    if [ -z "$1" ]; then
        echo "Usage: rpq <query>"
        return 1
    fi

    local file=${1}
    local query=""

    # If $1 is a directory use glob pattern
    if [ -d "$file" ]; then
        file="${file}/**/*.parquet"
    fi

    duckdb -c "select * from read_parquet('${file}') limit 10;"
    duckdb -c "describe select * from read_parquet('${file}') limit 10;"
    duckdb -c "select column_id \
        , path_in_schema \
        , num_values \
        , stats_min \
        , stats_max \
        , stats_null_count \
        , stats_distinct_count \
        , stats_min_value \
        , stats_max_value \
        from parquet_metadata('${file}');"
}

gb() {
    local story="git show --quiet --pretty=format:\"%s %b\" {1} \
            | grep -oE \"[A-Z]+-[0-9]+\" \
            | xargs -I % jira describe %"

    git rb | \
        fzf \
        --prompt 'Local Branches> ' \
        --ansi \
        --height=60% \
        --header-lines=1 \
        --border-label='  ctrl-r: toggle remote | ctrl-e: delete | ctrl-w: open web | ctrl-t: add as worktree | ctrl-i: show graph | ctrl-s: show ticket | ctrl-m: show message' \
        --border-label-pos=5:bottom \
        --border='rounded' \
        --preview='GH_FORCE_TTY="100%" gh pr view --comments $(echo {1} | \
            tr -d "*" | \
            sed "s|^origin/||") || \
            git show --stat --color=always $(echo {1} | tr -d "*" | sed "s|^origin/||")' \
        --preview-window=border-none,top,75% \
        --bind 'enter:execute(\
            echo {1} | \
            tr -d "*" | \
            sed "s|^origin/||" | \
            xargs --no-run-if-empty git sw )+abort' \
        --bind 'ctrl-e:execute-silent(git br -D {1})+reload(git rb)' \
        --bind 'ctrl-r:transform:[[ ! $FZF_PROMPT =~ "Local" ]] &&
              echo "change-prompt(Local Branches> )+reload(git rb)" ||
              echo "change-prompt(All Branches> )+reload(git rba)"' \
        --bind 'ctrl-t:execute(\
            awk -F"/" '"'"'{print \$NF}'"'"' <<< {1} | \
            xargs -I {} git worktree add --track -b {} worktrees/{} origin/{})+abort' \
        --bind 'ctrl-w:execute-silent(gh pr view --web)' \
        --bind 'ctrl-i:preview(git log \
            --color=always \
            --graph \
            --pretty=format:"%C(yellow)%d%Creset %s %C(magenta)(%cr) %C(blue)[%an]%Creset %Cgreen%h%Creset" \
            --abbrev-commit \
            --date=relative \
            --branches \
            --remotes \
            )' \
        --bind "ctrl-s:preview($story)" \
        --bind 'ctrl-m:preview(git show --stat --color=always $(echo {1} | tr -d "*" | sed "s|^origin/||"))'
}


js() {
    jira issues \
        | fzf \
        --ansi \
        --height=60% \
        --preview='jira describe {1}' \
        --preview-window='top,50%' \
        --header-lines=1 \
        --scheme=history \
        --bind 'ctrl-t:execute(jira transition {1})+reload(jira issues)' \
        --bind 'ctrl-i:execute(jira create)+reload(jira issues)' \
        --bind 'ctrl-l:reload(jira issues -i {1})+clear-query' \
        --bind 'ctrl-h:reload(jira issues)+clear-query' \
        --bind 'ctrl-e:reload(jira issues --epics-only)' \
        --border-label-pos=5:bottom \
        --border='rounded' \
        --border-label='  ctrl-t: transition | ctrl-e: epics | ctrl-i: new | ctrl-l: in epic | ctrl-h: all | '
}

jsc() {
    jira issues --current-sprint --mine \
        | fzf \
        --ansi \
        --height=40% \
        --preview='jira describe {1}' \
        --preview-window='top,80%' \
        --header-lines=1 \
        --scheme=history
}

jse() {
    jira issues --epics-only \
        | fzf \
        --ansi \
        --height=60% \
        --preview='jira describe {1}' \
        --preview-window='top,60%' \
        --header-lines=1 \
        --scheme=history \
        --bind 'ctrl-t:execute(jira transition {1})+reload(jira issues)' \
        --bind 'ctrl-i:execute(jira create)+reload(jira issues)' \
        --bind 'ctrl-l:reload(jira issues -i {1})+clear-query' \
        --bind 'ctrl-h:reload(jira issues)+clear-query' \
        --bind 'ctrl-e:reload(jira issues --epics-only)'
}
