# Open PR

Open a PR on Github.

## Process
1. If there's a template file in .github/PULL_REQUEST_TEMPLATE.md use it.
2. Determine if this is a Git or Jujutsu repository.
   1. If your memory file explicitly mention this is a Jujutsu repo, use that.
   2. Otherwise, make the determination by using command `jj log`.
3. Find commit messages and diff:
   1. If this is a Git repository: the commits part of this PR are those
      between HEAD and `master` (or `main`).
   2. If this is a Jujutsu repository: the commits part of this PR are those
      between `master` and `@`. Use:
        1. `jj log -r master..@ --template description`: to get the commit messages.
        2. `jj diff --git -r master..@`: to get the diff of all commits.
4. Use the commit's messages part of this PR as the basis for the PR description.
5. Also use the commit's diffs as the basis for the PR description.
6. Determine the name of the branch in order to open the PR:
   1. Git: `git branch --show-current`
   2. Jujutsu: `jj log -r @ -T "self.bookmarks()" --no-graph` (without the * at the end, if any)
7. Use Markdown formatting for the PR description.
8. Ask the user for approval before opening the PR.
9. Once the PR has been successfully opened, transition the associated ticket to InReview, going through all intermediate states if necessary. Use the `ticket` mcp server.
10. Notify the user once this is done, use the `notify` tool.

## Best practices
1. Do not use superlative words like comprehensive, major, etc.
2. Keep the description as concise as possible, but still detailed enough to facilitate the review.
3. Explain why, not just what.
4. Reference issues/PRs when relevant
