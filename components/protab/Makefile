# ProTab Makefile
# 提供标准化的构建、测试和开发工具

.PHONY: help build build-rust build-c test test-swift test-shell test-integration clean install dev setup coverage

# 默认目标
all: build test

# 显示帮助信息
help:
	@echo "ProTab 构建和测试系统"
	@echo "======================"
	@echo ""
	@echo "可用目标:"
	@echo "  build                编译所有程序 (Swift + Rust + C)"
	@echo "  build-rust           只编译 Rust 内存清理器"
	@echo "  build-c              只编译 C 版本程序"
	@echo "  test                 运行所有测试"
	@echo "  test-swift           只运行 Swift 测试"
	@echo "  test-shell           只运行 Shell 测试"
	@echo "  test-integration     只运行集成测试"
	@echo "  coverage             生成代码覆盖率报告"
	@echo "  clean                清理构建文件"
	@echo "  install              安装到系统"
	@echo "  setup                初次配置设置"
	@echo "  dev                  开发者模式运行"
	@echo "  help                 显示此帮助信息"
	@echo ""

# 编译所有程序
build: build-rust
	@echo "🔨 编译 ProTab Swift 程序..."
	@./build.sh

# 编译 Rust 内存清理器
build-rust:
	@echo "🦀 编译 Rust 内存清理器..."
	@cd rust && cargo build --release
	@echo "✅ Rust 内存清理器编译完成: rust/target/release/freeup_ram_rust"

# 编译 C 版本程序（备用）
build-c:
	@echo "🔧 编译 C 内存清理器..."
	@clang -O2 -o freeup_ram freeup_ram.c

# 运行所有测试
test:
	@echo "🧪 运行所有测试套件..."
	@./tests/run_tests.sh

# 只运行Swift测试
test-swift:
	@echo "🧪 运行 Swift 单元测试..."
	@./tests/run_tests.sh --swift-only

# 只运行Shell测试
test-shell:
	@echo "🧪 运行 Shell 脚本测试..."
	@./tests/run_tests.sh --shell-only

# 只运行集成测试
test-integration:
	@echo "🧪 运行集成测试..."
	@./tests/run_tests.sh --integration-only

# 生成代码覆盖率报告
coverage:
	@echo "📊 生成代码覆盖率报告..."
	@./tests/run_tests.sh --verbose
	@echo "📄 查看报告: ./tests/coverage_report.txt"

# 清理构建文件
clean:
	@echo "🧹 清理构建文件..."
	@rm -f tab_monitor
	@rm -rf tests/build
	@rm -f tests/test_results_*.log
	@rm -f tests/test_summary.txt
	@rm -f tests/coverage_report.txt
	@echo "✅ 清理完成"

# 安装到系统（创建符号链接）
install: build
	@echo "📦 安装 ProTab..."
	@if [ ! -f tab_monitor ]; then \
		echo "❌ 可执行文件不存在，请先运行 make build"; \
		exit 1; \
	fi
	@mkdir -p ~/.local/bin
	@ln -sf $(PWD)/protab.command ~/.local/bin/protab
	@echo "✅ ProTab 已安装到 ~/.local/bin/protab"
	@echo "📝 请确保 ~/.local/bin 在您的 PATH 中"

# 初次配置设置
setup:
	@echo "⚙️  ProTab 配置已简化，无需额外设置"
	@echo "✅ 项目已就绪，运行 make build 开始使用"

# 开发者模式（构建并运行）
dev: build
	@echo "🔧 开发者模式..."
	@echo "当前配置:"
	@./protab.command config
	@echo ""
	@echo "可执行文件已就绪: ./tab_monitor"
	@echo "主控制脚本: ./protab.command"

# 快速检查
check: build test-swift
	@echo "✅ 快速检查完成"

# 完整验证
verify: clean build test
	@echo "✅ 完整验证完成"

# 开发者工具
lint:
	@echo "🔍 代码检查..."
	@for script in *.sh shortcuts/*.sh tests/**/*.sh; do \
		if [ -f "$$script" ]; then \
			echo "检查: $$script"; \
			bash -n "$$script" || exit 1; \
		fi \
	done
	@echo "✅ 所有脚本语法正确"

# 格式化代码
format:
	@echo "💅 格式化代码..."
	@# 这里可以添加Swift和Shell代码格式化工具
	@echo "⚠️  代码格式化工具尚未配置"

# 生成文档
docs:
	@echo "📚 生成文档..."
	@echo "⚠️  文档生成工具尚未配置"

# 性能测试
benchmark:
	@echo "🏃 性能基准测试..."
	@echo "⚠️  性能测试尚未实现"

# 安全检查
security:
	@echo "🔒 安全检查..."
	@echo "检查脚本权限..."
	@find . -name "*.sh" -perm -111 -exec echo "可执行脚本: {}" \;
	@echo "检查配置文件..."
	@find . -name "*.json" -perm -111 -exec echo "⚠️  配置文件不应可执行: {}" \;

# 发布准备
release: clean verify
	@echo "🚀 准备发布..."
	@echo "1. 运行完整测试套件..."
	@./tests/run_tests.sh --verbose
	@echo "2. 生成发布包..."
	@mkdir -p release
	@tar czf release/protab-$(shell date +%Y%m%d).tar.gz \
		--exclude='tests' \
		--exclude='release' \
		--exclude='.git*' \
		--exclude='node_modules' \
		--exclude='.DS_Store' \
		.
	@echo "✅ 发布包已创建: release/protab-$(shell date +%Y%m%d).tar.gz"

# 调试构建
debug:
	@echo "🐛 调试构建..."
	@PROTAB_DEBUG=1 ./build.sh
	@echo "🔍 运行配置检查..."
	@PROTAB_DEBUG=1 ./protab.command config

# 监控文件变化（需要安装fswatch）
watch:
	@if command -v fswatch >/dev/null 2>&1; then \
		echo "👀 监控文件变化，自动运行测试..."; \
		fswatch -o . | xargs -n1 -I{} make test-swift; \
	else \
		echo "❌ fswatch 未安装，无法监控文件变化"; \
		echo "安装命令: brew install fswatch"; \
	fi

# 显示项目状态
status:
	@echo "📊 ProTab 项目状态"
	@echo "=================="
	@echo "项目路径: $(PWD)"
	@echo "Swift文件: $(shell find swift -name "*.swift" 2>/dev/null | wc -l)"
	@echo "Shell脚本: $(shell find . -name "*.sh" | wc -l)"
	@echo "配置文件: $(shell find . -name "*.json" | wc -l)"
	@echo "测试文件: $(shell find tests -name "test_*.sh" 2>/dev/null | wc -l)"
	@echo ""
	@if [ -f tab_monitor ]; then \
		echo "✅ 可执行文件存在"; \
	else \
		echo "❌ 可执行文件不存在"; \
	fi
	@if [ -f config.json ]; then \
		echo "✅ 配置文件存在"; \
	else \
		echo "❌ 配置文件不存在"; \
	fi