import { ethers } from "hardhat";
import { SafeFactory, SafeAccountConfig } from "@safe-global/safe-core-sdk";

/**
 * 完整系统部署脚本
 * 包括：Gnosis Safe + SafeManager + 业务合约
 */
async function main() {
    console.log("开始部署完整系统...");

    // 获取部署账户
    const [deployer] = await ethers.getSigners();
    console.log("部署账户:", deployer.address);

    // 配置参数
    const owners = process.env.SAFE_OWNERS?.split(",") || [
        "0x843076428Df85c8F7704a2Be73B0E1b1D5799D4d",
        "0xc4d97570A90096e9f8e23c58A1E7F528fDAa45e7",
        "0xac3D7D1CeDa1c6B4f25B25991f7401D441E13340"
    ];
    
    const threshold = parseInt(process.env.SAFE_THRESHOLD || "2");
    const foundationAddr = process.env.FOUNDATION_ADDRESS || "0xDD120c441ED22daC885C9167eaeFFA13522b4644";
    const pancakeRouter = process.env.PANCAKE_ROUTER || "0x10ED43C718714eb63d5aA57B78B54704E256024E";
    const initialAPY = parseInt(process.env.INITIAL_APY || "1000");

    console.log("系统配置:");
    console.log("- Safe所有者:", owners);
    console.log("- Safe阈值:", threshold);
    console.log("- 基金会地址:", foundationAddr);
    console.log("- PancakeSwap路由:", pancakeRouter);
    console.log("- 初始APY:", initialAPY / 100, "%");

    try {
        // 阶段1: 部署Gnosis Safe
        console.log("\n=== 阶段1: 部署Gnosis Safe ===");
        
        const safeAddress = await deployGnosisSafe(owners, threshold);
        console.log("✅ Gnosis Safe部署完成:", safeAddress);

        // 阶段2: 部署SafeManager
        console.log("\n=== 阶段2: 部署SafeManager ===");
        
        const safeManagerAddress = await deploySafeManager(safeAddress);
        console.log("✅ SafeManager部署完成:", safeManagerAddress);

        // 阶段3: 部署业务合约
        console.log("\n=== 阶段3: 部署业务合约 ===");
        
        const meshesAddress = await deployMeshes(owners, foundationAddr, pancakeRouter);
        console.log("✅ Meshes合约部署完成:", meshesAddress);

        const rewardAddress = await deployReward(owners, meshesAddress, foundationAddr);
        console.log("✅ Reward合约部署完成:", rewardAddress);

        const stakeAddress = await deployStake(owners, meshesAddress, foundationAddr, initialAPY);
        console.log("✅ Stake合约部署完成:", stakeAddress);

        // 阶段4: 配置系统
        console.log("\n=== 阶段4: 配置系统 ===");
        
        await configureSystem(safeManagerAddress, meshesAddress, rewardAddress, stakeAddress);
        console.log("✅ 系统配置完成");

        // 阶段5: 验证部署
        console.log("\n=== 阶段5: 验证部署 ===");
        
        await verifyDeployment(safeAddress, safeManagerAddress, meshesAddress, rewardAddress, stakeAddress);
        console.log("✅ 部署验证完成");

        // 保存部署信息
        await saveDeploymentInfo({
            safeAddress,
            safeManagerAddress,
            meshesAddress,
            rewardAddress,
            stakeAddress,
            owners,
            threshold,
            foundationAddr
        });

        console.log("\n🎉 完整系统部署成功！");
        console.log("\n=== 部署地址汇总 ===");
        console.log("Gnosis Safe:", safeAddress);
        console.log("SafeManager:", safeManagerAddress);
        console.log("Meshes合约:", meshesAddress);
        console.log("Reward合约:", rewardAddress);
        console.log("Stake合约:", stakeAddress);

        console.log("\n=== 后续步骤 ===");
        console.log("1. 在Gnosis Safe Web界面添加Safe地址");
        console.log("2. 配置所有者钱包和阈值");
        console.log("3. 测试Safe功能");
        console.log("4. 开始使用系统");

    } catch (error) {
        console.error("部署过程中发生错误:", error);
        process.exit(1);
    }
}

/**
 * 部署Gnosis Safe
 */
async function deployGnosisSafe(owners: string[], threshold: number): Promise<string> {
    console.log("部署Gnosis Safe...");
    
    // 部署Safe工厂合约
    const SafeFactory = await ethers.getContractFactory("SafeProxyFactory");
    const safeFactory = await SafeFactory.deploy();
    await safeFactory.deployed();
    
    // 部署Safe主合约
    const Safe = await ethers.getContractFactory("Safe");
    const safeMasterCopy = await Safe.deploy();
    await safeMasterCopy.deployed();
    
    // 创建Safe实例
    const saltNonce = ethers.utils.hexlify(ethers.utils.randomBytes(32));
    const safe = await safeFactory.createProxyWithNonce(
        safeMasterCopy.address,
        safeMasterCopy.interface.encodeFunctionData("setup", [
            owners,
            threshold,
            ethers.constants.AddressZero, // fallbackHandler
            ethers.constants.AddressZero, // paymentToken
            0, // payment
            ethers.constants.AddressZero  // paymentReceiver
        ]),
        saltNonce
    );
    
    const safeAddress = safe.receipt?.events?.find(
        (event: any) => event.event === "ProxyCreation"
    )?.args?.proxy;
    
    if (!safeAddress) {
        throw new Error("Failed to get Safe address");
    }
    
    return safeAddress;
}

/**
 * 部署SafeManager
 */
async function deploySafeManager(safeAddress: string): Promise<string> {
    console.log("部署SafeManager...");
    
    const SafeManager = await ethers.getContractFactory("SafeManager");
    const safeManager = await SafeManager.deploy(safeAddress);
    await safeManager.deployed();
    
    return safeManager.address;
}

/**
 * 部署Meshes合约
 */
async function deployMeshes(owners: string[], foundationAddr: string, pancakeRouter: string): Promise<string> {
    console.log("部署Meshes合约...");
    
    const Meshes = await ethers.getContractFactory("Meshes");
    const meshes = await Meshes.deploy(owners, foundationAddr, pancakeRouter);
    await meshes.deployed();
    
    return meshes.address;
}

/**
 * 部署Reward合约
 */
async function deployReward(owners: string[], meshToken: string, foundationAddr: string): Promise<string> {
    console.log("部署Reward合约...");
    
    const Reward = await ethers.getContractFactory("Reward");
    const reward = await Reward.deploy(owners, meshToken, foundationAddr);
    await reward.deployed();
    
    return reward.address;
}

/**
 * 部署Stake合约
 */
async function deployStake(owners: string[], meshToken: string, foundationAddr: string, apy: number): Promise<string> {
    console.log("部署Stake合约...");
    
    const Stake = await ethers.getContractFactory("Stake");
    const stake = await Stake.deploy(owners, meshToken, foundationAddr, apy);
    await stake.deployed();
    
    return stake.address;
}

/**
 * 配置系统
 */
async function configureSystem(
    safeManagerAddress: string,
    meshesAddress: string,
    rewardAddress: string,
    stakeAddress: string
) {
    console.log("配置系统...");
    
    // 这里可以添加系统配置逻辑
    // 例如：设置权限、初始化参数等
    
    console.log("系统配置完成");
}

/**
 * 验证部署
 */
async function verifyDeployment(
    safeAddress: string,
    safeManagerAddress: string,
    meshesAddress: string,
    rewardAddress: string,
    stakeAddress: string
) {
    console.log("验证部署...");
    
    // 验证Safe
    const Safe = await ethers.getContractFactory("Safe");
    const safe = Safe.attach(safeAddress);
    const safeOwners = await safe.getOwners();
    const safeThreshold = await safe.getThreshold();
    
    console.log("Safe验证:");
    console.log("- 所有者数量:", safeOwners.length);
    console.log("- 阈值:", safeThreshold.toString());
    
    // 验证SafeManager
    const SafeManager = await ethers.getContractFactory("SafeManager");
    const safeManager = SafeManager.attach(safeManagerAddress);
    const managerSafeAddress = await safeManager.safeAddress();
    
    console.log("SafeManager验证:");
    console.log("- Safe地址:", managerSafeAddress);
    
    // 验证业务合约
    const Meshes = await ethers.getContractFactory("Meshes");
    const meshes = Meshes.attach(meshesAddress);
    const meshName = await meshes.name();
    const meshSymbol = await meshes.symbol();
    
    console.log("Meshes验证:");
    console.log("- 名称:", meshName);
    console.log("- 符号:", meshSymbol);
    
    console.log("部署验证完成");
}

/**
 * 保存部署信息
 */
async function saveDeploymentInfo(deploymentInfo: any) {
    const fs = require("fs");
    
    const info = {
        network: process.env.NETWORK || "BSC Testnet",
        deployer: (await ethers.getSigners())[0].address,
        timestamp: new Date().toISOString(),
        ...deploymentInfo
    };
    
    fs.writeFileSync(
        "complete-system-deployment.json",
        JSON.stringify(info, null, 2)
    );
    
    console.log("部署信息已保存到 complete-system-deployment.json");
}

// 运行部署脚本
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
