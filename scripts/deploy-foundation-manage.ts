import { ethers } from "hardhat";

async function main() {
  console.log("=== 开始部署 FoundationManage 合约到 BSC Testnet ===");
  
  // 使用水龙头私钥创建部署者账户
  const FAUCET_PRIVATE_KEY = "0x33cbd8cb0f60a633e5e5e9c128bd4094bf3acd368761b649ea4e15424bf2e2a5";
  const provider = new ethers.providers.JsonRpcProvider("https://data-seed-prebsc-1-s1.binance.org:8545/");
  const deployer = new ethers.Wallet(FAUCET_PRIVATE_KEY, provider);
  
  console.log("部署者地址:", deployer.address);
  
  // 检查余额
  let balance = await deployer.getBalance();
  console.log("部署者余额:", ethers.utils.formatEther(balance), "tBNB");
  
  if (balance.lt(ethers.utils.parseEther("0.01"))) {
    console.log("\n⚠️  余额不足，需要获取测试币");
    console.log("请访问: https://testnet.bnbchain.org/faucet-smart");
    console.log("输入地址:", deployer.address);
    return;
  }
  
  console.log("✅ 余额充足，开始部署...");
  
  // 部署FoundationManage合约
  // 使用部署者地址作为临时的governanceSafe地址
  const governanceSafeAddress = deployer.address;
  
  console.log("\n=== 部署 FoundationManage 合约 ===");
  console.log("GovernanceSafe地址:", governanceSafeAddress);
  
  const FoundationManage = await ethers.getContractFactory("FoundationManage");
  const foundationManage = await FoundationManage.connect(deployer).deploy(governanceSafeAddress);
  await foundationManage.deployed();
  
  console.log("✅ FoundationManage合约部署完成!");
  console.log("合约地址:", foundationManage.address);
  
  // 验证部署
  try {
    const owner = await foundationManage.owner();
    console.log("合约Owner:", owner);
    console.log("部署者地址:", deployer.address);
    console.log("Owner验证:", owner.toLowerCase() === deployer.address.toLowerCase() ? "✅ 正确" : "❌ 错误");
  } catch (error) {
    console.log("❌ 验证失败:", error);
  }
  
  // 保存部署信息
  const deploymentInfo = {
    network: "bsctest",
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      foundationManage: {
        name: "FoundationManage",
        address: foundationManage.address,
        transactionHash: foundationManage.deployTransaction.hash,
        governanceSafe: governanceSafeAddress
      }
    }
  };
  
  const fs = require('fs');
  const path = require('path');
  const outputPath = path.join(__dirname, '../deployments/bsctest/FoundationManage.json');
  
  // 确保目录存在
  const outputDir = path.dirname(outputPath);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  
  fs.writeFileSync(outputPath, JSON.stringify(deploymentInfo, null, 2));
  console.log("✅ 部署信息已保存到:", outputPath);
  
  console.log("\n🎉 FoundationManage 合约部署完成!");
  console.log("请将以下地址更新到 management 项目中:");
  console.log(`BSC Testnet: ${foundationManage.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("部署失败:", error);
    process.exit(1);
  });



