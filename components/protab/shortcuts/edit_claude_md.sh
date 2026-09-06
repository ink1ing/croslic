#!/bin/bash
# Tab+M - 编辑 Claude 配置

# 获取用户Claude配置路径的函数
get_claude_path() {
    # 尝试多种可能的路径
    local possible_paths=(
        "$HOME/.claude"
        "/Users/$USER/.claude"
        "/Users/$(whoami)/.claude"
    )

    for path in "${possible_paths[@]}"; do
        if [ -d "$path" ] && [ -f "$path/CLAUDE.md" ]; then
            echo "$path"
            return 0
        fi
    done

    # 如果找不到，尝试搜索用户目录
    local search_result
    search_result=$(find /Users -maxdepth 2 -name ".claude" -type d 2>/dev/null | head -1)
    if [ -n "$search_result" ] && [ -f "$search_result/CLAUDE.md" ]; then
        echo "$search_result"
        return 0
    fi

    # 最后回退到默认路径
    echo "$HOME/.claude"
}

# 获取路径并打开文件
claude_path=$(get_claude_path)
open "$claude_path/CLAUDE.md"

# 显示通知
osascript -e 'display notification "Claude.md opened" with title "ProTab"'