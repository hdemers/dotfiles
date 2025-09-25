---
allowed-tools: Bash(jira:*), Bash(jj log:*), Bash(git rev-parse:*)
description: Create a ticket
---

# Create a ticket

Use the jira-ticket-manager subagent proactively to create a new ticket.

## Context
Provide the following context to the subagent. If a mandatory item is not provided, STOP and ASK before submitting to subagent.

- Type [MANDATORY]: possible values "Epic" or "Story". If not specified, assume "Story".

For Epic creation:
- Work classification [MANDATORY]: possible values: A, B or C.
- Capitalizable? [MANDATORY]: possible values: yes or no.
- Assignee [OPTIONAL]: leave blank if not provided.

For Story creation:
- Epic [MANDATORY]
- Sprint [OPTIONAL]: if not provided, leave blank
- Points [OPTIONAL]: if not provided, leave blank
- Assignee [OPTIONAL]: if not provided, leave blank. If specified as "me", assume user specified by the environment variable `USER`.

## Template
```markdown
h3. Description

* Work needed. Be as detailed as possible to allow coworkers to points the level of effort needed.
* DO NOT make a judgement call on the level of effort itself, only describe it.

h3. Expected work product

* Is this a code change? If so, provide the URL of the repository.
* Is the output a document? If so what type:
  - Google Docs?
  - Jupyter/Quarto Notebook?
* Keep this section real simple.

h3. Acceptance Criteria

- [ ] Criteria 1
- [ ] Criteria 2

NOTE: do not mention code reviews, these always happen.

h3. Any background context you want to provide

* What is the broader context of this work?
* Why are we doing this?
```

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
