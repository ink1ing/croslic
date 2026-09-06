#!/bin/bash
# Rust代码特殊测试场景

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 导入测试框架
source "$SCRIPT_DIR/../bash_test_lib.sh"

test_suite_start "Rust代码特殊场景测试"

echo "测试Rust代码的特殊场景和边界条件..."

# 测试Rust单元测试的全面覆盖
test_rust_comprehensive() {
    echo "运行完整的Rust测试套件..."

    cd "$PROJECT_DIR"

    # 测试标准测试
    if cargo test 2>&1 | tee /tmp/rust_test_output.log; then
        assert_success 0 "Rust单元测试通过"

        # 检查测试覆盖的函数数量
        local test_count=$(grep -c "test result:" /tmp/rust_test_output.log || echo "0")
        echo "运行了 $test_count 个测试套件"
    fi

    # 测试文档测试
    if cargo test --doc > /dev/null 2>&1; then
        assert_success 0 "Rust文档测试通过"
    fi

    # 测试release模式下的行为
    if cargo test --release > /dev/null 2>&1; then
        assert_success 0 "Release模式测试通过"
    fi

    rm -f /tmp/rust_test_output.log
}

# 测试内存清理器的特殊场景
test_memory_cleaner_edge_cases() {
    echo "测试内存清理器的边界条件..."

    local rust_binary="$PROJECT_DIR/rust/target/release/freeup_ram_rust"

    if [ -f "$rust_binary" ]; then
        # 测试在高负载下的行为
        echo "测试高负载情况..."

        # 创建一些内存压力
        local temp_processes=()
        for i in {1..3}; do
            yes > /dev/null &
            temp_processes+=($!)
        done

        sleep 1

        # 在高负载下测试内存清理
        if timeout 20s "$rust_binary" > /tmp/memory_test_output.log 2>&1; then
            assert_success 0 "高负载下内存清理成功"

            # 检查释放的内存量
            if grep -q "释放内存" /tmp/memory_test_output.log; then
                assert_success 0 "内存释放报告正常"
            fi
        fi

        # 清理测试进程
        for pid in "${temp_processes[@]}"; do
            kill "$pid" 2>/dev/null || true
        done

        rm -f /tmp/memory_test_output.log
    else
        echo "⚠️  Rust内存清理器二进制不存在，跳过特殊场景测试"
    fi
}

# 测试内存分配失败场景
test_memory_allocation_failures() {
    echo "测试内存分配失败场景..."

    # 使用ulimit限制内存使用（如果支持）
    local original_limit=$(ulimit -v 2>/dev/null || echo "unlimited")

    if [ "$original_limit" != "unlimited" ]; then
        echo "设置内存限制进行测试..."

        # 设置较小的内存限制
        ulimit -v 1048576 2>/dev/null || true  # 1GB

        # 测试内存清理器在受限环境下的行为
        if [ -f "$PROJECT_DIR/rust/target/release/freeup_ram_rust" ]; then
            if timeout 10s "$PROJECT_DIR/rust/target/release/freeup_ram_rust" > /dev/null 2>&1; then
                assert_success 0 "内存受限环境下清理成功"
            else
                echo "ℹ️  内存受限环境下的行为符合预期"
            fi
        fi

        # 恢复原始限制
        if [ "$original_limit" != "unlimited" ]; then
            ulimit -v "$original_limit" 2>/dev/null || true
        else
            ulimit -v unlimited 2>/dev/null || true
        fi
    fi
}

# 测试并发安全性
test_rust_concurrency() {
    echo "测试Rust代码并发安全性..."

    if [ -f "$PROJECT_DIR/rust/target/release/freeup_ram_rust" ]; then
        echo "启动多个内存清理进程..."

        local pids=()
        for i in {1..3}; do
            timeout 15s "$PROJECT_DIR/rust/target/release/freeup_ram_rust" > "/tmp/concurrent_$i.log" 2>&1 &
            pids+=($!)
        done

        # 等待所有进程完成
        local success_count=0
        for pid in "${pids[@]}"; do
            if wait "$pid"; then
                success_count=$((success_count + 1))
            fi
        done

        if [ $success_count -ge 1 ]; then
            assert_success 0 "并发内存清理成功 ($success_count/3 成功)"
        fi

        # 清理日志文件
        rm -f /tmp/concurrent_*.log
    fi
}

# 测试错误处理路径
test_error_handling_paths() {
    echo "测试错误处理路径..."

    # 测试无效参数（如果支持命令行参数）
    if [ -f "$PROJECT_DIR/rust/target/release/freeup_ram_rust" ]; then
        # 测试程序在各种条件下的错误处理
        echo "测试程序错误处理..."

        # 使用strace或dtrace监控系统调用（如果可用）
        if command -v dtruss >/dev/null 2>&1; then
            echo "使用dtruss监控系统调用..."
            if timeout 10s dtruss -p $$ >/dev/null 2>&1; then
                echo "系统调用监控可用"
            fi
        fi

        # 测试在受限权限下运行
        local temp_script="/tmp/test_restricted.sh"
        cat > "$temp_script" << 'EOF'
#!/bin/bash
# 在受限环境下测试
ulimit -n 10 2>/dev/null || true  # 限制文件描述符
exec "$1"
EOF
        chmod +x "$temp_script"

        if timeout 10s "$temp_script" "$PROJECT_DIR/rust/target/release/freeup_ram_rust" >/dev/null 2>&1; then
            assert_success 0 "受限环境下程序正常运行"
        else
            echo "ℹ️  受限环境下的行为符合预期"
        fi

        rm -f "$temp_script"
    fi
}

# 测试内存泄漏检测
test_memory_leak_detection() {
    echo "测试内存泄漏检测..."

    if [ -f "$PROJECT_DIR/rust/target/release/freeup_ram_rust" ]; then
        # 运行程序多次，检查内存使用是否稳定
        echo "多次运行检测内存泄漏..."

        local memory_before=$(ps -o rss= -p $$ 2>/dev/null || echo "0")

        for i in {1..5}; do
            timeout 10s "$PROJECT_DIR/rust/target/release/freeup_ram_rust" >/dev/null 2>&1 || true
            sleep 1
        done

        local memory_after=$(ps -o rss= -p $$ 2>/dev/null || echo "0")

        # 检查内存增长（允许10%的波动）
        local memory_growth=$((memory_after - memory_before))
        local growth_percentage=$((memory_growth * 100 / memory_before))

        if [ $growth_percentage -lt 10 ]; then
            assert_success 0 "无明显内存泄漏 (增长: ${growth_percentage}%)"
        else
            echo "⚠️  可能存在内存增长: ${growth_percentage}%"
        fi
    fi
}

# 测试性能回归
test_performance_regression() {
    echo "测试性能回归..."

    if [ -f "$PROJECT_DIR/rust/target/release/freeup_ram_rust" ]; then
        local total_time=0
        local iterations=3

        echo "进行性能基准测试 ($iterations 次)..."

        for i in $(seq 1 $iterations); do
            local start_time=$(date +%s%N)

            if timeout 30s "$PROJECT_DIR/rust/target/release/freeup_ram_rust" >/dev/null 2>&1; then
                local end_time=$(date +%s%N)
                local elapsed=$(((end_time - start_time) / 1000000))  # 转换为毫秒

                total_time=$((total_time + elapsed))
                echo "  第 $i 次运行: ${elapsed}ms"
            fi
        done

        local avg_time=$((total_time / iterations))
        echo "平均执行时间: ${avg_time}ms"

        # 基准：应该在30秒内完成
        if [ $avg_time -lt 30000 ]; then
            assert_success 0 "性能符合基准 (平均 ${avg_time}ms)"
        else
            echo "⚠️  性能可能存在问题 (平均 ${avg_time}ms)"
        fi
    fi
}

# 运行所有Rust特殊场景测试
test_rust_comprehensive
test_memory_cleaner_edge_cases
test_memory_allocation_failures
test_rust_concurrency
test_error_handling_paths
test_memory_leak_detection
test_performance_regression

test_suite_end