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
8. Use the Markdown.

### Context

Ticket can be one of:

- Epic
- Story
- Bug

If not specified, assume "Story".

**GLOBAL RULES FOR FIELDS:**

1. If a [MANDATORY] item is not provided, STOP and ASK.
2. For ANY [OPTIONAL] field (like Sprint, Points, or Assignee), if the user
   does not EXPLICITLY provide a value, you MUST leave it blank. DO NOT guess,
   DO NOT default to 'active', and DO NOT infer from context.
3. If Assignee is specified as "me", assume user specified by the environment
   variable `USER`.

Epic creation:

- Work classification [MANDATORY]: possible values: A (sustaining), B
  (engineering excellence) or C (product).
- Capitalizable? [MANDATORY]: possible values: yes or no.
- Assignee [MANDATORY]

Story creation:

- Epic [MANDATORY]
- Sprint [OPTIONAL]
- Points [OPTIONAL]
- Assignee [OPTIONAL]

Bug creation:

- Epic [MANDATORY]
- Bug Type [MANDATORY]: Pre-Production or Production
- Severity [MANDATORY]: A = Critical, B = Major, C = Minor, D = Trivial
- Steps to Reproduce [MANDATORY]: Free text
- Actual Result [MANDATORY]: Free text
- Expected Result [MANDATORY]: Free text
- Sprint [OPTIONAL]
- Points [OPTIONAL]
- Assignee [OPTIONAL]

Sprint can be specified as "current", "active", "next", "future", etc. in which
case use the `jira sprints` commands to find the one.

## Ticket Updates

1. Fetch current ticket state before making changes
2. Preserve important existing information
3. Add meaningful comments explaining changes
4. Link related tickets when appropriate
5. Update time tracking information if provided

# Template

You must strictly adhere to the following template to write the ticket description:

```markdown
### Description

- Work needed. Be as detailed as possible to allow coworkers to points the level of effort needed.
- DO NOT make a judgement call on the level of effort itself, only describe it.

### Expected work product

- Is this a code change? If so, provide the URL of the repository.
- Is the output a document? If so what type:
  - Google Docs?
  - Jupyter/Quarto Notebook?
- Keep this section real simple.

### Acceptance Criteria

- [ ] Criteria 1
- [ ] Criteria 2

NOTE: do not mention code reviews, these always happen.

### Out of Scope

- Detail what is out of scope for this ticket.

### Any background context you want to provide

- What is the broader context of this work?
- Why are we doing this?

### Plan

if you are provided with a plan, copy it here, as is.
```

**CLI Usage Patterns**:

- Use `jira issues` to list all tickets
- Use `jira issues --current-sprint --mine` to list user's ticket in current sprint.
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
- CRITICAL: do not mention brainstorming files by name, rather attached the
  brainstorming document to the ticket (using `--attach <filename>`)
