---
allowed-tools: Bash(printenv:*), Bash(jj diff:*), Bash(jj log:*), Bash(jira:*)
description: Create a ticket
model: sonnet
---

## Standard Operating Procedure

1. Run the jira-ticket skill. 
2. Create a ticket using the `jira` CLI and the context information found below.

## Context
- Current description: !`jj log -r "$AGENT_REVSET" -T description --no-graph`
- Current diff: !`jj diff --git -r "$AGENT_REVSET"`
- Project: !`printenv AGENT_TICKET_PROJECT`
- Epic: !`printenv AGENT_TICKET_EPIC`
- Sprint: '!`printenv AGENT_TICKET_SPRINT`'
- Points: !`printenv AGENT_TICKET_POINTS`
- Assignee: !`printenv AGENT_TICKET_ASSIGNEE`

## Command

`jira create --project <project> --sprint <sprint> --summary <summary> --epic <epic> --points <points> --assignee <assignee> --description <description>`
