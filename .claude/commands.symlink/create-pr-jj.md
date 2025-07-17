# Open PR

Open a PR on Github.

Note: this is a Jujutsu repository.

## Usage:
- `/create-pr-jj <branch>` - Open a PR for the given Jujutsu branch/bookmark.

## TODOs:
1. If there's a template file in .github/PULL_REQUEST_TEMPLATE.md use it.
2. Use the commit's messages part of this PR as the basis for the PR description.
   - Command: `jj log -r "master..<branch>" --template description --no-graph`
3. Also use the commit's diffs as the basis for the PR description.
   - Command: `jj diff --git -r "master..<branch>"`
4. Use Markdown formatting for the PR description.
5. Have the user review the PR description before creating it.
6. Ask the user if there are any specific reviewers.
7. Push the branch:
   - Command: `jj git push --bookmark <branch>`
8. Set `--head` to `<branch>` when calling `gh pr create`.
10. Once the PR has been successfully opened, transition the associated ticket
   to "In Review", going through all intermediate states if necessary
   (New -> Refined -> "In Dev" -> "In Review" -> Merged -> Closed)
   - Command: `jira transition-to <ticket> <state>`

## Best practices
- Write in imperative mood ("Add feature" not "Added feature")
- Do not use superlative words like comprehensive, major, several, etc.
- Keep the description as concise as possible, but still detailed enough to facilitate the review.
- Explain why, not just what.
- Reference issues/PRs when relevant
