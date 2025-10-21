#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "click>=8.0.0",
#     "rich>=13.0.0",
#     "pyyaml>=6.0",
#     "requests>=2.25.0",
# ]
# ///

import atexit
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from time import sleep
from typing import Dict, List, Optional
from functools import wraps

import click
import requests
import yaml
from rich.console import Console

console = Console()
error_console = Console(stderr=True)


def single_instance(func):
    """Decorator to ensure only one instance of the function runs at a time."""

    @wraps(func)
    def wrapper(*args, **kwargs):
        # Generate a unique lock file name based on current working directory
        cwd_hash = hashlib.md5(os.getcwd().encode()).hexdigest()[:8]
        lock_file = Path(tempfile.gettempdir()) / f".claude-checkpoint-{cwd_hash}.lock"

        def cleanup_lock():
            """Clean up lock file on exit."""
            try:
                if lock_file.exists():
                    lock_file.unlink()
            except Exception:
                pass

        def is_process_alive(pid):
            """Check if a process is still running."""
            try:
                # Check if /proc/pid exists (Linux/Unix)
                return Path(f"/proc/{pid}").exists()
            except Exception:
                # Fallback: try to send signal 0
                try:
                    os.kill(pid, 0)
                    return True
                except (OSError, ProcessLookupError):
                    return False

        # Check if lock file exists and process is alive
        if lock_file.exists():
            try:
                lock_data = json.loads(lock_file.read_text())
                if is_process_alive(lock_data["pid"]):
                    error_console.print(
                        "[red]Another checkpoint instance is already running[/red]"
                    )
                    sys.exit(1)
                else:
                    # Stale lock, remove it
                    lock_file.unlink()
            except (json.JSONDecodeError, KeyError, Exception):
                # Corrupted lock file, remove it
                try:
                    lock_file.unlink()
                except Exception:
                    pass

        # Create lock file
        try:
            lock_data = {"pid": os.getpid(), "timestamp": int(time.time())}
            lock_file.write_text(json.dumps(lock_data))
            atexit.register(cleanup_lock)
        except Exception as e:
            error_console.print(f"[red]Failed to create lock file: {e}[/red]")
            sys.exit(1)

        try:
            return func(*args, **kwargs)
        finally:
            cleanup_lock()

    return wrapper


# Language file patterns for filtering
LANGUAGE_PATTERNS = {
    "python": [
        "*.py",
    ],
    "javascript": ["*.js", "*.jsx", "*.mjs"],
    "typescript": ["*.ts", "*.tsx", "*.d.ts"],
    "rust": ["*.rs"],
    "go": ["*.go"],
    "shell": ["*.sh", "*.bash", "*.zsh", "*.fish"],
    "yaml": ["*.yml", "*.yaml"],
    "dockerfile": ["Dockerfile*", "*.dockerfile", ".dockerignore"],
    "sql": ["*.sql"],
}


def load_config(config_path: str = "config.yaml") -> Optional[Dict]:
    """Load configuration from YAML file."""
    # Get the directory of the current file
    config_file = Path(__file__).parent / config_path

    if not config_file.exists():
        console.print(f"[red]Config file {config_file} not found[/red]")
        return None

    try:
        with open(config_file, "r") as f:
            config = yaml.safe_load(f)
            if not config:
                console.print(f"[red]Config file {config_file} is empty[/red]")
                return None
            return config
    except Exception as e:
        console.print(f"[red]Error loading config: {e}[/red]")
        return None


def get_files_from_stdin() -> List[str]:
    """Extract modified file paths from stdin JSON data provided by PostToolUse hook."""
    try:
        # Read JSON from stdin
        stdin_data = sys.stdin.read()
        if not stdin_data:
            return []

        hook_data = json.loads(stdin_data)
        tool_name = hook_data.get("tool_name", "")
        tool_input = hook_data.get("tool_input", {})

        files = []

        # Extract file paths based on tool type
        if tool_name in ["Write", "Edit"]:
            file_path = tool_input.get("file_path")
            if file_path:
                files.append(file_path)

        elif tool_name == "MultiEdit":
            edits = tool_input.get("edits", [])
            for edit in edits:
                file_path = edit.get("file_path")
                if file_path:
                    files.append(file_path)

        elif tool_name == "NotebookEdit":
            notebook_path = tool_input.get("notebook_path")
            if notebook_path:
                files.append(notebook_path)

        # Return unique file paths
        return list(set(files))

    except (json.JSONDecodeError, KeyError) as e:
        error_console.print(f"[yellow]Warning: Failed to parse stdin JSON: {e}[/yellow]")
        return []
    except Exception as e:
        error_console.print(f"[yellow]Warning: Unexpected error reading stdin: {e}[/yellow]")
        return []


def get_modified_files() -> List[str]:
    """Get list of modified files using Jujutsu or Git."""
    modified_files = []
    vcs = detect_vcs()

    # Try Jujutsu first
    if vcs == "jujutsu":
        try:
            result = subprocess.run(
                ["jj", "diff", "--name-only", "-r", "@"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode == 0:
                files = [f.strip() for f in result.stdout.split("\n") if f.strip()]
                return files
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass
    elif vcs == "git":
        try:
            # Get files modified in working directory vs HEAD
            result1 = subprocess.run(
                ["git", "diff", "--name-only", "HEAD"],
                capture_output=True,
                text=True,
                timeout=10,
            )

            # Get staged files
            result2 = subprocess.run(
                ["git", "diff", "--cached", "--name-only"],
                capture_output=True,
                text=True,
                timeout=10,
            )

            # Combine results
            if result1.returncode == 0:
                modified_files.extend(
                    f.strip() for f in result1.stdout.split("\n") if f.strip()
                )
            if result2.returncode == 0:
                modified_files.extend(
                    f.strip() for f in result2.stdout.split("\n") if f.strip()
                )
            return list(set(modified_files))

        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass

    else:
        error_console.print("[red]No supported version control system detected[/red]")
        return []

    return []


def get_all_modified_languages(file_list: Optional[List[str]] = None) -> Dict[str, List[str]]:
    """Get all modified files grouped by detected language.

    Args:
        file_list: Optional list of files to categorize. If None, uses get_modified_files().
    """
    modified_files = file_list if file_list is not None else get_modified_files()
    languages_map = {}

    for file_path in modified_files:
        path = Path(file_path)

        # Check each language to see if this file matches
        for language, patterns in LANGUAGE_PATTERNS.items():
            for pattern in patterns:
                if path.match(pattern) or path.name == pattern:
                    if language not in languages_map:
                        languages_map[language] = []
                    if file_path not in languages_map[language]:
                        languages_map[language].append(file_path)
                    break

    return languages_map


def normalize_to_absolute_paths(files: List[str], cwd: Optional[str] = None) -> List[str]:
    """Normalize file paths to absolute paths.

    Args:
        files: List of file paths (can be relative or absolute)
        cwd: Current working directory for resolving relative paths (defaults to os.getcwd())

    Returns:
        List of absolute paths
    """
    if cwd is None:
        cwd = os.getcwd()

    base_path = Path(cwd).resolve()
    absolute_paths = []

    for file_path in files:
        path = Path(file_path)
        if path.is_absolute():
            absolute_paths.append(str(path.resolve()))
        else:
            absolute_paths.append(str((base_path / path).resolve()))

    return absolute_paths


def detect_language(directory: str = ".") -> Optional[str]:
    """Auto-detect programming language based on files in directory."""
    path = Path(directory)

    # Language detection patterns
    patterns = {
        "python": ["*.py", "requirements.txt", "pyproject.toml", "setup.py"],
        "javascript": ["*.js", "package.json", "*.jsx"],
        "typescript": ["*.ts", "*.tsx", "tsconfig.json"],
        "rust": ["Cargo.toml", "*.rs"],
        "go": ["go.mod", "*.go"],
    }

    for language, file_patterns in patterns.items():
        for pattern in file_patterns:
            if list(path.glob(pattern)):
                return language

    return None


def detect_vcs() -> Optional[str]:
    """Detect which VCS is being used - reuse get_modified_files logic."""
    if Path(".jj").exists():
        return "jujutsu"
    elif Path(".git").exists():
        return "git"
    return None


def commit_git(message: str, modified_files: List[str]) -> int:
    """Handle Git commits."""
    return_code = 0
    try:
        # Stage all changes
        result = subprocess.run(
            ["git", "add", " ".join(modified_files)],
            capture_output=True,
            text=True,
            timeout=30,
        )

        if result.returncode != 0:
            error_console.print(f"[red]Failed to stage changes: {result.stderr}[/red]")

        # Create commit
        result = subprocess.run(
            ["git", "commit", "-m", message], capture_output=True, text=True, timeout=30
        )

        if result.returncode != 0:
            return_code = 1
            # Handle "nothing to commit" case gracefully
            if "nothing to commit" in result.stdout.lower():
                error_console.print("[yellow]No changes to commit[/yellow]")
            else:
                error_console.print(
                    f"[red]Failed to create commit: {result.stderr}[/red]"
                )

    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        error_console.print(f"[red]Git command failed: {str(e)}[/red]")
        return_code = 1

    return return_code


def commit_jujutsu(message: str) -> int:
    """Handle Jujutsu commits."""
    return_code = 0
    try:
        # Make sure that the current revision has changes
        result = subprocess.run(
            ["jj", "diff", "-r", "@"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode != 0:
            error_console.print("[red]Failed to check Jujutsu status[/red]")
            return 1

        if not result.stdout.lower():
            error_console.print("[yellow]The working copy has no changes.")
            return 1

        # Describe current commit
        result = subprocess.run(
            ["jj", "describe", "-r", "@", "-m", message],
            capture_output=True,
            text=True,
            timeout=30,
        )

        if result.returncode != 0:
            error_console.print("[red]Failed to describe commit[/red]")
            return 1

        sleep(1)
        # Create new working commit
        result = subprocess.run(
            ["jj", "new"], capture_output=True, text=True, timeout=30
        )

        if result.returncode != 0:
            error_console.print("[red]Failed to create new working commit[/red]")
            return 1

    except Exception as e:
        error_console.print(f"[red]Jujutsu command failed: {str(e)}[/red]")
        return_code = 1

    return return_code


def _lint(
    language: str,
    target_files: List[str],
    config_data: Dict,
) -> int:
    """Run linters for a specific language on target files."""
    linters = config_data["languages"][language]["linters"]

    console.print(
        f"Running [bold]{language}[/bold] linters on {len(target_files)} file(s)"
    )

    return_code = 0
    ran_linters = []

    for linter_cmd in linters:
        console.print(f"[blue]Running:[/blue] {linter_cmd}")

        cmd_parts = linter_cmd.split()
        cmd_parts.extend(target_files)

        try:
            result = subprocess.run(
                cmd_parts,
                capture_output=True,
                text=True,
                timeout=120,
            )

            ran_linters.append(linter_cmd)

            if result.returncode != 0:
                return_code = 2
                if result.stdout:
                    error_console.print(f"\n{result.stdout.strip()}")
                if result.stderr:
                    error_console.print(f"\n{result.stderr.strip()}")

        except FileNotFoundError:
            return_code = 1
            error_console.print(
                f"[red]Skipping linting {language} files as "
                + f"command not found: {linter_cmd}[/red]"
            )
        except Exception as error:
            return_code = 1
            error_console.print(f"[red]Error while linting: {str(error)}[/red]")

    if return_code:
        error_console.print(
            f"[red]Linting FAILED! ({len(ran_linters)}/{len(linters)} ran)[/red]"
        )
        error_console.print("\n[red]STOP and FIX[/red]")
    else:
        console.print(
            f"[green]All available linters passed! ({len(ran_linters)}/{len(linters)} ran)[/green]"
        )

    return return_code


def _type_check(
    language: str,
    target_files: List[str],
    config_data: Dict,
) -> int:
    """Run type checkers for a specific language on target files."""
    type_checkers = config_data["languages"][language]["type_checkers"]

    console.print(
        f"Running [bold]{language}[/bold] type checkers on {len(target_files)} file(s)"
    )

    return_code = 0
    ran_type_checkers = []

    for type_checker_cmd in type_checkers:
        console.print(f"[blue]Running:[/blue] {type_checker_cmd}")

        cmd_parts = type_checker_cmd.split()
        cmd_parts.extend(target_files)

        try:
            result = subprocess.run(
                cmd_parts,
                capture_output=True,
                text=True,
                timeout=120,
            )

            ran_type_checkers.append(type_checker_cmd)

            if result.returncode != 0:
                return_code = 2
                if result.stdout:
                    error_console.print(f"\n{result.stdout.strip()}")
                if result.stderr:
                    error_console.print(f"\n{result.stderr.strip()}")

        except FileNotFoundError:
            return_code = 1
            error_console.print(
                f"[red]Skipping type checking {language} files as "
                + f"command not found: {type_checker_cmd}[/red]"
            )
        except Exception as error:
            return_code = 1
            error_console.print(f"[red]Error while type checking: {str(error)}[/red]")

    if return_code:
        error_console.print(
            f"[red]Type checking FAILED! ({len(ran_type_checkers)}/{len(type_checkers)} ran)[/red]"
        )
        error_console.print("\n[red]STOP and FIX[/red]")
    else:
        console.print(
            f"[green]All available type checkers passed! ({len(ran_type_checkers)}/{len(type_checkers)} ran)[/green]"
        )

    return return_code


@click.group()
@click.version_option()
def cli():
    """Claude Code Hooks - Linting and Notification Tool"""
    pass


@cli.command()
@click.option("--config", "-c", default="config.yaml", help="Config file path")
def lint(
    config: str,
):
    """Run linters based on configuration using files from stdin JSON."""

    config_data = load_config(config)

    if config_data is None:
        error_msg = f"Configuration required. Please create {config} with your linting preferences."
        error_console.print(f"[red]{error_msg}[/red]")
        sys.exit(1)

    # Type narrowing for type checker
    assert config_data is not None

    # Get files from stdin (PostToolUse hook)
    modified_files = get_files_from_stdin()

    # Skip silently if no files were modified
    if not modified_files:
        sys.exit(0)

    # Auto-detect and lint all modified languages
    languages_map = get_all_modified_languages(modified_files)
    if not languages_map:
        # Files were modified but none are lintable - skip silently
        sys.exit(0)

    return_codes = []
    languages = config_data.get("languages", {})
    for lang, files in languages_map.items():
        if languages and lang in languages:
            return_codes.append(_lint(lang, files, config_data))

    sys.exit(max(return_codes, default=0))


@cli.command(name="type-check")
@click.option("--config", "-c", default="config.yaml", help="Config file path")
def type_check(
    config: str,
):
    """Run type checkers based on configuration using files from stdin JSON."""

    config_data = load_config(config)

    if config_data is None:
        error_msg = f"Configuration required. Please create {config} with your type checking preferences."
        error_console.print(f"[red]{error_msg}[/red]")
        sys.exit(1)

    # Type narrowing for type checker
    assert config_data is not None

    # Get files from stdin (PostToolUse hook)
    modified_files = get_files_from_stdin()

    # Skip silently if no files were modified
    if not modified_files:
        sys.exit(0)

    # Auto-detect and type check all modified languages
    languages_map = get_all_modified_languages(modified_files)
    if not languages_map:
        # Files were modified but none are type checkable - skip silently
        sys.exit(0)

    return_codes = []
    languages = config_data.get("languages", {})
    for lang, files in languages_map.items():
        if (
            languages
            and lang in languages
            and "type_checkers" in languages[lang]
        ):
            return_codes.append(_type_check(lang, files, config_data))

    sys.exit(max(return_codes, default=0))


@cli.command()
@click.option("--message", "-m", default="🤖 wip: checkpoint", help="Commit message")
@single_instance
def checkpoint(message: str):
    """Create automated checkpoint commit using stdin data with overlap detection."""
    return_code = 0

    # Get files from stdin (PostToolUse hook)
    stdin_files = get_files_from_stdin()

    # Exit silently if no files from stdin (no files modified by Claude)
    if not stdin_files:
        sys.exit(0)

    # Get modified files from VCS
    vcs_files = get_modified_files()

    # Exit silently if no VCS changes
    if not vcs_files:
        sys.exit(0)

    # Normalize both lists to absolute paths for comparison
    stdin_absolute = set(normalize_to_absolute_paths(stdin_files))
    vcs_absolute = set(normalize_to_absolute_paths(vcs_files))

    # Find intersection - only files that Claude edited AND are in the current repo
    overlapping_files = stdin_absolute & vcs_absolute

    # Exit silently if no overlap (Claude edited files outside this repo)
    if not overlapping_files:
        sys.exit(0)

    # Convert back to list for VCS operations
    files_to_commit = list(overlapping_files)

    # Detect VCS
    vcs = detect_vcs()
    if not vcs:
        error_console.print("[red]No version control system detected[/red]")
        sys.exit(1)

    # Call appropriate VCS-specific function
    if vcs == "git":
        return_code = commit_git(message, files_to_commit)
    elif vcs == "jujutsu":
        return_code = commit_jujutsu(message)
    else:
        error_console.print(f"[red]Unsupported VCS: {vcs}[/red]")
        return_code = 1

    # Handle output
    console.print("[green]Checkpoint commit created successfully![/green]")

    sys.exit(return_code)


def get_ntfy_channel() -> Optional[str]:
    """Get ntfy channel from secret command or environment variable."""
    channel = os.getenv("NTFY_NEPTUNE_CHANNEL")
    if not channel:
        try:
            result = subprocess.run(
                ["secret", "lookup", "ntfy", "neptune"],
                capture_output=True,
                text=True,
                timeout=10,
            )

            if result.returncode:
                console.print(
                    "[yellow]Could not retrieve ntfy channel from secrets: "
                    + f"{result.stderr.strip()}[/yellow]"
                )
            else:
                channel = result.stdout.strip()

        except Exception as e:
            console.print(f"[yellow]Failed to retrieve ntfy channel: {str(e)}[/yellow]")

    return channel


@cli.command()
@click.argument("input", type=str, required=False)
@click.option(
    "--message",
    "-m",
    default="Message from Claude",
    help="Override message from Claude",
)
@click.option(
    "--priority",
    "-p",
    default="high",
    type=click.Choice(["min", "low", "default", "high", "max"]),
    help="Notification priority",
)
@click.option("--title", "-t", default="Message from Claude", help="Notification title")
@click.option("--tags", default="robot", help="Comma-separated tags")
def notify(
    input: str,
    message: str,
    priority: str,
    title: Optional[str],
    tags: Optional[str],
):
    """Send notification via ntfy.sh."""

    # Get ntfy channel using fallback strategy
    channel = get_ntfy_channel()

    if not channel:
        console.print("[red]Failed to get ntfy channel[/red]")
        console.print("[yellow]Try one of the following:[/yellow]")
        console.print("  1. Install and configure 'secret' command")
        console.print("  2. Set NTFY_NEPTUNE_CHANNEL environment variable")
        console.print("     Example: export NTFY_NEPTUNE_CHANNEL=your-topic-name")
        sys.exit(1)

    input_dict = json.loads(input) if input else {}
    message = input_dict.get("message", message)

    # Prepare notification payload
    headers = {"Content-Type": "text/plain; charset=utf-8"}

    if title:
        headers["X-Title"] = title
    if priority != "default":
        headers["Priority"] = priority
    if tags:
        headers["Tags"] = tags

    url = f"https://ntfy.sh/{channel}"

    try:
        response = requests.post(
            url, data=message.encode("utf-8"), headers=headers, timeout=10
        )

        if response.status_code == 200:
            console.print("[green]✓ Notification sent successfully![/green]")
        else:
            console.print(
                f"[red]Failed to send notification: {response.status_code}[/red]"
            )
            console.print(f"Response: {response.text}")
            sys.exit(1)

    except requests.RequestException as e:
        console.print(f"[red]Network error: {e}[/red]")
        sys.exit(1)


if __name__ == "__main__":
    cli()
