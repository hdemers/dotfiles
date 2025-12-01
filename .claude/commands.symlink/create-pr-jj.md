---
allowed-tools: Bash(jj log:*), Bash(jj diff:*), Bash(gh pr create:*), Bash(gh pr edit:*), Bash(jira transition-to:*), Bash(printenv:*), Bash(jira view:*), Bash(cat:*)
description: Open a PR from a Jujutsu bookmark
model: haiku
---

MANDATORY: You have all the informatin you need below, DO NOT attempt to run
`jj` (or worse `git`) commands, rather STOP and ASK if need be.

## Context

### Current commit descriptions:

!`jj log -r "$CLAUDE_JJ_BASE..$CLAUDE_BOOKMARK" --template description --no-graph`

### Current diffs

!`jj diff --git -r "$CLAUDE_JJ_BASE..$CLAUDE_BOOKMARK"`

### Associated ticket (if any)

!`jira view "$CLAUDE_TICKET" 2>/dev/null || echo "no ticket"`

### PR Template (if any)

!`cat .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null || echo "no pre-existing PR template."`

## Process:
1. Draft a PR description from the above commit messages and diffs.
2. Use the PR template, if any pre-existing exists, otherwise use a sensible structure.
3. Use Markdown formatting for the PR description.
4. Assign the PR to me.
5. Set reviewers to: !`printenv CLAUDE_REVIEWERS`
6. Set `--head` to !`printenv CLAUDE_BOOKMARK` when calling `gh pr create`.
6. Set `--base` to !`printenv CLAUDE_PR_BASE` when calling `gh pr create`.
7. Once the PR has been successfully opened, use the _jira-ticket_ skill to transition
   the associated ticket (if any) to "In Review", going through all
   intermediate states if necessary
    `New -> Refined -> "In Dev" -> "In Review" -> Merged -> Closed`
   - Command: `jira transition-to <ticket> <state>`

## Best practices
- Write in imperative mood ("Add feature" not "Added feature")
- Do not use superlative words like comprehensive, major, several, complete, etc.
- Keep the description as concise as possible, but still detailed enough to
  facilitate the review.
- If any commits are introducing breaking changes, highlight that very clearly
  in the PR description by adding "**⚠️ BREAKING CHANGE:**" to section 'Scope of
  Impact'.
- Explain why, not just what.
- Reference issues/PRs when relevant
- If `--base` is different from `master` or `main`, explain that this is a stacked PR (explain what stacked PRs are), and mention the base.
- DO NOT add a "Generated with Claude Code" footer.
