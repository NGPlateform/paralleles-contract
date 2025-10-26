import { ethers } from "hardhat";

async function main() {
  console.log("=== 开始部署 SimpleSwap 合约到 BSC Testnet ===");
  
  // 使用水龙头私钥创建部署者账户
  const FAUCET_PRIVATE_KEY = "0x33cbd8cb0f60a633e5e5e9c128bd4094bf3acd368761b649ea4e15424bf2e2a5";
  const provider = new ethers.providers.JsonRpcProvider("https://data-seed-prebsc-1-s1.binance.org:8545/");
  const deployer = new ethers.Wallet(FAUCET_PRIVATE_KEY, provider);
  
  console.log("水龙头地址:", deployer.address);
  
  // 检查水龙头余额
  let balance = await deployer.getBalance();
  console.log("水龙头余额:", ethers.utils.formatEther(balance), "tBNB");
  
  // 如果余额不足，提示用户
  if (balance.lt(ethers.utils.parseEther("0.01"))) {
    console.log("\n⚠️  水龙头余额不足，需要获取测试币");
    console.log("请访问以下水龙头获取 tBNB:");
    console.log("1. https://testnet.bnbchain.org/faucet-smart");
    console.log("2. 输入地址:", deployer.address);
    console.log("3. 获取 0.1 tBNB 测试币");
    console.log("\n获取测试币后，请重新运行此脚本");
    return;
  }
  
  console.log("✅ 余额充足，开始部署...");
  
  // 使用现有的 MESH 合约地址
  const MESH_CONTRACT_ADDRESS = "0x3cbDBd062A22D178Ab7743E967835d86e9356bFd";
  console.log("\n=== 使用现有 MESH 合约 ===");
  console.log("MESH 合约地址:", MESH_CONTRACT_ADDRESS);
  
  // 验证 MESH 合约
  const meshes = new ethers.Contract(MESH_CONTRACT_ADDRESS, [
    "function name() view returns (string)",
    "function symbol() view returns (string)",
    "function decimals() view returns (uint8)",
    "function totalSupply() view returns (uint256)",
    "function balanceOf(address) view returns (uint256)",
    "function approve(address,uint256) returns (bool)",
    "function transfer(address,uint256) returns (bool)",
    "function transferFrom(address,address,uint256) returns (bool)"
  ], deployer);
  
  try {
    const name = await meshes.name();
    const symbol = await meshes.symbol();
    const decimals = await meshes.decimals();
    const totalSupply = await meshes.totalSupply();
    
    console.log("✅ MESH 合约验证成功!");
    console.log("代币名称:", name);
    console.log("代币符号:", symbol);
    console.log("小数位数:", decimals);
    console.log("总供应量:", ethers.utils.formatEther(totalSupply));
  } catch (error) {
    console.error("❌ MESH 合约验证失败:", error.message);
    return;
  }
  
  // 第二步：部署 SimpleSwap 合约
  console.log("\n=== 步骤 2: 部署 SimpleSwap 合约 ===");
  const SimpleSwap = await ethers.getContractFactory("SimpleSwap");
  const simpleSwap = await SimpleSwap.connect(deployer).deploy(MESH_CONTRACT_ADDRESS);
  await simpleSwap.deployed();
  
  console.log("✅ SimpleSwap 合约部署成功!");
  console.log("合约地址:", simpleSwap.address);
  
  // 验证 SimpleSwap 合约
  const meshToken = await simpleSwap.meshToken();
  const bnbToMeshRate = await simpleSwap.BNB_TO_MESH_RATE();
  console.log("MESH 代币地址:", meshToken);
  console.log("BNB 到 MESH 汇率:", bnbToMeshRate.toString());
  
  // 第三步：添加流动性
  console.log("\n=== 步骤 3: 添加流动性 ===");
  
  // 给 SimpleSwap 合约添加一些 BNB 流动性
  const liquidityAmount = ethers.utils.parseEther("0.1"); // 0.1 BNB
  console.log("正在添加 0.1 BNB 流动性...");
  
  const addLiquidityTx = await simpleSwap.connect(deployer).addLiquidity({
    value: liquidityAmount
  });
  await addLiquidityTx.wait();
  console.log("✅ BNB 流动性添加成功");
  
  // 给 SimpleSwap 合约添加一些 MESH 流动性
  const meshLiquidityAmount = ethers.utils.parseEther("10000"); // 10,000 MESH
  console.log("正在添加 10,000 MESH 流动性...");
  
  // 首先需要给 SimpleSwap 合约授权 MESH 代币
  const approveTx = await meshes.connect(deployer).approve(simpleSwap.address, meshLiquidityAmount);
  await approveTx.wait();
  console.log("✅ MESH 代币授权成功");
  
  const addMeshLiquidityTx = await simpleSwap.connect(deployer).addMeshLiquidity(meshLiquidityAmount);
  await addMeshLiquidityTx.wait();
  console.log("✅ MESH 流动性添加成功");
  
  // 第四步：验证最终状态
  console.log("\n=== 步骤 4: 验证最终状态 ===");
  
  const [bnbBalance, meshBalance] = await simpleSwap.getBalances();
  console.log("SimpleSwap 合约 BNB 余额:", ethers.utils.formatEther(bnbBalance));
  console.log("SimpleSwap 合约 MESH 余额:", ethers.utils.formatEther(meshBalance));
  
  const deployerMeshBalance = await meshes.balanceOf(deployer.address);
  console.log("部署者 MESH 余额:", ethers.utils.formatEther(deployerMeshBalance));
  
  // 保存部署信息
  const deploymentInfo = {
    network: "bsctest",
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      meshes: {
        name: "Meshes",
        address: MESH_CONTRACT_ADDRESS,
        note: "使用现有合约",
      },
      simpleSwap: {
        name: "SimpleSwap",
        address: simpleSwap.address,
        transactionHash: simpleSwap.deployTransaction.hash,
        meshToken: MESH_CONTRACT_ADDRESS,
      }
    },
    liquidity: {
      bnb: ethers.utils.formatEther(bnbBalance),
      mesh: ethers.utils.formatEther(meshBalance),
    }
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
  
  const filePath = path.join(deploymentsDir, 'complete-deployment.json');
  fs.writeFileSync(filePath, JSON.stringify(deploymentInfo, null, 2));
  console.log("部署信息已保存到:", filePath);
  
  console.log("\n=== 部署完成 ===");
  console.log("🎉 SimpleSwap 合约部署成功!");
  console.log("");
  console.log("📋 合约地址:");
  console.log(`MESH 代币: ${MESH_CONTRACT_ADDRESS} (现有合约)`);
  console.log(`SimpleSwap: ${simpleSwap.address} (新部署)`);
  console.log("");
  console.log("🔗 BSC Testnet 浏览器:");
  console.log(`MESH: https://testnet.bscscan.com/address/${MESH_CONTRACT_ADDRESS}`);
  console.log(`SimpleSwap: https://testnet.bscscan.com/address/${simpleSwap.address}`);
  console.log("");
  console.log("⚙️  应用配置更新:");
  console.log("请将以下地址添加到应用配置中:");
  console.log(`meshes: '${MESH_CONTRACT_ADDRESS}' (已存在)`);
  console.log(`simpleSwap: '${simpleSwap.address}' (新增)`);
  console.log("");
  console.log("🧪 测试兑换:");
  console.log("1. 使用 SimpleSwap 合约进行 BNB ↔ MESH 兑换");
  console.log("2. 测试预览功能");
  console.log("3. 验证流动性池状态");
  console.log("");
  console.log("💡 注意事项:");
  console.log("- 使用了现有的 MESH 合约，无需重新部署");
  console.log("- 水龙头账户作为部署者和流动性提供者");
  console.log("- 已添加 0.1 BNB + 10,000 MESH 初始流动性");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("部署失败:", error);
    process.exit(1);
  });
