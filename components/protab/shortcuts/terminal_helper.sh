#!/bin/bash
# Terminal Helper - Detect and use preferred terminal application
# Supports: Terminal.app, iTerm2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$(dirname "$SCRIPT_DIR")/config.json"

# Get preferred terminal from config
get_preferred_terminal() {
    if [ -f "$CONFIG_FILE" ]; then
        # Extract terminal.preferred from config.json
        local pref=$(grep -A2 '"terminal"' "$CONFIG_FILE" | grep '"preferred"' | sed 's/.*: *"\([^"]*\)".*/\1/')
        echo "${pref:-auto}"
    else
        echo "auto"
    fi
}

get_iterm_mode() {
    local preferred=$(get_preferred_terminal)
    case "$preferred" in
        "iTerm2-tab"|"iTerm-tab")
            echo "tab"
            ;;
        *)
            echo "new"
            ;;
    esac
}

iterm_available() {
    if [ -d "/Applications/iTerm.app" ]; then
        return 0
    fi
    if open -Ra "iTerm" >/dev/null 2>&1; then
        return 0
    fi
    if open -Ra "iTerm2" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Detect which terminal to use
detect_terminal() {
    local preferred=$(get_preferred_terminal)

    case "$preferred" in
        "Terminal")
            echo "Terminal"
            return
            ;;
        "iTerm2"|"iTerm"|"iTerm2-new"|"iTerm-new"|"iTerm2-tab"|"iTerm-tab")
            if iterm_available; then
                echo "iTerm"
                return
            fi
            # Fallback to Terminal if iTerm2 not installed
            echo "Terminal"
            return
            ;;
        "auto"|*)
            # Auto-detect: prefer iTerm2 if installed
            if iterm_available; then
                echo "iTerm"
            else
                echo "Terminal"
            fi
            return
            ;;
    esac
}

escape_for_osascript() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Run command in terminal (opens new window/tab)
# Usage: run_in_terminal "command"
run_in_terminal() {
    local cmd="${1:-}"
    local terminal=$(detect_terminal)

    case "$terminal" in
        "iTerm")
            if [ -z "$cmd" ]; then
                local mode=$(get_iterm_mode)
                if [ "$mode" = "tab" ]; then
                    osascript -e 'tell application "iTerm"
                        activate
                        if (count of windows) is 0 then
                            create window with default profile
                        else
                            tell current window to create tab with default profile
                        end if
                    end tell' >/dev/null 2>&1
                else
                    osascript -e 'tell application "iTerm"
                        activate
                        create window with default profile
                    end tell' >/dev/null 2>&1
                fi
            else
                local mode=$(get_iterm_mode)
                local esc_cmd=$(escape_for_osascript "$cmd")
                if [ "$mode" = "tab" ]; then
                    osascript -e "tell application \"iTerm\"
                        activate
                        if (count of windows) is 0 then
                            create window with default profile
                        else
                            tell current window to create tab with default profile
                        end if
                        tell current session of current window
                            write text \"$esc_cmd\"
                        end tell
                    end tell" >/dev/null 2>&1
                else
                    osascript -e "tell application \"iTerm\"
                        create window with default profile
                        tell current session of current window
                            write text \"$esc_cmd\"
                        end tell
                    end tell" >/dev/null 2>&1
                fi
            fi
            ;;
        "Terminal"|*)
            if [ -z "$cmd" ]; then
                osascript -e 'tell application "Terminal" to do script ""' >/dev/null 2>&1
            else
                local esc_cmd=$(escape_for_osascript "$cmd")
                osascript -e "tell application \"Terminal\" to do script \"$esc_cmd\"" >/dev/null 2>&1
            fi
            ;;
    esac
}

# Get current terminal name (for display purposes)
get_terminal_name() {
    local terminal=$(detect_terminal)
    case "$terminal" in
        "iTerm") echo "iTerm2" ;;
        *) echo "Terminal" ;;
    esac
}

# Export functions for sourcing
export -f detect_terminal
export -f run_in_terminal
export -f get_terminal_name
