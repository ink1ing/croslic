import { Environment, Logger, Diagnostic } from "@matter/main";
import { CommissioningController } from "@project-chip/matter.js";
import "@matter/nodejs-ble";

async function main() {
    console.log("🔍 正在全量抓取局域网 Matter 节点特征...");

    const environment = Environment.default;
    environment.vars.set("storage.path", ".matter-storage");

    const commissioningController = new CommissioningController({
        environment: { environment, id: "scanner" },
        adminFabricLabel: "Scanner",
    });

    await commissioningController.start();

    // 扫描 10 秒
    const devices = await commissioningController.discoverCommissionableDevices({
        onIpNetwork: true,
        ble: true
    }, 10);

    console.log(`\n📡 扫描结束，共发现 ${devices.length} 个设备:`);
    devices.forEach((d, i) => {
        console.log(`\n[设备 #${i+1}]`);
        console.log(Diagnostic.json(d));
    });

    await commissioningController.close();
    process.exit(0);
}

main().catch(console.error);
