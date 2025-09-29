import { ethers } from "hardhat";

async function main() {
  console.log("=== 开始部署 SimpleSwap 合约到 BSC Testnet ===");
  
  // 获取部署者账户
  const [deployer] = await ethers.getSigners();
  console.log("部署者地址:", deployer.address);
  
  // 检查部署者余额
  const balance = await deployer.getBalance();
  console.log("部署者余额:", ethers.utils.formatEther(balance), "BNB");
  
  if (balance.lt(ethers.utils.parseEther("0.01"))) {
    throw new Error("部署者余额不足，至少需要 0.01 BNB");
  }
  
  // BSC Testnet 上的 MESH 代币地址
  // 注意：这里需要先确认 BSC Testnet 上是否有 MESH 代币
  // 如果没有，需要先部署 MESH 代币合约
  const MESH_TOKEN_ADDRESS = "0x0000000000000000000000000000000000000000"; // 待设置
  
  console.log("MESH 代币地址:", MESH_TOKEN_ADDRESS);
  
  if (MESH_TOKEN_ADDRESS === "0x0000000000000000000000000000000000000000") {
    console.log("⚠️  警告: MESH 代币地址未设置，需要先部署 MESH 代币合约");
    console.log("请先运行: npx hardhat run scripts/deploy-meshes.ts --network bsctest");
    return;
  }
  
  // 部署 SimpleSwap 合约
  console.log("正在部署 SimpleSwap 合约...");
  const SimpleSwap = await ethers.getContractFactory("SimpleSwap");
  const simpleSwap = await SimpleSwap.deploy(MESH_TOKEN_ADDRESS);
  
  console.log("等待合约部署确认...");
  await simpleSwap.deployed();
  
  console.log("✅ SimpleSwap 合约部署成功!");
  console.log("合约地址:", simpleSwap.address);
  console.log("交易哈希:", simpleSwap.deployTransaction.hash);
  
  // 验证合约部署
  console.log("\n=== 验证合约部署 ===");
  try {
    const meshToken = await simpleSwap.meshToken();
    console.log("MESH 代币地址:", meshToken);
    
    const bnbToMeshRate = await simpleSwap.BNB_TO_MESH_RATE();
    console.log("BNB 到 MESH 汇率:", bnbToMeshRate.toString());
    
    const [bnbBalance, meshBalance] = await simpleSwap.getBalances();
    console.log("合约 BNB 余额:", ethers.utils.formatEther(bnbBalance));
    console.log("合约 MESH 余额:", ethers.utils.formatEther(meshBalance));
    
    console.log("✅ 合约验证成功!");
  } catch (error) {
    console.error("❌ 合约验证失败:", error);
  }
  
  // 保存部署信息
  const deploymentInfo = {
    network: "bsctest",
    contractName: "SimpleSwap",
    address: simpleSwap.address,
    deployer: deployer.address,
    meshToken: MESH_TOKEN_ADDRESS,
    transactionHash: simpleSwap.deployTransaction.hash,
    blockNumber: simpleSwap.deployTransaction.blockNumber,
    timestamp: new Date().toISOString(),
    gasUsed: simpleSwap.deployTransaction.gasLimit?.toString(),
  };
  
  console.log("\n=== 部署信息 ===");
  console.log(JSON.stringify(deploymentInfo, null, 2));
  
  // 保存到文件
  const fs = require('fs');
  const path = require('path');
  const deploymentsDir = path.join(__dirname, '../deployments/bsctest');
  
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }
  
  const filePath = path.join(deploymentsDir, 'SimpleSwap.json');
  fs.writeFileSync(filePath, JSON.stringify(deploymentInfo, null, 2));
  console.log("部署信息已保存到:", filePath);
  
  console.log("\n=== 部署完成 ===");
  console.log("请将以下地址添加到应用配置中:");
  console.log(`simpleSwap: '${simpleSwap.address}'`);
  
  // 如果需要添加流动性，可以在这里调用
  console.log("\n=== 后续步骤 ===");
  console.log("1. 向合约添加 BNB 流动性: simpleSwap.addLiquidity()");
  console.log("2. 向合约添加 MESH 流动性: simpleSwap.addMeshLiquidity(amount)");
  console.log("3. 更新应用配置中的合约地址");
  console.log("4. 测试兑换功能");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("部署失败:", error);
    process.exit(1);
  });


