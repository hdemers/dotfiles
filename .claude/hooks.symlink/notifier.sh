#!/usr/bin/env bash
# ntfy-notifier.sh - Send notifications to ntfy service for Claude Code events
#
# SYNOPSIS
#   notifier.sh <event_type>
#
# DESCRIPTION
#   Sends push notifications via ntfy service when Claude Code events occur.
#   Supports notification and stop events. Automatically detects terminal
#   context and includes it in the notification for better identification.
#
# ARGUMENTS
#   event_type    Either "notification" or "stop"
#
# CONFIGURATION
#   Requires ~/.config/claude-code-ntfy/config.yaml with:
#     ntfy_topic: your-topic-name
#     ntfy_server: https://ntfy.sh (optional, defaults to public server)
#
# ENVIRONMENT
#   CLAUDE_HOOK_PAYLOAD   JSON payload from Claude Code (for notifications)
#   CLAUDE_HOOKS_NTFY_ENABLED   Set to "false" to disable notifications
#
# TERMINAL DETECTION
#   Attempts to detect terminal context from:
#   - tmux window name
#   - macOS Terminal window title
#   - X11 window title (Linux)
#
# EXAMPLES
#   # Send notification
#   ./ntfy-notifier.sh notification
#
#   # Send stop notification
#   ./ntfy-notifier.sh stop
#
# ERROR HANDLING
#   - Validates configuration file exists
#   - Retries failed notifications
#   - Rate limits to prevent spam

set -euo pipefail

# Get the event type from the first argument
EVENT_TYPE="${1:-notification}"

# Check if notifications are enabled (allow easy disable)
if [[ "${CLAUDE_HOOKS_NTFY_ENABLED:-true}" != "true" ]]; then
    exit 0
fi

# Check if yq is available
if ! command -v yq >/dev/null 2>&1; then
    echo "Warning: yq not found, cannot parse ntfy config" >&2
    exit 0
fi

# Extract configuration with error handling
NTFY_TOPIC=$(secret lookup ntfy neptune)
NTFY_SERVER="https://ntfy.sh"

# Validate required configuration
if [[ -z "$NTFY_TOPIC" ]]; then
    echo "Warning: ntfy_topic not configured in $CONFIG_FILE" >&2
    exit 0
fi

# Rate limiting - prevent notification spam
RATE_LIMIT_FILE="/tmp/.claude-ntfy-rate-limit"
if [[ -f "$RATE_LIMIT_FILE" ]]; then
    LAST_NOTIFICATION=$(cat "$RATE_LIMIT_FILE" 2>/dev/null || echo "0")
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_NOTIFICATION))

    # Limit to one notification per 2 seconds
    if [[ $TIME_DIFF -lt 2 ]]; then
        exit 0
    fi
fi
echo "$(date +%s)" > "$RATE_LIMIT_FILE"

# Get context information
CWD=$(pwd)
CWD_BASENAME=$(basename "$CWD")

# Build context string
CONTEXT="Claude Code: $CWD_BASENAME"

# Function to send notification with retry
send_notification() {
    local title="$1"
    local message="$2"
    local tags="$3"
    local priority="${4:-default}"

    local max_retries=2
    local retry_count=0

    while [[ $retry_count -lt $max_retries ]]; do
        if curl -s \
            --max-time 5 \
            -H "Title: $title" \
            -H "Tags: $tags" \
            -H "Priority: $priority" \
            -d "$message" \
            "$NTFY_SERVER/$NTFY_TOPIC" >/dev/null 2>&1; then
            return 0
        fi

        retry_count=$((retry_count + 1))
        [[ $retry_count -lt $max_retries ]] && sleep 1
    done

    echo "Warning: Failed to send notification after $max_retries attempts" >&2
    return 1
}

# Prepare notification based on event type
case "$EVENT_TYPE" in
    "notification")
        # Claude sent a notification - parse the payload if available
        if [[ -n "${CLAUDE_HOOK_PAYLOAD:-}" ]]; then
            # Extract message from JSON payload
            MESSAGE=$(echo "$CLAUDE_HOOK_PAYLOAD" \
                | jq -r '.message // "Claude notification"' 2>/dev/null \
                || echo "Claude notification")

            # Check for error or warning indicators
            PRIORITY="default"
            if echo "$MESSAGE" | grep -qiE '(error|fail|problem|issue)'; then
                PRIORITY="high"
            elif echo "$MESSAGE" | grep -qiE '(warn|warning|attention)'; then
                PRIORITY="default"
            fi
        else
            MESSAGE="Claude notification"
            PRIORITY="default"
        fi

        TITLE="$CONTEXT"
        TAGS="claude-code,notification"
        ;;

    "stop")
        TITLE="$CONTEXT"
        MESSAGE="Claude finished responding"
        TAGS="claude-code,stop,checkmark"
        PRIORITY="low"
        ;;

    *)
        echo "Error: Unknown event type: $EVENT_TYPE" >&2
        echo "Usage: $0 {notification|stop}" >&2
        exit 1
        ;;
esac

# Send notification
send_notification "$TITLE" "$MESSAGE" "$TAGS" "$PRIORITY"

# Clean up old rate limit files (older than 1 hour)
find /tmp -name ".claude-ntfy-rate-limit" -mmin +60 -delete 2>/dev/null || true
