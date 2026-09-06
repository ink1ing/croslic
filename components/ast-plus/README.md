# AST-plus

AST-plus 是一套面向二手 Mac 验机与新机状态核验的 macOS 本地诊断项目，目标不是替代 Apple 官方维修体系，而是尽可能自动化地收集证据、识别高风险机器，并把人工检查与 Apple Diagnostics 结果纳入统一报告。

## 语言支持

- CLI 输出支持：`zh` / `en`
- Markdown 报告支持：`zh` / `en`
- 交互启动脚本 `start.command` 支持选择语言
- `specific` 报告会输出更详细的中文说明，适合直接看验机结论

示例：

```bash
swift run AST-plus --once --language zh --detail specific
swift run AST-plus --once --language en --detail basic
```

项目设计参考了以下开源方向：

- [checkmymac](https://github.com/0xBugatti/checkmymac)：二手 Mac 风险检查思路与验机定位
- [DiagnosticTool](https://github.com/richwrightnyc/DiagnosticTool)：`system_profiler` 基础信息采集骨架
- [Diag](https://github.com/whschultz/Diag)：SMART、磁盘健康、panic 与错误日志分析
- [macmon](https://github.com/vladkens/macmon)：Apple Silicon 温度、功耗、内存监控思路
- [iSMC](https://github.com/dkorunic/iSMC)：传感器、风扇、电压、电流读取方向
- [macos-battery-exporter](https://github.com/jimeh/macos-battery-exporter)：`ioreg` 电池深度数据提取

## 项目目标

- 识别高风险机器：主板、存储、电池、散热、显示、日志存在明显异常
- 识别可接受的小问题：轻微电池磨损、正常使用痕迹、非致命告警
- 保留可复核证据：原始命令输出、阈值、判定原因、人工检查项

AST-plus 不承诺“证明机器 100% 无问题”，而是提供：

- 自动化信息采集
- 压力测试与前后对比
- 风险分级结论
- 可归档、可复核的报告

## Apple Silicon 兼容性

当前实现以 Apple 提供的稳定系统接口为主，例如 `system_profiler`、`ioreg`、`diskutil`、`pmset`、`log show`，并且避免对 M1 / M2 / M3 / M4 机型做硬编码判断。

因此它的目标兼容范围是：

- MacBook Air (M 系列)
- MacBook Pro 13/14/16 英寸 (M 系列)

当前规则层更偏“通用风险检查”，而不是某一代机型专属校验。

## 核心能力

- 机器身份与配置基线采集
- IORegistry 深挖与高低层信息交叉校验
- 电池健康分析
- SSD / NVMe 健康分析
- 磁盘性能与稳定性压测
- CPU / GPU / 内存稳定性验证
- 温控、功耗、节流检测
- 系统日志与历史故障扫描
- 显示、音频、无线、端口等模块化检查
- 人工检查清单与 Apple Diagnostics 配合记录

## 设计原则

- 标准模式：无 `sudo`，用于快速初筛
- 深度模式：带 `sudo`，用于更完整的传感器、功耗、日志与存储检测
- 输出统一：同时生成机器可读和人类可读报告
- 证据优先：保留原始采集结果，不只输出通过/失败
- 诚实边界：对“是否原装”“是否官方维修配对”只给出证据等级，不给绝对断言

## 建议技术路线

首选 Swift CLI，次选 Python + shell。

原因：

- macOS 原生分发更顺手
- 调系统命令与解析 plist / JSON 更自然
- 后续可以平滑扩展到 GUI、签名和 notarize

## 当前实现状态

当前仓库已经落地一版 Swift CLI MVP，可在本机运行并生成：

- `reports/report.json`
- `reports/report.md`
- `reports/manual_checklist.md`
- `artifacts/*.txt`

当前已实现的标准模式能力：

- 硬件基线采集
- 软件版本采集
- 电池健康解析
- 存储基础信息采集
- panic 报告与电源日志快速筛查
- 显示、Wi‑Fi、蓝牙、摄像头、音频存在性检查
- 短时 CPU 压测

## 快速开始

构建：

```bash
swift build
```

运行标准模式：

```bash
swift run AST-plus
```

运行标准模式并缩短压测时间：

```bash
swift run AST-plus --stress-seconds 3
```

指定输出目录：

```bash
swift run AST-plus --output /path/to/output
```

深度模式入口已预留：

```bash
swift run AST-plus --deep
```

注意：

- 深度模式后续会依赖更多 `sudo` 能力
- 当前日志模块采用快速筛查策略，优先保证真实机器上的可执行性
- 当前版本不会声称“绝对原装”或“100% 无问题”

## 输出产物

每次检测至少输出三类结果：

- `reports/report.json`：结构化检测结果
- `reports/report.md`：面向用户的可读结论
- `artifacts/`：原始命令输出、日志、采样文件、截图等证据

建议补充：

- `reports/manual_checklist.md`：人工检查清单与勾选结果

## 当前 CLI 用法

```bash
swift run AST-plus
printf '/help\n/exit\n' | swift run AST-plus
swift run AST-plus --once
swift run AST-plus --stress-seconds 15
swift run AST-plus --skip-stress
swift run AST-plus --deep
swift run AST-plus --log-window 24h
swift run AST-plus --output ./out
```

说明：

- `--deep` 会尝试采集 `powermetrics`，默认使用无交互 `sudo -n`
- 若当前机器未配置免交互 sudo，深度采样会降级为告警，不会卡死
- `--skip-stress` 适合只做静态采集
- `--log-window` 控制结构化日志窗口，默认 `1h`；`24h` 和 `7d` 适合复检，速度会更慢
- 默认会进入交互 REPL；若只想执行一次检测并退出，用 `--once`
- 输出默认写入当前目录下的 `reports/` 和 `artifacts/`

## 交互模式

交互模式下，CLI 会常驻并维护当前会话状态，支持轻量模式切换和参数调整。

可用命令：

```text
/help
/exit
/run
/run deep
/status
/last
/diff
/clear
/mode standard|deep|auto
/set stress <秒数>
/set skip-stress on|off
/set log-window 1h|24h|7d
/open report|json|checklist
```

说明：

- `standard`：标准扫描
- `deep`：深度扫描，尝试采集 `powermetrics`
- `auto`：当前实现上等同深度扫描预设，后续可扩展为更激进的自动流程

## 状态分级

所有模块统一使用四级状态：

- `PASS`
- `WARN`
- `FAIL`
- `UNKNOWN`

每条结论必须包含：

- 原始值
- 判定阈值
- 判定原因

示例：

```json
{
  "battery": {
    "cycle_count": 42,
    "max_capacity_percent": 97,
    "condition": "Normal",
    "status": "PASS",
    "reason": "Cycle count below 100 and capacity above 95%"
  }
}
```

## MVP 范围

V1 必做：

- `system_profiler` 全量采集
- `ioreg` 关键节点采集
- 电池模块
- SSD 模块
- 日志扫描模块
- CPU 压测与温度采样
- JSON / Markdown 报告输出
- 人工检查清单

V2 规划：

- GPU 压测
- 端口交互测试
- 摄像头 / 音频自动验证
- 多轮采样与趋势图
- GUI

V3 规划：

- 规则引擎
- 同型号基线比对
- 自动归档 sysdiagnose / System Diagnostics
- 自定义风险策略

## 建议目录结构

```text
AST-plus/
  bin/
  src/
    collect/
    parse/
    checks/
    stress/
    report/
  rules/
    battery.yaml
    storage.yaml
    logs.yaml
  artifacts/
  reports/
  README.md
  plans.md
```

## 关键模块与命令映射

### 1. 机器身份与配置基线

目标：确认机器“自称是什么”，并建立后续交叉比对基线。

主要命令：

```bash
system_profiler SPHardwareDataType -json
system_profiler SPSoftwareDataType -json
sysctl -n hw.model
uname -a
nvram -p
```

### 2. IORegistry 深挖

目标：抽取设备树低层属性，补足高层工具看不到的信息。

主要命令：

```bash
ioreg -l -w 0
ioreg -ar -w 0
ioreg -p IOService -l -w 0
```

### 3. 电池健康

主要命令：

```bash
system_profiler SPPowerDataType -json
pmset -g batt
ioreg -r -c AppleSmartBattery -l
```

重点字段：

- Cycle Count
- Condition
- Full Charge Capacity
- Design Capacity
- 当前电量
- 充电状态
- 温度

### 4. SSD / 存储健康

主要命令：

```bash
diskutil list
diskutil info -all
system_profiler SPNVMeDataType -json
smartctl -a /dev/disk0
smartctl -x /dev/disk0
```

### 5. 磁盘压测

最小实现可先用：

```bash
dd if=/dev/zero of=testfile.bin bs=1m count=8192
dd if=testfile.bin of=/dev/null bs=1m
```

后续建议改为 `fio` 并输出 JSON。

### 6. 温控与功耗

主要命令：

```bash
sudo powermetrics --samplers smc -n 1
sudo powermetrics --samplers cpu_power,gpu_power,thermal -i 1000 -n 20
pmset -g therm
```

### 7. 日志与历史故障

主要命令：

```bash
log show --last 7d --style json
log show --last 30d --predicate 'eventMessage CONTAINS[c] "Previous shutdown cause"'
log show --last 30d --predicate 'eventMessage CONTAINS[c] "I/O error"'
log show --last 30d --predicate 'eventMessage CONTAINS[c] "panic"'
pmset -g log
```

## 硬性红线

以下情况建议直接判为高风险：

- `Media and Data Integrity Errors > 0`
- 近期重复出现 kernel panic / I/O error / GPU reset
- 压测中死机、重启、无响应或掉盘
- 电池状态明显异常，且伴随温度或充电异常
- 显示屏有明显坏点、漏光、闪烁、色块
- 型号、容量、设备树、高层信息互相对不上

## 无法完全自动化的部分

以下能力只能半自动或人工确认：

- 显示屏坏点、漏光、均匀性、低亮度闪烁
- 键盘、触控板、扬声器、麦克风主观体验
- 每个端口的逐一插拔验证
- 是否“绝对原装”或是否存在精细板修

因此 AST-plus 的完整流程应是：

1. 自动化采集
2. 压力测试
3. 人工 checklist
4. Apple Diagnostics 结果录入

## 当前文档状态

当前仓库尚未落地代码实现。本次先根据 roadmap 固化项目定位、模块边界和实施计划，详细拆分见 [plans.md](/Users/inkling/Desktop/AST-plus/plans.md)。
