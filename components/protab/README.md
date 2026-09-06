# ProTab - Global Shortcut System

一个全局快捷键系统，通过 Tab + 字母 执行指令，提升效率。

<p align="center">
  <img src="assets/demo.gif" alt="ProTab Demo" width="600">
</p>

## 🚀 功能特性

- **跨平台**: 支持 macOS 和 Windows
- **快捷键触发**: Tab + 字母键组合，无冲突好记忆，全局生效
- **一键启动**: 双击 `.command` (macOS) 或 `.bat` (Windows) 即可运行
- **内存安全**: Rust 高效内存清理 (仅macOS)

## 📋 系统要求

### macOS
- macOS 10.14+ (Mojave 或更高版本)
- Xcode Command Line Tools (用于编译)
- 辅助功能权限

### Windows
- Windows 10/11
- Node.js (用于 Claude Code/Codex 功能)

## 🔧 安装方法

```bash
git clone https://github.com/silasxbt/protab.git
cd ProTab
```

### macOS
双击 `protab.command` 启动（自动编译）

### Windows
双击 `protab.bat` 启动

## 🎯 快捷键列表

| 快捷键 | 功能 | macOS | Windows |
|--------|------|:-----:|:-------:|
| Tab + c | 关闭空闲终端 | ✅ | ✅ |
| Tab + d | 编辑 agents.md (Codex) | ✅ | ✅ |
| Tab + m | 编辑 claude.md | ✅ | ✅ |
| Tab + j | 编辑 settings.json | ✅ | ✅ |
| Tab + o | 打开 Codex | ✅ | ✅ |
| Tab + p | 更新 Codex | ✅ | ✅ |
| Tab + u | 更新 Claude Code | ✅ | ✅ |
| Tab + f | 强制退出 | ✅ | - |
| Tab + t | 新建终端 | ✅ | ✅ |
| Tab + r | 清理内存 | ✅ | - |
| Tab + s | 截图 | ✅ | - |
| Tab + v | 录屏 | ✅ | - |
| Tab + x | 开关 VPN | ✅ | - |

## 📂 项目结构

```
ProTab/
├── protab.command      # macOS 启动脚本（双击运行）
├── protab.bat          # Windows 启动脚本（双击运行）
├── tab_monitor.swift   # macOS 键盘监听器
├── shortcuts/          # 快捷键脚本 (14个)
├── rust/               # Rust 内存清理器
├── tests/              # 测试文件
└── docs/               # 文档
```

## 🔒 权限说明

### macOS
首次运行需在「系统设置 > 隐私与安全性 > 辅助功能」中授权

### Windows
无需特殊权限

## 🛠️ 自定义快捷键

1. 在 `shortcuts/` 目录创建新脚本
2. 编辑 `tab_monitor.swift` 添加快捷键映射
3. 重启 ProTab

## 📝 更新日志

### v2.0.0 (2026-01-08)
- 新增 Windows 支持
- 新增 Codex 快捷键 (d, o, p)
- 新增 Anti-API 启动快捷键 (a)
- 新增关闭空闲终端 (c)
- 简化为一键启动
- 修复 page_size 硬编码问题

### v1.0.0 (2024-12-23)
- 初始版本发布
- macOS 全局快捷键系统

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE)
