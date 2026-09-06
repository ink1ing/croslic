#!/bin/bash
# ProTab 集成测试
# 测试整个系统的端到端功能

# 导入测试框架
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../bash_test_lib.sh"

# 项目目录
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 集成测试环境
INTEGRATION_TEST_DIR="/tmp/protab_integration_test"

# 清理并设置测试环境
setup_integration_env() {
    echo "🔧 设置集成测试环境..."

    # 清理旧环境
    rm -rf "$INTEGRATION_TEST_DIR"
    mkdir -p "$INTEGRATION_TEST_DIR/shortcuts"

    # 复制项目核心文件到测试环境
    if [ -f "$PROJECT_DIR/build.sh" ]; then cp "$PROJECT_DIR/build.sh" "$INTEGRATION_TEST_DIR/"; fi
    if [ -f "$PROJECT_DIR/protab.command" ]; then cp "$PROJECT_DIR/protab.command" "$INTEGRATION_TEST_DIR/"; fi
    if [ -f "$PROJECT_DIR/config.json" ]; then cp "$PROJECT_DIR/config.json" "$INTEGRATION_TEST_DIR/"; fi
    if [ -d "$PROJECT_DIR/shortcuts" ]; then cp -r "$PROJECT_DIR/shortcuts" "$INTEGRATION_TEST_DIR/"; fi
    cp "$PROJECT_DIR"/*.swift "$INTEGRATION_TEST_DIR/" 2>/dev/null || true
}

# 清理测试环境
cleanup_integration_env() {
    echo "🧹 清理集成测试环境..."
    rm -rf "$INTEGRATION_TEST_DIR"
}

test_suite_start "ProTab 集成测试"

echo "🔧 设置测试环境..."
setup_integration_env

# 测试编译
echo "🔨 测试编译..."
cd "$INTEGRATION_TEST_DIR"

if [ -f "build.sh" ]; then
    if ./build.sh > /dev/null 2>&1; then
        assert_success 0 "编译成功"

        # 检查可执行文件
        if [ -f "tab_monitor" ]; then
            assert_success 0 "可执行文件创建成功"
        else
            echo -e "${RED}✗${NC} 可执行文件未创建"
            tests_failed=$((tests_failed + 1))
        fi
    else
        echo -e "${RED}✗${NC} 编译失败"
        tests_failed=$((tests_failed + 1))
    fi
else
    echo -e "${RED}✗${NC} build.sh 不存在"
    tests_failed=$((tests_failed + 1))
fi
tests_run=$((tests_run + 3))

# 测试配置文件
echo "⚙️ 测试配置文件..."
if [ -f "config.json" ]; then
    assert_success 0 "配置文件存在"

    # 检查JSON格式
    if command -v jq &> /dev/null; then
        if jq . "config.json" > /dev/null 2>&1; then
            assert_success 0 "配置文件JSON格式正确"
        else
            echo -e "${RED}✗${NC} 配置文件JSON格式错误"
            tests_failed=$((tests_failed + 1))
        fi
        tests_run=$((tests_run + 1))
    fi
else
    echo -e "${RED}✗${NC} 配置文件不存在"
    tests_failed=$((tests_failed + 1))
    tests_run=$((tests_run + 1))
fi

# 测试快捷键脚本
echo "🔗 测试快捷键脚本..."
shortcuts_count=0
if [ -d "shortcuts" ]; then
    for script in shortcuts/*.sh; do
        if [ -f "$script" ]; then
            shortcuts_count=$((shortcuts_count + 1))
            if [ -x "$script" ]; then
                assert_success 0 "$(basename "$script") 脚本可执行"
            else
                echo -e "${RED}✗${NC} $(basename "$script") 脚本不可执行"
                tests_failed=$((tests_failed + 1))
            fi
            tests_run=$((tests_run + 1))
        fi
    done

    if [ $shortcuts_count -gt 0 ]; then
        assert_success 0 "找到 $shortcuts_count 个快捷键脚本"
    else
        echo -e "${RED}✗${NC} 未找到快捷键脚本"
        tests_failed=$((tests_failed + 1))
        tests_run=$((tests_run + 1))
    fi
else
    echo -e "${RED}✗${NC} shortcuts 目录不存在"
    tests_failed=$((tests_failed + 1))
    tests_run=$((tests_run + 1))
fi

# 测试主控制脚本
echo "🎛️ 测试主控制脚本..."
if [ -f "protab.command" ]; then
    assert_success 0 "protab.command 存在"

    if [ -x "protab.command" ]; then
        assert_success 0 "protab.command 可执行"
    else
        echo -e "${RED}✗${NC} protab.command 不可执行"
        tests_failed=$((tests_failed + 1))
        tests_run=$((tests_run + 1))
    fi
else
    echo -e "${RED}✗${NC} protab.command 不存在"
    tests_failed=$((tests_failed + 1))
    tests_run=$((tests_run + 1))
fi

# 清理环境
cd "$PROJECT_DIR"
cleanup_integration_env

test_suite_end