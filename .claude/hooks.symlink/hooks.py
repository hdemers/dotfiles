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
        "*.pyi",
        "*.pyx",
        "requirements.txt",
        "pyproject.toml",
        "setup.py",
    ],
    "javascript": ["*.js", "*.jsx", "*.mjs", "package.json"],
    "typescript": ["*.ts", "*.tsx", "*.d.ts", "tsconfig.json"],
    "rust": ["*.rs", "Cargo.toml", "Cargo.lock"],
    "go": ["*.go", "go.mod", "go.sum"],
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

    # Try Jujutsu first
    if Path(".jj").exists():
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

    # Fall back to Git
    if Path(".git").exists():
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

            # Remove duplicates while preserving order
            seen = set()
            unique_files = []
            for f in modified_files:
                if f not in seen:
                    seen.add(f)
                    unique_files.append(f)

            return unique_files

        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass

    return []


def filter_files_by_language(files: List[str], language: str) -> List[str]:
    """Filter files to only include those matching the specified language."""
    if language not in LANGUAGE_PATTERNS:
        return []

    patterns = LANGUAGE_PATTERNS[language]
    filtered_files = []

    for file_path in files:
        path = Path(file_path)
        # Check if file matches any pattern for this language
        for pattern in patterns:
            if path.match(pattern) or path.name == pattern:
                filtered_files.append(file_path)
                break

    return filtered_files


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


def commit_git(message: str, modified_files: List[str], dry_run: bool) -> Dict:
    """Handle Git commits."""
    if dry_run:
        return {
            "success": True,
            "dry_run": True,
            "vcs": "git",
            "message": message,
            "modified_files": modified_files,
            "commands": ["git add -A", f'git commit -m "{message}"'],
        }

    try:
        # Stage all changes
        stage_result = subprocess.run(
            ["git", "add", "-A"], capture_output=True, text=True, timeout=30
        )

        if stage_result.returncode != 0:
            return {
                "success": False,
                "vcs": "git",
                "error": f"Failed to stage files: {stage_result.stderr}",
                "modified_files": modified_files,
            }

        # Create commit
        commit_result = subprocess.run(
            ["git", "commit", "-m", message], capture_output=True, text=True, timeout=30
        )

        if commit_result.returncode != 0:
            # Handle "nothing to commit" case gracefully
            if "nothing to commit" in commit_result.stdout.lower():
                return {
                    "success": True,
                    "vcs": "git",
                    "message": message,
                    "modified_files": modified_files,
                    "info": "No changes to commit",
                }
            else:
                return {
                    "success": False,
                    "vcs": "git",
                    "error": f"Failed to create commit: {commit_result.stderr}",
                    "modified_files": modified_files,
                }

        # Extract commit hash from output
        commit_hash = None
        for line in commit_result.stdout.split("\n"):
            if "[" in line and "]" in line:
                # Look for pattern like "[main abc123f] commit message"
                parts = line.split("]")[0].split()
                if len(parts) >= 2:
                    commit_hash = parts[-1]
                    break

        return {
            "success": True,
            "vcs": "git",
            "message": message,
            "commit_hash": commit_hash,
            "modified_files": modified_files,
            "files_committed": len(modified_files),
        }

    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        return {
            "success": False,
            "vcs": "git",
            "error": f"Git command failed: {str(e)}",
            "modified_files": modified_files,
        }


def commit_jujutsu(message: str, modified_files: List[str], dry_run: bool) -> Dict:
    """Handle Jujutsu commits."""
    if dry_run:
        return {
            "success": True,
            "dry_run": True,
            "vcs": "jujutsu",
            "message": message,
            "modified_files": modified_files,
            "commands": [f'jj describe -r @ -m "{message}"', "jj new"],
        }

    try:
        # Describe current commit
        describe_result = subprocess.run(
            ["jj", "describe", "-r", "@", "-m", message],
            capture_output=True,
            text=True,
            timeout=30,
        )

        if describe_result.returncode != 0:
            return {
                "success": False,
                "vcs": "jujutsu",
                "error": f"Failed to describe commit: {describe_result.stderr}",
                "modified_files": modified_files,
            }

        # Create new working commit
        new_result = subprocess.run(
            ["jj", "new"], capture_output=True, text=True, timeout=30
        )

        if new_result.returncode != 0:
            return {
                "success": False,
                "vcs": "jujutsu",
                "error": f"Failed to create new commit: {new_result.stderr}",
                "modified_files": modified_files,
            }

        # Extract commit ID from jj new output if possible
        commit_id = None
        for line in new_result.stderr.split("\n"):
            if "Working copy now at:" in line:
                parts = line.split()
                if len(parts) >= 4:
                    commit_id = parts[4]  # Usually the commit ID
                    break

        return {
            "success": True,
            "vcs": "jujutsu",
            "message": message,
            "commit_id": commit_id,
            "modified_files": modified_files,
            "files_committed": len(modified_files),
        }

    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        return {
            "success": False,
            "vcs": "jujutsu",
            "error": f"Jujutsu command failed: {str(e)}",
            "modified_files": modified_files,
        }


def run_linters_for_language(
    language: str,
    target_files: List[str],
    directory: str,
    config_data: Dict,
    json_output: bool,
) -> bool:
    """Run linters for a specific language on target files."""
    linters = config_data["languages"][language]["linters"]

    if not json_output:
        if target_files:
            console.print(
                f"Running [bold]{language}[/bold] linters on {len(target_files)} file(s)"
            )
        else:
            console.print(f"Running [bold]{language}[/bold] linters in {directory}")

    results = []
    overall_success = True
    missing_tools = []
    ran_linters = []

    for linter_cmd in linters:
        if not json_output:
            console.print(f"\n[blue]Running:[/blue] {linter_cmd}")

        # Modify command to target specific files if provided
        if target_files:
            cmd_parts = linter_cmd.split()
            cmd_parts.extend(target_files)
        else:
            cmd_parts = linter_cmd.split()

        try:
            result = subprocess.run(
                cmd_parts,
                cwd=directory,
                capture_output=True,
                text=True,
                timeout=120,
            )

            linter_result = {
                "command": linter_cmd,
                "exit_code": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "success": result.returncode == 0,
            }

            results.append(linter_result)
            ran_linters.append(linter_cmd)

            if result.returncode != 0:
                overall_success = False

            if not json_output:
                if result.returncode == 0:
                    console.print("[green]✓ Passed[/green]")
                else:
                    error_console.print("[red]✗ Failed[/red]")
                    if result.stdout:
                        error_console.print(
                            f"[dim]stdout:[/dim] {result.stdout.strip()}"
                        )
                    if result.stderr:
                        error_console.print(
                            f"[dim]stderr:[/dim] {result.stderr.strip()}"
                        )

        except subprocess.TimeoutExpired:
            linter_result = {
                "command": linter_cmd,
                "exit_code": -1,
                "stdout": "",
                "stderr": "Command timed out",
                "success": False,
            }
            results.append(linter_result)
            ran_linters.append(linter_cmd)
            overall_success = False

            if not json_output:
                error_console.print("[red]✗ Timed out[/red]")

        except FileNotFoundError:
            # Graceful degradation - track missing tools but don't fail overall
            missing_tool = linter_cmd.split()[0]
            missing_tools.append(missing_tool)

            linter_result = {
                "command": linter_cmd,
                "exit_code": -1,
                "stdout": "",
                "stderr": f"Command not found: {missing_tool}",
                "success": False,
                "skipped": True,
            }
            results.append(linter_result)

            if not json_output:
                console.print(
                    f"[yellow]⚠ Skipped: {missing_tool} not installed[/yellow]"
                )

    if json_output:
        output = {
            "language": language,
            "directory": directory,
            "success": overall_success,
            "results": results,
            "missing_tools": missing_tools,
            "ran_linters": len(ran_linters),
            "total_linters": len(linters),
            "target_files": target_files,
        }
        click.echo(json.dumps(output, indent=2))
    else:
        # Summary output
        if missing_tools:
            console.print(
                f"\n[yellow]⚠ Missing tools: {', '.join(missing_tools)}[/yellow]"
            )

        if ran_linters:
            if overall_success:
                console.print(
                    f"\n[green]All available linters passed! ✓ ({len(ran_linters)}/{len(linters)} ran)[/green]"
                )
            else:
                error_console.print(
                    f"\n[red]Some linters failed! ✗ ({len(ran_linters)}/{len(linters)} ran)[/red]"
                )
        else:
            console.print(
                "\n[yellow]No linters were able to run - all tools missing[/yellow]"
            )

    # Only exit with error if linters actually ran and failed
    # Don't fail if tools are just missing (graceful degradation)
    if ran_linters:
        if not overall_success:
            sys.exit(2)
    else:
        # All tools missing but don't block the agent
        pass

    return overall_success


@click.group()
@click.version_option()
def cli():
    """Claude Code Hooks - Linting and Notification Tool"""
    pass


@cli.command()
@click.option("--language", "-l", help="Programming language to lint")
@click.option("--config", "-c", default="config.yaml", help="Config file path")
@click.option("--directory", "-d", default=".", help="Directory to lint")
@click.option("--json-output", is_flag=True, help="Output results as JSON for hooks")
@click.option(
    "--all-files", is_flag=True, help="Lint all files instead of just modified files"
)
def lint(
    language: Optional[str],
    config: str,
    directory: str,
    json_output: bool,
    all_files: bool,
):
    """Run linters based on configuration."""

    config_data = load_config(config)

    if config_data is None:
        error_msg = f"Configuration required. Please create {config} with your linting preferences."
        if json_output:
            click.echo(json.dumps({"error": error_msg, "success": False}))
        else:
            console.print(f"[red]{error_msg}[/red]")
            console.print("[yellow]Example configuration:[/yellow]")
            console.print("languages:")
            console.print("  python:")
            console.print("    linters:")
            console.print('      - "ruff check"')
            console.print('      - "ruff format --check"')
        sys.exit(1)

    # Determine which languages and files to lint
    if all_files:
        # Old behavior: lint entire directory for specified/detected language
        if not language:
            language = detect_language(directory)
            if not language:
                error_msg = "Could not detect language. Please specify with --language"
                if json_output:
                    click.echo(json.dumps({"error": error_msg, "success": False}))
                else:
                    console.print(f"[red]{error_msg}[/red]")
                sys.exit(1)

        if language not in config_data.get("languages", {}):
            error_msg = f"Language '{language}' not configured"
            if json_output:
                click.echo(json.dumps({"error": error_msg, "success": False}))
            else:
                console.print(f"[red]{error_msg}[/red]")
            sys.exit(1)

        # Run linters on entire directory (old behavior)
        run_linters_for_language(language, [], directory, config_data, json_output)

    else:
        # New behavior: lint only modified files
        if language:
            # Specific language: get modified files for that language only
            modified_files = get_modified_files()
            if not modified_files:
                if not json_output:
                    console.print("[yellow]No modified files found[/yellow]")
                else:
                    click.echo(
                        json.dumps({"success": True, "message": "No modified files"})
                    )
                sys.exit(0)

            target_files = filter_files_by_language(modified_files, language)
            if not target_files:
                if not json_output:
                    console.print(
                        f"[yellow]No modified {language} files found[/yellow]"
                    )
                else:
                    click.echo(
                        json.dumps(
                            {
                                "success": True,
                                "message": f"No modified {language} files",
                            }
                        )
                    )
                sys.exit(0)

            if language not in config_data.get("languages", {}):
                error_msg = f"Language '{language}' not configured"
                if json_output:
                    click.echo(json.dumps({"error": error_msg, "success": False}))
                else:
                    console.print(f"[red]{error_msg}[/red]")
                sys.exit(1)

            run_linters_for_language(
                language, target_files, directory, config_data, json_output
            )
        else:
            # No language specified: auto-detect and lint all modified languages
            languages_map = get_all_modified_languages()
            if not languages_map:
                if not json_output:
                    console.print("[yellow]No modified files found[/yellow]")
                else:
                    click.echo(
                        json.dumps({"success": True, "message": "No modified files"})
                    )
                sys.exit(0)

            # Show summary of what we found
            if not json_output:
                console.print("Linting Modified Files")
                for lang, files in languages_map.items():
                    if lang in config_data.get("languages", {}):
                        console.print(f"• {len(files)} {lang} file(s)")
                    else:
                        console.print(
                            f"• {len(files)} {lang} file(s) [dim](not configured)[/dim]"
                        )

            overall_success = True
            all_results = []

            for lang, files in languages_map.items():
                if lang in config_data.get("languages", {}):
                    success = run_linters_for_language(
                        lang, files, directory, config_data, json_output
                    )
                    if not success:
                        overall_success = False

            sys.exit(0 if overall_success else 2)


@cli.command()
@click.option("--message", "-m", default="wip: 🤖 checkpoint", help="Commit message")
@click.option("--dry-run", is_flag=True, help="Show what would be committed")
@click.option("--json-output", is_flag=True, help="Output results as JSON for hooks")
def commit(message: str, dry_run: bool, json_output: bool):
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

        if json_output:
            click.echo(json.dumps(result))
        else:
            console.print("[yellow]No modified files to commit[/yellow]")
        sys.exit(0)

    # Detect VCS
    vcs = detect_vcs()
    if not vcs:
        error_msg = "No version control system detected"
        if json_output:
            click.echo(json.dumps({"success": False, "error": error_msg}))
        else:
            console.print(f"[red]{error_msg}[/red]")
        sys.exit(1)

    # Show what will be committed (for both dry-run and normal execution)
    if not json_output:
        if dry_run:
            console.print("🤖 Would create checkpoint commit")
            console.print(f'• Message: "{message}"')
            console.print(f"• VCS: {vcs}")
            console.print(f"• Files to commit ({len(modified_files)}):")
            for file in modified_files:
                console.print(f"  - {file}")
        else:
            console.print("🤖 Creating checkpoint commit")
            console.print(f"Files to commit ({len(modified_files)}):")
            for file in modified_files:
                console.print(f"  • {file}")

    # Call appropriate VCS-specific function
    if vcs == "git":
        result = commit_git(message, modified_files, dry_run)
    elif vcs == "jujutsu":
        result = commit_jujutsu(message, modified_files, dry_run)
    else:
        result = {"success": False, "error": f"Unsupported VCS: {vcs}"}

    # Handle output
    if json_output:
        click.echo(json.dumps(result, indent=2))
    else:
        if result["success"]:
            if dry_run:
                console.print(
                    "\n[green]✓ Dry run completed - no actual commit made[/green]"
                )
                if "commands" in result:
                    console.print("Commands that would run:")
                    for cmd in result["commands"]:
                        console.print(f"  - {cmd}")
            else:
                if "info" in result:
                    console.print(f"[yellow]✓ {result['info']}[/yellow]")
                else:
                    commit_id = result.get("commit_hash") or result.get("commit_id")
                    if commit_id:
                        console.print(
                            f"[green]✓ Created commit: {message} ({commit_id})[/green]"
                        )
                    else:
                        console.print(f"[green]✓ Created commit: {message}[/green]")

                    if vcs == "jujutsu":
                        console.print("[green]✓ Created new working commit[/green]")
        else:
            error_console.print(f"[red]✗ {result['error']}[/red]")
            sys.exit(1)

    sys.exit(0)


def get_ntfy_channel() -> Optional[str]:
    """Get ntfy channel from secret command or environment variable."""

    # First, try the secret command
    try:
        result = subprocess.run(
            ["secret", "lookup", "ntfy", "neptune"],
            capture_output=True,
            text=True,
            timeout=10,
        )

        if result.returncode == 0:
            channel = result.stdout.strip()
            if channel:
                console.print("[dim]Using channel from secret command[/dim]")
                return channel
            else:
                console.print("[yellow]Secret command returned empty channel[/yellow]")
        else:
            console.print(
                f"[yellow]Secret command failed: {result.stderr.strip()}[/yellow]"
            )

    except FileNotFoundError:
        pass
    except subprocess.TimeoutExpired:
        console.print("[yellow]Secret command timed out[/yellow]")

    # Fallback to environment variable
    env_channel = os.getenv("NTFY_NEPTUNE_CHANNEL")
    if env_channel:
        console.print(
            "[dim]Using channel from NTFY_NEPTUNE_CHANNEL environment variable[/dim]"
        )
        return env_channel.strip()

    return None


@cli.command()
@click.option(
    "--message", "-m", default="Message from Claude", help="Notification message"
)
@click.option(
    "--priority",
    "-p",
    default="default",
    type=click.Choice(["min", "low", "default", "high", "max"]),
    help="Notification priority",
)
@click.option("--title", "-t", help="🤖 Claude says...")
@click.option("--tags", help="Comma-separated tags")
def notify(message: str, priority: str, title: Optional[str], tags: Optional[str]):
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

    # Prepare notification payload
    headers = {"Content-Type": "text/plain; charset=utf-8"}

    if title:
        headers["Title"] = title
    if priority != "default":
        headers["Priority"] = priority
    if tags:
        headers["Tags"] = tags

    url = f"https://ntfy.sh/{channel}"

    try:
        with console.status("[blue]Sending notification...[/blue]"):
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
