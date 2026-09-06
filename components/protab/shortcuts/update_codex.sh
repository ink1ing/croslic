#!/bin/bash
# Tab+P - 更新 Codex CLI

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/terminal_helper.sh"

run_in_terminal "npm install -g @openai/codex@latest"
osascript -e 'display notification "Codex update started" with title "ProTab"'
