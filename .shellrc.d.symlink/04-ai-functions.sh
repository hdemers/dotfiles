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

    reviewers=$(gum choose \
        --no-limit \
        --header="Select reviewers" \
        $(gh api orgs/grubhubprod/teams/mlops/members --jq '.[].login' | grep -v hdemers) 'I want more choice' )

    # If reviewers equals 'I want more choice', then start over with all members of that org
    if [ "${reviewers}" = "*I want more choice*" ]; then
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
    claude "/create-pr-jj"
    unset CLAUDE_BOOKMARK
    unset CLAUDE_REVIEWERS
    unset CLAUDE_JJ_BASE
    unset CLAUDE_PR_BASE

}

cticket() {
    # Have Claude create a JIRA ticket
    local bookmark
    local base="trunk()"
    local stacked=false
    local sprint
    local points
    local epic
    local assignee

    bookmark=$(_select_bookmark "" "Select a bookmark to create a JIRA ticket for:")

    if [ -z "$bookmark" ]; then
        gum log --level error "You must provide a bookmark."
        return 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --stacked)
                stacked=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    sprint=$(jira sprints \
        | grep DSSO \
        | cut -d '|' -f1,2 \
        | column -s '|' -t \
        | gum choose \
        | sed 's/  *active\|future.*//' \
    )

    points=$(gum choose "None" 0.5 1 2 3 5 8 13 --header="Select points for the ticket:")
    epic=$(jira issues -er \
        | fzf \
        --ansi \
        --header-lines=1 \
        --bind='enter:become(echo {1})' \
        --preview-window=up:50% \
        --preview='jira view --rich {1}' \
        --prompt='Select an epic for the ticket > ' \
    )

    assignee=$(gum choose "me" "<leave unassigned>" --header="Select assignee for the ticket:")

    if [ "${stacked}" = true ]; then
        base=$(_select_bookmark "" "Select a base bookmark for the stacked diffs:")
        if [ -z "$base" ]; then
            gum log --level error "You must provide a base."
            return 1
        fi
    fi

    export CLAUDE_BOOKMARK="${bookmark}"
    export CLAUDE_PR_BASE="${base}"
    export CLAUDE_TICKET_EPIC="${epic}"
    export CLAUDE_TICKET_SPRINT="${sprint}"
    export CLAUDE_TICKET_POINTS="${points}"
    export CLAUDE_TICKET_ASSIGNEE="${assignee}"
    export CLAUDE_TICKET_PROJECT="DSSO"

    gum confirm "$(printf 'Do you want to create a JIRA ticket for\nBookmark: %s\nEpic: %s\nSprint: %s\nPoints: %s\nAssignee: %s' "$bookmark" "$epic" "$sprint" "$points", "$assignee")" || {
        gum log --level info "Ticket creation cancelled."
        return 0
    }
    claude "/jj-ticket"
    unset CLAUDE_BOOKMARK
    unset CLAUDE_TICKET_EPIC
    unset CLAUDE_TICKET_SPRINT
    unset CLAUDE_TICKET_POINTS
    unset CLAUDE_PR_BASE
    unset CLAUDE_TICKET_ASSIGNEE
    unset CLAUDE_TICKET_PROJECT

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
    gum spin --spinner meter --title "Claude is describing your commit '${revset}'..." -- \
        claude "/describe ${revset}" | jj describe -r ${revset} --stdin
    unset CLAUDE_REVSET

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
