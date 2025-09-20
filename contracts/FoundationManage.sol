// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FoundationManage - 基金会代币管理合约
 * @dev 管理基金会代币的存储和分配，支持多级权限控制
 * 
 * 核心功能：
 * 1. 代币存储：安全存储基金会的Mesh代币
 * 2. 权限控制：支持Owner和Safe双重权限
 * 3. 自动分配：支持小额自动转账到其他合约
 * 4. 限额管理：为不同合约设置转账限额
 * 
 * 权限机制：
 * - Owner权限：合约所有者，可以设置Safe地址和批准支出者
 * - Safe权限：Gnosis Safe多签，可以执行大额转账
 * - 自动权限：批准的支出者可以在限额内自动转账
 * 
 * 安全特性：
 * - 重入保护：防止重入攻击
 * - 暂停机制：紧急情况下可暂停
 * - 访问控制：多级权限控制
 * - 限额检查：防止超额转账
 * 
 * @author Parallels Team
 * @notice 本合约实现了基金会代币的安全管理和分配系统
 */
contract FoundationManage is Ownable, ReentrancyGuard, Pausable {
    // ============ 合约地址配置 ============
    /** @dev Mesh代币合约地址（不可变） */
    IERC20 public immutable meshToken;
    
    /** @dev 多签Safe地址，作为二次权限来源 */
    address public safeAddress;

    // ============ 权限控制 ============
    /** @dev 允许的支出方（例如Rewards合约、Stake合约） */
    mapping(address => bool) public approvedSpenders;

    // ============ 自动限额配置 ============
    /**
     * @dev 小额自动划拨限额配置结构体
     * @param maxPerTx 单笔最大转账金额
     * @param maxDaily 当日累计最大转账金额
     * @param usedToday 当日已使用金额
     * @param dayIndex 记录usedToday对应的天索引
     * @param enabled 是否启用自动转账
     */
    struct AutoLimit {
        uint256 maxPerTx;     // 单笔最大转账金额
        uint256 maxDaily;     // 当日累计最大转账金额
        uint256 usedToday;    // 当日已使用金额
        uint256 dayIndex;     // 记录usedToday对应的天索引
        bool enabled;         // 是否启用自动转账
    }
    
    /** @dev 支出方自动限额配置：支出方地址 => 限额配置 */
    mapping(address => AutoLimit) public autoLimits;

    // ============ 事件定义 ============
    /** @dev Safe地址更新事件：当Safe地址变更时触发 */
    event SafeUpdated(address indexed oldSafe, address indexed newSafe);
    
    /** @dev 支出方批准事件：当支出方被批准或取消批准时触发 */
    event SpenderApproved(address indexed spender, bool approved);
    
    /** @dev 转账执行事件：当代币转账执行时触发 */
    event TransferExecuted(address indexed to, uint256 amount);
    
    /** @dev 自动限额更新事件：当自动限额配置更新时触发 */
    event AutoLimitUpdated(address indexed spender, uint256 maxPerTx, uint256 maxDaily, bool enabled);

    modifier onlySafe() {
        require(msg.sender == safeAddress || msg.sender == owner(), "FoundationManage: not authorized");
        _;
    }

    constructor(address _meshToken, address _safe) {
        require(_meshToken != address(0), "FoundationManage: invalid token");
        require(_safe != address(0), "FoundationManage: invalid safe");
        meshToken = IERC20(_meshToken);
        safeAddress = _safe;
    }

    function setSafe(address _newSafe) external onlyOwner {
        require(_newSafe != address(0), "FoundationManage: invalid safe");
        address old = safeAddress;
        safeAddress = _newSafe;
        emit SafeUpdated(old, _newSafe);
    }

    function setSpender(address spender, bool approved) external onlyOwner {
        approvedSpenders[spender] = approved;
        emit SpenderApproved(spender, approved);
    }

    function setAutoLimit(address spender, uint256 maxPerTx, uint256 maxDaily, bool enabled) external onlyOwner {
        AutoLimit storage lim = autoLimits[spender];
        lim.maxPerTx = maxPerTx;
        lim.maxDaily = maxDaily;
        lim.enabled = enabled;
        emit AutoLimitUpdated(spender, maxPerTx, maxDaily, enabled);
    }

    // Rewards 合约提出补充申请后，由 Safe 调用执行
    function transferTo(address to, uint256 amount) external onlySafe nonReentrant whenNotPaused {
        require(to != address(0), "FoundationManage: invalid to");
        require(amount > 0, "FoundationManage: zero amount");
        require(meshToken.balanceOf(address(this)) >= amount, "FoundationManage: insufficient");
        require(approvedSpenders[to], "FoundationManage: to not approved");
        require(meshToken.transfer(to, amount), "ERC20 transfer failed");
        emit TransferExecuted(to, amount);
    }

    // 受限自动划拨：由已批准的 spender 自行触发，用于“小额自动化”，不经 Safe
    function autoTransferTo(address to, uint256 amount) external nonReentrant whenNotPaused {
        require(to != address(0), "FoundationManage: invalid to");
        require(amount > 0, "FoundationManage: zero amount");
        require(approvedSpenders[to], "FoundationManage: to not approved");
        AutoLimit storage lim = autoLimits[msg.sender];
        require(lim.enabled, "FoundationManage: auto limit disabled");
        require(amount <= lim.maxPerTx, "FoundationManage: exceeds per-tx limit");
        uint256 day = block.timestamp / 1 days;
        if (lim.dayIndex != day) {
            lim.dayIndex = day;
            lim.usedToday = 0;
        }
        require(lim.usedToday + amount <= lim.maxDaily, "FoundationManage: exceeds daily limit");
        require(meshToken.balanceOf(address(this)) >= amount, "FoundationManage: insufficient");
        lim.usedToday += amount;
        require(meshToken.transfer(to, amount), "ERC20 transfer failed");
        emit TransferExecuted(to, amount);
    }

    // 允许 Safe 发起对某个 spender 的一次性划拨
    function transferFor(address spender, address to, uint256 amount) external onlySafe nonReentrant whenNotPaused {
        require(approvedSpenders[spender], "FoundationManage: spender not approved");
        require(to != address(0) && amount > 0, "FoundationManage: invalid params");
        require(meshToken.balanceOf(address(this)) >= amount, "FoundationManage: insufficient");
        require(meshToken.transfer(to, amount), "ERC20 transfer failed");
        emit TransferExecuted(to, amount);
    }
}



