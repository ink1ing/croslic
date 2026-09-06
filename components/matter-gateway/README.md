# Matter Without Gateway

无需网关，公网控制任意 Matter 设备。

## Quick Start

1. **安装**
   ```bash
   npm install && npm install -g pm2
   ```

2. **配网**
   在 `pair.js` 中填入设备 11 位代码，运行：
   ```bash
   node pair.js
   ```

3. **启动**
   双击桌面 `启动饮水机系统.command` 或：
   ```bash
   pm2 start server.js
   pm2 start "cloudflared tunnel run"
   ```

## Features
- **No Hub**: 不需要 Apple HomePod 或小米网关。
- **Remote**: 自带 Cloudflare 隧道。
- **UI**: 极简 iOS 风格面板。

---
MIT License.
