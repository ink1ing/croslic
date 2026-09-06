#!/bin/bash
# 性能基准测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 导入测试框架
source "$SCRIPT_DIR/../bash_test_lib.sh"

test_suite_start "性能基准测试"

echo "开始性能基准测试..."

# 创建测试结果目录
PERF_RESULTS_DIR="$PROJECT_DIR/tests/performance_results"
mkdir -p "$PERF_RESULTS_DIR"

# 性能测试函数
measure_time() {
    local command="$1"
    local description="$2"
    local iterations="${3:-5}"

    echo "测试: $description ($iterations 次迭代)"

    local total_time=0
    local min_time=999999
    local max_time=0

    for i in $(seq 1 $iterations); do
        local start_time=$(date +%s%N)

        # 执行命令并忽略输出
        if eval "$command" > /dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local elapsed=$((($end_time - $start_time) / 1000000))  # 转换为毫秒

            total_time=$((total_time + elapsed))

            if [ $elapsed -lt $min_time ]; then
                min_time=$elapsed
            fi

            if [ $elapsed -gt $max_time ]; then
                max_time=$elapsed
            fi

            echo "  迭代 $i: ${elapsed}ms"
        else
            echo "  迭代 $i: 执行失败"
        fi
    done

    if [ $total_time -gt 0 ]; then
        local avg_time=$((total_time / iterations))
        echo "  平均时间: ${avg_time}ms"
        echo "  最小时间: ${min_time}ms"
        echo "  最大时间: ${max_time}ms"

        # 保存结果到文件
        echo "$description,$avg_time,$min_time,$max_time" >> "$PERF_RESULTS_DIR/benchmark_results.csv"

        # 性能断言（基于合理的期望值）
        if [ $avg_time -lt 5000 ]; then  # 5秒以内
            assert_success 0 "$description 性能良好 (平均 ${avg_time}ms)"
        elif [ $avg_time -lt 10000 ]; then  # 10秒以内
            echo "⚠️  $description 性能一般 (平均 ${avg_time}ms)"
        else
            echo "❌ $description 性能较差 (平均 ${avg_time}ms)"
        fi
    else
        echo "❌ $description 测试失败"
    fi

    echo ""
}

# 初始化结果文件
echo "测试项目,平均时间(ms),最小时间(ms),最大时间(ms)" > "$PERF_RESULTS_DIR/benchmark_results.csv"

# 测试配置文件加载性能
test_config_loading_performance() {
    echo "🔧 配置文件加载性能测试"

    # 创建测试配置文件
    local test_config="/tmp/protab_perf_config.json"
    cat > "$test_config" << 'EOF'
{
    "app": {"name": "Performance Test", "version": "1.0.0", "debug": false},
    "paths": {"work_directory": "${HOME}/test_protab"},
    "keyboard": {
        "wait_timeout_ms": 1000,
        "shortcuts": {
            "a": "script_a.sh", "b": "script_b.sh", "c": "script_c.sh",
            "d": "script_d.sh", "e": "script_e.sh", "f": "script_f.sh",
            "g": "script_g.sh", "h": "script_h.sh", "i": "script_i.sh",
            "j": "script_j.sh", "k": "script_k.sh", "l": "script_l.sh"
        }
    }
}
EOF

    export PROTAB_CONFIG="$test_config"

    measure_time "$PROJECT_DIR/tests/run_swift_tests.sh" "Swift配置加载" 3

    # 清理
    rm -f "$test_config"
    unset PROTAB_CONFIG
}

# 测试内存清理性能
test_memory_cleanup_performance() {
    echo "🧠 内存清理性能测试"

    if [ -f "$PROJECT_DIR/rust/target/release/freeup_ram_rust" ]; then
        # 测试内存清理器启动时间
        measure_time "$PROJECT_DIR/rust/target/release/freeup_ram_rust" "Rust内存清理器执行" 3

        # 测试shell脚本封装的性能
        if [ -f "$PROJECT_DIR/shortcuts/clean_ram.sh" ]; then
            measure_time "$PROJECT_DIR/shortcuts/clean_ram.sh" "内存清理脚本完整执行" 2
        fi
    else
        echo "⚠️  内存清理器未编译，跳过性能测试"
    fi
}

# 测试编译性能
test_compilation_performance() {
    echo "🔨 编译性能测试"

    # 备份现有的可执行文件
    if [ -f "$PROJECT_DIR/tab_monitor" ]; then
        cp "$PROJECT_DIR/tab_monitor" "$PROJECT_DIR/tab_monitor.backup"
    fi

    # 测试Swift编译时间
    measure_time "cd '$PROJECT_DIR' && $PROJECT_DIR/build.sh" "Swift程序编译" 2

    # 测试Rust编译时间（release模式）
    measure_time "cd '$PROJECT_DIR' && cargo build --release" "Rust程序编译" 2

    # 恢复备份
    if [ -f "$PROJECT_DIR/tab_monitor.backup" ]; then
        mv "$PROJECT_DIR/tab_monitor.backup" "$PROJECT_DIR/tab_monitor"
    fi
}

# 测试测试套件性能
test_test_suite_performance() {
    echo "🧪 测试套件性能测试"

    # 测试各个测试组件的运行时间
    measure_time "$PROJECT_DIR/tests/shell/test_shortcuts.sh" "快捷键测试执行" 3
    measure_time "$PROJECT_DIR/tests/integration/test_full_system.sh" "集成测试执行" 2
    measure_time "cd '$PROJECT_DIR' && cargo test" "Rust单元测试执行" 2
}

# 测试文件I/O性能
test_file_io_performance() {
    echo "📁 文件I/O性能测试"

    local test_dir="/tmp/protab_io_test"
    mkdir -p "$test_dir"

    # 测试大量小文件读取
    for i in {1..100}; do
        echo "test content $i" > "$test_dir/file_$i.txt"
    done

    measure_time "find '$test_dir' -name '*.txt' -exec cat {} \;" "100个小文件读取" 3

    # 测试大文件操作
    dd if=/dev/zero of="$test_dir/large_file.dat" bs=1M count=10 2>/dev/null
    measure_time "cat '$test_dir/large_file.dat'" "大文件读取(10MB)" 3

    # 清理
    rm -rf "$test_dir"
}

# 内存使用量测试
test_memory_usage() {
    echo "📊 内存使用量测试"

    # 获取当前内存使用基线
    local baseline_memory=$(ps -o rss= -p $$ 2>/dev/null || echo "0")
    echo "基线内存使用: ${baseline_memory}KB"

    # 测试Swift程序内存使用
    if [ -f "$PROJECT_DIR/tab_monitor" ]; then
        echo "启动tab_monitor进程进行内存监控..."
        "$PROJECT_DIR/tab_monitor" &
        local monitor_pid=$!
        sleep 2  # 让进程启动

        if kill -0 "$monitor_pid" 2>/dev/null; then
            local monitor_memory=$(ps -o rss= -p "$monitor_pid" 2>/dev/null || echo "0")
            echo "tab_monitor内存使用: ${monitor_memory}KB"

            if [ "$monitor_memory" -lt 50000 ]; then  # 50MB以内
                assert_success 0 "tab_monitor内存使用合理 (${monitor_memory}KB)"
            else
                echo "⚠️  tab_monitor内存使用较高: ${monitor_memory}KB"
            fi

            kill "$monitor_pid" 2>/dev/null
        fi
    fi
}

# 运行所有性能测试
echo "开始性能基准测试..."

test_config_loading_performance
test_memory_cleanup_performance
test_compilation_performance
test_test_suite_performance
test_file_io_performance
test_memory_usage

# 生成性能报告
echo "📊 生成性能报告..."

cat > "$PERF_RESULTS_DIR/performance_report.md" << EOF
# ProTab 性能基准测试报告

生成时间: $(date)

## 测试结果摘要

$(cat "$PERF_RESULTS_DIR/benchmark_results.csv" | awk -F',' '
NR==1 { print "| " $1 " | " $2 " | " $3 " | " $4 " |" }
NR==2 { print "|---|---|---|---|" }
NR>1 { print "| " $1 " | " $2 " | " $3 " | " $4 " |" }
')

## 性能评估

- **配置加载**: $(grep "Swift配置加载" "$PERF_RESULTS_DIR/benchmark_results.csv" | cut -d',' -f2)ms 平均
- **内存清理**: $(grep "Rust内存清理器" "$PERF_RESULTS_DIR/benchmark_results.csv" | cut -d',' -f2 || echo "N/A")ms 平均
- **编译时间**: $(grep "Swift程序编译" "$PERF_RESULTS_DIR/benchmark_results.csv" | cut -d',' -f2 || echo "N/A")ms 平均

## 建议

- 配置加载时间应保持在1000ms以内
- 内存清理时间应保持在10000ms以内
- 编译时间可接受在30000ms以内

## 系统信息

- 操作系统: $(uname -s) $(uname -r)
- 硬件: $(uname -m)
- 测试时间: $(date)
EOF

echo "✅ 性能报告已生成: $PERF_RESULTS_DIR/performance_report.md"

test_suite_end