# Open PR

Open a PR on Github. Important: this is a Jujutsu repository.

## Process
1. If there's a template file in .github/PULL_REQUEST_TEMPLATE.md use it.
2. The commits part of this PR are those between `master` and `@`.
3. Use the commit's messages part of this PR as the basis for the PR description.
   - Command: `jj log -r master..@ --template description`
4. Also use the commit's diffs as the basis for the PR description.
   - Command: `jj diff -r master..@`
5. Determine the name of the branch in order to open the PR:
   - Command: `jj bookmark list -r @- -T 'self.name()'`
6. Use Markdown formatting for the PR description.
7. Have the user review the PR description before creating it.
8. Once the PR has been successfully opened, transition the associated ticket
   to "In Review", going through all intermediate states if necessary. Use the
   `ticket` mcp server.
9. Notify the user once this is done, use the `notify` tool.

## Best practices
1. Do not use superlative words like comprehensive, major, several, etc.
2. Keep the description as concise as possible, but still detailed enough to facilitate the review.
3. Explain why, not just what.
4. Reference issues/PRs when relevant
