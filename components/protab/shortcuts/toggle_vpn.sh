#!/bin/bash
# Tab+X - Toggle macOS System VPN

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

get_first_vpn_name() {
    scutil --nc list 2>/dev/null | grep -E "^\*.*VPN" | head -1 | sed -E 's/.*"([^"]+)".*/\1/'
}

is_vpn_connected() {
    local vpn_name="$1"
    scutil --nc status "$vpn_name" 2>/dev/null | head -1 | grep -q "Connected"
}

connect_vpn() {
    local vpn_name="$1"
    scutil --nc start "$vpn_name" 2>/dev/null
}

disconnect_vpn() {
    local vpn_name="$1"
    scutil --nc stop "$vpn_name" 2>/dev/null
}

main() {
    local vpn_name="${1:-$(get_first_vpn_name)}"

    if [ -z "$vpn_name" ]; then
        osascript -e 'display notification "No VPN found" with title "ProTab - VPN"'
        echo "No VPN configuration found"
        exit 1
    fi

    if is_vpn_connected "$vpn_name"; then
        disconnect_vpn "$vpn_name"
        sleep 1

        if is_vpn_connected "$vpn_name"; then
            osascript -e "display notification \"$vpn_name disconnect failed\" with title \"ProTab - VPN\""
            echo "VPN disconnect failed: $vpn_name"
        else
            osascript -e "display notification \"$vpn_name disconnected\" with title \"ProTab - VPN\""
            echo "VPN disconnected: $vpn_name"
        fi
    else
        connect_vpn "$vpn_name"
        sleep 2

        if is_vpn_connected "$vpn_name"; then
            osascript -e "display notification \"$vpn_name connected\" with title \"ProTab - VPN\""
            echo "VPN connected: $vpn_name"
        else
            osascript -e "display notification \"$vpn_name connecting...\" with title \"ProTab - VPN\""
            echo "VPN connecting: $vpn_name"
        fi
    fi
}

main "$@"
