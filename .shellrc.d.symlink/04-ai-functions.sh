###############################################################################
#
# AI related function definitions

_extract_ticket() {
    local change_id="$1"
    local base="${2:-trunk()}"

    jj log -T builtin_log_compact_full_description -r "${base}..${change_id}" \
        | grep -oE "[A-Z]+-[0-9]+" \
        | uniq
}

mdescribe() {
    # Have Claude describe a Jujutsu commit
    local revset=$1
    local ticket_id=$2
    local prompt

    # If the first argument is not a revset (does not contain :: or ..), assume
    # it's a change ID and expand it.
    if [[ "$revset" != *"::"* && "$revset" != *".."* ]]; then
        # If the first argument is a change ID, expand it to a revset.
        revset=$(jj log -r "$revset" --template "self.change_id()" --no-graph)
    fi

    # Validate mandatory first argument
    if [ -z "$revset" ]; then
        gum log --level error "Error: revset is required as the first argument"
        gum log --level info "Usage: cdescribe <revset> [ticket_id]"
        return 1
    fi

    if ! jj log -r "${revset}" >/dev/null 2>&1; then
        gum log --level error "Error: revset '${revset}' not found"
        return 1
    fi

    prompt=$(cat << EOF
Provide a concise, clear, and descriptive commit message for the following code changes.
Use conventional commit format and the gitmoji standard.

Make sure to abide by this template:

<emoji><type>(<scope>): <summary>

<body>


where:
  summary, one line, maximum of 50 characters.
  body for complex changes explaining why, limit lines to 79 characters.

Best practices:
- Limit the title of commit messages to 50 characters and the body to 79.
- The title should summarize the most impactful change.
- The body should expand on the title, and also explain the other smaller changes.
- Write in imperative mood ("Add feature" not "Added feature")
- Explain why, not just what.
EOF
)

    gum log --level info "Using API key: ${ANTHROPIC_API_KEY}"
    gum spin --spinner meter --title "Claude is describing your commit '${revset}'..." -- \
        jj diff --git -r "${revset}" | mods --role commit --prompt "${prompt}" | jj describe -r "${revset}" --stdin

    # Modify the description of the commit to add the ticket ID on the last line
    if [ -n "$ticket_id" ]; then
        gum log --level info "Adding ticket ID: ${ticket_id}"

        # Get current description and check if operation succeeded
        if ! description=$(jj log -r "${revset}" --template description --no-graph 2>/dev/null); then
            gum log --level error "Error: failed to get commit description"
            return 1
        fi

        # Add ticket ID to description
        new_description="${description}"$'\n\n'"${ticket_id}"

        # Update commit description
        if jj describe -r "${revset}" -m "${new_description}" >/dev/null 2>&1; then
            gum log --level info "Successfully updated commit description with ticket ID"
        else
            gum log --level error "Error: failed to update commit description"
            return 1
        fi
    fi

    jj log -r "${revset}" --color always --no-graph \
        -T 'self.change_id().shortest(8) ++ "\n" ++ self.description()'

    gum confirm "Edit description?" && jj describe -r "${revset}"
}

clauded() {
# This is a fix for a known bug in Claude Code when running in sandbox mode.
# See https://github.com/anthropics/claude-code/issues/10952
export TMPDIR=/tmp/claude
# Call claude with all remaining arguments 
claude --dangerously-skip-permissions "$@"
unset TMPDIR

}
