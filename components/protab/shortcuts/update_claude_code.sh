#!/bin/bash
# 更新 Claude Code

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/terminal_helper.sh"

run_in_terminal "npm install -g @anthropic-ai/claude-code@latest"

# 显示通知
osascript -e 'display notification "Claude Code update started" with title "ProTab"'
