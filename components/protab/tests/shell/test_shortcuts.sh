#!/bin/bash
# 快捷键脚本功能测试

# 导入测试框架
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../bash_test_lib.sh"

# 项目目录
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 测试环境目录
TEST_ENV_DIR="/tmp/protab_shortcuts_test"
mkdir -p "$TEST_ENV_DIR/shortcuts"

test_suite_start "快捷键脚本测试"

echo "测试快捷键脚本的基本功能..."

# 测试脚本是否存在
echo "检查快捷键脚本是否存在..."
shortcuts_dir="$PROJECT_DIR/shortcuts"

# 检查重要的快捷键脚本
test_script_exists() {
    local script_name="$1"
    local script_path="$shortcuts_dir/$script_name"

    if [ -f "$script_path" ]; then
        assert_success 0 "$script_name 脚本存在"

        # 检查脚本是否可执行
        if [ -x "$script_path" ]; then
            assert_success 0 "$script_name 脚本可执行"
        else
            assert_failure 1 "$script_name 脚本应该可执行"
        fi
    else
        assert_failure 1 "$script_name 脚本不存在"
    fi
}

# 测试主要快捷键脚本
test_script_exists "new_terminal.sh"
test_script_exists "new_claude_code.sh"
test_script_exists "new_private_tab.sh"
test_script_exists "screenshot.sh"
test_script_exists "record.sh"
test_script_exists "clean_ram.sh"
test_script_exists "network_test.sh"
test_script_exists "open_force_quit.sh"

echo "测试基本配置文件..."
config_file="$PROJECT_DIR/config.json"

if [ -f "$config_file" ]; then
    assert_success 0 "配置文件存在"

    # 检查JSON格式
    if command -v jq &> /dev/null; then
        if jq . "$config_file" > /dev/null 2>&1; then
            assert_success 0 "配置文件JSON格式正确"
        else
            assert_failure 1 "配置文件JSON格式错误"
        fi
    else
        echo "⚠️  jq 未安装，跳过JSON格式检查"
    fi
else
    assert_failure 1 "配置文件不存在"
fi

# 清理测试环境
rm -rf "$TEST_ENV_DIR"

test_suite_end