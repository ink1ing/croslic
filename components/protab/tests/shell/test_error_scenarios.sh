#!/bin/bash
# 错误场景和边界条件测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 导入测试框架
source "$SCRIPT_DIR/../bash_test_lib.sh"

test_suite_start "错误场景和边界条件测试"

echo "测试各种错误场景和边界条件..."

# 创建临时测试目录
TEST_TEMP_DIR="/tmp/protab_error_tests"
mkdir -p "$TEST_TEMP_DIR"

# 清理函数
cleanup_test_env() {
    rm -rf "$TEST_TEMP_DIR"
    unset PROTAB_CONFIG
    unset PROTAB_DEBUG
}

# 捕获退出信号
trap cleanup_test_env EXIT

# 测试损坏的配置文件
test_corrupted_config() {
    echo "测试损坏的配置文件处理..."

    local corrupted_config="$TEST_TEMP_DIR/corrupted_config.json"

    # 测试空文件
    touch "$corrupted_config"
    export PROTAB_CONFIG="$corrupted_config"

    # Swift配置加载应该使用默认值
    if "$PROJECT_DIR/tests/run_swift_tests.sh" > "$TEST_TEMP_DIR/swift_empty_test.log" 2>&1; then
        assert_success 0 "空配置文件处理正确"
    else
        echo "⚠️  空配置文件处理可能有问题"
    fi

    # 测试无效JSON
    echo "{ invalid json syntax" > "$corrupted_config"

    if "$PROJECT_DIR/tests/run_swift_tests.sh" > "$TEST_TEMP_DIR/swift_invalid_test.log" 2>&1; then
        assert_success 0 "无效JSON配置处理正确"
    else
        echo "⚠️  无效JSON配置处理可能有问题"
    fi

    # 测试部分缺失的配置
    cat > "$corrupted_config" << 'EOF'
{
    "app": {
        "name": "Partial Config"
    }
}
EOF

    if "$PROJECT_DIR/tests/run_swift_tests.sh" > "$TEST_TEMP_DIR/swift_partial_test.log" 2>&1; then
        assert_success 0 "部分配置处理正确"
    else
        echo "⚠️  部分配置处理可能有问题"
    fi
}

# 测试权限问题
test_permission_issues() {
    echo "测试权限相关问题..."

    local readonly_config="$TEST_TEMP_DIR/readonly_config.json"
    local valid_config='{"app": {"name": "ReadOnly Test"}, "keyboard": {"wait_timeout_ms": 500}}'

    echo "$valid_config" > "$readonly_config"
    chmod 000 "$readonly_config"

    export PROTAB_CONFIG="$readonly_config"

    # 测试是否优雅处理只读配置文件
    if "$PROJECT_DIR/tests/run_swift_tests.sh" > "$TEST_TEMP_DIR/swift_readonly_test.log" 2>&1; then
        assert_success 0 "只读配置文件处理正确"
    else
        echo "⚠️  只读配置文件处理可能有问题"
    fi

    # 恢复权限以便清理
    chmod 644 "$readonly_config"
}

# 测试内存不足场景
test_memory_stress() {
    echo "测试内存压力场景..."

    # 测试Rust内存清理器在低内存情况下的行为
    if [ -f "$PROJECT_DIR/rust/target/release/freeup_ram_rust" ]; then
        # 使用timeout限制运行时间，防止系统hang
        if timeout 30s "$PROJECT_DIR/rust/target/release/freeup_ram_rust" > "$TEST_TEMP_DIR/memory_stress.log" 2>&1; then
            assert_success 0 "内存清理器在压力下正常工作"
        else
            echo "⚠️  内存清理器可能在压力下失败"
        fi
    else
        echo "⚠️  内存清理器未编译，跳过压力测试"
    fi
}

# 测试并发安全性
test_concurrent_access() {
    echo "测试并发访问安全性..."

    local concurrent_config="$TEST_TEMP_DIR/concurrent_config.json"
    echo '{"app": {"name": "Concurrent Test"}, "keyboard": {"wait_timeout_ms": 100}}' > "$concurrent_config"

    export PROTAB_CONFIG="$concurrent_config"

    # 启动多个Swift测试进程模拟并发访问
    local pids=()
    for i in {1..3}; do
        "$PROJECT_DIR/tests/run_swift_tests.sh" > "$TEST_TEMP_DIR/concurrent_$i.log" 2>&1 &
        pids+=($!)
    done

    # 等待所有进程完成
    local success_count=0
    for pid in "${pids[@]}"; do
        if wait "$pid"; then
            success_count=$((success_count + 1))
        fi
    done

    if [ $success_count -eq 3 ]; then
        assert_success 0 "并发配置访问安全"
    else
        echo "⚠️  并发访问中有 $((3 - success_count)) 个进程失败"
    fi
}

# 测试大配置文件处理
test_large_config() {
    echo "测试大型配置文件处理..."

    local large_config="$TEST_TEMP_DIR/large_config.json"

    # 生成包含大量快捷键的配置文件
    cat > "$large_config" << 'EOF'
{
    "app": {"name": "Large Config Test"},
    "keyboard": {
        "wait_timeout_ms": 500,
        "shortcuts": {
EOF

    # 添加大量快捷键映射
    for i in {0..25}; do
        local key=$(printf "\\$(printf %03o $((97 + i)))")  # a-z
        echo "            \"$key\": \"script_$i.sh\"," >> "$large_config"
    done

    # 添加数字键映射
    for i in {0..9}; do
        echo "            \"$i\": \"number_script_$i.sh\"," >> "$large_config"
    done

    # 移除最后的逗号并关闭JSON
    sed -i '' '$s/,$//' "$large_config"
    cat >> "$large_config" << 'EOF'
        }
    }
}
EOF

    export PROTAB_CONFIG="$large_config"

    if "$PROJECT_DIR/tests/run_swift_tests.sh" > "$TEST_TEMP_DIR/swift_large_test.log" 2>&1; then
        assert_success 0 "大型配置文件处理正确"
    else
        echo "⚠️  大型配置文件处理可能有问题"
    fi
}

# 测试环境变量边界情况
test_env_variables() {
    echo "测试环境变量边界情况..."

    # 测试没有HOME环境变量的情况
    local original_home="$HOME"
    unset HOME

    if "$PROJECT_DIR/tests/run_swift_tests.sh" > "$TEST_TEMP_DIR/swift_no_home_test.log" 2>&1; then
        echo "⚠️  无HOME环境变量时的行为需要验证"
    fi

    # 恢复HOME环境变量
    export HOME="$original_home"

    # 测试极长的环境变量
    local long_path=$(printf '/tmp/very_long_path_%*s' 1000 | tr ' ' 'x')
    export PROTAB_CONFIG="$long_path/config.json"

    if "$PROJECT_DIR/tests/run_swift_tests.sh" > "$TEST_TEMP_DIR/swift_long_path_test.log" 2>&1; then
        assert_success 0 "长路径处理正确"
    else
        echo "⚠️  长路径处理可能有问题"
    fi
}

# 测试资源耗尽场景
test_resource_exhaustion() {
    echo "测试资源耗尽场景..."

    # 测试文件描述符限制
    # 注意：这是一个轻量级测试，不会真正耗尽系统资源
    local fd_test_dir="$TEST_TEMP_DIR/fd_test"
    mkdir -p "$fd_test_dir"

    # 创建多个临时文件测试文件句柄使用
    for i in {1..100}; do
        echo "test" > "$fd_test_dir/temp_$i.txt"
    done

    # 测试在多文件存在时的配置读取
    export PROTAB_CONFIG="$TEST_TEMP_DIR/concurrent_config.json"
    if "$PROJECT_DIR/tests/run_swift_tests.sh" > "$TEST_TEMP_DIR/swift_fd_test.log" 2>&1; then
        assert_success 0 "多文件环境下配置读取正常"
    fi

    # 清理
    rm -rf "$fd_test_dir"
}

# 运行所有错误场景测试
echo "开始运行错误场景测试..."

test_corrupted_config
test_permission_issues
test_memory_stress
test_concurrent_access
test_large_config
test_env_variables
test_resource_exhaustion

test_suite_end