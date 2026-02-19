---
name: pr
description: Open a PR from a Jujutsu bookmark
tools: Bash(gh pr create:*), Bash(gh pr edit:*), Bash(jira transition-to:*), Bash(jira view:*)
---

## Standard Operating Procedure

1. Draft a PR description from the commit descriptions and diffs in the context.
2. Use the PR template if one is provided in the context, otherwise use a sensible structure.
3. Use Markdown formatting for the PR description.
4. Assign the PR to me.
5. Set reviewers to the value provided in the context.
6. Set `--head` to the bookmark from the context when calling `gh pr create`.
7. Set `--base` to the base from the context when calling `gh pr create`.
8. IMPORTANT: you do not need to change directory. You are in the correct one.
9. Once the PR has been successfully opened, use the _jira-ticket_ skill to transition
   the associated ticket (if any) to "In Review", going through all
   intermediate states if necessary:
   `New -> Refined -> "In Dev" -> "In Review" -> Merged -> Closed`
   - Command: `jira transition-to <ticket> <state>`

## Best Practices

- Write in imperative mood ("Add feature" not "Added feature")
- Do not use superlative words like comprehensive, major, several, complete, etc.
- Keep the description as concise as possible, but still detailed enough to
  facilitate the review.
- If any commits are introducing breaking changes, highlight that very clearly
  in the PR description by adding "**⚠️ BREAKING CHANGE:**" to section 'Scope of
  Impact'.
- Explain why, not just what.
- Reference issues/PRs when relevant.
- If `--base` is different from `master` or `main`, explain that this is a stacked PR
  (explain what stacked PRs are), and mention the base.
- DO NOT add a "Generated with Claude Code" footer.
