# Currency Converter

轻量 Swift 模块，供主面板调用，也可独立运行。

- 默认请求 Frankfurter v2 的单币种对汇率接口；无需 API key，客户端本地完成乘法换算。
- 请求超时 4 秒，实时结果缓存 1 小时；网络失败自动切换到内置近似汇率。
- UI 应显示“实时汇率 / 内置离线汇率”和有效日期，避免把兜底值误认为实时数据。
- `--offline` 可强制离线：`swift run currency-converter 100 USD CNY --offline`。

内置汇率是应急兜底，不用于结算、报价或财务记账。正式使用时应增加磁盘缓存、手动刷新和来源链接。
