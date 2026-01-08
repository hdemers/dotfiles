---
name: jira-ticket
description: Proactively use this skill when you need to read, create, update, or manage Jira tickets.
tools: Bash(jira:*)
---

Use the `jira` CLI to create, update, and manage Jira tickets.

**Core Skills**:

1. **Ticket Creation**: When creating new tickets, you will:
   - Use the type 'Story', unless explicitly specified by the user to use 'Epic'.
   - Write clear, concise summaries
   - Optionally add label `ai-ready` IF AND ONLY IF the ticket is detailed
     enough that it can be implemented by an AI agent or if the ticket's plan
     was written by an agent.
   - Use future tense.
   - Write ticket as if the work is to be done.
   - Summary starts with the name of the repo in square brackets:
       [REPO-NAME] <SUMMARY>
   - Craft detailed descriptions including:
     - Problem statement or feature description
     - Expected work product
     - Technical details when relevant

2. **Ticket Updates**: When updating existing tickets, you will:
   - Fetch current ticket state before making changes
   - Preserve important existing information
   - Add meaningful comments explaining changes
   - Link related tickets when appropriate
   - Update time tracking information if provided

**Template**:

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

### Specific command options

`jira view --help`:
```shell
Usage: jira view [OPTIONS] KEY

  View an issue.

Options:
  --help      Show this message and exit.
```

`jira issues --help`:
```shell
Usage: jira issues [OPTIONS]

  List issues.

Options:
  -c, --current-sprint  only show issues in the current sprint
  -m, --mine            only show my issues
  -e, --epics-only      only show epics
  -p, --programs-only   only show programs
  -i, --in-epic TEXT    only show issues in the given epic
  --help                Show this message and exit.
```

`jira sprints --help`:
```shell
Usage: jira sprints [OPTIONS]

  List sprints.

Options:
  --help      Show this message and exit.
```

`jira create --help`:
```shell
Usage: jira create [OPTIONS]

  Create an issue.

  Can be used in two modes:

  1. Interactive mode (default or --interactive): Uses prompts like before
  2. Non-interactive mode: Provide --project and --summary to create directly

  Examples:
      jira create
      jira create --interactive

      # Non-interactive mode
      jira create --project ABC --summary "Fix login bug" --points 3
      jira create -p ABC -s "Add new feature" --epic ABC-100 --assignee john.doe

Options:
  -p, --project TEXT              Project key
  -s, --summary TEXT              Issue summary (required for non-interactive
                                  mode)
  --points [None|0|0.5|1|2|3|5|8]
                                  Story points
  --sprint TEXT                   Sprint name (default: Backlog)
  -e, --epic TEXT                 Epic key to link to
  -a, --assignee TEXT             Username to assign to
  -d, --description TEXT          Issue description (uses template if not
                                  provided)
  --type [Story|Epic]             Issue type
  --epic-name TEXT                Epic Name (required for Epic issues)
  --work-classification [A|B|C]   Work Classification: A=Sustaining,
                                  B=Engineering Excellence, C=Product
  --parent TEXT                   Parent issue key (for Epic)
  --capitalizable [Yes|No]        Capitalizable (required for Epic issues)
  -i, --interactive               Use interactive mode (original behavior)
  -l, --labels TEXT               Comma-separated list of labels to assign to
                                  the issue
  --target-start [%Y-%m-%d]       Target start date for Epic (YYYY-MM-DD)
  --target-end [%Y-%m-%d]         Target end date for Epic (YYYY-MM-DD)
  --help
```

`jira update --help`:
```shell
Usage: jira update [OPTIONS] KEY

  Update an issue.

Options:
  -s, --summary TEXT              New issue summary
  --points [None|0|0.5|1|2|3|5|8]
                                  New story points
  --sprint TEXT                   New sprint name
  -e, --epic TEXT                 New epic key to link to (use empty string to
                                  remove epic)
  -a, --assignee TEXT             New username to assign to (use empty string
                                  to unassign)
  -d, --description TEXT          New issue description
  -i, --interactive               Use interactive mode (original behavior)
  -l, --labels TEXT               Comma-separated list of labels to assign to
                                  the issue
  --help                          Show this message and exit.
```

`jira transition --help`

```shell
Usage: jira transition [OPTIONS] ISSUE [TO]

  Transition an issue to target state.

  The state must be one of the valid workflow states for the issue:

  New -> Refined -> In Dev -> In Review -> Merged -> Closed

  Possible resolutions are: Fixed, Resolved, Cancelled, Duplicate, Works as
  Designed, Won't Do, Done, Declined, Postponed, Not a Priority, No Longer
  Applicable, Misconfiguration, Cannot Reproduce, Change Success, Change
  Failure, Change Cancelled, Invalid, Rejected, Withdrawn, Change Partially
  Implemented, Launched

  Examples:
      jira transition ABC-123 "In Dev"
      jira transition ABC-123 Closed --resolution "Won't Do"

Options:
  -i, --interactive      Use interactive mode
  -r, --resolution TEXT  Resolution name for closed transitions (e.g., 'Done')
  --help                 Show this message and exit.
```

`jira close --help`:
```shell
Usage: jira close [OPTIONS] ISSUE

  Close an issue by automatically transitioning through the workflow.

  This command will automatically transition an issue through the predefined
  workflow states until it reaches 'Closed' status:

  New -> Refine -> Start Dev -> Submit for Review -> Passed Review -> Close
  Issue

  Use --cancelled to skip the workflow and close directly via Cancelled
  transition.

  Possible resolutions are: Fixed, Resolved, Cancelled, Duplicate, Works as
  Designed, Won't Do, Done, Declined, Postponed, Not a Priority, No Longer
  Applicable, Misconfiguration, Cannot Reproduce, Change Success, Change
  Failure, Change Cancelled, Invalid, Rejected, Withdrawn, Change Partially
  Implemented, Launched

  Examples:
      jira close ABC-123
      jira close DEF-456 --resolution "Won't Do"
      jira close GHI-789 --cancelled --resolution Duplicate

Options:
  -r, --resolution TEXT  Resolution name for closed transition (e.g., 'Done')
  --cancelled            Use 'Cancelled' transition to close directly
  --help                 Show this message and exit.
```


**Context**:
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


**Error Handling**:
- If the `jira` CLI is not installed, immediately STOP and ASK
- If a ticket number is invalid, search for similar tickets, STOP and ASK.
- If required fields are missing, STOP and ASK.
- If the operation fails, provide the exact error and STOP.

**Best Practices**:
- Keep summaries action-oriented (e.g., 'Fix database connection timeout' not
  'Database broken')
- Use bullet points and numbered lists for clarity in descriptions
- Include code snippets in triple backticks when relevant
- Reference related tickets using the PROJ-#### format
- Add screenshots or error messages as attachments when available
- Use the Jira Text Formatting language:
  - Use `{{monospace}}` instead of `{code}..{code}` for inline code.
  - Code blocks should specify the language: `{code:language} some code {code}`.

**Communication Style**:
- Be precise and technical when documenting issues
- Maintain professional tone in all ticket content
- Acknowledge successful operations with ticket numbers (use `jira issues` to
  find newly create ticket).
- Proactively suggest related actions (e.g., 'Should I also create a subtask
  for testing?')
- NEVER use superlative terms like comprehensive.

Remember: Every ticket you create or update becomes part of the project's
permanent record. Ensure all information is accurate, complete, and valuable
for current and future team members.

