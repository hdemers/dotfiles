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

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional

import click
import requests
import yaml
from rich.console import Console

console = Console()
error_console = Console(stderr=True)

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


def get_all_modified_languages() -> Dict[str, List[str]]:
    """Get all modified files grouped by detected language."""
    modified_files = get_modified_files()
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
        # Describe current commit
        result = subprocess.run(
            ["jj", "describe", "-r", "@", "-m", message],
            capture_output=True,
            text=True,
            timeout=30,
        )

        if result.returncode != 0:
            error_console.print("[red]Failed to describe commit[/red]")
            return_code = 1

        # Create new working commit
        result = subprocess.run(
            ["jj", "new"], capture_output=True, text=True, timeout=30
        )

        if result.returncode != 0:
            error_console.print("[red]Failed to create new working commit[/red]")
            return_code = 1

    except Exception as e:
        error_console.print(f"[red]Jujutsu command failed: {str(e)}[/red]")
        return_code = 1

    return return_code


def _lint(
    language: str,
    target_files: List[str],
    config_data: Dict,
) -> bool:
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
    """Run linters based on configuration."""

    config_data = load_config(config)

    if config_data is None:
        error_msg = f"Configuration required. Please create {config} with your linting preferences."
        error_console.print(f"[red]{error_msg}[/red]")
        sys.exit(1)

    # No language specified: auto-detect and lint all modified languages
    languages_map = get_all_modified_languages()
    if not languages_map:
        error_console.print("[yellow]No modified files found[/yellow]")
        sys.exit(1)

    return_codes = []
    for lang, files in languages_map.items():
        if lang in config_data.get("languages", {}):
            return_codes.append(_lint(lang, files, config_data))

    sys.exit(max(return_codes, default=0))


@cli.command()
@click.option("--message", "-m", default="wip: 🤖 checkpoint", help="Commit message")
def checkpoint(message: str):
    """Create automated checkpoint commit."""

    # Reuse existing function to get modified files
    modified_files = get_modified_files()

    # Check if there are files to commit
    if not modified_files:
        result = {
            "success": True,
            "message": "No modified files to commit",
            "modified_files": [],
            "vcs": detect_vcs(),
        }

        console.print("[yellow]No modified files to commit[/yellow]")
        sys.exit(0)

    # Detect VCS
    vcs = detect_vcs()
    if not vcs:
        error_msg = "No version control system detected"
        console.print(f"[red]{error_msg}[/red]")
        sys.exit(1)

    # Call appropriate VCS-specific function
    if vcs == "git":
        result = commit_git(message, modified_files)
    elif vcs == "jujutsu":
        result = commit_jujutsu(message)
    else:
        result = {"success": False, "error": f"Unsupported VCS: {vcs}"}

    # Handle output
    if result:
        error_console.print("[red]Could not checkpoint[/red]")
    else:
        console.print("[green]Checkpoint commit created successfully![/green]")

    sys.exit(result)


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
    input: str, message: str, priority: str, title: Optional[str], tags: Optional[str]
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

    input = json.loads(input) if input else {}
    message = input.get("message", message)

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
