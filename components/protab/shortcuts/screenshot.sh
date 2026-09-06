#!/bin/bash
# Tab+S - 区域截图（按空格切换窗口/全屏）

FILE=~/Desktop/screenshot_$(date +%Y%m%d_%H%M%S).png
screencapture -i "$FILE" && \
osascript -e 'display notification "Screenshot saved" with title "ProTab"' || \
osascript -e 'display notification "Cancelled" with title "ProTab"'