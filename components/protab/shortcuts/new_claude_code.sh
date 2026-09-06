#!/bin/bash
# Tab+L - 打开 Claude Code

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/terminal_helper.sh"

run_in_terminal "claude"
osascript -e 'display notification "Claude Code" with title "ProTab"'
