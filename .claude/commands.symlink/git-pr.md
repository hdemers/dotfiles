# Open PR

Open a PR on Github.

## Process
1. If there's a template file in .github/PULL_REQUEST_TEMPLATE.md use it.
2. The commits part of this PR are those between HEAD and `master` (or `main`).
3. Use the commit's messages part of this PR as the basis for the PR description.
4. Also use the commit's diffs as the basis for the PR description.
5. Use Markdown formatting for the PR description.
6. Ask the user for approval before opening the PR.
7. Once the PR has been successfully opened, transition the associated ticket to InReview, going through all intermediate states if necessary. Use the `ticket` mcp server.
8. Notify the user once this is done, use the `notify` tool.

## Best practices
1. Do not use superlative words like comprehensive, major, etc.
2. Keep the description as concise as possible, but still detailed enough to facilitate the review.
3. Explain why, not just what.
4. Reference issues/PRs when relevant
