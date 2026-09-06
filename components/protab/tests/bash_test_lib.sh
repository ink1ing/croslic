#!/bin/bash
# 简单的 Bash 测试框架

# 测试统计
tests_run=0
tests_passed=0
tests_failed=0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 断言函数
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    tests_run=$((tests_run + 1))

    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "${RED}✗${NC} $message"
        echo -e "  Expected: ${YELLOW}$expected${NC}"
        echo -e "  Actual:   ${YELLOW}$actual${NC}"
        tests_failed=$((tests_failed + 1))
    fi
}

assert_success() {
    local exit_code="$1"
    local message="${2:-Command should succeed}"

    tests_run=$((tests_run + 1))

    if [[ "$exit_code" -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} $message"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "${RED}✗${NC} $message"
        echo -e "  Expected exit code 0, got: $exit_code"
        tests_failed=$((tests_failed + 1))
    fi
}

assert_failure() {
    local exit_code="$1"
    local message="${2:-Command should fail}"

    tests_run=$((tests_run + 1))

    if [[ "$exit_code" -ne 0 ]]; then
        echo -e "${GREEN}✓${NC} $message"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "${RED}✗${NC} $message"
        echo -e "  Expected non-zero exit code, got: $exit_code"
        tests_failed=$((tests_failed + 1))
    fi
}

assert_file_exists() {
    local file_path="$1"
    local message="${2:-File should exist: $file_path}"

    tests_run=$((tests_run + 1))

    if [[ -f "$file_path" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "${RED}✗${NC} $message"
        tests_failed=$((tests_failed + 1))
    fi
}

assert_file_not_exists() {
    local file_path="$1"
    local message="${2:-File should not exist: $file_path}"

    tests_run=$((tests_run + 1))

    if [[ ! -f "$file_path" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "${RED}✗${NC} $message"
        tests_failed=$((tests_failed + 1))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"

    tests_run=$((tests_run + 1))

    if [[ "$haystack" =~ $needle ]]; then
        echo -e "${GREEN}✓${NC} $message"
        tests_passed=$((tests_passed + 1))
    else
        echo -e "${RED}✗${NC} $message"
        echo -e "  Haystack: ${YELLOW}$haystack${NC}"
        echo -e "  Needle:   ${YELLOW}$needle${NC}"
        tests_failed=$((tests_failed + 1))
    fi
}

# 测试套件开始
test_suite_start() {
    echo -e "${YELLOW}🧪 开始测试套件: $1${NC}"
    echo "========================================"
}

# 测试套件结束
test_suite_end() {
    echo "========================================"
    echo -e "${YELLOW}📊 测试统计:${NC}"
    echo "  运行: $tests_run"
    echo -e "  通过: ${GREEN}$tests_passed${NC}"
    echo -e "  失败: ${RED}$tests_failed${NC}"

    if [[ $tests_failed -eq 0 ]]; then
        echo -e "${GREEN}🎉 所有测试通过!${NC}"
        return 0
    else
        echo -e "${RED}❌ 有 $tests_failed 个测试失败${NC}"
        return 1
    fi
}