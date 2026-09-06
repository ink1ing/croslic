#!/bin/bash
# Tab+T - 新建终端

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/terminal_helper.sh"

run_in_terminal ""
terminal_name=$(get_terminal_name)
osascript -e "display notification \"New $terminal_name\" with title \"ProTab\""