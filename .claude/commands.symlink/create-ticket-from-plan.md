---
allowed-tools: Bash(jira:*), Bash(jj log:*), Bash(git rev-parse:*)
description: Create a ticket from Claude Code plan
---

# Create a ticket from plan

Create a ticket using the `jira` CLI, specifically the command `jira create`.
Be as detailed as possible for Claude Code to execute that ticket at a later
date.

## Usage:
- `/create-ticket <parameters>` - Create a new ticket

## Template:
h3. Brief description

* Work needed

h3. Expected work product

* Document? Metric? Code/Repo?

h3. Dependencies

* Meetings? Another ticket? Peer review?

h3. Any background context you want to provide

* Detail that supports work needed

## Process:
1. Use the template.
2. Use future tense.
3. Use Jira Text Formatting language.
5. The summary of the ticket should be prefixed with `[repo-name]`.
6. If the user has provided an epic, a sprint, a number of points, etc., use
   those, otherwise leave blank (do not set corresponding CLI flag).
7. The description of the ticket is the plan made for this work.
8. Be as detailed as possible for Claude Code to execute this at a later date.

## Command

`jira create --project <project> --sprint <sprint> --summary <summary> --epic <epic> --points <points> --assignee <assignee> --description <description>`
