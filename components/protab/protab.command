#!/bin/bash
# ProTab - macOS Global Shortcut System
# Double-click to launch, supports interactive configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.json"
SHORTCUTS_DIR="$SCRIPT_DIR/shortcuts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# ============================================
# Utility Functions
# ============================================

get_used_keys() {
    sed -n '/"shortcuts"/,/}/p' "$CONFIG_FILE" | grep -E '^\s*"[a-zA-Z]"' | sed 's/.*"\([a-zA-Z]\)".*/\1/' | tr '\n' ' '
}

is_key_used() {
    local key="$1"
    local used_keys=$(get_used_keys)
    [[ "$used_keys" == *"$key"* ]]
}

get_script_for_key() {
    local key="$1"
    sed -n '/"shortcuts"/,/}/p' "$CONFIG_FILE" | grep "\"$key\"" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ','
}

get_description_for_script() {
    local script="$1"
    local script_path="$SHORTCUTS_DIR/$script"
    if [ -f "$script_path" ]; then
        sed -n '2p' "$script_path" \
            | sed 's/^# *//' \
            | sed -E 's/^Tab\+[A-Za-z][[:space:]]*-[[:space:]]*//'
    else
        echo "$script"
    fi
}

is_terminal_target() {
    local target="$1"
    if [ -z "$target" ]; then
        return 1
    fi
    if [ -e "$target" ]; then
        if [ -d "$target" ]; then
            return 1
        fi
        case "$target" in
            *.app)
                return 1
                ;;
            *.command|*.sh)
                return 0
                ;;
        esac
        if [ -x "$target" ]; then
            return 0
        fi
        return 1
    fi
    return 0
}

escape_for_double_quotes() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/\"/\\\"/g'
}

get_terminal_preferred() {
    python3 << PYEOF
import json
with open("$CONFIG_FILE", "r") as f:
    config = json.load(f)
print(config.get("terminal", {}).get("preferred", "auto"))
PYEOF
}

set_auto_start() {
    local value="$1"
    python3 << PYEOF
import json
with open("$CONFIG_FILE", "r") as f:
    config = json.load(f)
config.setdefault("system", {})["auto_start"] = ($value == "true")
with open("$CONFIG_FILE", "w") as f:
    json.dump(config, f, indent=2)
PYEOF
}

is_auto_start_enabled() {
    python3 << PYEOF
import json
with open("$CONFIG_FILE", "r") as f:
    config = json.load(f)
print("true" if config.get("system", {}).get("auto_start", False) else "false")
PYEOF
}

is_auto_start_prompted() {
    python3 << PYEOF
import json
with open("$CONFIG_FILE", "r") as f:
    config = json.load(f)
print("true" if config.get("system", {}).get("auto_start_prompted", False) else "false")
PYEOF
}

set_auto_start_prompted() {
    python3 << PYEOF
import json
with open("$CONFIG_FILE", "r") as f:
    config = json.load(f)
config.setdefault("system", {})["auto_start_prompted"] = True
with open("$CONFIG_FILE", "w") as f:
    json.dump(config, f, indent=2)
PYEOF
}

launch_agent_path() {
    echo "$HOME/Library/LaunchAgents/com.inkling.protab.plist"
}

install_launch_agent() {
    local plist_path
    plist_path=$(launch_agent_path)
    cat > "$plist_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.inkling.protab</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/tab_monitor</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/ProTab.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/ProTab.log</string>
</dict>
</plist>
EOF

    launchctl unload "$plist_path" >/dev/null 2>&1 || true
    launchctl load "$plist_path" >/dev/null 2>&1 || true
}

maybe_request_autostart() {
    local enabled
    enabled=$(is_auto_start_enabled)
    if [ "$enabled" = "true" ]; then
        return 0
    fi

    local prompted
    prompted=$(is_auto_start_prompted)
    if [ "$prompted" = "true" ]; then
        return 0
    fi

    echo ""
    echo -e "${YELLOW}Enable ProTab to start at login? (y/n)${NC}"
    read -r -p "> " confirm
    if [[ "$confirm" = "y" || "$confirm" = "Y" ]]; then
        install_launch_agent
        set_auto_start true
        echo -e "${GREEN}Auto-start enabled${NC}"
    fi
    set_auto_start_prompted
}

ensure_preset_shortcuts() {
    python3 << PYEOF
import json

preset_shortcuts = {
    "t": "new_terminal.sh",
    "l": "new_claude_code.sh",
    "o": "new_codex.sh",
    "u": "update_claude_code.sh",
    "p": "update_codex.sh",
    "m": "edit_claude_md.sh",
    "d": "edit_agents_md.sh",
    "j": "edit_settings_json.sh",
    "b": "new_private_tab.sh",
    "r": "clean_ram.sh",
    "n": "network_test.sh",
    "x": "toggle_vpn.sh",
    "q": "open_force_quit.sh",
    "s": "screenshot.sh",
    "v": "record.sh",
    "c": "close_idle_terminals.sh",
    "h": "custom_h.sh",
    "a": "custom_a.sh",
}

with open("$CONFIG_FILE", "r") as f:
    config = json.load(f)
config.setdefault("keyboard", {})["shortcuts"] = preset_shortcuts
with open("$CONFIG_FILE", "w") as f:
    json.dump(config, f, indent=2)
PYEOF
}

# ============================================
# Display Functions
# ============================================

show_panel() {
    clear
    echo -e "${BLUE}"
    echo "██████╗ ██████╗  ██████╗ ████████╗ █████╗ ██████╗ "
    echo "██╔══██╗██╔══██╗██╔═══██╗╚══██╔══╝██╔══██╗██╔══██╗"
    echo "██████╔╝██████╔╝██║   ██║   ██║   ███████║██████╔╝"
    echo "██╔═══╝ ██╔══██╗██║   ██║   ██║   ██╔══██║██╔══██╗"
    echo "██║     ██║  ██║╚██████╔╝   ██║   ██║  ██║██████╔╝"
    echo "╚═╝     ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝╚═════╝ "
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}Shortcuts (Tab + Key):${NC}"
    echo "────────────────────────────────────────"
    sed -n '/"shortcuts"/,/}/p' "$CONFIG_FILE" | grep -E '^\s*"[a-zA-Z]"' | while read -r line; do
        key=$(echo "$line" | sed 's/.*"\([a-zA-Z]\)".*/\1/')
        script=$(echo "$line" | sed 's/.*: *"\([^"]*\)".*/\1/' | tr -d ',')
        desc=$(get_description_for_script "$script")
        printf "  ${GREEN}%s${NC}  %s\n" "$key" "$desc"
    done
    echo "────────────────────────────────────────"
}

# ============================================
# Command Functions
# ============================================

cmd_add() {
    echo ""
    echo -e "${CYAN}=== Add New Shortcut ===${NC}"
    echo ""

    echo -e "${YELLOW}Enter file path or command:${NC}"
    read -r -p "> " file_path

    if [ -z "$file_path" ]; then
        echo -e "${RED}Error: Cannot be empty${NC}"
        sleep 1
        show_panel
        return 1
    fi

    file_path="${file_path/#\~/$HOME}"

    echo ""
    echo -e "${YELLOW}Enter shortcut key (single letter):${NC}"
    read -r -p "> " shortcut_key

    if [ -z "$shortcut_key" ]; then
        echo -e "${RED}Error: Cannot be empty${NC}"
        sleep 1
        show_panel
        return 1
    fi

    if [ ${#shortcut_key} -ne 1 ] || ! [[ "$shortcut_key" =~ ^[a-zA-Z]$ ]]; then
        echo -e "${RED}Error: Must be a single letter (a-z)${NC}"
        sleep 1
        show_panel
        return 1
    fi

    shortcut_key=$(echo "$shortcut_key" | tr '[:upper:]' '[:lower:]')

    if is_key_used "$shortcut_key"; then
        existing=$(get_script_for_key "$shortcut_key")
        echo -e "${RED}Error: '$shortcut_key' is already used for: $existing${NC}"
        sleep 1
        show_panel
        return 1
    fi

    echo ""
    echo -e "${YELLOW}Enter description (optional):${NC}"
    read -r -p "> " description
    [ -z "$description" ] && description="Open $file_path"

    script_name="custom_${shortcut_key}.sh"
    script_path="$SHORTCUTS_DIR/$script_name"

    if is_terminal_target "$file_path"; then
        escaped_cmd=$(escape_for_double_quotes "$file_path")
        if [ -e "$file_path" ]; then
            run_cmd="bash \"$escaped_cmd\""
        else
            run_cmd="$escaped_cmd"
        fi
        cat > "$script_path" << EOF
#!/bin/bash
# $description
# Auto-generated by ProTab

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
source "\$SCRIPT_DIR/terminal_helper.sh"

run_in_terminal "$run_cmd"
osascript -e 'display notification "$description" with title "ProTab"'
EOF
    else
        cat > "$script_path" << EOF
#!/bin/bash
# $description
# Auto-generated by ProTab

open "$file_path"
osascript -e 'display notification "$description" with title "ProTab"'
EOF
    fi
    chmod +x "$script_path"

    python3 << PYEOF
import json
with open("$CONFIG_FILE", "r") as f:
    config = json.load(f)
config["keyboard"]["shortcuts"]["$shortcut_key"] = "$script_name"
with open("$CONFIG_FILE", "w") as f:
    json.dump(config, f, indent=2)
PYEOF

    # Show success briefly then clean panel
    echo ""
    echo -e "${GREEN}Added: Tab+$shortcut_key${NC}"
    sleep 0.5
    show_panel
}

cmd_delete() {
    echo ""
    echo -e "${CYAN}=== Delete Shortcut ===${NC}"
    echo ""

    echo -e "${YELLOW}Enter key to delete:${NC}"
    read -r -p "> " shortcut_key

    if [ -z "$shortcut_key" ]; then
        echo -e "${RED}Error: Cannot be empty${NC}"
        sleep 1
        show_panel
        return 1
    fi

    shortcut_key=$(echo "$shortcut_key" | tr '[:upper:]' '[:lower:]')

    if ! is_key_used "$shortcut_key"; then
        echo -e "${RED}Error: '$shortcut_key' is not in use${NC}"
        sleep 1
        show_panel
        return 1
    fi

    script_name=$(get_script_for_key "$shortcut_key")

    echo -e "${RED}Delete '$shortcut_key' -> $script_name? (y/n)${NC}"
    read -r -p "> " confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        show_panel
        return 0
    fi

    python3 << PYEOF
import json
with open("$CONFIG_FILE", "r") as f:
    config = json.load(f)
if "$shortcut_key" in config["keyboard"]["shortcuts"]:
    del config["keyboard"]["shortcuts"]["$shortcut_key"]
with open("$CONFIG_FILE", "w") as f:
    json.dump(config, f, indent=2)
PYEOF

    if [[ "$script_name" == custom_* ]]; then
        rm -f "$SHORTCUTS_DIR/$script_name"
    fi

    echo -e "${GREEN}Deleted: $shortcut_key${NC}"
    sleep 0.5
    show_panel
}

cmd_default() {
    echo ""
    echo -e "${CYAN}=== Default Terminal ===${NC}"
    echo ""
    current_pref=$(get_terminal_preferred)
    echo -e "${YELLOW}Current:${NC} $current_pref"
    echo ""
    echo -e "${YELLOW}Choose default terminal:${NC}"
    echo "  1) Terminal (系统终端)"
    echo "  2) iTerm2 新开窗口"
    echo "  3) iTerm2 复用标签页"
    echo ""
    read -r -p "> " choice

    case "$(echo "$choice" | tr '[:upper:]' '[:lower:]')" in
        "1"|"terminal"|"system"|"sys")
            new_pref="Terminal"
            ;;
        "2"|"iterm2"|"iterm"|"iterm2-new"|"iterm-new"|"new"|"window")
            new_pref="iTerm2-new"
            ;;
        "3"|"iterm2-tab"|"iterm-tab"|"tab"|"reuse")
            new_pref="iTerm2-tab"
            ;;
        "")
            show_panel
            return 0
            ;;
        *)
            echo -e "${RED}Error: Invalid choice${NC}"
            sleep 1
            show_panel
            return 1
            ;;
    esac

    python3 << PYEOF
import json
with open("$CONFIG_FILE", "r") as f:
    config = json.load(f)
config.setdefault("terminal", {})["preferred"] = "$new_pref"
with open("$CONFIG_FILE", "w") as f:
    json.dump(config, f, indent=2)
PYEOF

    echo ""
    echo -e "${GREEN}Default terminal set to: $new_pref${NC}"
    sleep 0.5
    show_panel
}

# ============================================
# Config Mode
# ============================================

config_mode() {
    while true; do
        read -r -p "protab> " cmd

        case "$cmd" in
            "/add"|"add"|"a")
                cmd_add
                ;;
            "/delete"|"delete"|"/del"|"del"|"/rm"|"rm"|"d")
                cmd_delete
                ;;
            "/default"|"default"|"/def"|"def")
                cmd_default
                ;;
            "/list"|"list"|"/ls"|"ls"|"l")
                show_panel
                ;;
            "/help"|"help"|"h"|"?")
                echo ""
                echo -e "  ${GREEN}/add${NC}     Add shortcut"
                echo -e "  ${GREEN}/delete${NC}  Delete shortcut"
                echo -e "  ${GREEN}/default${NC} Set default terminal"
                echo -e "  ${GREEN}/list${NC}    Refresh list"
                echo -e "  ${GREEN}/quit${NC}    Exit"
                echo ""
                ;;
            "/quit"|"quit"|"/exit"|"exit"|"/q"|"q")
                return 0
                ;;
            "")
                ;;
            *)
                echo -e "${RED}Unknown: $cmd${NC}"
                ;;
        esac
    done
}

# ============================================
# Main
# ============================================

main() {
    # Kill existing monitor
    pkill -f "tab_monitor" 2>/dev/null

    # Keep built-in shortcut mapping fixed to presets.
    ensure_preset_shortcuts

    # Compile if needed (silent)
    if [ ! -f "$SCRIPT_DIR/tab_monitor" ] || [ "$SCRIPT_DIR/tab_monitor.swift" -nt "$SCRIPT_DIR/tab_monitor" ]; then
        swiftc "$SCRIPT_DIR/tab_monitor.swift" -o "$SCRIPT_DIR/tab_monitor" 2>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "${RED}Compilation failed${NC}"
            read -p "Press Enter to exit..."
            exit 1
        fi
    fi

    maybe_request_autostart

    # Start the global key monitor in background FIRST
    "$SCRIPT_DIR/tab_monitor" 2>/dev/null &
    MONITOR_PID=$!

    # Trap to restart monitor if script exits unexpectedly
    trap "kill $MONITOR_PID 2>/dev/null" EXIT

    # Show clean panel
    show_panel

    # Interactive mode (tab_monitor already running in background)
    config_mode

    # After exit, keep monitor running
    trap - EXIT

    # Show final panel
    show_panel
    echo -e "${GREEN}ProTab running in background (PID: $MONITOR_PID)${NC}"
    echo -e "${GRAY}Close this window to stop.${NC}"

    # Wait for monitor to finish (keeps terminal open)
    wait $MONITOR_PID
}

main
