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
    /** @dev Mesh代币合约地址 */
    IERC20 public meshToken;
    
    /** @dev 多签Safe地址，作为二次权限来源 */
    address public safeAddress;

    // ============ 权限控制 ============
    /** @dev 收款白名单（允许作为 to 接收划拨） */
    mapping(address => bool) public approvedRecipients;
    /** @dev 发起白名单（允许作为 spender/initiator 发起拨款） */
    mapping(address => bool) public approvedInitiators;
    /** @dev 自动划拨收款白名单（仅 autoTransferTo 允许的 to） */
    mapping(address => bool) public approvedAutoRecipients;

    /** @dev 按收款地址的自动划拨限额（进一步风控） */
    struct RecipientAutoLimit {
        uint256 maxPerTx;
        uint256 maxDaily;
        uint256 usedToday;
        uint256 dayIndex;
        bool enabled;
    }
    mapping(address => RecipientAutoLimit) public autoRecipientLimits;

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
    
    /** @dev Mesh代币地址更新事件：当Mesh代币地址设置时触发 */
    event MeshTokenUpdated(address indexed meshToken);
    
    /** @dev 转账执行事件：记录调用发起者、名义发起方、收款方、金额、方式与原因ID */
    // method: 1=transferTo, 2=autoTransferTo, 3=transferFor
    event TransferExecuted(address indexed initiator, address indexed spender, address indexed to, uint256 amount, uint8 method, bytes32 reasonId);
    
    /** @dev 自动限额更新事件：当自动限额配置更新时触发 */
    event AutoLimitUpdated(address indexed spender, uint256 maxPerTx, uint256 maxDaily, bool enabled);

    // 仅限 Safe 执行（用于资金划拨）
    modifier onlySafeExec() {
        require(msg.sender == safeAddress, "FoundationManage: only Safe");
        _;
    }

    constructor(address _safe) {
        require(_safe != address(0), "FoundationManage: invalid safe");
        safeAddress = _safe;
        // meshToken 初始化为 address(0)，后续通过 setMeshToken 设置
        meshToken = IERC20(address(0));
    }

    function setSafe(address _newSafe) external onlyOwner {
        require(_newSafe != address(0), "FoundationManage: invalid safe");
        address old = safeAddress;
        safeAddress = _newSafe;
        emit SafeUpdated(old, _newSafe);
    }

    /**
     * @dev 设置Mesh代币地址（仅限Owner，且只能设置一次）
     * @param _meshToken Mesh代币合约地址
     * 
     * 功能说明：
     * - 设置Mesh代币合约地址
     * - 只能设置一次，防止意外修改
     * - 用于解决部署时的循环依赖问题
     * 
     * 安全特性：
     * - 仅限Owner调用
     * - 地址验证：不能为零地址
     * - 一次性设置：防止重复设置
     * - 事件记录：便于追踪地址设置
     */
    function setMeshToken(address _meshToken) external onlyOwner {
        require(_meshToken != address(0), "FoundationManage: invalid token");
        require(address(meshToken) == address(0), "FoundationManage: token already set");
        meshToken = IERC20(_meshToken);
        emit MeshTokenUpdated(_meshToken);
    }

    // 新接口：单独设置收款白名单
    function setRecipient(address to, bool approved) external onlyOwner {
        approvedRecipients[to] = approved;
        emit SpenderApproved(to, approved);
    }

    // 新接口：单独设置发起白名单
    function setInitiator(address spender, bool approved) external onlyOwner {
        approvedInitiators[spender] = approved;
        emit SpenderApproved(spender, approved);
    }

    // 新接口：设置自动划拨可用的收款白名单
    function setAutoRecipient(address to, bool approved) external onlyOwner {
        approvedAutoRecipients[to] = approved;
        emit SpenderApproved(to, approved);
    }

    function setAutoLimit(address spender, uint256 maxPerTx, uint256 maxDaily, bool enabled) external onlyOwner {
        AutoLimit storage lim = autoLimits[spender];
        lim.maxPerTx = maxPerTx;
        lim.maxDaily = maxDaily;
        lim.enabled = enabled;
        emit AutoLimitUpdated(spender, maxPerTx, maxDaily, enabled);
    }

    // 全局自动划拨日上限（风控断路器）。如 autoGlobalEnabled=false 则禁用自动划拨
    uint256 public globalAutoDailyMax;
    uint256 public globalAutoUsedToday;
    uint256 public globalAutoDayIndex;
    bool public autoGlobalEnabled;

    function setGlobalAutoDailyMax(uint256 maxAmount) external onlyOwner {
        globalAutoDailyMax = maxAmount;
    }

    function setGlobalAutoEnabled(bool enabled) external onlyOwner {
        autoGlobalEnabled = enabled;
    }

    // 只读白名单查询，供外部约束使用（如 Meshes 强约束设置 FoundationAddr）
    function isRecipientApproved(address to) external view returns (bool) {
        return approvedRecipients[to];
    }

    function isInitiatorApproved(address spender) external view returns (bool) {
        return approvedInitiators[spender];
    }

    function isAutoRecipientApproved(address to) external view returns (bool) {
        return approvedAutoRecipients[to];
    }

    // Rewards 合约提出补充申请后，由 Safe 调用执行
    function transferTo(address to, uint256 amount) external onlySafeExec nonReentrant whenNotPaused {
        require(to != address(0), "FoundationManage: invalid to");
        require(amount > 0, "FoundationManage: zero amount");
        require(meshToken.balanceOf(address(this)) >= amount, "FoundationManage: insufficient");
        require(approvedRecipients[to], "FoundationManage: recipient not approved");
        require(meshToken.transfer(to, amount), "ERC20 transfer failed");
        emit TransferExecuted(msg.sender, address(0), to, amount, 1, bytes32(0));
    }

    // 带原因ID的转账（Safe 执行）
    function transferToWithReason(address to, uint256 amount, bytes32 reasonId) external onlySafeExec nonReentrant whenNotPaused {
        require(to != address(0), "FoundationManage: invalid to");
        require(amount > 0, "FoundationManage: zero amount");
        require(approvedRecipients[to], "FoundationManage: recipient not approved");
        require(meshToken.balanceOf(address(this)) >= amount, "FoundationManage: insufficient");
        require(meshToken.transfer(to, amount), "ERC20 transfer failed");
        emit TransferExecuted(msg.sender, address(0), to, amount, 1, reasonId);
    }

    // 受限自动划拨：由已批准的 spender 自行触发，用于“小额自动化”，不经 Safe
    function autoTransferTo(address to, uint256 amount) external nonReentrant whenNotPaused {
        require(to != address(0), "FoundationManage: invalid to");
        require(amount > 0, "FoundationManage: zero amount");
        require(approvedAutoRecipients[to], "FoundationManage: auto recipient not approved");
        require(autoGlobalEnabled, "FoundationManage: auto disabled");
        require(approvedInitiators[msg.sender], "FoundationManage: initiator not approved");
        AutoLimit storage lim = autoLimits[msg.sender];
        require(lim.enabled, "FoundationManage: auto limit disabled");
        require(amount <= lim.maxPerTx, "FoundationManage: exceeds per-tx limit");
        uint256 day = block.timestamp / 1 days;
        if (lim.dayIndex != day) {
            lim.dayIndex = day;
            lim.usedToday = 0;
        }
        require(lim.usedToday + amount <= lim.maxDaily, "FoundationManage: exceeds daily limit");
        // 收款地址限额
        RecipientAutoLimit storage rlim = autoRecipientLimits[to];
        require(rlim.enabled, "FoundationManage: auto recipient limit disabled");
        require(amount <= rlim.maxPerTx, "FoundationManage: recipient per-tx limit");
        if (rlim.dayIndex != day) {
            rlim.dayIndex = day;
            rlim.usedToday = 0;
        }
        require(rlim.usedToday + amount <= rlim.maxDaily, "FoundationManage: recipient daily limit");
        // 全局自动化日限额
        if (globalAutoDayIndex != day) {
            globalAutoDayIndex = day;
            globalAutoUsedToday = 0;
        }
        require(globalAutoDailyMax > 0, "FoundationManage: global daily max not set");
        require(globalAutoUsedToday + amount <= globalAutoDailyMax, "FoundationManage: exceeds global daily limit");
        require(meshToken.balanceOf(address(this)) >= amount, "FoundationManage: insufficient");
        lim.usedToday += amount;
        rlim.usedToday += amount;
        globalAutoUsedToday += amount;
        require(meshToken.transfer(to, amount), "ERC20 transfer failed");
        emit TransferExecuted(msg.sender, msg.sender, to, amount, 2, bytes32(0));
    }

    // 带原因ID的自动划拨
    function autoTransferToWithReason(address to, uint256 amount, bytes32 reasonId) external nonReentrant whenNotPaused {
        require(to != address(0), "FoundationManage: invalid to");
        require(amount > 0, "FoundationManage: zero amount");
        require(approvedAutoRecipients[to], "FoundationManage: auto recipient not approved");
        require(autoGlobalEnabled, "FoundationManage: auto disabled");
        require(approvedInitiators[msg.sender], "FoundationManage: initiator not approved");
        AutoLimit storage lim = autoLimits[msg.sender];
        require(lim.enabled, "FoundationManage: auto limit disabled");
        require(amount <= lim.maxPerTx, "FoundationManage: exceeds per-tx limit");
        uint256 day = block.timestamp / 1 days;
        if (lim.dayIndex != day) {
            lim.dayIndex = day;
            lim.usedToday = 0;
        }
        require(lim.usedToday + amount <= lim.maxDaily, "FoundationManage: exceeds daily limit");
        RecipientAutoLimit storage rlim = autoRecipientLimits[to];
        require(rlim.enabled, "FoundationManage: auto recipient limit disabled");
        require(amount <= rlim.maxPerTx, "FoundationManage: recipient per-tx limit");
        if (rlim.dayIndex != day) {
            rlim.dayIndex = day;
            rlim.usedToday = 0;
        }
        require(rlim.usedToday + amount <= rlim.maxDaily, "FoundationManage: recipient daily limit");
        if (globalAutoDayIndex != day) {
            globalAutoDayIndex = day;
            globalAutoUsedToday = 0;
        }
        require(globalAutoDailyMax > 0, "FoundationManage: global daily max not set");
        require(globalAutoUsedToday + amount <= globalAutoDailyMax, "FoundationManage: exceeds global daily limit");
        require(meshToken.balanceOf(address(this)) >= amount, "FoundationManage: insufficient");
        lim.usedToday += amount;
        rlim.usedToday += amount;
        globalAutoUsedToday += amount;
        require(meshToken.transfer(to, amount), "ERC20 transfer failed");
        emit TransferExecuted(msg.sender, msg.sender, to, amount, 2, reasonId);
    }

    // 允许 Safe 发起对某个 spender 的一次性划拨
    function transferFor(address spender, address to, uint256 amount) external onlySafeExec nonReentrant whenNotPaused {
        require(approvedInitiators[spender], "FoundationManage: initiator not approved");
        require(approvedRecipients[to], "FoundationManage: recipient not approved");
        require(to != address(0) && amount > 0, "FoundationManage: invalid params");
        require(meshToken.balanceOf(address(this)) >= amount, "FoundationManage: insufficient");
        require(meshToken.transfer(to, amount), "ERC20 transfer failed");
        emit TransferExecuted(msg.sender, spender, to, amount, 3, bytes32(0));
    }

    function transferForWithReason(address spender, address to, uint256 amount, bytes32 reasonId) external onlySafeExec nonReentrant whenNotPaused {
        require(approvedInitiators[spender], "FoundationManage: initiator not approved");
        require(approvedRecipients[to], "FoundationManage: recipient not approved");
        require(to != address(0) && amount > 0, "FoundationManage: invalid params");
        require(meshToken.balanceOf(address(this)) >= amount, "FoundationManage: insufficient");
        require(meshToken.transfer(to, amount), "ERC20 transfer failed");
        emit TransferExecuted(msg.sender, spender, to, amount, 3, reasonId);
    }

    // 配置每个收款地址的自动限额
    function setAutoRecipientLimit(address to, uint256 maxPerTx, uint256 maxDaily, bool enabled) external onlyOwner {
        RecipientAutoLimit storage rlim = autoRecipientLimits[to];
        rlim.maxPerTx = maxPerTx;
        rlim.maxDaily = maxDaily;
        rlim.enabled = enabled;
    }

    // 仅 Safe 可暂停/恢复，作为业务断路器
    function pause() external onlySafeExec {
        _pause();
    }

    function unpause() external onlySafeExec {
        _unpause();
    }
}



