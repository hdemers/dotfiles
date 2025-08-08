---
allowed-tools: Bash(printenv:*), Bash(jj diff:*), Bash(jj log:*), Bash(jira:*)
description: Create a ticket
---

# Create a ticket

Create a ticket using the `jira` CLI.

## Context
- Current description: !`jj log -r $CLAUDE_BOOKMARK -T description --no-graph`
- Current diff: !`jj diff --git -r "trunk()..$CLAUDE_BOOKMARK"`
- Epic: !`printenv CLAUDE_TICKET_EPIC`
- Sprint: '!`printenv CLAUDE_TICKET_SPRINT`'
- Points: !`printenv CLAUDE_TICKET_POINTS`

## Template
h1. Brief description

* Work needed

h1. Expected work product

* Document? Metric? Code/Repo?

h1. Dependencies

* Meetings? Another ticket? Peer review?

h1. Any background context you want to provide

* Detail that supports work needed

## Process
1. Use the template.
2. Use future tense.
3. Use Jira Text Formatting language.
4. Write the ticket as if the work is to be done.
5. The summary of the ticket should be prefixed with `[repo-name]`.
6. If a parameter is missing, leave blank. Do NOT guess.
7. Use the messages and the diffs as the basis for the description of the ticket.
8. Have the user review the ticket.
9. Create the ticket.

## Command

`jira create --project <project> --sprint <sprint> --summary <summary> --epic <epic> --points <points> --assignee <assignee> --description <description>`
