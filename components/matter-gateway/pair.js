import { Environment, Logger, StorageService } from "@matter/main";
import { ManualPairingCodeCodec } from "@matter/main/types";
import { CommissioningController } from "@project-chip/matter.js";
import "@matter/nodejs-ble";

const pairingCode = "31184712357";
const targetIp = "192.168.2.22";

async function main() {
    console.log(`🚀 终极强攻 (IP: ${targetIp}, Code: ${pairingCode})`);

    const environment = Environment.default;
    environment.vars.set("storage.path", ".matter-storage");

    const commissioningController = new CommissioningController({
        environment: { environment, id: "controller" },
        autoConnect: true,
        adminFabricLabel: "Anywhere Controller",
    });

    await commissioningController.start();

    if (!commissioningController.isCommissioned()) {
        const pairingCodeCodec = ManualPairingCodeCodec.decode(pairingCode);

        const options = {
            commissioning: {
                regulatoryLocation: 0,
                regulatoryCountryCode: "XX",
            },
            discovery: {
                knownAddress: { ip: targetIp, port: 5540, type: "udp" },
                // 刚才解析出的 D=12
                identifierData: { shortDiscriminator: pairingCodeCodec.shortDiscriminator },
                discoveryCapabilities: { onIpNetwork: true },
            },
            passcode: pairingCodeCodec.passcode,
        };

        console.log(`📡 正在强攻 ${targetIp}... (Passcode: ${pairingCodeCodec.passcode})`);
        try {
            const nodeId = await commissioningController.commissionNode(options);
            console.log(`\n✅ 配网成功！Node ID: ${nodeId}`);
        } catch (e) {
            console.error("\n❌ 失败:", e.message);
        }
    }

    await commissioningController.close();
    process.exit(0);
}

main().catch(console.error);
