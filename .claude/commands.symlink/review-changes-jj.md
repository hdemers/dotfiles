# Change Review

Comprehensive change review instructions. 

Note: This is a Jujutsu repository.

## Usage:
- `/review-changes-jj <id>`

## Process:
1. Review code changes systematically.
   Command: `jj show --git -r <id>`
2. Review linked issue(s) (use the `ticket` tool)
3. Make sure the work described in the issue is implemented by the changes.
3. Test functionality locally if applicable.
4. Consider possible regression issues.
5. Commented out code should not be left in.
6. Provide constructive feedback.
7. Submit your feedback to the user.

## Key Principle:
1. Improvements scheduled for later must have a comment starting with FIXME:
   ..., ending with TICKET: ...
2. Provide comments in the style of [conventional comments](https://conventionalcomments.org/).
3. Try to have at least one 'praise', but no more than 2.
