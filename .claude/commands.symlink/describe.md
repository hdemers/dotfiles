---
allowed-tools: Bash(jj diff:*), Bash(jj log:*)
description: Provide a Jujutsu commit description and ONLY the description.
---
# Describe Jujutsu commit

Create well-formatted description for Jujutsu commits with conventional
commit messages and emojis and answer to the user with the description, nothing
else.

## Context
- Current description: !`jj log -r $CLAUDE_REVSET`
- Current diff: !`jj diff --git -r $CLAUDE_REVSET`

##  Format
- Uses conventional commit format with descriptive emojis from the
[gitmoji](https://gitmoji.dev/) set.
- Include scope in summary if applicable.

Example format:
```
<emoji><type>(<scope>): <summary>

<body>

```

## TODOs:
1. Based on the above context, generate a descriptive commit message
2. Write summary, one line, maximum of 50 characters.
3. Add body for complex changes explaining why, limit lines to 79 characters.

## Best Practices:
- Limit the title of commit messages to 50 characters and the body to 79.
- Write in imperative mood ("Add feature" not "Added feature")
- Explain why, not just what
- Exclude Claude co-authorship footer from commits
