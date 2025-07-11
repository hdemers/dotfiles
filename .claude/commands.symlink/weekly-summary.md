# Weekly Summary

Summarize the work done in this repository over a specific time horizon.

## Usage:
`/weekly-summary <date | since >`

## Parameters:
- `<date | since>`: either a date in the past or a number of days to look back.

## Examples:
- `/weekly-summary June 10th, 2025`
- `/weekly-summary 8 days`

## Process:
0. This is a Jujutsu repository, but ONLY use `git ...` comamnds. It will work.
2. Separate the narrative in two: 'Completed Work' and 'Active Development'.
3. Work is considered completed if it was merged into master (commits are
   before master)
4. Look at the remote branches for the active development part.
5. Get approval from user.
6. Write the summary as a Markdown formatted document.
7. Write it in directory `,weekly-summaries`, titled `<today's date>.md`

## Guidelines
- Write this as a narrative for stakeholders.
- Focus on the biggest commits (those that introduced several new lines of
  code), but do not report the number of added/removed lines.
- Do not report bug fixes
- Do not use superlative words like comprehensive, major, several, etc. Use
  only factual statements.
