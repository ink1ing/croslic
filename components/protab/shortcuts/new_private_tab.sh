#!/bin/bash
# Tab+P - Open private browsing window

osascript -e 'tell application "Safari" to activate' -e 'tell application "System Events" to keystroke "n" using {command down, shift down}'
osascript -e 'display notification "Private tab opened" with title "ProTab"'
