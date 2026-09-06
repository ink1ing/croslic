# AST-plus 研发计划

## 1. 项目定位

AST-plus 是一个 macOS 本地验机与诊断项目，重点面向二手 Mac、新购 Mac 和维修后 Mac 的状态核验。目标不是复刻 Apple 内部维修工具，而是构建一套“自动采集 + 压测 + 人工复核 + 证据归档”的完整流程。

项目最终结论应偏向风险控制，而不是绝对判定：

- 可购买
- 可购买但需压价或继续复测
- 不建议购买

## 2. 参考项目拆解

### checkmymac

定位：最接近目标场景的二手 Mac 验机项目。

可借鉴点：

- 验机导向而不是单纯信息展示
- MDM / DEP / 企业锁 / 激活锁等风险思路
- 将多项检查统一聚合成可执行流程

不足：

- 项目较新，稳定性与覆盖面需要自行验证

### DiagnosticTool

定位：系统信息采集骨架。

可借鉴点：

- 用 `system_profiler` 建立硬件、软件、配置基线
- 先把采集层抽象清楚，再上规则层

### Diag

定位：存储健康和系统历史错误分析。

可借鉴点：

- SSD SMART
- panic / error 日志
- 盘健康结论不只看容量和写入量

### macmon

定位：Apple Silicon 性能、温度、功耗监控。

可借鉴点：

- 压测时配套采样
- JSON 输出
- 温控、功耗、内存趋势化记录

### iSMC

定位：传感器层。

可借鉴点：

- 温度、风扇、电压、电流
- 深度模式的数据来源补充

### macos-battery-exporter

定位：电池深度信息提取。

可借鉴点：

- 从 `ioreg` 读取结构化电池数据
- 与 `system_profiler` 结果交叉验证

## 3. 产品边界

### 能做的

- 自动采集机器身份、硬件、软件、日志、健康与压力测试数据
- 根据公开阈值和自定义规则输出风险等级
- 生成 JSON、Markdown、原始证据包
- 提供人工检查流程

### 半自动能做的

- 摄像头拍帧、音频播放录制、Wi‑Fi 连通性、端口逐一插拔
- Apple Diagnostics 结果录入与报告整合

### 做不到的

- 100% 证明机器绝对无问题
- 100% 判断所有部件是否原装官方配对
- 获取 Apple 内部未公开的校准或维修后台状态

## 4. 技术路线

### 首选方案

Swift CLI。

理由：

- macOS 原生体验更好
- `Process` 调系统命令稳定
- 易于解析 plist / JSON
- 后续扩展 GUI 和签名分发更顺

### 备选方案

Python + shell。

适合早期快速打样，但后续若要 GUI、分发、权限处理、长期维护，Swift 更合适。

## 5. 运行模式

### 标准模式

特征：

- 不需要 `sudo`
- 偏快速初筛
- 可覆盖基础采集、电池、显示、网络、部分日志和部分存储信息

### 深度模式

特征：

- 需要 `sudo`
- 追加 `powermetrics`、更完整日志、低层健康信息、更多传感器数据
- 用于复检与出正式报告

## 6. 输出设计

每次检测固定生成以下内容：

- `reports/report.json`
- `reports/report.md`
- `reports/manual_checklist.md`
- `artifacts/` 原始命令输出和采样日志

建议目录：

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
  artifacts/
  reports/
```

## 7. 模块规划

### 模块 1：机器身份与配置基线

目标：

- 建立型号、芯片、内存、存储、序列号、系统版本、固件版本基线

命令：

```bash
system_profiler SPHardwareDataType -json
system_profiler SPSoftwareDataType -json
sysctl -n hw.model
uname -a
nvram -p
```

判定重点：

- 型号与机型标识一致
- 序列号不为空且格式合理
- Boot ROM / 固件版本存在

### 模块 2：IORegistry 深挖

目标：

- 抽取设备树低层属性，补齐高层信息

命令：

```bash
ioreg -l -w 0
ioreg -ar -w 0
ioreg -p IOService -l -w 0
```

判定重点：

- 关键节点存在
- 属性结构完整
- 与 `system_profiler` 高层结果一致

### 模块 3：电池健康

命令：

```bash
system_profiler SPPowerDataType -json
pmset -g batt
ioreg -r -c AppleSmartBattery -l
```

至少提取：

- Cycle Count
- Condition
- Full Charge Capacity
- Design Capacity
- 当前电量
- 是否在充电
- 温度

建议规则：

- 优秀：循环 < 100，容量 > 95%
- 良好：循环 < 300，容量 > 90%
- 可接受：循环 < 600，容量 > 85%
- 警惕：循环 > 600 或容量 < 85%
- 高风险：维修建议、异常温度、掉电或充电异常

实现要求：

- 同时读取 `system_profiler` 与 `ioreg`
- 连续采样 3 到 5 次
- 记录采样时间

### 模块 4：SSD / 存储健康

命令：

```bash
diskutil list
diskutil info -all
system_profiler SPNVMeDataType -json
smartctl -a /dev/disk0
smartctl -x /dev/disk0
```

至少提取：

- 盘型号
- 容量
- SMART / Health
- Percentage Used
- Data Units Read / Written
- Media Errors
- Error Log Entries
- Unsafe Shutdowns
- 温度

规则重点：

- 错误计数与完整性异常比单纯写入量更重要

### 模块 5：磁盘性能与稳定性压测

目标：

- 验证稳定性，而不是只看跑分峰值

首版命令：

```bash
dd if=/dev/zero of=testfile.bin bs=1m count=8192
dd if=testfile.bin of=/dev/null bs=1m
```

后续升级：

- 使用 `fio`
- 支持顺序读写、小文件混合 I/O、持续写入
- 压测前后抓取 SMART 与日志

### 模块 6：温控、功耗、节流

命令：

```bash
sudo powermetrics --samplers smc -n 1
sudo powermetrics --samplers cpu_power,gpu_power,thermal -i 1000 -n 20
pmset -g therm
```

目标：

- 捕获 CPU / GPU 功耗、温度、热限制状态、频率趋势

规则重点：

- 空载温度正常
- 压测升温合理
- 不出现异常降频、异常关机或明显 thermal pressure

### 模块 7：CPU / GPU 稳定性

目标：

- 做 20 到 30 分钟的 CPU、GPU、混合负载稳定性验证

要求：

- 全程记录温度、日志、错误事件
- 不是只看“跑通”，还要看掉速、错误、异常退出

### 模块 8：内存健康

目标：

- 通过大内存分配和校验循环验证稳定性

采样：

- `vm_stat`
- `memory_pressure`

关注：

- memory pressure
- crash
- panic

### 模块 9：显示屏检查

脚本能做：

- 枚举内建/外接显示设备
- 读取分辨率、刷新率、色深、显示日志

命令：

```bash
system_profiler SPDisplaysDataType -json
ioreg -lw0 | grep -i IODisplay
```

人工必做：

- 坏点
- 漏光
- 色偏
- 黑底均匀性
- 低亮度闪烁

### 模块 10：无线、蓝牙、摄像头、麦克风、音频

命令：

```bash
system_profiler SPAirPortDataType -json
system_profiler SPBluetoothDataType -json
system_profiler SPCameraDataType -json
system_profiler SPAudioDataType -json
```

自动化：

- 枚举存在性
- 识别信息完整性
- 当前链路信息

半自动：

- 摄像头采样
- 音频播放录制
- Wi‑Fi 连通性与吞吐

### 模块 11：端口与总线

命令：

```bash
system_profiler SPThunderboltDataType -json
system_profiler SPUSBDataType -json
system_profiler SPEthernetDataType -json
```

建议做成端口测试模式：

- 提示用户逐个端口插拔外设
- 监听设备树变化
- 自动标记响应与失败

### 模块 12：系统日志与历史故障

命令：

```bash
log show --last 7d --style json
log show --last 30d --predicate 'eventMessage CONTAINS[c] "Previous shutdown cause"'
log show --last 30d --predicate 'eventMessage CONTAINS[c] "I/O error"'
log show --last 30d --predicate 'eventMessage CONTAINS[c] "panic"'
pmset -g log
```

重点关键字：

- panic
- watchdog
- previous shutdown cause
- I/O error
- nvme
- thermal
- GPU reset

### 模块 13：Apple Diagnostics 配合模式

目标：

- 不替代 Apple Diagnostics，而是把其结果纳入最终报告

实现：

- 在人工检查清单里记录已做 / 未做
- 记录错误代码、联网/离线状态、备注

### 模块 14：原装/维修痕迹判断

输出必须谨慎：

- 原装证据充分
- 未发现明显异常
- 存在可疑线索
- 无法仅靠软件确认

禁止输出：

- 绝对原装
- 100% 未维修

### 模块 15：人工检查清单

必须覆盖：

- 外观
- 螺丝与缝隙
- 屏轴阻尼
- 屏幕坏点与漏光
- 键盘逐键
- 触控板全区域
- 摄像头
- 扬声器
- 麦克风
- 每个端口插拔
- Wi‑Fi / 蓝牙实连
- MagSafe / 充电状态

## 8. 统一判定模型

每个模块统一输出：

- `status`
- `raw_values`
- `thresholds`
- `reason`

状态枚举：

- `PASS`
- `WARN`
- `FAIL`
- `UNKNOWN`

示例：

```json
{
  "storage": {
    "media_errors": 0,
    "percentage_used": 2,
    "unsafe_shutdowns": 5,
    "status": "WARN",
    "reason": "Unsafe shutdown count is elevated, but no integrity errors were found."
  }
}
```

## 9. 硬性红线

以下触发即优先判高风险：

- `Media and Data Integrity Errors > 0`
- 近期重复 kernel panic / I/O error / GPU reset
- 压测中死机、重启、无响应、掉盘
- 电池状态异常且伴随温度或充电异常
- 显示屏存在明显坏点、漏光、闪烁、色块
- 关键信息不一致

## 10. 最易遗漏点

- 过去 7 到 30 天历史日志
- 压测后的二次采样
- 连续采样而不是单次快照
- 报告保留原始输出

## 11. 版本计划

### V1

目标：做出可用 MVP。

交付：

- `system_profiler` 全量采集
- `ioreg` 关键节点采集
- 电池模块
- SSD 模块
- 日志扫描模块
- CPU 压测 + 温度采样
- JSON / Markdown 报告
- 人工检查清单

### V2

目标：补足交互测试和多模块压测。

交付：

- GPU 压测
- 端口交互测试
- 摄像头 / 音频自动验证
- 多轮采样与趋势图
- 初版 GUI

### V3

目标：提高规则能力和复核能力。

交付：

- 规则引擎
- 同型号基线比对
- 自动归档 sysdiagnose / System Diagnostics
- 自定义风险策略

## 12. 实施顺序

建议按以下顺序开发：

1. 采集层：封装命令执行器和原始输出归档
2. 解析层：把 `system_profiler`、`ioreg`、`pmset`、`diskutil` 等转成统一结构
3. 检查层：先做电池、存储、日志三大高价值模块
4. 压测层：先 CPU，再温控，再磁盘
5. 报告层：`report.json`、`report.md`、人工清单
6. 深度层：GPU、端口、音频、摄像头、规则引擎

## 13. 本阶段交付结果

本次先完成项目文档基线：

- 明确项目目标与边界
- 固化参考项目拆解
- 固化模块设计、判定模型、红线与版本计划
- 为后续代码实现准备统一执行框架

下一步进入代码阶段时，建议先搭 Swift CLI 骨架和最小采集器。
