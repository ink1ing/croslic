#!/bin/bash
# Tab+C - 关闭所有空闲的终端窗口

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/terminal_helper.sh"

terminal=$(detect_terminal)
closed_count=0

if [ "$terminal" = "iTerm" ]; then
    # Close idle iTerm2 windows
    closed_count=$(osascript << 'EOF'
set closedCount to 0

tell application "iTerm"
    set windowList to every window

    repeat with theWindow in windowList
        set tabList to every tab of theWindow
        set allTabsIdle to true

        repeat with theTab in tabList
            set sessionList to every session of theTab
            repeat with theSession in sessionList
                -- Check if session is at shell prompt (idle)
                if (is processing of theSession) then
                    set allTabsIdle to false
                    exit repeat
                end if
            end repeat
            if not allTabsIdle then exit repeat
        end repeat

        -- Close window if all tabs are idle
        if allTabsIdle then
            close theWindow
            set closedCount to closedCount + 1
        end if
    end repeat
end tell

return closedCount
EOF
)
else
    # Close idle Terminal.app windows
    closed_count=$(osascript << 'EOF'
set closedCount to 0

tell application "Terminal"
    set windowList to every window

    repeat with theWindow in windowList
        set tabList to every tab of theWindow
        set allTabsIdle to true

        repeat with theTab in tabList
            -- Check if tab is busy (has process running)
            if busy of theTab then
                set allTabsIdle to false
                exit repeat
            end if
        end repeat

        -- Close window if all tabs are idle
        if allTabsIdle then
            close theWindow
            set closedCount to closedCount + 1
        end if
    end repeat
end tell

return closedCount
EOF
)
fi

terminal_name=$(get_terminal_name)
if [ "$closed_count" -gt 0 ]; then
    osascript -e "display notification \"Closed $closed_count idle $terminal_name window(s)\" with title \"ProTab\""
else
    osascript -e "display notification \"No idle $terminal_name windows\" with title \"ProTab\""
fi
