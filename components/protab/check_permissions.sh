#!/bin/bash
# ProTab Permission Check Tool

echo "=== ProTab Permission Check ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAB_MONITOR="$SCRIPT_DIR/tab_monitor"

if [ ! -f "$TAB_MONITOR" ]; then
    echo "tab_monitor not found"
    echo "Please run: ./build.sh"
    exit 1
fi

echo "tab_monitor path: $TAB_MONITOR"
echo ""

echo "Checking accessibility permission..."
if "$TAB_MONITOR" 2>&1 | grep -q "permission required"; then
    echo "No accessibility permission"
    echo ""
    echo "Steps to fix:"
    echo "1. Open System Settings > Privacy & Security > Accessibility"
    echo "2. Click + button"
    echo "3. Add: $TAB_MONITOR"
    echo "4. Run this script again"
    echo ""

    osascript -e 'tell application "System Settings" to activate' -e 'do shell script "open \"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\""' 2>/dev/null

    exit 1
else
    echo "Accessibility permission granted"
fi

echo ""
echo "=== Check Complete ==="
echo "Run ./protab.command to start ProTab"
