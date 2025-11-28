###############################################################################
#
# AI related function definitions

cpr() {
    # Have Claude create a pull request for a Jujutsu bookmark
    local bookmark=""
    local no_verify=false
    local no_push=false
    local stacked=false
    local jj_base="trunk()"
    local pr_base=$(git branch -r | grep -E 'origin/(main|master)$' | sed 's/.*\///')
    local empty_change_ids
    local ticket

    # Check prerequisites
    if ! _check_prerequisites; then return 1; fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-verify)
                no_verify=true
                shift
                ;;
            --no-push)
                no_push=true
                shift
                ;;
            --stacked)
                stacked=true
                shift
                ;;
            --help)
                echo "Usage: cpr [--no-verify] [--no-push] [--stacked] [bookmark]"
                echo ""
                echo "Options:"
                echo "  --no-verify    Skip precommit checks"
                echo "  --no-push      Do not push the bookmark before creating the PR"
                echo "  --stacked      Create a stacked PR (select a base bookmark)"
                echo "  --help         Show this help message"
                return 0
                ;;
            *)
                bookmark="$1"
                shift
                ;;
        esac
    done

    bookmark=$(_select_bookmark "${bookmark}")
    if [ -z "$bookmark" ]; then
        gum log --level error "You must provide a bookmark."
        return 1
    fi

    # If no_verify is set, skip precommit checks
    if [ "${no_verify}" = true ]; then
        gum log --level info "Skipping precommit checks."
    else
        jj precommit -r "trunk()..${bookmark}" || {
            gum log --level error "Precommit checks failed for bookmark '${bookmark}'."
            return 1
        }
    fi

    if [ "${stacked}" = true ]; then
        jj_base=$(_select_bookmark "" "Select a base bookmark for the stacked PR:")
        pr_base=${jj_base}
        if [ -z "$jj_base" ]; then
            gum log --level error "You must provide a base."
            return 1
        fi
    fi

    ticket=$(_extract_ticket "${bookmark}")

    reviewers=$(gum choose \
        --no-limit \
        --header="Select reviewers" \
        'None' $(gh api orgs/grubhubprod/teams/mlops/members --jq '.[].login' | grep -v hdemers) 'more...' )

    # If reviewers equals 'more...', then start over with all members of that org
    if [[ "${reviewers}" == *"more..."* ]]; then
        reviewers=$(gh api orgs/grubhubprod/members --jq '.[].login' --paginate | fzf --multi)
    fi

    reviewers=$(echo "${reviewers}" | tr '\n' ',' | sed 's/,$//')

    empty_change_ids=$(jj log -r "trunk()..${bookmark} & description(exact:'')" --no-graph -T 'change_id.short()')
    [ -n "${empty_change_ids}" ] && jj describe -r "${empty_change_ids}"

    if ! jj git push --bookmark "${bookmark}"; then
        gum log --level error "Failed to push bookmark '${bookmark}'."
        return 1
    fi

    export CLAUDE_BOOKMARK="${bookmark}"
    export CLAUDE_REVIEWERS="${reviewers}"
    export CLAUDE_JJ_BASE="${jj_base}"
    export CLAUDE_PR_BASE="${pr_base}"
    export CLAUDE_TICKET="${ticket}"
    export TMPDIR=/tmp/claude
    claude "/create-pr-jj"
    unset CLAUDE_TICKET
    unset CLAUDE_BOOKMARK
    unset CLAUDE_REVIEWERS
    unset CLAUDE_JJ_BASE
    unset CLAUDE_PR_BASE
    unset TMPDIR

}

cdescribe() {
    # Have Claude describe a Jujutsu commit
    local revset=$1
    local ticket_id=$2

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

    export CLAUDE_REVSET="${revset}"
    # This is a workaround for the fact that TMPDIR is not set correctly by
    # Claude Code when running in sandbox mode.
    # See https://github.com/anthropics/claude-code/issues/10952
    export TMPDIR=/tmp/claude
    gum spin --spinner meter --title "Claude is describing your commit '${revset}'..." -- \
        claude "/describe ${revset}" | jj describe -r "${revset}" --stdin
    unset CLAUDE_REVSET
    unset TMPDIR

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
