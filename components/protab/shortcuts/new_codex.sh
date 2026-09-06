#!/bin/bash
# Tab+O - 打开 Codex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/terminal_helper.sh"

run_in_terminal "codex"
osascript -e 'display notification "Codex" with title "ProTab"'
