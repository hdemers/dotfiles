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

if [[ $CURRENT_SHELL = "zsh" ]]; then
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
                local cmd=$(echo "$CMD_TO_NOTIFY" | sed -E 's/([;&|]\s*)?notify\s*$//')
                notify "$cmd" "$LAST_EXIT_CODE"
            fi
            unset CMD_START_TIME CMD_TO_NOTIFY
        fi
    }

    add-zsh-hook preexec notify_preexec
    add-zsh-hook precmd notify_precmd

    notify() {
        local error_code="$?"
        local cmd
        if [[ -n "$1" ]]; then
            cmd="$1"
            error_code="${2:-$error_code}"
        else
            cmd="$CMD_TO_NOTIFY"
            # Remove trailing notify invocation if present
            cmd=$(echo "$cmd" | sed -E 's/([;&|]\s*)?notify\s*$//')
        fi
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
  selected=$(atuin search --reverse --format "{relativetime}\t{host}\t{exit}\t{command}" \
      | awk -F'\t' -v cols="$(tput cols)" '{ 
          time=sprintf("%-5s", $1);
          host=sprintf("%-20s", $2);
          exit_code=sprintf("%-3s", $3);
          # Calculate remaining space: total width - time(5) - host(20) - exit(3) - tabs(3) - margin(2)
          remaining = cols - 35;
          if (remaining < 10) remaining = 10;  # Minimum width for command
          
          cmd = $4;
          if (length(cmd) > remaining) {
              cmd = substr(cmd, 1, remaining - 3) "...";
          }
          
          printf "\033[36m%s\t\033[33m%s\t\033[32m%s\t\033[35m%s\033[0m\n", time, host, exit_code, cmd
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

    jira issues --current-sprint --mine  \
        | fzf \
        --height 90% \
        --ansi \
        --preview 'jira describe {1}' \
        --preview-window 'top,60%' \
        --header-lines 1 \
        --scheme history \
        --bind 'enter:execute(wl-copy {1})+abort' \
        --bind 'ctrl-t:execute(jira transition {1})+reload(jira issues)' \
        --bind 'ctrl-i:execute(jira create)+reload(jira issues)' \
        --bind 'ctrl-l:reload(jira issues --in-epic {1})+clear-query' \
        --bind 'ctrl-h:reload(jira issues)+clear-query' \
        --bind 'ctrl-e:reload(jira issues --epics-only)' \
        --bind "ctrl-w:execute(wl-copy ${url}/{1})" \
        --bind "ctrl-o:execute(${cmd} ${url}/{1})" \
        --border-label-pos 5:bottom \
        --border 'rounded' \
        --border-label '  ctrl-t: transition | ctrl-e: epics | ctrl-i: new | ctrl-l: in epic | ctrl-h: all | ctrl-w: copy url | ctrl-o: open url'
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

jwa() {
    local repo_name=$(basename $(jj workspace root))
    local branch="$1"

    # If no branch provided, use gum to select one
    if [ -z "${branch}" ]; then
        if ! command -v gum &> /dev/null; then
            echo "gum is not installed. Please provide a branch name or install gum."
            echo "Usage: jwa <branch>"
            return 1
        fi

        # Get bookmarks, clean up trailing '*', and present with gum
        branch=$(jj bookmark list -r "master:: ~ dev ~ master" -T '"\n" ++ self.name()' \
            | uniq | gum choose --header="Select a branch to create workspace for:")

        if [ -z "${branch}" ]; then
            echo "No branch selected."
            return 1
        fi
    fi

    local workspace_path="../${branch}"

    jj workspace add -r "${branch}" "${workspace_path}"
    gum log -sl info "Workspace ${branch} created at ${workspace_path}"
    # Return if the workspace already exists
    if [ $? -ne 0 ]; then
        gum log -sl error "Workspace '${workspace_path}' already exists. Skipping creation."
        return 1
    fi

    cd "${workspace_path}" || return 1
    # Copy .envrc from the main workspace if it exists
    if [ -f "${OLDPWD}/.envrc" ]; then
        cp "${OLDPWD}/.envrc" .
        gum log -sl info "file '.envrc' copied to new workspace."
        direnv allow .
    else
        gum log -sl warn "No '.envrc' file found in the main workspace."
    fi
    # Copy CLAUDE.local.md from the main workspace if it exists
    if [ -f "${OLDPWD}/CLAUDE.local.md" ]; then
        cp "${OLDPWD}/CLAUDE.local.md" .
        gum log -sl info "file 'CLAUDE.local.md' copied to new workspace."
    fi

    if [ -d "${OLDPWD}/.claude" ]; then
        # If the main workspace has a .claude directory, copy it to the new workspace
        cp -r "${OLDPWD}/.claude" .
        gum log -sl info "'.claude' directory copied to new workspace."
    fi

    if gum confirm "Do you want to run 'make install' in the new workspace?"; then
        make install
    else
        gum log -sl warn "'make install' skipped."
    fi

}

jwr() {
    # Git workspace Remove (jwr)
    # Removes a workspace above the current one, using jj workspace list for selection.

    local workspace_to_remove="$1"

    # If no workspace path provided, use gum to select one from existing workspaces
    if [ -z "${workspace_to_remove}" ]; then
        if ! command -v gum &> /dev/null; then
            echo "gum is not installed. Please provide a workspace path or install gum."
            echo "Usage: jwr <workspace_path>"
            return 1
        fi

        # Get workspace names, exclude 'default', and present with gum
        workspace_to_remove=$(jj workspace list \
            | awk -F: '{print $1}' \
            | grep -v '^default$' \
            | grep -v '^[[:space:]]*$' \
            | gum choose --header="Select a workspace to remove:")

        if [ -z "${workspace_to_remove}" ]; then
            gum log -sl error "No workspace selected."
            return 1
        fi
    fi

    local workspace_path="../${workspace_to_remove}"

    if [ ! -d "${workspace_path}" ]; then
        gum log -sl error "Workspace directory '${workspace_path}' does not exist."
        return 1
    fi

    jj workspace forget "${workspace_to_remove}"
    gum log -sl info "Workspace '${workspace_to_remove}' removed."
    gum log -sl info "Directory '${workspace_path}' was not deleted."
}

jb(){
    local ticket='
        jj log -T builtin_log_compact_full_description -r master..{3} \
            | grep -oE "[A-Z]+-[0-9]+" \
            | uniq'

    local combined_preview='
    if echo "$FZF_PROMPT" | grep -q "Pull"; then
        base=$(gh pr view {1} --json baseRefName -q .baseRefName);
        jj log --color always -r ${base}..{3} --stat -T builtin_log_detailed ;
        printf "\033[38;5;242m";
        printf "%*s" "${COLUMNS:-$(tput cols)}" "" | sed "s/ /─/g";
        printf "\033[0m\n";
        env GH_FORCE_TTY=1 gh pr view --comments {1}
    else
        '"$ticket"' | xargs -I % jira describe %
    fi'

    local integrate="
    ticket=\$(jj log -T builtin_log_compact_full_description -r master..{3} | grep -oE \"[A-Z]+-[0-9]+\" | uniq);
    if [ \$(jj log -r \"{3} & ~remote_bookmarks()\" --no-graph | wc -l) -gt 0 ]; then
        gum confirm \"Bookmark {3} needs push first. Now?\" && jj git push -b {3} && \\
        jenkins integrate -p {1}
    else
        gum confirm \"Integrate {3}?\" && jenkins integrate -p {1} && jira close \$ticket
    fi
    "

    local width=${COLUMNS:-$(tput cols)}
    local title_width=$((width * 40 / 100))    # 40% for title
    local branch_width=$((width * 25 / 100))   # 25% for branch
    local time_width=12                        # Fixed width for time
    local author_width=20                      # Fixed width for author

    env GH_FORCE_TTY="100%" gh pr list \
    --json number,title,headRefName,updatedAt,author \
    --template '{{range .}}{{printf "%v\t%s\t%s\t%s\t%s\n" .number .title .headRefName (timeago .updatedAt) .author.name}}{{end}}' \
    | awk -F'\t' -v tw="$title_width" -v bw="$branch_width" -v timew="$time_width" -v aw="$author_width" '{
        # Color codes
        reset = "\033[0m"
        pr_color = "\033[1;36m"      # Bright cyan for PR numbers
        title_color = "\033[1;37m"   # Bright white for titles
        branch_color = "\033[1;33m"  # Bright yellow for branches
        time_color = "\033[0;32m"    # Green for timestamps
        author_color = "\033[0;35m"  # Magenta for authors

        # Truncate and pad fields
        title = (length($2) > tw) ? substr($2, 1, tw-1) "…" : $2
        branch = (length($3) > bw) ? substr($3, 1, bw-1) "…" : $3
        author = (length($5) > aw) ? substr($5, 1, aw-1) "…" : $5

        # Format with fixed widths and preserve tabs
        printf "%s%-3s%s\t%s%-*s%s\t%s%-*s%s\t%s%-*s%s\t%s%-*s%s\n", 
               pr_color, $1, reset,
               title_color, tw, title, reset,
               branch_color, bw, branch, reset,
               time_color, timew, $4, reset,
               author_color, aw, author, reset
    }' \
    | fzf \
        --ansi \
        --preview-window 'top,90%' \
        --height 100% \
        --delimiter '\t' \
        --preview "$combined_preview" \
        --bind "ctrl-i:become($integrate)" \
        --bind 'ctrl-w:execute-silent(gh pr view --web {1})' \
        --bind 'ctrl-s:transform:if echo "$FZF_PROMPT" | grep -q "Pull"; then echo "change-prompt(Ticket> )+refresh-preview"; else echo "change-prompt(Pull Request> )+refresh-preview"; fi' \
        --prompt 'Pull Request> ' \
        --border-label-pos 5:bottom \
        --border 'rounded' \
        --border-label '  ctrl-i: integrate | ctrl-w: web | ctrl-s: toggle view'
}

function _jjhistory() {
    jj log -T \
        'change_id.shortest(8) ++ "|" ++ author.name() ++ "|" ++ committer.timestamp().local().format("%Y-%m-%d") ++ "|" ++ if(tags, tags.join(" ") ++ "|", "|") ++ commit_id.short(8) ++ "|" ++ if(description, description.first_line() ++ " ", "") ++ if(bookmarks, "(" ++ bookmarks.join(", ") ++ ")", "") ++ "\n"'\
        --color always \
        -r "::" \
    | column -t -s '|'
}


jh() {
    local change_id='echo {} | grep -oE  "\\b[k-z]+\\b" | head -1'
    local ticket='
        '"$change_id"' | xargs -I % jj log -T description --no-graph -r % \
            | grep -oE "[A-Z]+-[0-9]+" \
            | uniq'

    local preview='
    if echo "$FZF_PROMPT" | grep -q '::'; then
        '"$change_id"' | xargs --no-run-if-empty -I % jj lll -r % --color always
    elif echo "$FZF_PROMPT" | grep -q "Ticket"; then
        '"$change_id"' | xargs -I % jj log -T description --no-graph -r % \
            | grep -oE "[A-Z]+-[0-9]+" \
            | uniq \
            | xargs -I % jira describe %
    elif echo "$FZF_PROMPT" | grep -q "Diff"; then
        '"$change_id"' | xargs -I % jj diff --tool difft -r %
    fi'
    
    _jjhistory \
    | fzf  \
        --ansi \
        --preview "$preview" \
        --preview-window 'top,60%' \
        --height 100% \
        --reverse \
        --prompt "::> " \
        --bind 'ctrl-s:transform:if echo "$FZF_PROMPT" | grep -qv "Ticket"; then echo "change-prompt(Ticket> )+refresh-preview"; else echo "change-prompt(::> )+refresh-preview"; fi' \
        --bind 'ctrl-c:execute('"$ticket"' | xargs -I % jira close %)' \
        --bind 'ctrl-d:transform:if echo "$FZF_PROMPT" | grep -qv "Diff"; then echo "change-prompt(Diff> )+refresh-preview"; else echo "change-prompt(::> )+refresh-preview"; fi' \
        --bind 'ctrl-e:execute(jj describe $('"$change_id"'))+reload(. ~/.shellrc.d/03-functions.sh && _jjhistory)' \
        --bind 'ctrl-/:execute(jj split -r $('"$change_id"'))+reload(. ~/.shellrc.d/03-functions.sh && _jjhistory)' \
        --bind 'ctrl-x:execute(jj abandon -r $('"$change_id"'))+reload(. ~/.shellrc.d/03-functions.sh && _jjhistory)' \
        --bind 'ctrl-w:execute(jj new -r $('"$change_id"'))+reload(. ~/.shellrc.d/03-functions.sh && _jjhistory)' \
        --bind 'ctrl-t:execute(jj edit -r $('"$change_id"'))+reload(. ~/.shellrc.d/03-functions.sh && _jjhistory)' \
        --bind 'ctrl-u:execute(jj undo)+reload(. ~/.shellrc.d/03-functions.sh && _jjhistory)' \
        --bind 'enter:execute(echo $('"$change_id"') | tr -d '\n' | xsel --clipboard --input)+abort' \
        --preview-label-pos 5:bottom \
        --border 'rounded' \
        --preview-label '  ctrl-d: diff | ctrl-e: describe | ctrl-x: abandon | ctrl-u: undo | ctrl-t: edit | ctrl-w: new | ctrl-/: split | ctrl-w: web | ctrl-s: toggle ticket | ctrl-c: close ticket' \
        --highlight-line \
        --color='fg:#f8f8f2,bg:#282a36,hl:#bd93f9' \
        --color='fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9' \
        --color='info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6' \
        --color='marker:#ff79c6,spinner:#ffb86c,header:#6272a4'
}

bcheck() {
    local bookmark="$1"
    jj diff --name-only -r "trunk()::${bookmark}" | grep -E ".py" | xargs ruff check
}

jop() {
    jj op log \
        -T 'self.id().short() ++ " " ++ self.time().start().ago() ++ " " ++ self.description() ++ "\n" ++ self.tags() ++ "\0"' \
        --color always \
        --no-graph \
        | fzf \
        --read0 \
        --ansi \
        --highlight-line \
        --preview 'jj op show {1} --summary --color always' \
        --bind 'ctrl-r:become(jj op restore {1})' \
        --border-label 'ctrl-r: restore' \
        --border-label-pos 5:bottom \
        --border rounded \
        --border-label 'Jujutsu Op Log' \
        --border-label-pos 5:top \
        --preview-border left \
        --color='fg:#f8f8f2,bg:#282a36,hl:#bd93f9' \
        --color='fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9' \
        --color='info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6' \
        --color='marker:#ff79c6,spinner:#ffb86c,header:#6272a4'
}

lsemr() {
    local ip=$(listemr | \
    fzf \
    --header-lines=1 \
    --preview='listemr describe {1}' \
    --preview-window=up:50% \
    --bind='ctrl-o:execute(browse http://{4}:8088 > /dev/null)' \
    --bind='enter:execute(echo {4} | tr -d \"\\n\" | xsel --clipboard --input)+become(echo {4})' \
    --height 50%)

    export GDP_SPARK_CLUSTER_IP="$ip"
}
