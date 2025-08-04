---
allowed-tools: Bash(printenv:*), Bash(jj diff:*), Bash(jj log:*), mcp__mymcp__sprints, mcp__mymcp__my_tickets, mcp__mymcp__my_tickets_for_this_sprint, mcp__mymcp__transition_ticket, mcp__mymcp__query, mcp__mymcp__create_ticket, mcp__mymcp__update_ticket, mcp__mymcp__describe_ticket
description: Create a ticket
---

# Create a ticket

Create a ticket using the `ticket` mcp tool.

## Context
- Current description: !`jj log -r $CLAUDE_BOOKMARK -T description --no-graph`
- Current diff: !`jj diff --git -r "trunk()..$CLAUDE_BOOKMARK"`
- Epic: !`printenv CLAUDE_TICKET_EPIC`
- Sprint: '!`printenv CLAUDE_TICKET_SPRINT`'
- Points: !`printenv CLAUDE_TICKET_POINTS`

## Template
{*}Brief description{*}:

* Work needed

{*}Expected work product{*}:

* Document? Metric? Code/Repo?

{*}Dependencies{*}:

* Meetings? Another ticket? Peer review?

{*}Any background context you want to provide{*}:

* Detail that supports work needed

## Process
1. Use the template.
2. Use future tense.
3. Use Markdown formatting where appropriate.
4. Write the ticket as if the work is to be done.
5. The summary of the ticket should be prefixed with `[repo-name]`.
6. If a parameter is missing, leave blank. Do NOT guess.
7. Use the messages and the diffs as the basis for the description of the ticket.
8. Have the user review the ticket.
1. Create the ticket.
