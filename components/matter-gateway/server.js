import express from "express";
import fs from "fs";
import crypto from "crypto";
import "dotenv/config";
import { Environment } from "@matter/main";
import { CommissioningController } from "@project-chip/matter.js";
import { ManualPairingCodeCodec } from "@matter/main/types";
import { OnOffClient } from "@matter/main/behaviors/on-off";
import "@matter/nodejs-ble";

const app = express();
const port = Number(process.env.PORT || 3000);
const host = process.env.HOST || "127.0.0.1";
const DEVICES_FILE = "./devices.json";
const SETTINGS_FILE = "./settings.json";
const DEVICE_SLOTS = [0, 1, 2];
const DEFAULT_SCHEDULE = { onTime: "", offTime: "", enabled: false };
const DEFAULT_SETTINGS = { title: "IT STUDIO 设备控制" };
const AUTH_COOKIE = "water_auth";
const AUTH_TTL_MS = 24 * 60 * 60 * 1000;
const CONTROL_PIN = /^\d{6}$/.test(process.env.CONTROL_PIN || "") ? process.env.CONTROL_PIN : null;
const COOKIE_SECURE = process.env.COOKIE_SECURE === "true";
const DEFAULT_DEVICES = [
    { id: 0, name: "IT 工作室饮水机", emoji: "🚰" },
    { id: 1, name: "设备 2", emoji: "💡" },
    { id: 2, name: "设备 3", emoji: "🔌" },
];

app.use(express.static("public"));
app.use(express.json());

if (!CONTROL_PIN) {
    console.warn("⚠️ CONTROL_PIN 未配置或不是 6 位数字，所有控制操作都会被拒绝。");
}

// ── 设备配置存储 ──────────────────────────────────────────
// 格式: { id, name, emoji, nodeId, schedule: {onTime, offTime, enabled} }
let deviceConfigs = [];
if (fs.existsSync(DEVICES_FILE)) {
    deviceConfigs = JSON.parse(fs.readFileSync(DEVICES_FILE));
}
let appSettings = { ...DEFAULT_SETTINGS };
if (fs.existsSync(SETTINGS_FILE)) {
    appSettings = { ...DEFAULT_SETTINGS, ...JSON.parse(fs.readFileSync(SETTINGS_FILE)) };
}
function saveDeviceConfigs() {
    fs.writeFileSync(DEVICES_FILE, JSON.stringify(deviceConfigs, null, 2));
}
function saveAppSettings() {
    fs.writeFileSync(SETTINGS_FILE, JSON.stringify(appSettings, null, 2));
}
function defaultDevice(id) {
    const base = DEFAULT_DEVICES.find(device => device.id === Number(id)) || { id: Number(id), name: `设备 ${Number(id) + 1}`, emoji: "💡" };
    return { ...base, nodeId: null, schedule: { ...DEFAULT_SCHEDULE } };
}
function isValidSlot(id) {
    return DEVICE_SLOTS.includes(Number(id));
}

// ── 访问控制 ──────────────────────────────────────────────
const sessions = new Map();

function parseCookies(req) {
    const header = req.headers.cookie || "";
    return Object.fromEntries(header.split(";").map(part => {
        const [key, ...value] = part.trim().split("=");
        return [key, decodeURIComponent(value.join("=") || "")];
    }).filter(([key]) => key));
}

function isAuthenticated(req) {
    const token = parseCookies(req)[AUTH_COOKIE];
    if (!token) return false;
    const expiresAt = sessions.get(token);
    if (!expiresAt) return false;
    if (expiresAt <= Date.now()) {
        sessions.delete(token);
        return false;
    }
    return true;
}

function requireAuth(req, res, next) {
    if (isAuthenticated(req)) return next();
    res.status(401).json({ error: "需要输入 6 位密码", authenticated: false });
}

function setAuthCookie(res, token, expiresAt) {
    const maxAge = Math.floor((expiresAt - Date.now()) / 1000);
    const secure = COOKIE_SECURE ? "; Secure" : "";
    res.setHeader("Set-Cookie", `${AUTH_COOKIE}=${encodeURIComponent(token)}; Max-Age=${maxAge}; Path=/; HttpOnly; SameSite=Lax${secure}`);
}

function clearAuthCookie(res) {
    res.setHeader("Set-Cookie", `${AUTH_COOKIE}=; Max-Age=0; Path=/; HttpOnly; SameSite=Lax`);
}

// ── Matter 控制器 ─────────────────────────────────────────
const environment = Environment.default;
environment.vars.set("storage.path", ".matter-storage");

const controller = new CommissioningController({
    environment: { environment, id: "controller" },
    autoConnect: true,
    adminFabricLabel: "Anywhere Controller",
});

// 运行时节点缓存: slotId → node
const nodes = {};

async function initMatter() {
    console.log("📂 加载 Matter 存储...");
    await controller.start();
    const commissioned = controller.getCommissionedNodes();
    console.log(`🔌 已配对节点: ${commissioned.length} 个`);

    // 把已知 nodeId 对应到配置
    for (const cfg of deviceConfigs) {
        if (!cfg.nodeId) continue;
        const nodeId = BigInt("0x" + cfg.nodeId);
        if (commissioned.some(n => n === nodeId || String(n) === String(nodeId) || n.toString() === nodeId.toString())) {
            try {
                nodes[cfg.id] = await controller.getNode(nodeId);
                console.log(`✅ 设备 [${cfg.id}] ${cfg.name} 已就绪`);
            } catch (e) {
                // 尝试直接用 commissioned 列表找
                for (const nid of commissioned) {
                    try {
                        const n = await controller.getNode(nid);
                        // 比较 nodeId 字符串
                        if (nid.toString(16) === cfg.nodeId) {
                            nodes[cfg.id] = n;
                            break;
                        }
                    } catch {}
                }
            }
        }
    }

    // 向后兼容：如果有旧的单设备 schedule.json，迁移到 slot 0
    if (deviceConfigs.length === 0) {
        const oldScheduleFile = "./schedule.json";
        let oldSchedule = { onTime: "", offTime: "", enabled: false };
        if (fs.existsSync(oldScheduleFile)) {
            oldSchedule = JSON.parse(fs.readFileSync(oldScheduleFile));
        }
        // 如果有已配对节点，自动绑定到 slot 0
        if (commissioned.length > 0) {
            const firstNodeId = commissioned[0];
            deviceConfigs.push({
                id: 0,
                name: "IT 工作室饮水机",
                emoji: "🚰",
                nodeId: firstNodeId.toString(16),
                schedule: oldSchedule,
            });
            saveDeviceConfigs();
            nodes[0] = await controller.getNode(firstNodeId);
            console.log("🔄 已自动迁移旧设备到 Slot 0");
        }
    }
}

// ── 定时任务引擎 (每分钟) ─────────────────────────────────
setInterval(async () => {
    const now = new Date();
    const currentTime = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
    for (const cfg of deviceConfigs) {
        const { schedule, id } = cfg;
        if (!schedule?.enabled || !nodes[id]) continue;
        try {
            const ep = nodes[id].parts.get(1);
            const cmds = ep.commandsOf(OnOffClient);
            if (currentTime === schedule.onTime) {
                console.log(`⏰ [${cfg.name}] 定时开启`);
                await cmds.on();
            } else if (currentTime === schedule.offTime) {
                console.log(`⏰ [${cfg.name}] 定时关闭`);
                await cmds.off();
            }
        } catch (e) {
            console.error(`定时执行出错 [${cfg.name}]:`, e.message);
        }
    }
}, 60000);

// ── 辅助：获取设备配置 ────────────────────────────────────
function getConfig(id) {
    return deviceConfigs.find(c => c.id === Number(id));
}

function ensureConfig(id) {
    let cfg = getConfig(id);
    if (!cfg) {
        cfg = defaultDevice(id);
        deviceConfigs.push(cfg);
    }
    cfg.schedule ||= { ...DEFAULT_SCHEDULE };
    if (!cfg.name) cfg.name = defaultDevice(id).name;
    if (!cfg.emoji) cfg.emoji = defaultDevice(id).emoji;
    return cfg;
}

// ── API: 身份验证 ─────────────────────────────────────────
app.get("/api/auth/status", (req, res) => {
    const authenticated = isAuthenticated(req);
    res.json({
        authenticated,
        expiresAt: authenticated ? new Date(sessions.get(parseCookies(req)[AUTH_COOKIE])).toISOString() : null,
    });
});

app.post("/api/auth/login", (req, res) => {
    if (!CONTROL_PIN) return res.status(503).json({ error: "CONTROL_PIN 未配置" });
    const pin = String(req.body?.pin || "");
    const expected = Buffer.from(CONTROL_PIN);
    const actual = Buffer.from(pin);
    const validLength = actual.length === expected.length;
    const valid = validLength && crypto.timingSafeEqual(actual, expected);
    if (!valid) return res.status(403).json({ error: "密码错误" });

    const token = crypto.randomBytes(32).toString("hex");
    const expiresAt = Date.now() + AUTH_TTL_MS;
    sessions.set(token, expiresAt);
    setAuthCookie(res, token, expiresAt);
    res.json({ success: true, authenticated: true, expiresAt: new Date(expiresAt).toISOString() });
});

app.post("/api/auth/logout", requireAuth, (req, res) => {
    const token = parseCookies(req)[AUTH_COOKIE];
    if (token) sessions.delete(token);
    clearAuthCookie(res);
    res.json({ success: true, authenticated: false });
});

// ── API: 页面设置 ─────────────────────────────────────────
app.get("/api/settings", (req, res) => {
    res.json(appSettings);
});

app.post("/api/settings", requireAuth, (req, res) => {
    const { title } = req.body;
    if (title !== undefined) {
        appSettings.title = String(title).trim() || DEFAULT_SETTINGS.title;
    }
    saveAppSettings();
    res.json({ success: true, settings: appSettings });
});

// ── API: 获取所有设备列表 ─────────────────────────────────
app.get("/api/devices", (req, res) => {
    const list = DEVICE_SLOTS.map(id => {
        const cfg = getConfig(id) || defaultDevice(id);
        return {
            id,
            name: cfg.name,
            emoji: cfg.emoji,
            paired: !!cfg?.nodeId,
            online: !!nodes[id],
            schedule: cfg?.schedule || { ...DEFAULT_SCHEDULE },
        };
    });
    res.json(list);
});

// ── API: 获取单设备状态 ───────────────────────────────────
app.get("/api/device/:id/status", async (req, res) => {
    const id = Number(req.params.id);
    if (!isValidSlot(id)) return res.status(404).json({ error: "设备槽位不存在" });
    const cfg = getConfig(id);
    if (!cfg || !nodes[id]) return res.status(503).json({ error: "Not ready", paired: !!cfg?.nodeId });
    try {
        const ep = nodes[id].parts.get(1);
        const state = ep.stateOf(OnOffClient);
        res.json({ on: state.onOff, schedule: cfg.schedule });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ── API: 切换开关 ─────────────────────────────────────────
app.post("/api/device/:id/toggle", requireAuth, async (req, res) => {
    const id = Number(req.params.id);
    if (!isValidSlot(id)) return res.status(404).json({ error: "设备槽位不存在" });
    if (!nodes[id]) return res.status(503).json({ error: "Not ready" });
    try {
        const ep = nodes[id].parts.get(1);
        const cmds = ep.commandsOf(OnOffClient);
        await cmds.toggle();
        const state = ep.stateOf(OnOffClient);
        res.json({ success: true, on: state.onOff });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ── API: 配置设备名称/emoji ───────────────────────────────
app.post("/api/device/:id/config", requireAuth, (req, res) => {
    const id = Number(req.params.id);
    if (!isValidSlot(id)) return res.status(404).json({ error: "设备槽位不存在" });
    const { name, emoji } = req.body;
    const cfg = ensureConfig(id);
    if (name !== undefined) cfg.name = String(name).trim() || defaultDevice(id).name;
    if (emoji !== undefined) cfg.emoji = String(emoji).trim() || defaultDevice(id).emoji;
    saveDeviceConfigs();
    res.json({ success: true });
});

// ── API: 配对设备 ─────────────────────────────────────────
app.post("/api/device/:id/pair", requireAuth, async (req, res) => {
    const id = Number(req.params.id);
    if (!isValidSlot(id)) return res.status(404).json({ error: "设备槽位不存在" });
    const { pairingCode, targetIp } = req.body;
    if (!pairingCode) return res.status(400).json({ error: "需要配对码" });

    try {
        const normalizedCode = String(pairingCode).trim();
        const normalizedIp = String(targetIp || "").trim();
        const pairingData = ManualPairingCodeCodec.decode(normalizedCode);
        console.log(`🔗 开始配对 Slot ${id}, 码: ${normalizedCode}${normalizedIp ? `, IP: ${normalizedIp}` : ""}`);

        const discovery = normalizedIp
            ? {
                knownAddress: { ip: normalizedIp, port: 5540, type: "udp" },
                identifierData: {
                    shortDiscriminator: pairingData.shortDiscriminator,
                },
                discoveryCapabilities: { onIpNetwork: true },
            }
            : {
                identifierData: {
                    shortDiscriminator: pairingData.shortDiscriminator,
                },
            };

        const nodeId = await controller.commissionNode({
            commissioning: {
                regulatoryLocation: 0,
                regulatoryCountryCode: "CN",
            },
            discovery,
            passcode: pairingData.passcode,
        });

        const nodeIdHex = nodeId.toString(16);
        const node = await controller.getNode(nodeId);

        const cfg = ensureConfig(id);
        cfg.nodeId = nodeIdHex;
        saveDeviceConfigs();
        nodes[id] = node;

        console.log(`✅ Slot ${id} 配对成功, nodeId: ${nodeIdHex}`);
        res.json({ success: true, nodeId: nodeIdHex });
    } catch (e) {
        console.error("配对失败:", e.message);
        res.status(500).json({ error: e.message });
    }
});

// ── API: 解除配对 ─────────────────────────────────────────
app.post("/api/device/:id/unpair", requireAuth, async (req, res) => {
    const id = Number(req.params.id);
    if (!isValidSlot(id)) return res.status(404).json({ error: "设备槽位不存在" });
    const cfg = getConfig(id);
    if (!cfg?.nodeId) return res.status(400).json({ error: "未配对" });
    try {
        if (nodes[id]) {
            await controller.removeNode(BigInt("0x" + cfg.nodeId));
            delete nodes[id];
        }
        cfg.nodeId = null;
        saveDeviceConfigs();
        res.json({ success: true });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ── API: 设置定时 ─────────────────────────────────────────
app.post("/api/device/:id/schedule", requireAuth, (req, res) => {
    const id = Number(req.params.id);
    if (!isValidSlot(id)) return res.status(404).json({ error: "设备槽位不存在" });
    const { onTime, offTime, enabled } = req.body;
    const cfg = ensureConfig(id);
    cfg.schedule = { onTime: onTime || "", offTime: offTime || "", enabled: !!enabled };
    saveDeviceConfigs();
    res.json({ success: true });
});

// ── 向后兼容旧 API（饮水机 slot 0）────────────────────────
app.get("/api/status", async (req, res) => {
    req.params = { id: 0 };
    const cfg = getConfig(0);
    if (!cfg || !nodes[0]) return res.status(503).json({ error: "Node not ready" });
    try {
        const ep = nodes[0].parts.get(1);
        const state = ep.stateOf(OnOffClient);
        res.json({ on: state.onOff, schedule: cfg.schedule });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post("/api/toggle", requireAuth, async (req, res) => {
    if (!nodes[0]) return res.status(503).json({ error: "Node not ready" });
    try {
        const ep = nodes[0].parts.get(1);
        await ep.commandsOf(OnOffClient).toggle();
        const state = ep.stateOf(OnOffClient);
        res.json({ success: true, on: state.onOff });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post("/api/schedule", requireAuth, (req, res) => {
    const cfg = ensureConfig(0);
    const { onTime, offTime, enabled } = req.body;
    cfg.schedule = { onTime: onTime || "", offTime: offTime || "", enabled: !!enabled };
    saveDeviceConfigs();
    res.json({ success: true });
});

// ── 启动 ─────────────────────────────────────────────────
initMatter().then(() => {
    app.listen(port, host, () => console.log(`🚀 Matter 控制台已启动: http://${host}:${port}`));
});
