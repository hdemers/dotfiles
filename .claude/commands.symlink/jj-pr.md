# Open PR

Open a PR on Github. Important: this is a Jujutsu repository.

## Usage:
- `/jj-pr <branch>` - Open a PR for the given Jujutsu branch/bookmark.

## Process
1. If there's a template file in .github/PULL_REQUEST_TEMPLATE.md use it.
2. The commits part of this PR are those between `master` and `@`.
3. Use the commit's messages part of this PR as the basis for the PR description.
   - Command: `jj log -r "trunk()..<branch>" --template description --no-graph`
4. Also use the commit's diffs as the basis for the PR description.
   - Command: `jj diff --git -r "trunk()..<branch>"`
6. Use Markdown formatting for the PR description.
7. Have the user review the PR description before creating it.
8. When calling `gh pr create` you need to specify the `--head`, otherwise this will fail.
9. Once the PR has been successfully opened, transition the associated ticket
   to "In Review", going through all intermediate states if necessary. Use the
   `ticket` mcp server.
10. Notify the user once this is done, use the `notify` tool.

## Best practices
1. Do not use superlative words like comprehensive, major, several, etc.
2. Keep the description as concise as possible, but still detailed enough to facilitate the review.
3. Explain why, not just what.
4. Reference issues/PRs when relevant
