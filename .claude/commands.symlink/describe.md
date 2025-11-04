---
allowed-tools: Bash(jj diff:*), Bash(jj log:*)
description: Provide a Jujutsu commit description and ONLY the description.
---
# Describe Jujutsu commit

Create well-formatted description for Jujutsu commits with conventional
commit messages and emojis

MANDATORY: ultrathink carefully to analyze the commit for breaking changes in
the public API. If found, breaking changes MUST be indicated by a ! immediately
before the :. Moreover, breaking changes must be described in a footer of the
commit body. The footer MUST consist of uppercase text BREAKING CHANGE,
followed by a colon, space and description.

## Context
- Current description: !`jj log -r $CLAUDE_REVSET`
- Current diff: !`jj diff --git -r $CLAUDE_REVSET`

##  Format
- Uses conventional commit format with descriptive emojis from the
[gitmoji](https://gitmoji.dev/) set.
- Include scope in summary if applicable.
- MANDATORY: your answer must contain only the commit message, nothing else.
- MANDATORY: do not wrap the commit message in triple quotes ``` ```

Example format:
```
<emoji><type>(<scope>)[!]: <summary>

<body>

[BREAKING CHANGE: <description>]
```

## TODOs:
1. Based on the above context, generate a descriptive commit message
2. Write summary, one line, maximum of 50 characters.
3. Add body for complex changes explaining why, limit lines to 79 characters.

## Best Practices:
- Limit the title of the commit message to 50 characters and the body to 79.
- Write in imperative mood ("Add feature" NOT "Added feature")
- Explain why, not just what
- Exclude Claude co-authorship footer from commits
