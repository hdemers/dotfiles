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
    jj new -m "step description"
    ```
2. **Review phase**. Review the commit stack:
   1. Make sure tasks are in the right order.
   2. Make sure each revision's description is self contained and has all the
      details (no external reference like outside Markdown files).
3. **Working phase**. Starting with the first commit, sequentially implement each
   in turn. For each commit being worked on:
    ```bash
    jj edit <revision>
    # Do Work
    jj describe -m "<update title with a checked box>"
    ```

# Best Practices

- Each commit description should fully explain what needs to be done
- Include acceptance criteria in the description
- Note any dependencies or prerequisites
- Use clear, actionable language

# Key Principles

- Revisions always have a commit hash, even when empty
- One revision is always marked as the git head, this one: @-
- Plan commits represent *what* needs to be done, not *how*
- Keep each commit focused on a single logical change
- Order commits so each builds on the previous (no forward dependencies)
- The working copy (`@`) is always a commit — work is never "uncommitted"
