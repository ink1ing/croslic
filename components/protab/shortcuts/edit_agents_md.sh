#!/bin/bash
# Tab+D - 编辑 Codex AGENTS.md

# 查找 AGENTS.md
agents_md=""

# 优先级：全局 > 当前项目
if [ -f "$HOME/.codex/AGENTS.md" ]; then
    agents_md="$HOME/.codex/AGENTS.md"
elif [ -f "./AGENTS.md" ]; then
    agents_md="./AGENTS.md"
elif [ -f "./.codex/AGENTS.md" ]; then
    agents_md="./.codex/AGENTS.md"
fi

if [ -n "$agents_md" ]; then
    open "$agents_md"
    osascript -e 'display notification "AGENTS.md opened" with title "ProTab"'
else
    # 创建全局 AGENTS.md
    mkdir -p "$HOME/.codex"
    echo "# AGENTS.md" > "$HOME/.codex/AGENTS.md"
    open "$HOME/.codex/AGENTS.md"
    osascript -e 'display notification "Created new AGENTS.md" with title "ProTab"'
fi
