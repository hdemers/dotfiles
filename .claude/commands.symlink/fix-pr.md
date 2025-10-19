---
allowed-tools: Bash(gh:*)
description: Address all comments from PR flagged with the :robot: emoji.
---

# Address all comments from PR flagged with the :robot: emoji

Using the `pr-robot-discussions` subagent, retrieve all discussion threads
flagged with the :robot: emoji. Then using the Todo tool, make a list of all
discussion threads and address each in turn.

## Context
Provide the PR number to the subagent. If the user has not provided a PR number, STOP and ASK.


## Process

1. Use the subagent `pr-robot-discussions` and retrieve all :robot: flagged discussion threads.
2. Using the Todo tool, make a checklist, one item per discussion thread.
3. Investigate each item and propose a plan to the user.
4. STOP and ASK the user to review the plan.
5. Upon approval from the user, proceed to implement each item from the Todo list.
6. Summarize your work.

