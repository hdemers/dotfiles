---
name: simplify
description: Proactively use when asked to simplify the code.
---

- Phase 1 — Identify Changes: Run `git diff <revision>` (or `git diff HEAD`)
  or `jj diff --git <revision>` to find what changed. Falls back to recently
  modified or mentioned files if no git changes exist.
- Phase 2 — Three parallel review agents (all launched simultaneously with the
  full diff):
  - Agent 1 (Reuse): Searches for existing utilities that could replace newly
    written code. Flags duplicated functionality and hand-rolled logic that
    already exists elsewhere.
  - Agent 2 (Quality): Looks for hacky patterns — redundant state, parameter
    sprawl, copy-paste blocks, leaky abstractions, stringly-typed code.
  - Agent 3 (Efficiency): Looks for unnecessary work, missed concurrency
    opportunities, hot-path bloat, TOCTOU anti-patterns, memory leaks, and
    overly broad operations.
- Phase 3 — Fix: Waits for all three agents, aggregates findings, and applies
  fixes directly. False positives are noted and skipped without argument.

Ends with a brief summary.
