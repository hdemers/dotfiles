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
        --status "~Closed" \
        --order-by status,updated \
        --type "~Epic" \
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
    
    # Read default project from config file.
    local default_project=$(\
        sed -n '/project:/,/ key:/ {s/\s*key:\s*\(\w*\)/\1/p}' \
        ~/.config/.jira/.config.yml \
    )
    if [[ -z "${1}" ]]; then
        read project"?Which project? [$default_project]: "
        if [[ -z "${project}" ]]; then
            local project=$default_project
        fi
    else
        local project=${1}
    fi

    if [[ -z "${2}" ]]; then
        read _epic_key"?Which epic? [enter to interactively choose]: "
        local epic_key=${_epic_key}
        if [[ -z "${epic_key}" ]]; then
            local epic_key=$(jira_epics $project)
        fi
    else
        local epic_key=${2}
    fi

    read capitalizable"?Capitalizable? [Y/n]: "
    if [[ -z "${capitalizable}" ]]; then
        local capitalizable="Yes"
    else
        case $capitalizable in
            yes|YES|Y|y) local capitalizable="Yes" ;;
            *) local capitalizable="No" ;;
        esac
    fi

    read acceptance_criteria"?Acceptance Criteria: "

    jira issue create \
        --template $GRUBHUB_DIR/.jira.tmpl \
        --type Story \
        --project $project \
        --parent $epic_key \
        --custom "capitalizable?"=$capitalizable \
        --custom "acceptance-criteria"=$acceptance_criteria
}

alias jsto="jira issues list --status ~Closed --order-by status,updated --type ~Epic" 

