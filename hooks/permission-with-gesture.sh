#!/bin/bash

# PermissionRequest hook that:
# 1. Pauses system-wide media playback
# 2. Uses macOS "say" to ask for permission
# 3. Uses bobble to get yes/no response
# 4. Resumes media playback

set -e

echo "[DEBUG] Hook started" >&2

# Path to bobble executable
BOBBLE="$(dirname "$0")/../.build/release/bobble"

echo "[DEBUG] Bobble path: $BOBBLE" >&2

# Check if bobble is built
if [ ! -f "$BOBBLE" ]; then
    echo "Error: bobble not found at $BOBBLE" >&2
    echo "Please build it first with: cd $(dirname "$0")/.. && ./build.sh" >&2
    exit 1
fi

# Read JSON input from stdin
INPUT=$(cat)

echo "[DEBUG] Received input" >&2

# Parse tool name and input
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('tool_name', ''))" 2>&1)
echo "[DEBUG] Tool name: $TOOL_NAME" >&2

TOOL_INPUT=$(echo "$INPUT" | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin).get('tool_input', {})))" 2>&1)
echo "[DEBUG] Tool input: $TOOL_INPUT" >&2

# Check if headphone motion is available before proceeding
# If not available, immediately fall back to normal permission flow
echo "[DEBUG] Checking for headphone motion availability..." >&2
if ! "$BOBBLE" --check 2>/dev/null; then
    echo "[DEBUG] Headphone motion not available, deferring to normal permission flow" >&2
    exit 1
fi
echo "[DEBUG] Headphone motion available" >&2

# Media playback control disabled for now
# Future: Add Spotify/Music pause/resume here

# Create a descriptive permission message based on the tool
PERMISSION_MESSAGE="Claude wants to use $TOOL_NAME."

# Add context based on tool type
case "$TOOL_NAME" in
    "Bash")
        COMMAND=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('command', ''))" 2>/dev/null || echo "")
        if [ -n "$COMMAND" ]; then
            # Truncate long commands
            COMMAND_SHORT=$(echo "$COMMAND" | head -c 100)
            PERMISSION_MESSAGE="Claude wants to run a command."
        fi
        ;;
    "Write"|"Edit")
        FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('filePath', json.load(sys.stdin).get('file_path', '')))" 2>/dev/null || echo "")
        if [ -n "$FILE_PATH" ]; then
            FILENAME=$(basename "$FILE_PATH")
            PERMISSION_MESSAGE="Claude wants to $TOOL_NAME $FILENAME."
        fi
        ;;
    "Task")
        PERMISSION_MESSAGE="Claude wants to start a subtask."
        ;;
esac

# Debug: Log what we're about to say
echo "[DEBUG] Speaking: $PERMISSION_MESSAGE" >&2

# Speak the permission request (synchronously, not in background)
# Don't specify voice - let it use your system default
say "$PERMISSION_MESSAGE Nod for yes, shake for no."

echo "[DEBUG] Finished speaking, waiting for gesture..." >&2

# Small pause before listening for gesture
sleep 0.5

# Use bobble to get response
"$BOBBLE" --timeout 15 --sensitivity 0.5
GESTURE_EXIT=$?

echo "[DEBUG] Gesture exit code: $GESTURE_EXIT" >&2

# Media resume disabled for now

# Process the gesture response
case $GESTURE_EXIT in
    0)
        # Nod detected - approve
        OUTPUT=$(cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow"
    }
  },
  "suppressOutput": true,
  "systemMessage": "✓ Approved via head nod"
}
EOF
)
        echo "$OUTPUT"
        exit 0
        ;;
    1)
        # Shake detected - deny
        OUTPUT=$(cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "deny",
      "message": "User denied via head shake gesture",
      "interrupt": false
    }
  },
  "systemMessage": "✗ Denied via head shake"
}
EOF
)
        echo "$OUTPUT"
        exit 0
        ;;
    2)
        # Timeout - fall back to normal UI prompt
        # Don't return decision, let normal permission flow happen
        echo "No gesture detected within 15 seconds" >&2
        exit 1
        ;;
    3)
        # Error - fall back to normal permission flow
        echo "Headphones not available - falling back to normal permission flow" >&2
        exit 1
        ;;
esac
