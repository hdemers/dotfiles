###############################################################################
#
# Jujutsu related function definitions

_select_bookmark() {
    local bookmark="$1"
    local header=${2:-"Select a bookmark:"}

    if [ -z "${bookmark}" ]; then
        # Get bookmarks, clean up trailing '*', and present with gum
        bookmark=$(jj bookmark list -r "trunk():: ~ dev ~ trunk()" -T '"\n" ++ self.name()' \
            | uniq | gum choose --header="${header}")

        if [ -z "${bookmark}" ]; then
            # Ask if the user wants to create a new bookmark
            if gum confirm "No bookmark selected. Do you want to create a new bookmark?"; then
                bookmark=$(gum input --placeholder="Enter new bookmark name")
                if [ -z "${bookmark}" ]; then
                    gum log --level error "Error: Bookmark name cannot be empty"
                    return 1
                else
                    revset=$(gum input --placeholder="Enter revset (default: trunk())")
                    revset=${revset:-trunk()}
                    if ! jj log -r "${revset}" >/dev/null 2>&1; then
                        gum log --level error "Error: revset '${revset}' not found"
                        return 1

                    fi
                    if ! jj bookmark create -r "${revset}" "${bookmark}"; then
                        gum log --level error "Error: Failed to create bookmark '${bookmark}'"
                        return 1
                    fi

                fi
            fi
        fi
    else
        # Validate the provided bookmark
        if ! jj log -r "${bookmark}" >/dev/null 2>&1; then
            gum log --level error "Error: bookmark '${bookmark}' not found"
            return 1
        fi
        gum log --level info "Using bookmark: ${bookmark}"
    fi
    echo "${bookmark}"
}



jwa() {
    local branch="$1"

    # If no branch provided, use gum to select one
    if [ -z "${branch}" ]; then
        if ! command -v gum &> /dev/null; then
            echo "gum is not installed. Please provide a branch name or install gum."
            echo "Usage: jwa <branch>"
            return 1
        fi

        # Get bookmarks, clean up trailing '*', and present with gum
        branch=$(jj bookmark list -r "trunk():: ~ dev ~ trunk()" -T '"\n" ++ self.name()' \
            | uniq | gum choose --header="Select a branch to create workspace for:")

        if [ -z "${branch}" ]; then
            echo "No branch selected."
            return 1
        fi
    fi

    local workspace_path="../${branch}"

    # IF workspace directory already exists, return
    if [ -d "${workspace_path}" ]; then
        gum log -sl error "Workspace directory '${workspace_path}' already exists. Skipping creation."
        return 1
    fi

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
            gum log -sl info "No workspace selected."
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

_extract_ticket() {
    local change_id="$1"

    jj log -T builtin_log_compact_full_description -r "trunk()..${change_id}" \
            | grep -oE "[A-Z]+-[0-9]+" \
            | uniq
}

_jpreview() {
    local pr_number="$1"
    local change_id="$2"

    # Check that change_id exists. If not, try change_id@origin.
    if ! jj log -r "${change_id}" >/dev/null 2>&1; then
        if ! jj log -r "${change_id}@origin" >/dev/null 2>&1; then
            printf "\033[38;5;196mError: Change ID '%s' not found.\033[0m\n" "${change_id}"
            return 1
        else
            change_id="${change_id}@origin"
        fi
    fi

    if echo "$FZF_PROMPT" | grep -q "Pull"; then
        base=$(gh pr view "${pr_number}" --json baseRefName -q .baseRefName)
        jj log --color always -r "${base}..${change_id}" --stat -T builtin_log_detailed
        printf "\033[38;5;242m"
        printf "%*s" "${COLUMNS:-$(tput cols)}" "" | sed "s/ /─/g"
        printf "\033[0m\n"
        env GH_FORCE_TTY=1 gh pr view --comments "${pr_number}"
    else
        jira view --rich "$(_extract_ticket "${change_id}")"
    fi
}

jb(){
    local width=${COLUMNS:-$(tput cols)}

    # Fetch PR data once and store it
    local pr_data
    pr_data=$(env GH_FORCE_TTY="100%" gh pr list \
        --json number,title,headRefName,updatedAt,author \
        --template '{{range .}}{{printf "%v\t%s\t%s\t%s\t%s\n" .number .title .headRefName (timeago .updatedAt) .author.name}}{{end}}')

    # Calculate maximum branch name length (dynamic width)
    local max_branch_width
    max_branch_width=$(echo "$pr_data" | awk -F'\t' 'BEGIN {max=0} {if (length($3) > max) max=length($3)} END {print max}')

    # Set fixed column widths
    local branch_width=$max_branch_width  # Dynamic: never truncate
    local title_width=60                  # Fixed: truncate if longer
    local time_width=15                   # Fixed: truncate if longer
    local author_width=20                 # Fixed: truncate if longer

    echo "$pr_data" | awk -F'\t' -v tw="$title_width" -v bw="$branch_width" -v timew="$time_width" -v aw="$author_width" '{
        # Color codes
        reset = "\033[0m"
        pr_color = "\033[1;36m"      # Bright cyan for PR numbers
        title_color = "\033[1;37m"   # Bright white for titles
        branch_color = "\033[1;33m"  # Bright yellow for branches
        time_color = "\033[0;32m"    # Green for timestamps
        author_color = "\033[0;35m"  # Magenta for authors

        # Strip emojis and non-ASCII characters from title for proper alignment
        gsub(/[^\x00-\x7F]/, "", $2)

        # Truncate title and author if needed, but never truncate branch
        title = (length($2) > tw) ? substr($2, 1, tw-1) "…" : $2
        branch = $3  # Never truncate branch name
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
        --with-shell "$HOME/.local/bin/fzf-shell.sh" \
        --height 100% \
        --delimiter '\t' \
        --preview "_jpreview {1} {3}" \
        --bind "ctrl-i:become(jintegrate {1} {3})" \
        --bind "ctrl-b:become(jdeploy {3})" \
        --bind 'ctrl-w:execute-silent(gh pr view --web {1})' \
        --bind 'ctrl-s:transform:if echo "$FZF_PROMPT" | grep -q "Pull"; then echo "change-prompt(Ticket> )+refresh-preview"; else echo "change-prompt(Pull Request> )+refresh-preview"; fi' \
        --bind 'ctrl-m:become(pr-discussions {1} --human)' \
        --prompt 'Pull Request> ' \
        --border-label-pos 5:bottom \
        --border 'rounded' \
        --border-label '  ctrl-i: integrate | ctrl-b: deploy branch | ctrl-w: web | ctrl-s: toggle view | ctr-m: list comments'
}

_jjhistory() {
    jj log -T \
        "builtin_log_compact" \
        --color always \
        -r "::"
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
            | xargs -I % jira view  --rich %
    elif echo "$FZF_PROMPT" | grep -q "Diff"; then
        '"$change_id"' | xargs -I % jj diff --tool difft -r %
    fi'

    _jjhistory \
    | fzf  \
        --ansi \
        --highlight-line \
        --preview "$preview" \
        --preview-window 'top,60%' \
        --height 100% \
        --reverse \
        --prompt "::> " \
        --bind 'ctrl-s:transform:if echo "$FZF_PROMPT" | grep -qv "Ticket"; then echo "change-prompt(Ticket> )+refresh-preview"; else echo "change-prompt(::> )+refresh-preview"; fi' \
        --bind 'ctrl-c:execute('"$ticket"' | xargs -I % jira close %)' \
        --bind 'ctrl-d:transform:if echo "$FZF_PROMPT" | grep -qv "Diff"; then echo "change-prompt(Diff> )+refresh-preview"; else echo "change-prompt(::> )+refresh-preview"; fi' \
        --bind 'ctrl-e:execute(jj show $('"$change_id"'))+reload(. ~/.shellrc.d/05-jj-functions.sh && _jjhistory)' \
        --bind 'ctrl-/:execute(jj split -r $('"$change_id"'))+reload(. ~/.shellrc.d/05-jj-functions.sh && _jjhistory)' \
        --bind 'ctrl-x:execute(jj abandon -r $('"$change_id"'))+reload(. ~/.shellrc.d/05-jj-functions.sh && _jjhistory)' \
        --bind 'ctrl-w:execute(jj new -r $('"$change_id"'))+reload(. ~/.shellrc.d/05-jj-functions.sh && _jjhistory)' \
        --bind 'ctrl-t:execute(jj edit -r $('"$change_id"'))+reload(. ~/.shellrc.d/05-jj-functions.sh && _jjhistory)' \
        --bind 'ctrl-u:execute(jj undo)+reload(. ~/.shellrc.d/05-jj-functions.sh && _jjhistory)' \
        --bind 'enter:execute(echo $('"$change_id"') | tr -d '\n' | xsel --clipboard --input)+abort' \
        --bind 'ctrl-p,ctrl-k,up:up+up' \
        --bind 'ctrl-n,ctrl-j,down:down+down' \
        --preview-label-pos 5:bottom \
        --border 'rounded' \
        --preview-label '  ctrl-d: diff | ctrl-e: view | ctrl-x: abandon | ctrl-u: undo | ctrl-t: edit | ctrl-w: new | ctrl-/: split | ctrl-w: web | ctrl-s: toggle ticket | ctrl-c: close ticket' \
        --highlight-line \
        --color='bg+:#313244,bg:#1E1E2E,spinner:#F5E0DC,hl:#F38BA8' \
        --color='fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC' \
        --color='marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8' \
        --color='selected-bg:#45475A' \
        --color='border:#6C7086,label:#CDD6F4'
}

bcheck() {
    local bookmark="$1"
    jj diff --name-only -r "trunk()::${bookmark}" | grep -E ".py" | xargs ruff check
}

jjoplog() {
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
        --color='marker:#ff79c6,spinner:#ffb86c,header:#6272a4' \
        --border-label-pos 5:bottom \
        --border 'rounded' \
        --border-label ' ctrl-r: restore'
}

jjadopt() {
    jj log \
        --color always \
        -r 'untracked_remote_bookmarks()' \
        -T 'bookmarks ++ "|" ++ author.email() ++ "|" ++ committer.timestamp().local().format("%Y-%m-%d %H:%M") ++ "|" ++ description.first_line() ++ "\n"' \
        --no-graph \
    | column -t -s "|" \
    | gum choose --selected.background='#33001d' --cursor.background='#33001d' --no-limit --no-strip-ansi \
    | cut -d ' ' -f 1 \
    | xargs --no-run-if-empty printf ' -d %s' \
    | xargs --no-run-if-empty jj rdev
}

jjreview() {
    jj log \
        --color always \
        -r 'remote_bookmarks()' \
        -T 'bookmarks ++ "|" ++ author.name() ++ "|" ++ committer.timestamp().local().format("%Y-%m-%d %H:%M") ++ "|" ++ description.first_line() ++ "\n"' \
        --no-graph \
    | column -t -s "|" \
    | grep -v "Hugues" \
    | grep -v "master" \
    | grep -v "main" \
    | gum choose --selected.background='#33001d' --cursor.background='#33001d' --no-strip-ansi \
    | cut -d ' ' -f 1 \
    | xargs --no-run-if-empty jj new
}

jintegrate() {
    local pr_number="$1"
    local bookmark="$2"
    local ticket

    ticket=$(_extract_ticket "${bookmark}")

    if [ "$(jj log -r "${bookmark} & ~remote_bookmarks()" --no-graph | wc -l)" -gt 0 ]; then
        gum confirm "Bookmark ${bookmark} needs push first. Now?" \
            && jj git push -b "${bookmark}"
    fi

    cmd="jenkins integrate -p ${pr_number} \
       && jira close ${ticket} \
       && notify 'Pull Request ${pr_number} integrated and ticket ${ticket} closed.'"

    gum confirm "Integrate PR ${pr_number} (${bookmark}) and close ticket ${ticket}?" \
        && zellij_float_cmd "$cmd"


}

# Export functions for subshells, but only in bash (not zsh)
if [[ -n "$BASH_VERSION" ]]; then
    export -f _jpreview
    export -f jintegrate
    export -f _select_bookmark 
fi
