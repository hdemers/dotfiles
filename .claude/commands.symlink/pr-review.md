# Pull Request Review

Comprehensive pull request review.

## Usage:
- `/pr-review <#PR | None>`

## Parameters
- `#PR` is the PR number. If not provided, the PR associated with the current
  branch is assumed. If there are no PR associated with the current branch, abort
  and notify the user.

## Review Process:
1. Read PR description and linked issues (use the `ticket` tool)
2. Review code changes systematically.
3. Test functionality locally if applicable.
4. Consider possible regression issues.
5. Commented out code should not be left in.
6. Leave constructive feedback.
7. Submit your feedback to the user. Do not create a PR review before approval from the user.

## Key Principle:
1. Improvements scheduled for later must have a comment starting with FIXME: ..., ending with TICKET: ...
2. Use [conventional comments](https://conventionalcomments.org/).
3. Try to have at least one 'praise'.
