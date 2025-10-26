import { ethers } from "hardhat";

async function main() {
  console.log("=== 增加 SimpleSwap 流动性 ===");
  
  // 使用水龙头私钥创建账户
  const FAUCET_PRIVATE_KEY = "0x33cbd8cb0f60a633e5e5e9c128bd4094bf3acd368761b649ea4e15424bf2e2a5";
  const provider = new ethers.providers.JsonRpcProvider("https://data-seed-prebsc-1-s1.binance.org:8545/");
  const wallet = new ethers.Wallet(FAUCET_PRIVATE_KEY, provider);
  
  // 合约地址
  const SIMPLE_SWAP_ADDRESS = "0xD01f245Afb7E026b721631Ea199a4e648208Ba96";
  const MESH_CONTRACT_ADDRESS = "0x3cbDBd062A22D178Ab7743E967835d86e9356bFd";
  
  console.log("操作账户:", wallet.address);
  console.log("SimpleSwap 合约:", SIMPLE_SWAP_ADDRESS);
  console.log("MESH 合约:", MESH_CONTRACT_ADDRESS);
  
  // 创建合约实例
  const simpleSwap = new ethers.Contract(SIMPLE_SWAP_ADDRESS, [
    "function addLiquidity() payable",
    "function addMeshLiquidity(uint256 amount)",
    "function getBalances() view returns (uint256 bnbBalance, uint256 meshBalance)",
    "function owner() view returns (address)"
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
  
  // 方法1: 直接转账 BNB
  console.log("\n=== 方法1: 直接转账 BNB ===");
  const bnbAmount = ethers.utils.parseEther("0.1"); // 0.1 tBNB
  
  if (walletBnbBalance.gte(bnbAmount)) {
    console.log("正在直接转账 0.1 tBNB 到合约...");
    
    const tx = await wallet.sendTransaction({
      to: SIMPLE_SWAP_ADDRESS,
      value: bnbAmount,
      gasLimit: 21000
    });
    
    await tx.wait();
    console.log("✅ BNB 转账成功，交易哈希:", tx.hash);
  } else {
    console.log("⚠️  钱包 BNB 余额不足");
  }
  
  // 方法2: 使用合约函数添加 BNB 流动性
  console.log("\n=== 方法2: 使用合约函数添加 BNB 流动性 ===");
  const liquidityAmount = ethers.utils.parseEther("0.05"); // 0.05 tBNB
  
  if (walletBnbBalance.gte(liquidityAmount)) {
    console.log("正在使用 addLiquidity() 添加 0.05 tBNB...");
    
    const tx = await simpleSwap.addLiquidity({
      value: liquidityAmount
    });
    
    await tx.wait();
    console.log("✅ BNB 流动性添加成功，交易哈希:", tx.hash);
  } else {
    console.log("⚠️  钱包 BNB 余额不足");
  }
  
  // 方法3: 添加 MESH 流动性（如果有 MESH 代币）
  console.log("\n=== 方法3: 添加 MESH 流动性 ===");
  const meshAmount = ethers.utils.parseEther("1000"); // 1000 MESH
  
  if (walletMeshBalance.gte(meshAmount)) {
    console.log("正在添加 1000 MESH 流动性...");
    
    // 先授权
    const approveTx = await meshes.approve(SIMPLE_SWAP_ADDRESS, meshAmount);
    await approveTx.wait();
    console.log("✅ MESH 授权成功");
    
    // 添加流动性
    const addMeshTx = await simpleSwap.addMeshLiquidity(meshAmount);
    await addMeshTx.wait();
    console.log("✅ MESH 流动性添加成功，交易哈希:", addMeshTx.hash);
  } else {
    console.log("⚠️  钱包 MESH 余额不足，无法添加 MESH 流动性");
    console.log("💡 提示: 可以通过 ClaimMesh 功能获取 MESH 代币");
  }
  
  // 检查最终状态
  console.log("\n=== 最终状态 ===");
  const [finalBnbBalance, finalMeshBalance] = await simpleSwap.getBalances();
  console.log("合约 BNB 余额:", ethers.utils.formatEther(finalBnbBalance), "tBNB");
  console.log("合约 MESH 余额:", ethers.utils.formatEther(finalMeshBalance), "MESH");
  
  console.log("\n=== 流动性增加完成 ===");
  console.log("🎉 流动性已成功增加！");
  console.log("");
  console.log("📋 总结:");
  console.log("- 直接转账: 最简单的方法，直接向合约地址发送代币");
  console.log("- 合约函数: 使用 addLiquidity() 和 addMeshLiquidity() 函数");
  console.log("- 授权机制: MESH 代币需要先 approve 授权");
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





