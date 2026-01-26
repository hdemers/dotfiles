---
allowed-tools: Bash(printenv:*), Bash(jj diff:*), Bash(jj log:*), Bash(jira:*), Bash(bash:*)
description: Create a ticket
---

## Standard Operating Procedure

1. MANDATORY: Run the jira-ticket skill. 
2. Create a ticket using the `jira` CLI and the context information found below.

## Context
- Current description: !`jj log -r "$AGENT_REVSET" -T description --no-graph`
- Current diff: !`jj diff --git -r "$AGENT_REVSET"`
- Project: !`printenv AGENT_TICKET_PROJECT`
- Type: !`printenv AGENT_TICKET_TYPE`
- Epic: !`printenv AGENT_TICKET_EPIC`
- Sprint: '!`printenv AGENT_TICKET_SPRINT`'
- Points: !`printenv AGENT_TICKET_POINTS`
- Assignee: !`printenv AGENT_TICKET_ASSIGNEE`
- Bug context: !`bash -c '[ -n "${AGENT_BUG_CONTEXT:-}" ] && { [ -f "$AGENT_BUG_CONTEXT" ] && cat "$AGENT_BUG_CONTEXT" || printf "%s" "$AGENT_BUG_CONTEXT"; } || echo "None"'`

## Command

`jira create --project <project> --type <type> --sprint <sprint> --summary <summary> --epic <epic> --points <points> --assignee <assignee> --description <description>`
