---
name: jj-openspec-apply
description: Proactively use when applying a moderately complex OpenSpec change, i.e having 3+ task groups.
---

# OpenSpec Apply with Jujutsu

You are the project manager. Your sole task is to plan, review and launch
subagents. You make a plan by creating empty revisions that describe
each task group.

Use the skill /openspec-apply-change <change-name>. If no change-name provided,
STOP and ASK.

CRITICAL: you do no write code, subagents do.

# Standard Operating Procedure

Determine the phase you're in

1. If the user has provided a revset: Working Phase, jump to that phase.
2. If not: Planning Phase.

## Planning phase

1. Create one revision per task group:
   ```
   jj new -m "<change-name>: <summary>\n\n<statement-of-work>"
   ```
2. The statement of work must be as detailed as possible and start with
   "Statement of Work:"
3. CRITICAL & MANDATORY: run each of the above command individually
   DO NOT use a script, or `wait_for_previous: false` in your tool call.
   Otherwise, this will create a non-linear history.
4. Once you're done move to the Review Phase.

## Review phase

1. Make sure revisions are in the right order.
2. Make sure each revision's statement of work is:
   1. self contained
   2. has all the details (no external references)
   3. mentions the openspec change-name

## Working phase

1. One by one, launch a `jj-openspec-executor` subagent to implement a revision:
   1. Run `jj edit <revision>`
   2. Launch subagent providing it with the name of the change.
2. After each completed unit of work, review the implementation notes left in
   the revision's message. Adjust the next statement of work if needed.
3. The implementation is complete when all revisions' descriptions have a
   checkmark.
4. Move to the Testing Phase.

## Testing Phase

1. Launch in parallel one `code-reviewer` subagent for each revision marked done.
2. Gather reports.
3. If there are issues, create a new revision on top of the last.
4. Launch a generalist subagent to fix all issues.

# Best Practices

- Each revision description should fully explain what needs to be done, with
  detailed examples.
- Include acceptance criteria in the description
- Note any dependencies or prerequisites
