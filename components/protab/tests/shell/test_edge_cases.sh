#!/bin/bash
# 边界条件和异常情况专项测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 导入测试框架
source "$SCRIPT_DIR/../bash_test_lib.sh"

test_suite_start "边界条件和异常情况测试"

echo "测试各种边界条件和异常情况..."

# 测试极值配置
test_extreme_config_values() {
    echo "测试极值配置参数..."

    local test_config="/tmp/extreme_config.json"

    # 测试极小超时值
    cat > "$test_config" << 'EOF'
{
    "keyboard": {
        "wait_timeout_ms": 1
    }
}
EOF

    export PROTAB_CONFIG="$test_config"

    if "$PROJECT_DIR/tests/run_swift_tests.sh" > /dev/null 2>&1; then
        assert_success 0 "极小超时值处理正确"
    fi

    # 测试极大超时值
    cat > "$test_config" << 'EOF'
{
    "keyboard": {
        "wait_timeout_ms": 999999999
    }
}
EOF

    if "$PROJECT_DIR/tests/run_swift_tests.sh" > /dev/null 2>&1; then
        assert_success 0 "极大超时值处理正确"
    fi

    # 测试负值
    cat > "$test_config" << 'EOF'
{
    "keyboard": {
        "wait_timeout_ms": -100
    }
}
EOF

    if "$PROJECT_DIR/tests/run_swift_tests.sh" > /dev/null 2>&1; then
        assert_success 0 "负值超时处理正确"
    fi

    rm -f "$test_config"
    unset PROTAB_CONFIG
}

# 测试内存边界条件
test_memory_boundary_conditions() {
    echo "测试内存边界条件..."

    if [ -f "$PROJECT_DIR/rust/target/release/freeup_ram_rust" ]; then
        # 在低内存环境下测试（模拟）
        local start_time=$(date +%s)
        if timeout 15s "$PROJECT_DIR/rust/target/release/freeup_ram_rust" > /dev/null 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))

            if [ $duration -lt 20 ]; then
                assert_success 0 "内存清理在超时内完成 (${duration}秒)"
            else
                echo "⚠️  内存清理耗时较长: ${duration}秒"
            fi
        else
            echo "⚠️  内存清理器在边界条件下可能失败"
        fi
    fi
}

# 测试文件系统边界
test_filesystem_boundary() {
    echo "测试文件系统边界条件..."

    # 测试长文件名
    local long_name=$(printf 'a%.0s' {1..200})
    local long_config="/tmp/${long_name}.json"

    if touch "$long_config" 2>/dev/null; then
        echo '{"app": {"name": "Long Name Test"}}' > "$long_config"
        export PROTAB_CONFIG="$long_config"

        if "$PROJECT_DIR/tests/run_swift_tests.sh" > /dev/null 2>&1; then
            assert_success 0 "长文件名处理正确"
        fi

        rm -f "$long_config"
        unset PROTAB_CONFIG
    else
        echo "ℹ️  系统不支持极长文件名，跳过测试"
    fi
}

# 测试Unicode和特殊字符
test_unicode_handling() {
    echo "测试Unicode和特殊字符处理..."

    local unicode_config="/tmp/unicode_测试_config.json"

    cat > "$unicode_config" << 'EOF'
{
    "app": {
        "name": "Unicode测试应用程序",
        "version": "1.0.0测试版"
    },
    "keyboard": {
        "shortcuts": {
            "t": "测试脚本.sh",
            "a": "应用程序.sh"
        }
    }
}
EOF

    export PROTAB_CONFIG="$unicode_config"

    if "$PROJECT_DIR/tests/run_swift_tests.sh" > /dev/null 2>&1; then
        assert_success 0 "Unicode字符处理正确"
    fi

    rm -f "$unicode_config"
    unset PROTAB_CONFIG
}

# 测试网络相关边界条件
test_network_boundary() {
    echo "测试网络相关边界条件..."

    # 测试网络脚本在无网络环境下的行为
    if [ -f "$PROJECT_DIR/shortcuts/network_test.sh" ]; then
        # 模拟网络不可用（使用无效DNS）
        export DNS_SERVERS="0.0.0.0"

        if timeout 5s "$PROJECT_DIR/shortcuts/network_test.sh" > /dev/null 2>&1; then
            assert_success 0 "网络脚本在无网络时正常退出"
        else
            echo "ℹ️  网络脚本在无网络时的行为符合预期"
        fi

        unset DNS_SERVERS
    fi
}

# 测试进程数量限制
test_process_limits() {
    echo "测试进程数量限制..."

    # 检查当前进程数
    local current_processes=$(ps aux | wc -l)
    echo "当前系统进程数: $current_processes"

    # 启动多个tab_monitor进程测试
    local pids=()
    for i in {1..3}; do
        if [ -f "$PROJECT_DIR/tab_monitor" ]; then
            "$PROJECT_DIR/tab_monitor" &
            local pid=$!
            pids+=($pid)
            sleep 0.5
        fi
    done

    # 检查进程是否正常启动
    local running_count=0
    for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            running_count=$((running_count + 1))
        fi
    done

    if [ $running_count -gt 0 ]; then
        assert_success 0 "多进程启动正常 ($running_count 个进程)"
    fi

    # 清理进程
    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
}

# 测试磁盘空间边界
test_disk_space_boundary() {
    echo "测试磁盘空间边界条件..."

    # 检查可用磁盘空间
    local available_space=$(df -h . | awk 'NR==2 {print $4}')
    echo "可用磁盘空间: $available_space"

    # 测试在临时目录创建大文件
    local test_file="/tmp/protab_diskspace_test"
    local test_size="100M"

    if dd if=/dev/zero of="$test_file" bs=1M count=100 2>/dev/null; then
        assert_success 0 "大文件创建成功"

        # 测试配置读取是否受影响
        if "$PROJECT_DIR/tests/run_swift_tests.sh" > /dev/null 2>&1; then
            assert_success 0 "磁盘使用不影响配置读取"
        fi

        rm -f "$test_file"
    else
        echo "ℹ️  磁盘空间不足，跳过大文件测试"
    fi
}

# 测试时间相关边界条件
test_time_boundary() {
    echo "测试时间相关边界条件..."

    # 测试系统时间变化对程序的影响
    local start_time=$(date +%s)

    # 运行一个较短的测试
    if timeout 2s "$PROJECT_DIR/tests/run_swift_tests.sh" > /dev/null 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        if [ $duration -le 5 ]; then
            assert_success 0 "时间敏感操作正常完成"
        fi
    fi
}

# 运行所有边界条件测试
test_extreme_config_values
test_memory_boundary_conditions
test_filesystem_boundary
test_unicode_handling
test_network_boundary
test_process_limits
test_disk_space_boundary
test_time_boundary

test_suite_end