---
name: jujutsu-planning
description: Proactively use when planning a complex multi-step implementation.
---

# Project Planning with Jujutsu

Plan projects by creating empty commits that describe each task. Work through
the commit stack sequentially, implementing each feature as you go.

# Standard Operating Procedure

1. Planning phase. For each step of the plan, create a new commit describing the plan:
    ```
    jj new -m "step description"
    ```
2. Review phase. Review the commit stack and parallelize any commits that can
   be worked on in parallel without causing conflicts. Use this command to
   parallelize commits A and B:
   ```
   jj parallelize -r A::B
   ```
2. Working phase. Starting with the first commit, sequentially implement each
   step in turn. For commits that are siblings, spawn a subagent using the Task
   tool for each commit. For each commit being worked on:
    ```bash
    jj edit <revision>
    # Do Work
    jj describe # Describe work done
    ```

# Best Practices

Create Descriptive Empty Commits:
  - Each commit description should fully explain what needs to be done
  - Include acceptance criteria in the description
  - Note any dependencies or prerequisites
  - Use clear, actionable language

# Key Principles

- Jujutsu automatically snapshots your working copy
- The working copy is itself a commit (marked with `@`)
- Use `jj describe` to set meaningful commit messages
- Use `jj new` to move to the next commit in your stack
- The layout of most Jujutsu repositories looks something like this:

    @  xsylloqz email@example.com 2026-01-16 09:11:56 097cb3d1
    │  (no description set)
    │ ○  lqzpqmqy email@example.com 2026-01-15 11:18:08 d7a4d743
    ├─╯  🩹 fix(scope-3): fix a broken function
    │ ○  xuztksoy email@example.com 2026-01-15 11:18:08 a9ff8359
    ├─╯  ✨ feat(scope-1): add a requested feature
    ◆      mywuvnxw email@example.com 2026-01-15 11:18:08 dev* 94067318
    ├─┬─╮  (empty) 🚧 hdemers dev commit
    │ ◇ │  tzqslqlp email@example.com 2026-01-15 11:18:08 bookmark-1 4cf62e12
    │ ├─╯  ✨ feat(scope-1): Support editable pip installations
    ◇ │  sppvptnr email@example.com 2026-01-15 11:18:08 bookmark-2 8eaa1944
    ├─╯  🐛 fix(scope-2): Fix some bugs
    ◆  ronrryqk email@example.com 2026-01-15 11:17:18 master 0.1.150 9134bc80
    │  ✨ feat(scope-3): Add some new cool features

    Where:

    - Everything after the empty `dev` commit is considered private.
    - Everything between `master` and `dev` is considered shared and in review.
    - In the above example, `bookmark-1` and `bookmark-2` are two branches with PRs.
