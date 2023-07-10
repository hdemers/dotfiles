jira_epics() {
    # This function makes use of jira-cli, found here:
    #   https://github.com/ankitpokhrel/jira-cli
    # and fzf found here:
    #   https://github.com/junegunn/fzf
    if [[ -z "${1}" ]]; then
        echo "You must provide a project."
        return 1
    else
        local project=${1}
    fi

    jira issue list -tEpic --project $project \
        --plain --columns KEY,SUMMARY,STATUS,REPORTER --no-headers \
        | fzf  \
        --bind 'enter:execute(echo {1})+abort' \
        --header="Epics" \
        --preview="jira issue view {1}" \
        --preview-window=top
}

jira_stories() {
    # This function makes use of jira-cli, found here:
    #   https://github.com/ankitpokhrel/jira-cli
    # and fzf found here:
    #   https://github.com/junegunn/fzf
    if [[ -z "${1}" ]]; then
        echo "You must provide a project."
        return 1
    else
        local project=${1}
    fi

    jira issues list \
        --jql "project = $project" \
        --status ~Closed \
        --order-by status,updated \
        --type ~Epic \
        --plain \
        --columns key,summary,status,assignee,updated \
        --no-headers \
        | fzf  \
        --bind 'enter:execute(echo {1})+abort' \
        --header="$project's open stories" \
        --preview="jira issue view {1}" \
        --preview-window=top
}

jira_create_story() {
    # This function makes use of jira-cli, found here:
    #   https://github.com/ankitpokhrel/jira-cli
    if [[ -z "${1}" ]]; then
        echo "You must provide a project."
        return 1
    else
        local project=${1^^}
    fi

    if [[ -z "${2}" ]]; then
        local epic_key=$(jira_epics $project)
    else
        local epic_key=${2^^}
    fi


    jira issue create \
        --template $GRUBHUB_DIR/.jira.tmpl \
        --type Story \
        --project $project \
        --parent $epic_key
}

alias jsto="jira issues list --status ~Closed --order-by status,updated --type ~Epic" 

