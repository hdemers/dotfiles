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
    local FROM
    local TO
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

# If either CURRENT_SHELL or SHELL is zsh, then...
if [[ "$CURRENT_SHELL" == "zsh" || "$SHELL" == *zsh* ]]; then
    NOTIFY_THRESHOLD=120

    notify_preexec() {
        export CMD_START_TIME=$EPOCHSECONDS
        export CMD_TO_NOTIFY="$1"
    }

    notify_precmd() {
        export LAST_EXIT_CODE=$?
        if [[ -n "$CMD_START_TIME" && -n "$CMD_TO_NOTIFY" ]]; then
            local elapsed=$((EPOCHSECONDS - CMD_START_TIME))
            if (( elapsed > NOTIFY_THRESHOLD )); then
                local cmd=$(echo "$CMD_TO_NOTIFY" | sed -E 's/([;&|]\s*)?_notify\s*$//')
                _notify "$cmd" "$LAST_EXIT_CODE"
            fi
            unset CMD_START_TIME CMD_TO_NOTIFY
        fi
    }

    add-zsh-hook preexec notify_preexec
    add-zsh-hook precmd notify_precmd

    _notify() {
        local error_code="$?"
        local cmd
        if [[ -n "$1" ]]; then
            cmd="$1"
            error_code="${2:-$error_code}"
        else
            cmd="$CMD_TO_NOTIFY"
            # Remove trailing notify invocation if present
            cmd=$(echo "$cmd" | sed -E 's/([;&|]\s*)?_notify\s*$//')
        fi
        # If command contains one of the following substrings, do not send notifications.
        local ignore_list=("ssh" "vim" "nvim" "lsemr" "js" "claude" "jb" "jj")

        for ignore in "${ignore_list[@]}"; do
            if [[ "$cmd" == *"$ignore"* ]]; then
                return
            fi
        done
        if [ "$error_code" -eq 0 ]; then
            ntfy "$cmd" -H "X-Title: Success" -H "Tags: heavy_check_mark"
        else
            ntfy "$cmd" -H "X-Title: Fail" -H "Tags: x"
        fi
        return "$error_code"
    }
fi

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
        "$@" \
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
  selected=$(atuin search --exit 0 --reverse --format "{relativetime}\t{time}\t{host}\t{exit}\t{command}" \
      | awk -F'\t' -v cols="$(tput cols)" '{
          reltime=sprintf("%-5s", $1);
          datetime=sprintf("%-16s", $2);
          host=sprintf("%-20s", $3);
          exit_code=sprintf("%-3s", $4);
          # Calculate remaining space: total width - reltime(5) - datetime(16) - host(20) - exit(3) - tabs(4) - margin(2)
          remaining = cols - 52;
          if (remaining < 10) remaining = 10;  # Minimum width for command

          cmd = $5;
          if (length(cmd) > remaining) {
              cmd = substr(cmd, 1, remaining - 3) "...";
          }

          printf "\033[36m%s\t\033[36m%s\t\033[33m%s\t\033[32m%s\t\033[35m%s\033[0m\n", reltime, datetime, host, exit_code, cmd
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


rpq() {
    if ! command -v duckdb &> /dev/null; then
        echo "duckdb is not installed. Please install it first."
        return 1
    fi

    if [ -z "$1" ]; then
        echo "Usage: rpq <file>"
        return 1
    fi

    local file=${1}
    local query=""

    # If $1 is a directory use glob pattern
    if [ -d "$file" ]; then
        file="${file}/**/*.parquet"
    fi

    local row_count=$(duckdb -ascii -c "select count(*) as Rows from read_parquet('${file}');")
    echo "Row count: ${row_count}"

    duckdb -c "select * from read_parquet('${file}', hive_partitioning=true) limit 10;"
    duckdb -c "describe select * from read_parquet('${file}', hive_partitioning=true);"

    echo "Parquet metadata for ${file}:"
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
            | xargs -I % jira view --rich %"

    git rb | \
        fzf \
        --prompt 'Local Branches> ' \
        --ansi \
        --height=60% \
        --header-lines=1 \
        --border-label='  ctrl-r: toggle remote | ctrl-e: delete | ctrl-w: open web | ctrl-t: add as worktree | ctrl-i: show graph | ctrl-s: show ticket | ctrl-g: show message' \
        --border-label-pos=5:bottom \
        --border='rounded' \
        --preview='GH_FORCE_TTY="100%" gh pr view --comments $(echo {1} | \
            tr -d "*" | \
            sed "s|^origin/||") || \
            git show --stat --color=always $(echo {1} | tr -d "*" | sed "s|^origin/||")' \
        --preview-window=border-none,top,75% \
        --bind 'enter:execute(echo {1} | tr -d "*" | sed "s|^origin/||" | xargs --no-run-if-empty git sw )+reload(git rb)' \
        --bind 'ctrl-e:execute-silent(git br -D {1})+reload(git rb)' \
        --bind 'ctrl-r:transform:[[ ! $FZF_PROMPT =~ "Local" ]] &&
              echo "change-prompt(Local Branches> )+reload(git rb)" ||
              echo "change-prompt(All Branches> )+reload(git rba)"' \
        --bind 'ctrl-t:execute(gwa)+abort' \
        --bind 'ctrl-w:execute-silent(gh pr view --web {1})' \
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
        --bind 'ctrl-g:preview(git show --stat --color=always $(echo {1} | tr -d "*" | sed "s|^origin/||"))'
}

gwa() {
    # Git Worktree Add (gwa)
    # This function adds a new worktree for a given branch in the parent directory.
    # If the branch already exists, it will add the worktree without creating a new branch.
    # If no branch is provided, it will use gum to present a choice of branches.

    local repo_name=$(basename $(git rev-parse --show-toplevel))
    local branch="$1"

    # If no branch provided, use gum to select one
    if [ -z "${branch}" ]; then
        if ! command -v gum &> /dev/null; then
            echo "gum is not installed. Please provide a branch name or install gum."
            echo "Usage: gwa <branch>"
            return 1
        fi

        # Get local branches sorted by commit date (similar to git rb alias)
        branch=$(git for-each-ref --sort=-committerdate refs/heads --format='%(refname:short)' | gum choose --header="Select a branch to create worktree for:")

        if [ -z "${branch}" ]; then
            echo "No branch selected."
            return 1
        fi
    fi

    local worktree_path="../${branch}"

    if git rev-parse --verify --quiet "${branch}"; then
        echo "Branch '${branch}' already exists. Adding worktree without creating a new branch."
        git worktree add "${worktree_path}" "${branch}"
    else
        echo "Branch '${branch}' does not exist. Creating new branch and adding worktree."
        git worktree add "${worktree_path}" -b "${branch}"
    fi
    cd "${worktree_path}" || return 1
    # Copy .envrc from the main worktree if it exists
    if [ -f "${OLDPWD}/.envrc" ]; then
        cp "${OLDPWD}/.envrc" .
        echo ".envrc copied to new worktree."
        direnv allow .
    else
        echo "No .envrc file found in the main worktree."
    fi
}

gwr() {
    # Git Worktree Remove (gwr)
    # This function removes a worktree situated in a directory above the current one.
    # If no worktree path is provided, it will use gum to present a choice of existing worktrees.
    local worktree_to_remove="$1"

    # If no worktree path provided, use gum to select one from existing worktrees
    if [ -z "${worktree_to_remove}" ]; then
        if ! command -v gum &> /dev/null; then
            echo "gum is not installed. Please provide a worktree path or install gum."
            echo "Usage: gwr <worktree_path>"
            return 1
        fi

        # Get existing worktrees and extract only the path (first column)
        # Skip the main worktree (current directory) and show only additional worktrees
        local current_worktree=$(git rev-parse --show-toplevel)
        worktree_to_remove=$(\
            git worktree list | \
            gum choose --header="Select a worktree to remove:")

        if [ -z "${worktree_to_remove}" ]; then
            echo "No worktree selected."
            return 1
        fi
    fi

    if [ ! -d "${worktree_to_remove}" ]; then
        echo "Worktree '${worktree_to_remove}' does not exist."
        return 1
    fi

    git worktree remove "${worktree_to_remove}"
}


lsemr() {
    local ip=$(listemr | \
    fzf \
    --ansi \
    --header-lines=1 \
    --preview='listemr describe {1}' \
    --preview-window=up:75% \
    --bind='ctrl-h:execute(browse http://{4}:8088 > /dev/null)' \
    --bind='ctrl-g:execute(browse http://{4}/ganglia > /dev/null)' \
    --bind='ctrl-s:execute(sshpass -eOKTA_PASSWORD ssh {4})+abort' \
    --bind='ctrl-i:execute(source $HOME/.shellrc.d/99-remote.sh; remote_setup {4})' \
    --bind='enter:execute(echo {4} | tr -d \"\\n\" | xsel --clipboard --input)+become(echo {4})' \
    --height 50% \
    --border-label-pos 5:bottom \
    --border rounded \
    --border-label 'ctrl-h: Hadoop UI | ctrl-s: ssh | ctrl-g: Ganglia | ctrl-i: install dotfiles' \
    --preview-border 'none'
    )

    export GDP_SPARK_CLUSTER_IP="$ip"
    export REMOTE_SPARK_IP="$ip"
}

_check_prerequisites() {
    if ! command -v gum &> /dev/null; then
        echo "gum is not installed. Install it with 'brew install gum'."
        return 1
    fi

    if ! command -v gh &> /dev/null; then
        echo "gh (GitHub CLI) is not installed. Install it with 'brew install gh'."
        return 1
    fi

}

zellij_float_cmd() {
    local cmd="$1"
    zellij run -x 10% -y 10% -f -- bash -ic "eval \"\$(direnv export bash)\"; $cmd"
}

js() {
    local url="${JIRA_SERVER_URL}/browse"
    local container_name="${DBX_CONTAINER_NAME}"
    local cmd='xdg-open'
    if [ -n "$container_name" ]; then
        if [ -n "$CONTAINER_ID" ]; then
            cmd="gtk-launch google-chrome.desktop"
        else
            cmd="gtk-launch ${container_name}-google-chrome.desktop"
        fi
    fi

    jira issues -r --current-sprint --mine  \
        | fzf \
        --height 90% \
        --ansi \
        --preview 'jira view -r {1}' \
        --preview-window 'top,60%' \
        --header-lines 1 \
        --scheme history \
        --bind 'enter:execute(wl-copy {1})+abort' \
        --bind 'ctrl-t:execute(jira transition --interactive {1})+reload(jira issues -r)' \
        --bind 'ctrl-i:execute(jira create)+reload(jira issues -r)' \
        --bind 'ctrl-l:reload(jira issues -r --in-epic {1})+clear-query' \
        --bind 'ctrl-h:reload(jira issues -r)+clear-query' \
        --bind 'ctrl-e:reload(jira issues -r --epics-only)' \
        --bind 'ctrl-r:reload(jira issues -r --programs-only)' \
        --bind "ctrl-y:execute(wl-copy ${url}/{1})" \
        --bind "ctrl-o:execute(${cmd} ${url}/{1})" \
        --bind "ctrl-u:execute(jira update {1})" \
        --bind "ctrl-s:reload(jira issues -r --current-sprint --mine)" \
        --border-label-pos 5:bottom \
        --border 'rounded' \
        --border-label '  ctrl-s: mine | ctrl-t: transition | ctrl-e: epics | ctrl-r: programs | ctrl-i: new | ctrl-l: to epic | ctrl-j: all | ctrl-y: yank url | ctrl-o: open url | ctrl-u: update'
}

# Export functions for subshells, but only in bash (not zsh)
if [[ -n "$BASH_VERSION" ]]; then
    export -f ntfy
fi
