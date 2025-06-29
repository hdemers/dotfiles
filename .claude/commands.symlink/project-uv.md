# uv-based project instructions

These are instructions on how to use a uv-based project.

## Running commands
Run a command using the following pattern:

```sh
uv run <command>
```

For example:

```sh
uv run python -c "import example"
```

## Managing dependencies
These are the commands to manage dependencies:

- `uv add <package`
- `uv remove <package>`

These will modify pyproject.toml, so you do not need to do that yourself.

## Code quality

Ruff is used to format and lint code:

- Format: `uv run ruff format`
- Lint: `uv run ruff check`
