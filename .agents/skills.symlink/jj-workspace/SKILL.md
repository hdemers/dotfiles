---
name: jj-workspace
description: Proactively use when you need to create and manage Jujutsu workspaces.
---

# Standard Operating Procedure

CRITICAL: do not ever use the standard `jj workspace` command, rather use the
custom CLI `jj-workspace`.

1. Make sure there's a bookmark dedicated to the workspace
2. Create a workspace using `jj-workspace create <bookmark>`
3. Remove a workspace with `jj-workspace remove <bookmark>`
