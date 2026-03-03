---
name: jujutsu-planning
description: Proactively use when planning a complex multi-step implementation.
---

# Project Planning with Jujutsu

Plan projects by creating empty commits that describe each task. Work through
the commit stack sequentially, implementing each feature as you go.

# Standard Operating Procedure

1. Determine the phase you're starting in:
   1. If the user has provided a revset: Working Phase, jump to that phase.
   2. If not: Planning Phase.
1. **Planning phase**. For each step of the plan, create a new commit
   describing the plan:
   ```
   jj new -m "☐ <ticket>: <summary>\n\n<description>"
   ```
   The description must be as detailed as possible.
1. **Review phase**. Review the commit stack:
   1. Make sure tasks are in the right order.
   2. Make sure each revision's description is self contained and has all the
      details (no external reference like outside Markdown files).
1. **Working phase**. Starting with the first commit, sequentially implement each
   in turn. For each commit being worked on:
   1. run `jj edit <revision>`
   2. Implement
   3. Validate: lint, unit test, type check, etc.
   4. Update the description:
      `jj describe -m "☑ <ticket>: <summary>\n\n<updated description>"`

# Best Practices

- Each commit description should fully explain what needs to be done
- Include acceptance criteria in the description
- Note any dependencies or prerequisites
- Use clear, actionable language

# Key Principles

- Revisions always have a commit hash, even when empty
- One revision is always marked as the git head, this one: @-
- Plan commits represent _what_ needs to be done, not _how_
- Keep each commit focused on a single logical change
- Order commits so each builds on the previous (no forward dependencies)
- The working copy (`@`) is always a commit — work is never "uncommitted"
