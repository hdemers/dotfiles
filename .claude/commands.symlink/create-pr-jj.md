---
allowed-tools: Bash(jj log:*), Bash(jj diff:*), Bash(gh pr create:*), Bash(gh pr edit:*), Bash(jira transition-to:*), Bash(printenv:*), Bash(jira describe:*)
description: Open a PR from a Jujutsu bookmark
---

## Context
- Current commit description: !`jj log -r "trunk()..$CLAUDE_BOOKMARK" --template description --no-graph`
- Current diffs: !`jj diff --git -r "trunk()..$CLAUDE_BOOKMARK"`

## Process:
1. Use the template found in .github/PULL_REQUEST_TEMPLATE.md.
2. Use Markdown formatting for the PR description.
3. Assigne the PR to me.
4. Set reviewers to: !`printenv CLAUDE_REVIEWERS`
5. Set `--head` to !`printenv CLAUDE_BOOKMARK` when calling `gh pr create`.
6. Once the PR has been successfully opened, transition the associated ticket
    (if any) to "In Review", going through all intermediate states if necessary
    `New -> Refined -> "In Dev" -> "In Review" -> Merged -> Closed`
   - Command: `jira transition-to <ticket> <state>`

## Best practices
- Write in imperative mood ("Add feature" not "Added feature")
- Do not use superlative words like comprehensive, major, several, complete, etc.
- Keep the description as concise as possible, but still detailed enough to facilitate the review.
- Explain why, not just what.
- Reference issues/PRs when relevant
- DO NOT add a "Generated with Claude Code" footer.
