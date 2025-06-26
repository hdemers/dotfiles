# Describe Jujutsu commit

Create well-formatted description for a Jujutsu commits with conventional
commit messages and emojis.

## Usage:
- `/describe <commit_id>` - Describe the given commit.

##  Features
- Uses conventional commit format with descriptive emojis
- Suggests splitting commits for different concerns

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

## Process:
1. Run pre-commit checks, see below
2. Analyze changes to determine commit type: `jj diff -r master..@`
3. Generate descriptive commit message
4. Include scope in summary: `type(scope): summary`
5. Add body for complex changes explaining why
6. Exclude Claude co-authorship footer from commits
7. Seek approval from user.
8. Execute: `jj describe <commit> -m <description>`

## Pre-commit checks
1. Runs pre-commit checks by default. For python code run:
    1. `jj diff -r master..@ --name-only | xargs ruff format`
    2. `jj diff -r master..@ --name-only | xargs ruff check`


## Best Practices:
- Keep commits atomic and focused
- Write in imperative mood ("Add feature" not "Added feature")
- Explain why, not just what
- Reference issues/PRs when relevant
- Split unrelated changes into separate commits
- Exclude Claude co-authorship footer from commits
