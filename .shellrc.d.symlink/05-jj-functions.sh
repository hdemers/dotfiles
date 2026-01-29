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
                    revset=$(gum input --placeholder="Enter revset (default: @)")
                    revset=${revset:-"@"}
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

jjoplog() {
    jj op log \
        -T 'self.id().short() ++ " " ++ self.time().start().ago() ++ " " ++ self.description() ++ "\n" ++ self.tags() ++ "\0"' \
        --color always \
        --no-graph \
        | fzf \
        --read0 \
        --ansi \
        --height 100% \
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

jd() {
    local bookmark=""
    local cmd=""

    bookmark=$(\
        jj log \
            -r "trunk()..dev" \
            -T 'if(bookmarks, bookmarks.map(|b| b.name()).join("\n") ++ "\n")' \
            --no-graph \
        | gum choose --header="Select bookmark to deploy:" \
    )

    if [ -z "${bookmark}" ]; then
        gum log --level error "No bookmark selected. Deployment cancelled."
        return 1
    fi

    if [ "$(jj log -r "${bookmark} & ~remote_bookmarks()" --no-graph | wc -l)" -gt 0 ]; then
        cmd="jj git push -b ${bookmark} && "
    fi

    cmd="${cmd}jenkins deploy-branch --branch ${bookmark} --no-unit-tests"

    name="DEPLOYING BOOKMARK ${bookmark}"

    zellij run -n "${name}" -x 10% -y 10% -f -- bash -ic "eval \"\$(direnv export bash)\"; $cmd"
}

# Export functions for subshells, but only in bash (not zsh)
if [[ -n "$BASH_VERSION" ]]; then
    export -f _select_bookmark
fi
