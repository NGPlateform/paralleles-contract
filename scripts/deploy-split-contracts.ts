import { ethers } from "hardhat";

async function main() {
  console.log("开始部署拆分后的合约...");

  // 获取部署账户
  const [deployer] = await ethers.getSigners();
  console.log("部署账户:", deployer.address);

  // 配置参数
  const owners = [
    "0x843076428Df85c8F7704a2Be73B0E1b1D5799D4d",
    "0xc4d97570A90096e9f8e23c58A1E7F528fDAa45e7",
    "0xac3D7D1CeDa1c6B4f25B25991f7401D441E13340",
  ];
  
  const foundationAddr = "0xDD120c441ED22daC885C9167eaeFFA13522b4644";
  const pancakeRouter = "0x10ED43C718714eb63d5aA57B78B54704E256024E"; // BSC主网PancakeSwap路由
  const initialAPY = 1000; // 10% APY (1000基点)

  console.log("配置参数:");
  console.log("- 所有者数量:", owners.length);
  console.log("- 基金会地址:", foundationAddr);
  console.log("- PancakeSwap路由:", pancakeRouter);
  console.log("- 初始APY:", initialAPY / 100, "%");

  try {
    // 1. 部署Meshes合约
    console.log("\n1. 部署Meshes合约...");
    const Meshes = await ethers.getContractFactory("Meshes");
    const meshes = await Meshes.deploy(owners, foundationAddr, pancakeRouter);
    await meshes.deployed();
    console.log("Meshes合约已部署到:", meshes.address);

    // 2. 部署Reward合约
    console.log("\n2. 部署Reward合约...");
    const Reward = await ethers.getContractFactory("Reward");
    const reward = await Reward.deploy(owners, meshes.address, foundationAddr);
    await reward.deployed();
    console.log("Reward合约已部署到:", reward.address);

    // 3. 部署Stake合约
    console.log("\n3. 部署Stake合约...");
    const Stake = await ethers.getContractFactory("Stake");
    const stake = await Stake.deploy(owners, meshes.address, foundationAddr, initialAPY);
    await stake.deployed();
    console.log("Stake合约已部署到:", stake.address);

    // 4. 输出部署结果
    console.log("\n=== 部署完成 ===");
    console.log("Meshes合约:", meshes.address);
    console.log("Reward合约:", reward.address);
    console.log("Stake合约:", stake.address);

    // 5. 保存部署信息
    const deploymentInfo = {
      network: "BSC Mainnet",
      deployer: deployer.address,
      timestamp: new Date().toISOString(),
      contracts: {
        Meshes: {
          address: meshes.address,
          constructorArgs: [owners, foundationAddr, pancakeRouter]
        },
        Reward: {
          address: reward.address,
          constructorArgs: [owners, meshes.address, foundationAddr]
        },
        Stake: {
          address: stake.address,
          constructorArgs: [owners, meshes.address, foundationAddr, initialAPY]
        }
      },
      configuration: {
        owners: owners,
        foundationAddr: foundationAddr,
        pancakeRouter: pancakeRouter,
        initialAPY: initialAPY
      }
    };

    // 保存到文件
    const fs = require("fs");
    fs.writeFileSync(
      "deployment-split-contracts.json",
      JSON.stringify(deploymentInfo, null, 2)
    );
    console.log("\n部署信息已保存到 deployment-split-contracts.json");

    // 6. 验证合约状态
    console.log("\n=== 合约验证 ===");
    
    // 验证Meshes合约
    const meshTokenName = await meshes.name();
    const meshTokenSymbol = await meshes.symbol();
    console.log("Meshes代币名称:", meshTokenName);
    console.log("Meshes代币符号:", meshTokenSymbol);
    
    // 验证Reward合约
    const rewardFoundation = await reward.foundationAddr();
    const rewardMeshToken = await reward.meshToken();
    console.log("Reward基金会地址:", rewardFoundation);
    console.log("Reward代币地址:", rewardMeshToken);
    
    // 验证Stake合约
    const stakeFoundation = await stake.foundationAddr();
    const stakeMeshToken = await stake.meshToken();
    const stakeAPY = await stake.apy();
    console.log("Stake基金会地址:", stakeFoundation);
    console.log("Stake代币地址:", stakeMeshToken);
    console.log("Stake APY:", stakeAPY / 100, "%");

    console.log("\n所有合约部署和验证完成！");

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
