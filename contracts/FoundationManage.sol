// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FoundationManage
 * @notice 基金会 Mesh 国库存管，支持 Gnosis Safe 审批（通过设置 safeAddress）
 * - Rewards 合约的自动补充从这里申请
 * - 管理员/多签安全地批准转账
 */
contract FoundationManage is Ownable, ReentrancyGuard, Pausable {
    IERC20 public immutable meshToken;
    address public safeAddress; // 多签 Safe 地址，作为二次权限来源

    // 允许的借口方（例如 Rewards 合约）
    mapping(address => bool) public approvedSpenders;

    // 小额自动划拨限额配置（按 spender 维度）
    struct AutoLimit {
        uint256 maxPerTx;     // 单笔最大
        uint256 maxDaily;     // 当日累计最大
        uint256 usedToday;    // 当日已用
        uint256 dayIndex;     // 记录 usedToday 对应的天索引
        bool enabled;         // 是否启用
    }
    mapping(address => AutoLimit) public autoLimits; // spender => 限额

    event SafeUpdated(address indexed oldSafe, address indexed newSafe);
    event SpenderApproved(address indexed spender, bool approved);
    event TransferExecuted(address indexed to, uint256 amount);
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
        require(approvedSpenders[to] || to == owner(), "FoundationManage: to not approved");
        meshToken.transfer(to, amount);
        emit TransferExecuted(to, amount);
    }

    // 受限自动划拨：由已批准的 spender 自行触发，用于“小额自动化”，不经 Safe
    function autoTransferTo(address to, uint256 amount) external nonReentrant whenNotPaused {
        require(to != address(0), "FoundationManage: invalid to");
        require(amount > 0, "FoundationManage: zero amount");
        require(approvedSpenders[to] || to == owner(), "FoundationManage: to not approved");
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
        meshToken.transfer(to, amount);
        emit TransferExecuted(to, amount);
    }

    // 允许 Safe 发起对某个 spender 的一次性划拨
    function transferFor(address spender, address to, uint256 amount) external onlySafe nonReentrant whenNotPaused {
        require(approvedSpenders[spender], "FoundationManage: spender not approved");
        require(to != address(0) && amount > 0, "FoundationManage: invalid params");
        require(meshToken.balanceOf(address(this)) >= amount, "FoundationManage: insufficient");
        meshToken.transfer(to, amount);
        emit TransferExecuted(to, amount);
    }
}



