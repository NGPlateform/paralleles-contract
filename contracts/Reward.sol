// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ICheckInVerifier {
    function isEligible(uint256 activityId, address user) external view returns (bool);
}

interface IFoundationManage {
    function transferTo(address to, uint256 amount) external;
}

contract Reward is ReentrancyGuard {
    struct RewardInfo {
        uint256 totalAmount;
        uint256 withdrawnAmount;
        uint256 lastWithdrawTime;
    }

    IERC20 public meshToken;
    address public foundationAddr;
    address public foundationManager; // FoundationManage 合约地址
    ICheckInVerifier public checkInVerifier; // Chainlink 校验合约
    address public governanceSafe;            // Gnosis Safe 地址（用于管理操作）
    
    mapping(address => RewardInfo) public userRewards;
    mapping(address => mapping(uint256 => bool)) public dayWithdrawn;
    
    uint256 public totalRewardsDistributed;
    uint256 public totalRewardsWithdrawn;
    
    uint256 private spendNonce;
    mapping(address => bool) private isOwner;
    address[] private owners;
    uint256 private signRequired;
    
    uint256 public constant SECONDS_IN_DAY = 86400;
    uint256 public constant DAILY_WITHDRAW_LIMIT_PERCENT = 10; // 每日提取限制为10%
    
    event RewardSet(address indexed user, uint256 amount, uint256 timestamp);
    event RewardWithdrawn(address indexed user, uint256 amount, uint256 timestamp);
    event FoundationUpdated(address indexed oldFoundation, address indexed newFoundation);
    event FoundationManagerUpdated(address indexed oldManager, address indexed newManager);
    event CheckInVerifierUpdated(address indexed oldVerifier, address indexed newVerifier);
    event ActivityRewarded(uint256 indexed activityId, address indexed user, uint256 amount);
    event ActivityBatchRewarded(uint256 indexed activityId, uint256 count, uint256 totalAmount);
    
    modifier isOnlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }
    
    modifier onlySafe() {
        require(msg.sender == governanceSafe, "Only Safe");
        _;
    }

    modifier onlyFoundation() {
        require(msg.sender == foundationAddr, "Only foundation can call");
        _;
    }
    
    constructor(
        address[] memory _owners,
        address _meshToken,
        address _foundationAddr
    ) {
        require(_meshToken != address(0), "Invalid mesh token address");
        require(_foundationAddr != address(0), "Invalid foundation address");
        
        for (uint256 i = 0; i < _owners.length; i++) {
            address _owner = _owners[i];
            if (isOwner[_owner] || _owner == address(0)) {
                revert("Invalid owner address");
            }
            
            isOwner[_owner] = true;
            owners.push(_owner);
        }
        
        meshToken = IERC20(_meshToken);
        foundationAddr = _foundationAddr;
        signRequired = _owners.length / 2 + 1;
        governanceSafe = address(0);
    }
    
    /**
     * @dev 设置/更新治理 Safe 地址（由旧多签所有者发起一次性迁移）
     */
    function setGovernanceSafe(address _safe) external isOnlyOwner {
        require(_safe != address(0), "Invalid safe");
        governanceSafe = _safe;
    }
    
    /**
     * @dev 设置用户奖励（需要多签确认）
     * @param _users 用户地址数组
     * @param _amounts 对应的奖励金额数组
     * @param _totalAmount 总奖励金额
     * @param vs 签名v值数组
     * @param rs 签名r值数组
     * @param ss 签名s值数组
     */
    function setUserReward(
        address[] calldata _users,
        uint256[] calldata _amounts,
        uint256 _totalAmount,
        uint8[] memory vs,
        bytes32[] memory rs,
        bytes32[] memory ss
    ) external onlySafe {
        // 迁移到 Safe 后，不再需要合约内多签校验，保留签名参数以兼容接口
        require(_users.length == _amounts.length, "Array length mismatch");
        require(_users.length > 0, "Empty arrays");
        
        spendNonce++;
        
        uint256 calculatedTotal = 0;
        for (uint256 i = 0; i < _users.length; i++) {
            require(_users[i] != address(0), "Invalid user address");
            require(_amounts[i] > 0, "Invalid amount");
            
            userRewards[_users[i]].totalAmount += _amounts[i];
            calculatedTotal += _amounts[i];
            
            emit RewardSet(_users[i], _amounts[i], block.timestamp);
        }
        
        require(calculatedTotal == _totalAmount, "Total amount mismatch");
        totalRewardsDistributed += _totalAmount;
    }

    /**
     * @dev 单个激励：针对活动成功者发放奖励（需验证 eligibility）
     */
    function rewardActivityWinner(
        uint256 activityId,
        address user,
        uint256 amount
    ) external isOnlyOwner {
        require(user != address(0) && amount > 0, "Invalid params");
        require(address(checkInVerifier) != address(0), "Verifier not set");
        require(checkInVerifier.isEligible(activityId, user), "Not eligible");

        userRewards[user].totalAmount += amount;
        totalRewardsDistributed += amount;
        emit ActivityRewarded(activityId, user, amount);

        _ensureTopUp(amount);
    }

    /**
     * @dev 批次激励：对一批活动成功者发放奖励
     */
    function rewardActivityWinnersBatch(
        uint256 activityId,
        address[] calldata users,
        uint256[] calldata amounts
    ) external isOnlyOwner {
        require(users.length == amounts.length && users.length > 0, "Invalid arrays");
        require(address(checkInVerifier) != address(0), "Verifier not set");
        uint256 total;
        for (uint256 i = 0; i < users.length; i++) {
            address u = users[i];
            uint256 a = amounts[i];
            require(u != address(0) && a > 0, "Invalid item");
            require(checkInVerifier.isEligible(activityId, u), "Not eligible");
            userRewards[u].totalAmount += a;
            total += a;
        }
        totalRewardsDistributed += total;
        emit ActivityBatchRewarded(activityId, users.length, total);
        _ensureTopUp(total);
    }
    
    /**
     * @dev 获取用户奖励信息
     * @param _user 用户地址
     * @return totalAmount 总奖励金额
     * @return withdrawnAmount 已提取金额
     * @return availableAmount 可提取金额
     * @return lastWithdrawTime 最后提取时间
     */
    function getRewardAmount(address _user) 
        external 
        view 
        returns (
            uint256 totalAmount,
            uint256 withdrawnAmount,
            uint256 availableAmount,
            uint256 lastWithdrawTime
        ) 
    {
        RewardInfo memory reward = userRewards[_user];
        totalAmount = reward.totalAmount;
        withdrawnAmount = reward.withdrawnAmount;
        availableAmount = reward.totalAmount - reward.withdrawnAmount;
        lastWithdrawTime = reward.lastWithdrawTime;
    }
    
    /**
     * @dev 用户提取奖励
     * @param _amount 提取金额
     */
    function withdraw(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        
        RewardInfo storage reward = userRewards[msg.sender];
        require(reward.totalAmount > reward.withdrawnAmount, "No rewards available");
        
        uint256 availableAmount = reward.totalAmount - reward.withdrawnAmount;
        require(_amount <= availableAmount, "Insufficient available rewards");
        
        // 检查每日提取限制
        uint256 dayIndex = block.timestamp / SECONDS_IN_DAY;
        require(!dayWithdrawn[msg.sender][dayIndex], "Already withdrawn today");
        
        // 计算每日提取限制
        uint256 dailyLimit = (reward.totalAmount * DAILY_WITHDRAW_LIMIT_PERCENT) / 100;
        require(_amount <= dailyLimit, "Exceeds daily withdrawal limit");
        
        // 从基金会账户转移代币
        require(meshToken.transferFrom(foundationAddr, msg.sender, _amount), "Transfer failed");
        
        // 更新状态
        reward.withdrawnAmount += _amount;
        reward.lastWithdrawTime = block.timestamp;
        dayWithdrawn[msg.sender][dayIndex] = true;
        totalRewardsWithdrawn += _amount;
        
        emit RewardWithdrawn(msg.sender, _amount, block.timestamp);
    }
    
    /**
     * @dev 批量提取奖励（一次性提取所有可用奖励）
     */
    function withdrawAll() external nonReentrant {
        RewardInfo storage reward = userRewards[msg.sender];
        require(reward.totalAmount > reward.withdrawnAmount, "No rewards available");
        
        uint256 availableAmount = reward.totalAmount - reward.withdrawnAmount;
        
        // 检查每日提取限制
        uint256 dayIndex = block.timestamp / SECONDS_IN_DAY;
        require(!dayWithdrawn[msg.sender][dayIndex], "Already withdrawn today");
        
        uint256 dailyLimit = (reward.totalAmount * DAILY_WITHDRAW_LIMIT_PERCENT) / 100;
        uint256 withdrawAmount = availableAmount > dailyLimit ? dailyLimit : availableAmount;
        
        // 从基金会账户转移代币
        require(meshToken.transferFrom(foundationAddr, msg.sender, withdrawAmount), "Transfer failed");
        
        // 更新状态
        reward.withdrawnAmount += withdrawAmount;
        reward.lastWithdrawTime = block.timestamp;
        dayWithdrawn[msg.sender][dayIndex] = true;
        totalRewardsWithdrawn += withdrawAmount;
        
        emit RewardWithdrawn(msg.sender, withdrawAmount, block.timestamp);
    }
    
    /**
     * @dev 更新基金会地址（仅限所有者）
     */
    function updateFoundation(address _newFoundation) external onlySafe {
        require(_newFoundation != address(0), "Invalid foundation address");
        require(_newFoundation != foundationAddr, "Same foundation address");
        
        address oldFoundation = foundationAddr;
        foundationAddr = _newFoundation;
        
        emit FoundationUpdated(oldFoundation, _newFoundation);
    }

    function setFoundationManager(address _manager) external onlySafe {
        require(_manager != address(0), "Invalid manager");
        address old = foundationManager;
        foundationManager = _manager;
        emit FoundationManagerUpdated(old, _manager);
    }

    function setCheckInVerifier(address _verifier) external onlySafe {
        require(_verifier != address(0), "Invalid verifier");
        address old = address(checkInVerifier);
        checkInVerifier = ICheckInVerifier(_verifier);
        emit CheckInVerifierUpdated(old, _verifier);
    }
    
    /**
     * @dev 获取合约统计信息
     */
    function getContractStats() external view returns (
        uint256 _totalRewardsDistributed,
        uint256 _totalRewardsWithdrawn,
        uint256 _pendingRewards,
        uint256 _ownerCount,
        uint256 _signRequired
    ) {
        _totalRewardsDistributed = totalRewardsDistributed;
        _totalRewardsWithdrawn = totalRewardsWithdrawn;
        _pendingRewards = totalRewardsDistributed - totalRewardsWithdrawn;
        _ownerCount = owners.length;
        _signRequired = signRequired;
    }
    
    /**
     * @dev 获取用户列表（用于管理）
     */
    function getUsersWithRewards(uint256 _startIndex, uint256 _endIndex) 
        external 
        view 
        returns (address[] memory users, uint256[] memory amounts) 
    {
        require(_startIndex < _endIndex, "Invalid index range");
        require(_endIndex <= owners.length, "Index out of range");
        
        uint256 count = _endIndex - _startIndex;
        users = new address[](count);
        amounts = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            address user = owners[_startIndex + i];
            users[i] = user;
            amounts[i] = userRewards[user].totalAmount;
        }
    }
    
    // 多签验证相关函数
    function validSignature(
        address _sender,
        uint8[] memory vs,
        bytes32[] memory rs,
        bytes32[] memory ss
    ) public view returns (bool) {
        require(vs.length == rs.length, "vs.length == rs.length");
        require(rs.length == ss.length, "rs.length == ss.length");
        require(vs.length <= owners.length, "vs.length <= owners.length");
        require(vs.length >= signRequired, "vs.length >= signRequired");
        
        bytes32 message = _messageToRecover(_sender);
        address[] memory addrs = new address[](vs.length);
        
        for (uint256 i = 0; i < vs.length; i++) {
            addrs[i] = ecrecover(message, vs[i] + 27, rs[i], ss[i]);
        }
        
        return _distinctOwners(addrs);
    }
    
    function _messageToRecover(address _sender) private view returns (bytes32) {
        bytes32 hashedUnsignedMessage = generateMessageToSign(_sender);
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        return keccak256(abi.encodePacked(prefix, hashedUnsignedMessage));
    }
    
    function generateMessageToSign(address _sender) private view returns (bytes32) {
        return keccak256(abi.encodePacked(_sender, block.chainid, spendNonce));
    }
    
    function _distinctOwners(address[] memory addrs) private view returns (bool) {
        if (addrs.length > owners.length) {
            return false;
        }
        
        for (uint256 i = 0; i < addrs.length; i++) {
            if (!isOwner[addrs[i]]) {
                return false;
            }
            
            for (uint256 j = 0; j < i; j++) {
                if (addrs[i] == addrs[j]) {
                    return false;
                }
            }
        }
        return true;
    }
    
    function getSpendNonce() external view returns (uint256) {
        return spendNonce;
    }
    
    function addSpendNonce() external onlySafe {
        spendNonce++;
    }

    // ============ 内部：余额不足时自动向 FoundationManage 申请补充 =========
    uint256 public minFoundationBalance; // 低于该值则触发申请
    event MinFoundationBalanceUpdated(uint256 oldValue, uint256 newValue);
    event AutoTopUpRequested(address indexed manager, uint256 requestedAmount);

    function setMinFoundationBalance(uint256 _min) external onlySafe {
        emit MinFoundationBalanceUpdated(minFoundationBalance, _min);
        minFoundationBalance = _min;
    }

    function _ensureTopUp(uint256 pendingNewRewards) internal {
        if (foundationManager == address(0)) return;
        uint256 bal = meshToken.balanceOf(foundationAddr);
        if (bal >= minFoundationBalance) return;
        // 估算请求量：目标补至 minFoundationBalance 的 2 倍，至少覆盖 pendingNewRewards
        uint256 target = minFoundationBalance * 2;
        uint256 need = target > bal ? (target - bal) : 0;
        if (need < pendingNewRewards) {
            need = pendingNewRewards;
        }
        if (need == 0) return;
        // 由 Safe 发起对 FoundationManage 的转账调用；此处只发起请求事件
        emit AutoTopUpRequested(foundationManager, need);
        // 可选：尝试直接调用（如由治理预授权）
        try IFoundationManage(foundationManager).transferTo(foundationAddr, need) {
        } catch {
            // 忽略失败，等待 Safe 手动或自动执行
        }
    }
}
