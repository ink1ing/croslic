#!/bin/bash
# Tab+A - 启动/重启 Anti-API

# 查找并杀掉已存在的进程
pkill -f "anti-api" 2>/dev/null

# 等待进程结束
sleep 0.5

# 查找并启动脚本
for path in \
    "$HOME/Desktop/anti-api" \
    "$HOME/anti-api" \
    "/Applications/anti-api"; do
    if [ -f "$path/anti-api-start.command" ]; then
        osascript -e 'display notification "Anti-API starting..." with title "ProTab"'
        open "$path/anti-api-start.command"
        exit 0
    fi
done

# 未找到
osascript -e 'display notification "Anti-API not found" with title "ProTab"'
echo "Anti-API not found"
exit 1
