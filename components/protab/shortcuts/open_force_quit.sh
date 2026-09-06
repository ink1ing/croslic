#!/bin/bash
# 打开强制退出

osascript -e "tell application \"System Events\" to key code 53 using {option down, command down}"

# 显示通知
osascript -e 'display notification "Force Quit opened" with title "ProTab"'
