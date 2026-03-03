---
name: review-code-with-sow
description: Use this skill when you need to perform a code review with a statement of work, usually a ticket.
---

If no statement of work (SoW) was provided, stop and ask, do not proceed.

# Standard Operating Procedure

1. Determine changes to analyze:
   - If a PR was provided, run `gh pr view <number>` and `gh pr diff <number>`
   - If revisions were provided, run either of:
     - Jujutsu revset: `jj diff --git -r <revset>`
     - Git commits: `git diff <id1..id2>`
2. Determine Statement of Work:
   - This is usually a ticket: use the jira-ticket skill.
   - If ticket not provided by the user, search for it in the commit messages:
     - Jujutsu revset: `jj log -r <revset> -T description --no-graph`
     - Git commits: `git log <revision-range>`
   - Retrieve the ticket: `jira view <ticket>`
3. Perform a rigorous, constraint-based comparison against the Statement of Work:
   - EXPLICITLY cross-reference the list of modified files in the diff against
     the "Files to modify" list in the SoW. Flag any unlisted files as
     out-of-scope deviations.
   - EXPLICITLY verify that the exact code requested in the "Plan" section was
     implemented. Do not accept functionally equivalent alternatives if a
     specific implementation was mandated.
   - Confirm all acceptance criteria are met.
   - Confirm expected work product provided.
4. Analyze the changes and provide a thorough code review that includes:
   - Overview of what the changes do
   - Analysis of code quality and style
   - Specific suggestions for improvements
   - Any potential issues or risks
   - The detailed SoW comparison results from step 3.
5. Write the review to file: ,reviews/review-<ticket>-<date>.md.
   CRITICAL: the comma in front of 'reviews' is required.
   MANDATORY: if a review already exists, update it, do not create a new file.
6. If a ticket was provided, add as comment:
   `jira update <ticket> --comment <review>`
   MANDATORY: format the comment using the Jira markup language.
