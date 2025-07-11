# Commit

Create well-formatted commits with conventional commit messages and emojis.

## Usage:
- `/commit` - Standard commit with pre-commit checks
- `/commit --no-verify` - Skip pre-commit checks

##  Features
- Uses conventional commit format with descriptive emojis
- Suggests splitting commits for different concerns

## Message format
1. Use [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/) to write commit messages.
2. Limit the title of commit messages to 50 characters and the body to 79.
3. Use [semantic versioning](https://semver.org/).
4. Use [conventional comments](https://conventionalcomments.org) when reviewing PRs.
6. Avoid superlatives like comprehensive, major, etc.


### Commit Types:
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
1. Run pre-commit checks (unless --no-verify), see below
2. Analyze changes to determine commit type
3. Generate descriptive commit message
4. Include scope in summary: `type(scope): summary`
5. Add body for complex changes explaining why
6. Exclude Claude co-authorship footer from commits
7. Seek approval from user.
8. Execute commit
9. Push the changes to the remote.
10. If the push is rejected, stop there, do not try to fix, notify the user using the `notify` tool.

## Pre-commit checks
1. Runs pre-commit checks by default. For python code run:
    1. `ruff format`
    2. `ruff check --fix`
    3. `basedpyright` (if available)
    4. `ty` (if available)


## Best Practices:
- Keep commits atomic and focused
- Write in imperative mood ("Add feature" not "Added feature")
- Explain why, not just what
- Reference issues/PRs when relevant
- Split unrelated changes into separate commits
- Exclude Claude co-authorship footer from commits
