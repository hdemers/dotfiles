---
allowed-tools: Bash(jj describe:*), Bash(jj diff:*), Bash(jj log:*)
description: Describe a Jujutsu commit
---
# Describe Jujutsu commit

Create well-formatted description for Jujutsu commits with conventional
commit messages and emojis.

## Context
- Current description: !`jj log -r $CLAUDE_REVSET`
- Current diff: !`jj diff --git -r $CLAUDE_REVSET`

##  Features
- Uses conventional commit format with descriptive emojis

## Commit Types
- ✨feat: New features
- 🐛fix: Bug fixes
- 📝docs: Documentation changes
- ♻️refactor: Code restructuring without changing functionality
- 🎨style: Code formatting, missing semicolons, etc.
- ⚡️perf: Performance improvements
- ✅test: Adding or correcting tests
- 💤chore: Tooling, configuration, maintenance
- 🚧wip: Work in progress
- 🔥remove: Removing code or files
- 🚑hotfix: Critical fixes
- 🔒security: Security improvements

## TODOs:
1. Based on the above context, generate a descriptive commit message
2. Include scope in summary: `type(scope): summary`
3. Add body for complex changes explaining why
6. Execute: `jj describe -r $ARGUMENT -m <description>`

## Best Practices:
- Limit the title of commit messages to 50 characters and the body to 79.
- Write in imperative mood ("Add feature" not "Added feature")
- Explain why, not just what
- Exclude Claude co-authorship footer from commits
