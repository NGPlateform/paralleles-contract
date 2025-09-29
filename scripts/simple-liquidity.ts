import { ethers } from "hardhat";

async function main() {
  console.log("=== SimpleSwap 流动性管理 ===");
  
  // 使用水龙头私钥创建账户
  const FAUCET_PRIVATE_KEY = "0x33cbd8cb0f60a633e5e5e9c128bd4094bf3acd368761b649ea4e15424bf2e2a5";
  const provider = new ethers.providers.JsonRpcProvider("https://data-seed-prebsc-1-s1.binance.org:8545/");
  const wallet = new ethers.Wallet(FAUCET_PRIVATE_KEY, provider);
  
  // 合约地址
  const SIMPLE_SWAP_ADDRESS = "0x7f193eBAFdf17959FFee32b5F601FEEc3759c9EB";
  const MESH_CONTRACT_ADDRESS = "0x58d740f45Ec1043071A0fFF004176377188180C6";
  
  console.log("操作账户:", wallet.address);
  console.log("SimpleSwap 合约:", SIMPLE_SWAP_ADDRESS);
  
  // 创建合约实例
  const simpleSwap = new ethers.Contract(SIMPLE_SWAP_ADDRESS, [
    "function addLiquidity() payable",
    "function addMeshLiquidity(uint256 amount)",
    "function getBalances() view returns (uint256 bnbBalance, uint256 meshBalance)",
    "function getRates() view returns (uint256 bnbToMesh, uint256 meshToBnb, uint256 feeRate)"
  ], wallet);
  
  const meshes = new ethers.Contract(MESH_CONTRACT_ADDRESS, [
    "function balanceOf(address) view returns (uint256)",
    "function approve(address,uint256) returns (bool)",
    "function transfer(address,uint256) returns (bool)"
  ], wallet);
  
  // 检查当前状态
  console.log("\n=== 当前状态 ===");
  const [bnbBalance, meshBalance] = await simpleSwap.getBalances();
  console.log("合约 BNB 余额:", ethers.utils.formatEther(bnbBalance), "tBNB");
  console.log("合约 MESH 余额:", ethers.utils.formatEther(meshBalance), "MESH");
  
  const walletBnbBalance = await wallet.getBalance();
  const walletMeshBalance = await meshes.balanceOf(wallet.address);
  console.log("钱包 BNB 余额:", ethers.utils.formatEther(walletBnbBalance), "tBNB");
  console.log("钱包 MESH 余额:", ethers.utils.formatEther(walletMeshBalance), "MESH");
  
  // 检查汇率
  const [bnbToMeshRate, meshToBnbRate, feeRate] = await simpleSwap.getRates();
  console.log("\n=== 汇率信息 ===");
  console.log("BNB → MESH 汇率:", bnbToMeshRate.toString());
  console.log("MESH → BNB 汇率:", ethers.utils.formatEther(meshToBnbRate));
  console.log("手续费率:", feeRate.toString(), "bps");
  
  // 添加 BNB 流动性
  console.log("\n=== 添加 BNB 流动性 ===");
  const bnbAmount = ethers.utils.parseEther("0.05"); // 0.05 tBNB
  
  if (walletBnbBalance.gte(bnbAmount)) {
    console.log("正在添加 0.05 tBNB 流动性...");
    
    try {
      const tx = await simpleSwap.addLiquidity({
        value: bnbAmount,
        gasLimit: 100000
      });
      
      await tx.wait();
      console.log("✅ BNB 流动性添加成功，交易哈希:", tx.hash);
    } catch (error) {
      console.log("❌ BNB 流动性添加失败:", error.message);
    }
  } else {
    console.log("⚠️  钱包 BNB 余额不足");
  }
  
  // 检查 MESH 余额并添加流动性
  console.log("\n=== 添加 MESH 流动性 ===");
  const meshAmount = ethers.utils.parseEther("100"); // 100 MESH
  
  if (walletMeshBalance.gte(meshAmount)) {
    console.log("正在添加 100 MESH 流动性...");
    
    try {
      // 先授权
      const approveTx = await meshes.approve(SIMPLE_SWAP_ADDRESS, meshAmount);
      await approveTx.wait();
      console.log("✅ MESH 授权成功");
      
      // 添加流动性
      const addMeshTx = await simpleSwap.addMeshLiquidity(meshAmount);
      await addMeshTx.wait();
      console.log("✅ MESH 流动性添加成功，交易哈希:", addMeshTx.hash);
    } catch (error) {
      console.log("❌ MESH 流动性添加失败:", error.message);
    }
  } else {
    console.log("⚠️  钱包 MESH 余额不足，无法添加 MESH 流动性");
    console.log("💡 提示: 可以通过 ClaimMesh 功能获取 MESH 代币");
  }
  
  // 检查最终状态
  console.log("\n=== 最终状态 ===");
  const [finalBnbBalance, finalMeshBalance] = await simpleSwap.getBalances();
  console.log("合约 BNB 余额:", ethers.utils.formatEther(finalBnbBalance), "tBNB");
  console.log("合约 MESH 余额:", ethers.utils.formatEther(finalMeshBalance), "MESH");
  
  console.log("\n=== 流动性管理完成 ===");
  console.log("🎉 流动性管理操作完成！");
  console.log("");
  console.log("📋 总结:");
  console.log("- 使用合约函数是增加流动性的正确方法");
  console.log("- 直接转账可能失败，因为合约可能没有 receive() 函数");
  console.log("- MESH 代币需要先 approve 授权");
  console.log("- 建议保持合理的 BNB:MESH 比例");
  console.log("");
  console.log("🔗 查看合约状态:");
  console.log("https://testnet.bscscan.com/address/" + SIMPLE_SWAP_ADDRESS);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("操作失败:", error);
    process.exit(1);
  });


