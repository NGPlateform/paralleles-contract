// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimpleSwap
 * @dev 简单的固定汇率兑换合约
 * 固定汇率: 1 BNB = 100 MESH
 */
contract SimpleSwap is ReentrancyGuard, Ownable {
    IERC20 public meshToken;
    
    // 固定汇率: 1 BNB = 100 MESH
    uint256 public constant BNB_TO_MESH_RATE = 100;
    uint256 public constant MESH_TO_BNB_RATE = 1; // 100 MESH = 1 BNB
    
    // 手续费 (0.3% = 3/1000)
    uint256 public constant FEE_NUMERATOR = 3;
    uint256 public constant FEE_DENOMINATOR = 1000;
    
    // 事件
    event SwapBnbToMesh(address indexed user, uint256 bnbAmount, uint256 meshAmount, uint256 fee);
    event SwapMeshToBnb(address indexed user, uint256 meshAmount, uint256 bnbAmount, uint256 fee);
    event LiquidityAdded(address indexed provider, uint256 bnbAmount, uint256 meshAmount);
    event LiquidityRemoved(address indexed provider, uint256 bnbAmount, uint256 meshAmount);
    
    constructor(address _meshToken) {
        meshToken = IERC20(_meshToken);
    }
    
    /**
     * @dev BNB兑换MESH
     * 用户发送BNB，获得MESH
     */
    function swapBnbToMesh() external payable nonReentrant {
        require(msg.value > 0, "BNB amount must be greater than 0");
        
        uint256 bnbAmount = msg.value;
        
        // 计算手续费
        uint256 fee = (bnbAmount * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 bnbAfterFee = bnbAmount - fee;
        
        // 计算可获得的MESH数量
        uint256 meshAmount = bnbAfterFee * BNB_TO_MESH_RATE;
        
        // 检查合约MESH余额
        require(meshToken.balanceOf(address(this)) >= meshAmount, "Insufficient MESH liquidity");
        
        // 转账MESH给用户
        require(meshToken.transfer(msg.sender, meshAmount), "MESH transfer failed");
        
        emit SwapBnbToMesh(msg.sender, bnbAmount, meshAmount, fee);
    }
    
    /**
     * @dev MESH兑换BNB
     * 用户发送MESH，获得BNB
     */
    function swapMeshToBnb(uint256 meshAmount) external nonReentrant {
        require(meshAmount > 0, "MESH amount must be greater than 0");
        require(meshAmount % 100 == 0, "MESH amount must be multiple of 100");
        
        // 计算可获得的BNB数量
        uint256 bnbAmount = meshAmount / BNB_TO_MESH_RATE;
        
        // 计算手续费
        uint256 fee = (bnbAmount * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 bnbAfterFee = bnbAmount - fee;
        
        // 检查合约BNB余额
        require(address(this).balance >= bnbAfterFee, "Insufficient BNB liquidity");
        
        // 从用户转入MESH
        require(meshToken.transferFrom(msg.sender, address(this), meshAmount), "MESH transfer failed");
        
        // 转账BNB给用户
        payable(msg.sender).transfer(bnbAfterFee);
        
        emit SwapMeshToBnb(msg.sender, meshAmount, bnbAmount, fee);
    }
    
    /**
     * @dev 预览BNB兑换MESH
     */
    function previewBnbToMesh(uint256 bnbAmount) external pure returns (uint256 meshAmount, uint256 fee) {
        fee = (bnbAmount * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 bnbAfterFee = bnbAmount - fee;
        meshAmount = bnbAfterFee * BNB_TO_MESH_RATE;
    }
    
    /**
     * @dev 预览MESH兑换BNB
     */
    function previewMeshToBnb(uint256 meshAmount) external pure returns (uint256 bnbAmount, uint256 fee) {
        bnbAmount = meshAmount / BNB_TO_MESH_RATE;
        fee = (bnbAmount * FEE_NUMERATOR) / FEE_DENOMINATOR;
        bnbAmount = bnbAmount - fee;
    }
    
    /**
     * @dev 添加流动性 (仅所有者)
     */
    function addLiquidity() external payable onlyOwner {
        require(msg.value > 0, "BNB amount must be greater than 0");
        emit LiquidityAdded(msg.sender, msg.value, 0);
    }
    
    /**
     * @dev 添加MESH流动性 (仅所有者)
     */
    function addMeshLiquidity(uint256 meshAmount) external onlyOwner {
        require(meshAmount > 0, "MESH amount must be greater than 0");
        require(meshToken.transferFrom(msg.sender, address(this), meshAmount), "MESH transfer failed");
        emit LiquidityAdded(msg.sender, 0, meshAmount);
    }
    
    /**
     * @dev 移除BNB流动性 (仅所有者)
     */
    function removeBnbLiquidity(uint256 bnbAmount) external onlyOwner {
        require(bnbAmount <= address(this).balance, "Insufficient BNB balance");
        payable(owner()).transfer(bnbAmount);
        emit LiquidityRemoved(owner(), bnbAmount, 0);
    }
    
    /**
     * @dev 移除MESH流动性 (仅所有者)
     */
    function removeMeshLiquidity(uint256 meshAmount) external onlyOwner {
        require(meshAmount <= meshToken.balanceOf(address(this)), "Insufficient MESH balance");
        require(meshToken.transfer(owner(), meshAmount), "MESH transfer failed");
        emit LiquidityRemoved(owner(), 0, meshAmount);
    }
    
    /**
     * @dev 获取合约余额信息
     */
    function getBalances() external view returns (uint256 bnbBalance, uint256 meshBalance) {
        bnbBalance = address(this).balance;
        meshBalance = meshToken.balanceOf(address(this));
    }
    
    /**
     * @dev 获取兑换汇率信息
     */
    function getRates() external pure returns (uint256 bnbToMesh, uint256 meshToBnb, uint256 feeRate) {
        bnbToMesh = BNB_TO_MESH_RATE;
        meshToBnb = MESH_TO_BNB_RATE;
        feeRate = (FEE_NUMERATOR * 100) / FEE_DENOMINATOR; // 返回百分比形式
    }
    
    /**
     * @dev 紧急提取函数 (仅所有者)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 bnbBalance = address(this).balance;
        uint256 meshBalance = meshToken.balanceOf(address(this));
        
        if (bnbBalance > 0) {
            payable(owner()).transfer(bnbBalance);
        }
        
        if (meshBalance > 0) {
            meshToken.transfer(owner(), meshBalance);
        }
    }
    
    // 接收BNB的fallback函数
    receive() external payable {
        // 可以接收BNB，但不执行兑换
    }
}
