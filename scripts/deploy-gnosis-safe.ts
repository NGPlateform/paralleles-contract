import { ethers } from "hardhat";
import { SafeFactory, SafeAccountConfig } from "@safe-global/safe-core-sdk";
import { SafeTransactionDataPartial } from "@safe-global/safe-core-sdk-types";

/**
 * 部署Gnosis Safe多签钱包
 */
async function main() {
    console.log("开始部署Gnosis Safe多签钱包...");

    // 获取部署账户
    const [deployer] = await ethers.getSigners();
    console.log("部署账户:", deployer.address);

    // 配置参数 - 从环境变量读取
    const owners = process.env.SAFE_OWNERS?.split(",") || [
        "0x843076428Df85c8F7704a2Be73B0E1b1D5799D4d",
        "0xc4d97570A90096e9f8e23c58A1E7F528fDAa45e7",
        "0xac3D7D1CeDa1c6B4f25B25991f7401D441E13340"
    ];
    
    const threshold = parseInt(process.env.SAFE_THRESHOLD || "2");
    const fallbackHandler = process.env.SAFE_FALLBACK_HANDLER || ethers.constants.AddressZero;
    
    console.log("Safe配置:");
    console.log("- 所有者:", owners);
    console.log("- 阈值:", threshold);
    console.log("- 回退处理器:", fallbackHandler);

    try {
        // 1. 部署Safe合约
        console.log("\n1. 部署Safe合约...");
        
        // 获取Safe合约工厂
        const SafeFactory = await ethers.getContractFactory("SafeProxyFactory");
        const safeFactory = await SafeFactory.deploy();
        await safeFactory.deployed();
        console.log("Safe工厂合约已部署:", safeFactory.address);

        // 获取Safe主合约
        const Safe = await ethers.getContractFactory("Safe");
        const safeMasterCopy = await Safe.deploy();
        await safeMasterCopy.deployed();
        console.log("Safe主合约已部署:", safeMasterCopy.address);

        // 2. 创建Safe实例
        console.log("\n2. 创建Safe实例...");
        
        // 准备Safe配置
        const safeConfig: SafeAccountConfig = {
            owners: owners,
            threshold: threshold,
            fallbackHandler: fallbackHandler,
            saltNonce: ethers.utils.hexlify(ethers.utils.randomBytes(32))
        };

        // 创建Safe
        const safe = await safeFactory.createProxyWithNonce(
            safeMasterCopy.address,
            safeMasterCopy.interface.encodeFunctionData("setup", [
                safeConfig.owners,
                safeConfig.threshold,
                safeConfig.fallbackHandler,
                safeConfig.fallbackHandler,
                safeConfig.fallbackHandler,
                0,
                safeConfig.fallbackHandler
            ]),
            safeConfig.saltNonce
        );

        const safeAddress = safe.receipt?.events?.find(
            (event: any) => event.event === "ProxyCreation"
        )?.args?.proxy;

        console.log("Safe实例已创建:", safeAddress);

        // 3. 部署SafeManager合约
        console.log("\n3. 部署SafeManager合约...");
        const SafeManager = await ethers.getContractFactory("SafeManager");
        const safeManager = await SafeManager.deploy(safeAddress);
        await safeManager.deployed();
        console.log("SafeManager合约已部署:", safeManager.address);

        // 4. 配置Safe权限
        console.log("\n4. 配置Safe权限...");
        
        // 将SafeManager设置为Safe的所有者（可选）
        // 这需要Safe的所有者签名确认

        // 5. 保存部署信息
        const deploymentInfo = {
            network: process.env.NETWORK || "BSC Testnet",
            deployer: deployer.address,
            timestamp: new Date().toISOString(),
            safe: {
                address: safeAddress,
                factory: safeFactory.address,
                masterCopy: safeMasterCopy.address,
                config: safeConfig
            },
            safeManager: {
                address: safeManager.address,
                constructorArgs: [safeAddress]
            }
        };

        // 保存到文件
        const fs = require("fs");
        fs.writeFileSync(
            "gnosis-safe-deployment.json",
            JSON.stringify(deploymentInfo, null, 2)
        );
        console.log("\n部署信息已保存到 gnosis-safe-deployment.json");

        // 6. 验证部署
        console.log("\n=== 部署验证 ===");
        console.log("Safe地址:", safeAddress);
        console.log("SafeManager地址:", safeManager.address);
        
        // 验证Safe配置
        const safeContract = Safe.attach(safeAddress);
        const safeOwners = await safeContract.getOwners();
        const safeThreshold = await safeContract.getThreshold();
        
        console.log("Safe所有者数量:", safeOwners.length);
        console.log("Safe阈值:", safeThreshold.toString());
        
        // 验证SafeManager
        const managerSafeAddress = await safeManager.safeAddress();
        console.log("SafeManager中的Safe地址:", managerSafeAddress);

        console.log("\nGnosis Safe部署完成！");

        // 7. 输出后续步骤
        console.log("\n=== 后续步骤 ===");
        console.log("1. 在Gnosis Safe Web界面添加Safe地址:", safeAddress);
        console.log("2. 配置所有者钱包和阈值");
        console.log("3. 测试Safe功能");
        console.log("4. 集成到业务合约中");

    } catch (error) {
        console.error("部署过程中发生错误:", error);
        process.exit(1);
    }
}

// 运行部署脚本
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
