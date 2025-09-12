---
allowed-tools: Bash(jira:*), Bash(jj log:*), Bash(git rev-parse:*)
description: Create a ticket
---

# Create a ticket

Create a ticket using the `jira` CLI, specifically the command `jira create`.

## Context
The following context must be provided by the user. If not, STOP and ASK for it:

The ticket can either be of type "Epic" or "Story". If not specified, assume "Story".

For Epic creation:
- Work classification
- Capitalizable? Yes/No
- Assignee

For Story creation:
- Epic
- Sprint
- Points
- Assignee

## Template
h3. Brief description

* Work needed

h3. Expected work product

* Document? Metric? Code/Repo?

h3. Dependencies

* Meetings? Another ticket? Peer review?

h3. Any background context you want to provide

* Detail that supports work needed

## Process

1. Use the template.
2. Use future tense.
3. Use Jira Text Formatting language.
4. The description of the ticket can either be provided by the user or can be
   written by the AI agent from instructions provided by the user.
5. Produce a summary from the description
6. The summary of the ticket should be prefixed with `[repo-name]`.
7. If a parameter is missing, leave blank. Do NOT guess (do not set corresponding CLI flag).
8. Have the user review the ticket.
9. Create the ticket.

## Command

`jira create --project <project> --sprint <sprint> --summary <summary> --epic <epic> --points <points> --assignee <assignee> --description <description>`
