---
description: Provide a Jujutsu commit description and ONLY the description.
allowed-tools: Bash(jj diff:*), Bash(jj log:*)
---

# Context
- Current description: !`jj log -r $AGENT_REVSET`
- Current diff: !`jj diff --git -r $AGENT_REVSET`

# Standard Operating Procedure

1. Based on the above context, generate a descriptive commit message
2. Perform a careful breaking change analysis in the public API. Ultrathink.
3. Use conventional commit standard with [gitmoji](https://gitmoji.dev/).
4. Write summary, one line, maximum of 50 characters.
5. Add body for complex changes explaining why, limit lines to 79 characters.
6. If breaking changes found:
   1. add ! immediately after the colon in the summary. 
   2. Add a footer. It must consist of the uppercase text BREAKING CHANGE,
      followed by a colon, space and description.

##  Format

<emoji><type>(<scope>)[!]: <summary>

<body>

[BREAKING CHANGE: <description>]


# Best Practices

- Include scope in summary if applicable.
- MANDATORY: your answer must contain only the commit message, nothing else.
- MANDATORY: do not wrap the commit message in triple quotes ``` ```
- Limit the title of the commit message to 50 characters and the body to 79.
- Write in imperative mood ("Add feature" NOT "Added feature")
- Explain why, not just what
- Exclude co-authorship footer from commits
