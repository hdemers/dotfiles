---
name: jj-changelog
description: Proactively use to generate or update a CHANGELOG.md file from Jujutsu commit history.
---

# Jujutsu Changelog Generator

Generate or update a CHANGELOG.md file from Jujutsu history, emphasizing user-facing changes.

MANDATORY: do not analyze the repository yourself, everything you need is
provided by changes.sh.

## Standard Operating Procedure

1. Read CHANGELOG.md and identify the latest version tag.
2. Gather history using `changes.sh --from-version <version-tag>`.
3. Categorize each commit based on its description using conventional
   commit prefixes or semantic analysis:

   | Category             | Prefixes/Keywords                     | Emphasis                     |
   | -------------------- | ------------------------------------- | ---------------------------- |
   | Breaking Changes     | `BREAKING:`, `!:`, `breaking change`  | **HIGH** - Always at top     |
   | New Features         | `feat:`, `feature:`, `add:`           | **HIGH** - User-facing       |
   | Bug Fixes (User)     | `fix:` affecting user-facing behavior | **MEDIUM**                   |
   | Performance          | `perf:`                               | **MEDIUM** - If user-visible |
   | Bug Fixes (Internal) | `fix:` for internal/dev issues        | LOW                          |
   | Refactoring          | `refactor:`                           | LOW                          |
   | Documentation        | `docs:`                               | LOW                          |
   | Tests                | `test:`                               | LOW                          |
   | Chores               | `chore:`, `ci:`, `build:`             | LOW                          |

4. Update CHANGELOG.md following this template:

   ```markdown
   ## [version/tag] - YYYY-MM-DD

   ### Breaking Changes

   - **BREAKING**: Detailed/full description of breaking change
     - Detailed/full migration steps if applicable

   ### New Features

   - **Feature**: Description of new feature

   ### Bug Fixes

   - **Fix**: Description of user-facing bug fix

   ### Other Changes

   <details>
   <summary>Internal improvements and maintenance</summary>

   - Refactored X for better maintainability
   - Fixed internal issue with Y
   - Updated dependencies

   </details>
   ```

5. Formatting rules:
   - Breaking changes MUST be at the top of each version section
   - Breaking changes MUST include migration guidance when possible
   - User-facing features and fixes get full descriptions
   - Internal changes go in a collapsible `<details>` section
   - Empty sections should be omitted
   - Use imperative mood ("Add feature" not "Added feature")
   - Link to issues/PRs if referenced in commit messages

6. Write the changelog:
   - If CHANGELOG.md exists, update it (prepend new versions)
   - If it doesn't exist, create it
   - Preserve any manual edits in existing entries

## Example Output

```markdown
# Changelog

## [v2.1.0] - 2024-12-01

### Breaking Changes

- **BREAKING**: Removed deprecated `legacy_api()` function
  - Migrate to `new_api()` which provides the same functionality

### New Features

- **Feature**: Add support for custom output formats
- **Feature**: New `--verbose` flag for detailed logging

### Bug Fixes

- **Fix**: Resolve crash when input file is empty
- **Fix**: Correct timezone handling in date parsing

### Other Changes

<details>
<summary>Internal improvements and maintenance</summary>

- Refactored configuration loading for clarity
- Fixed flaky test in CI pipeline
- Updated pytest to 8.0

</details>

## [v2.0.0] - 2024-11-15

...
```

## Notes

- If commits don't follow conventional commits, use best judgment to categorize
- When uncertain if a change is user-facing, err on the side of including it in the main sections
- Commits with empty descriptions should be skipped
- Multiple commits can be consolidated if they address the same feature/fix
