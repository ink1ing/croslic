#!/bin/bash
# Tab+V - 区域录屏（Ctrl+C停止）

FILE=~/Desktop/recording_$(date +%Y%m%d_%H%M%S).mov
screencapture -v "$FILE" && \
osascript -e 'display notification "Recording saved" with title "ProTab"' || \
osascript -e 'display notification "Cancelled" with title "ProTab"'
