---
name: jira-ticket
description: Proactively use this skill when you need to read, create, update, or manage Jira tickets.
tools: Bash(jira:*)
---

Use the `jira` CLI to create, update, and manage Jira tickets.

# Standard Operation Procedures

Choose:

## Ticket Creation

1. Use the type 'Story', unless explicitly specified by the user to use 'Epic'.
   See Context below for details about each type.
2. Write clear, concise summaries
3. Optionally add label `ai-ready` IF AND ONLY IF the ticket is detailed
   enough that it can be implemented by an AI agent or if the ticket's plan
   was written by an agent.
4. Use present tense.
5. Write ticket as if the work is to be done.
6. Summary starts with the name of the repo in square brackets:
     [REPO-NAME] <SUMMARY>
7. Craft detailed descriptions including:
    - Problem statement or feature description
    - Expected work product
    - Technical details when relevant
8. Use the Jira Text Formatting language:
    - Use `{{monospace}}` instead of `{code}..{code}` for inline code.
    - Code blocks should specify the language: `{code:language} some code {code}`.

### Context

The ticket can either be of type "Epic" or "Story". If not specified, assume
"Story". If a mandatory item is not provided, STOP and ASK.

For Epic creation:
- Work classification [MANDATORY]: possible values: A, B or C.
- Capitalizable? [MANDATORY]: possible values: yes or no.
- Assignee [MANDATORY]

For Story creation:
- Epic [MANDATORY]
- Sprint [OPTIONAL]: if not provided, leave blank. If specified as "current" or
  "active", use the `jira sprints` command to find the 'active' sprint. If
  specified as "next", use the `jira sprints` command to find the next sprint.
- Points [OPTIONAL]: if not provided, leave blank
- Assignee [OPTIONAL]: if not provided, leave blank. If specified as "me",
  assume user specified by the environment variable `USER`.


## Ticket Updates

1. Fetch current ticket state before making changes
2. Preserve important existing information
3. Add meaningful comments explaining changes
4. Link related tickets when appropriate
5. Update time tracking information if provided
6. Use the Jira Text Formatting language:
    - Use `{{monospace}}` instead of `{code}..{code}` for inline code.
    - Code blocks should specify the language: `{code:language} some code {code}`.

# Template

You must strictly adhere to the following template to write the ticket description:

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

h3. Out of Scope

- Detail what is out of scope for this ticket.

h3. Any background context you want to provide

* What is the broader context of this work?
* Why are we doing this?

h3. Plan

if you are provided with a plan, copy it here, as is.
```

**CLI Usage Patterns**:
- Use `jira issues` to list all tickets
- Use `jira issues --epics-only` to list epics only
- Use `jira issues --programs-only` to list programs only
- Use `jira issues --in-epic <EPIC>` to list issues in epic <EPIC>
- Use `jira sprints` to list sprints
- Use `jira view <TICKET>` to view a ticket.
- Use `jira create` with appropriate flags for new tickets
- Use `jira update` with appropriate flags to modify existing tickets
- Use `jira transition <TICKET> "<STATE>"` to move tickets through workflow states
- Use `jira close <TICKET>` to close a ticket.

# Best Practices

- Be precise and technical when documenting issues
- Acknowledge successful operations with ticket numbers (use `jira issues` to
  find newly create ticket).
- NEVER use superlative terms like comprehensive.
