# Describe Jujutsu commit

Create well-formatted description for Jujutsu commits with conventional
commit messages and emojis.

## Usage:
- `/describe <revset> <ticket>` - Describe the given commit.

##  Features
- Uses conventional commit format with descriptive emojis

## Commit Types:
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
1. Analyze changes to determine commit type.
    - Command: `jj diff --git -r <revset>`
2. Generate descriptive commit message
3. Include scope in summary: `type(scope): summary`
4. Add body for complex changes explaining why
5. If provided, at the `<ticket>` at the end of the body, on a line of its own.
5. Seek approval from user.
6. Execute: `jj describe -r <revset> -m <description>`

## Best Practices:
- Limit the title of commit messages to 50 characters and the body to 79.
- Write in imperative mood ("Add feature" not "Added feature")
- Explain why, not just what
- Exclude Claude co-authorship footer from commits
