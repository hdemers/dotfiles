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

    # If there is a second argument and it is the word "mine", then only
    # display my stories.
    if [[ -n "${2}" ]] && [[ "${2}" == "mine" ]]; then
        local assignee=$(jira me)
        local columns="key,summary,status,"
    elif [[ -n "${2}" ]]; then
        local assignee=${2}
        local columns="key,summary,status,"
    else
        local assignee=""
        local columns="key,summary,status,assignee"
    fi

    jira issues list \
        --jql "project = $project" \
        --status "~Closed" \
        --assignee "$assignee" \
        --order-by status,updated \
        --type "~Epic" \
        --plain \
        --columns "$columns" \
        --no-headers \
        | fzf  \
        --bind 'enter:execute(echo {1})+abort' \
        --header="$project's open stories" \
        --preview="jira issue view {1}" \
        --preview-window=top
}

jira_move_story() {
    local issues
    if [[ -z "${1}" ]]; then
        issues=$(jira_sprint)
    else
        issues=$@
    fi

    if [[ -z "${issues}" ]]; then
        echo "No issue selected."
        return 1
    else
        echo "Moving issue(s) $issues"
    fi

    local state
    echo "Move all to state:\n"
    echo "1) Refined"
    echo "2) In Progress"
    echo "3) In Review"
    echo "4) Merged"
    echo "5) Done"
    
    read state"?New state: "
    
    case $state in
        1) state="Refine" ;;
        2) state="Start Dev" ;;
        3) state="Submit for Review" ;;
        4) state="Passed Review" ;;
        5) state="Close Issue" ;;
        *) echo "Invalid option"; return ;;
    esac

    # Move all issues found in the space separated list `issues` to the new
    # state `state`.
    for issue in $=issues; do
        echo -e "\n 🚚  Moving $issue to $state"
        jira issue move ${issue} ${state}
    done
}

jira_sprint() {
    # This function makes use of jira-cli, found here:
    #   https://github.com/ankitpokhrel/jira-cli

    export current_script=${(%):-%x}
    echo $current_script
    jira sprint list \
        --current \
        --assignee=$(jira me) \
        --status="~Closed" \
        --plain \
        --columns key,summary,status,updated \
        --no-headers \
        | fzf \
        --bind 'enter:execute(echo {+1})+abort' \
        --bind 'ctrl-m:execute("source $current_script; jira_move_story {+1}")' \
        --header="My sprint" \
        --preview="jira issue view {1}" \
        --preview-window=top \
        --multi
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

