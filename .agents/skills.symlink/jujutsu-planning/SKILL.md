---
name: jujutsu-planning
description: Proactively use when planning a complex/long multi-step implementation. DO NOT use for simple sequential tasks.
---

# Project Planning with Jujutsu

You are the project manager. Your sole task is to plan, review and launch
subagents in parallel.

CRITICAL: you do no write code, subagents do.

Plan projects by creating empty commits that describe each task.

# Standard Operating Procedure

Determine the phase you're in

1. If the user has provided a revset: Working Phase, jump to that phase.
2. If not: Planning Phase.

## Planning phase

1. For each step of the plan, create a new commit describing the plan:
   ```
   jj new -m "☐ <ticket>: <summary>\n\n<description>"
   ```
2. The description must be as detailed as possible.
3. Once you're done move to the Review Phase.

## Review phase

1. Make sure tasks are in the right order.
2. Work that can be done in parallel should be set as such. Use the
   following command to parallelize revisions:
   ```
   jj parallelize <revset>
   ```
   CRITICAL: Do NOT skip parallelization for independent tasks. You MUST take
   advantage of parallel execution.
3. Make sure each revision's description is self contained and has all the
   details (no external references).
4. Create a bookmark at the tip of each branch, even the main one.
5. Determine the parent revision of all bookmarks, this is call the <base>.

## Working phase

1. For each bookmark, create a Jujutsu workspace using the custom CLI:
   `jj-workspace create <bookmark>`
   (CRITICAL: Do NOT use the standard `jj workspace` command)
2. CRITICAL - CONCURRENT EXECUTION: Launch a generalist subagent in each newly
   created directory concurrently.
3. Each subagent's task is to implement the revisions on their branch:
   1. Run `jj edit <revision>`
   2. Implement
   3. Validate: lint, type check, tests, etc.
   4. Update the description:
      ```
      jj describe -m "☑ <ticket>: <summary>\n\n<append your implementation notes to the original description>"
      ```
      CRITICAL: a jj revision's summary must contain a checkmark when work
      has been completed.
4. You, the main agent, will automatically monitor and wait for all concurrent
   subagent tool calls to return.
5. The implementation is complete when all revisions' descriptions have a
   checkmark.
6. Move to the testing phase.

## Finale Phase

1. When all python-auditors are done, remove the jj workspace with command:
   ```
   jj-workspace remove <bookmark>
   ```
2. Rebase everything to a linear history.
3. Fix any conflicted files that arise from the reconciliation.
4. Report.

# Best Practices

- Each revision description should fully explain what needs to be done, with
  detailed examples.
- Include acceptance criteria in the description
- Note any dependencies or prerequisites
