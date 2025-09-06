// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IFoundationManage {
    function transferTo(address to, uint256 amount) external;
}

contract Stake is ReentrancyGuard {
    struct StakeInfo {
        uint256 term;           // 质押天数
        uint256 maturityTs;     // 到期时间戳
        uint256 amount;         // 质押金额
        uint256 startTime;      // 开始时间戳
        uint256 lastClaimTime;  // 最后领取时间
    }
    
    struct StakeStats {
        uint256 totalStaked;
        uint256 totalEarned;
        uint256 activeStakes;
        uint256 totalStakers;
    }

    IERC20 public meshToken;
    address public foundationAddr;
    address public foundationManager; // FoundationManage 合约地址
    address public governanceSafe;     // Gnosis Safe 地址（用于管理操作）
    
    uint256 public apy;                    // 年化收益率 (基点，如1000表示10%)
    uint256 public constant SECONDS_IN_DAY = 86400;
    uint256 public constant APY_BASE = 10000; // APY基数，10000 = 100%
    uint256 public minContractBalance; // 低于该值则触发申请
    
    mapping(address => StakeInfo) public userStakes;
    mapping(address => uint256) public userTotalEarned;
    mapping(address => uint256) public userTotalStaked;
    
    StakeStats public stakeStats;
    
    uint256 private spendNonce;
    mapping(address => bool) private isOwner;
    address[] private owners;
    uint256 private signRequired;
    
    // 质押相关事件
    event Staked(address indexed user, uint256 amount, uint256 term, uint256 maturityTs);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event InterestClaimed(address indexed user, uint256 amount, uint256 timestamp);
    event APYUpdated(uint256 oldAPY, uint256 newAPY);
    event FoundationUpdated(address indexed oldFoundation, address indexed newFoundation);
    event FoundationManagerUpdated(address indexed oldManager, address indexed newManager);
    event MinContractBalanceUpdated(uint256 oldValue, uint256 newValue);
    event AutoTopUpRequested(address indexed manager, uint256 requestedAmount);
    
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
    
    modifier hasStake() {
        require(userStakes[msg.sender].amount > 0, "No active stake");
        _;
    }
    
    constructor(
        address[] memory _owners,
        address _meshToken,
        address _foundationAddr,
        uint256 _apy
    ) {
        require(_meshToken != address(0), "Invalid mesh token address");
        require(_foundationAddr != address(0), "Invalid foundation address");
        require(_apy > 0, "APY must be greater than 0");
        
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
        apy = _apy;
        signRequired = _owners.length / 2 + 1;
        // 初始 Safe 地址留空，由旧多签设置或部署后设置
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
     * @dev 质押代币
     * @param _amount 质押金额
     * @param _term 质押天数
     */
    function stake(uint256 _amount, uint256 _term) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        require(_term >= 1, "Term must be at least 1 day");
        require(_term <= 365, "Term cannot exceed 1 year");
        require(userStakes[msg.sender].amount == 0, "Active stake already exists");
        require(meshToken.balanceOf(msg.sender) >= _amount, "Insufficient balance");
        
        // 转移代币到合约
        require(
            meshToken.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );
        
        // 创建质押记录
        uint256 maturityTs = block.timestamp + (_term * SECONDS_IN_DAY);
        userStakes[msg.sender] = StakeInfo({
            term: _term,
            maturityTs: maturityTs,
            amount: _amount,
            startTime: block.timestamp,
            lastClaimTime: block.timestamp
        });
        
        // 更新统计信息
        userTotalStaked[msg.sender] += _amount;
        stakeStats.totalStaked += _amount;
        stakeStats.activeStakes++;
        stakeStats.totalStakers++;
        
        emit Staked(msg.sender, _amount, _term, maturityTs);
    }
    
    /**
     * @dev 提取质押本金和利息
     */
    function withdraw() external nonReentrant hasStake {
        StakeInfo storage userStake = userStakes[msg.sender];
        require(block.timestamp >= userStake.maturityTs, "Stake not matured yet");
        
        uint256 principal = userStake.amount;
        uint256 interest = calculateInterest(msg.sender);
        uint256 totalAmount = principal + interest;
        _ensureTopUp(totalAmount);
        
        // 更新统计信息
        stakeStats.totalStaked -= principal;
        stakeStats.totalEarned += interest;
        stakeStats.activeStakes--;
        
        // 从合约余额支付（本金+利息）
        require(meshToken.transfer(msg.sender, totalAmount), "Transfer failed");
        
        // 更新用户统计
        userTotalEarned[msg.sender] += interest;
        
        emit Withdrawn(msg.sender, principal, interest);
        
        // 清除质押记录
        delete userStakes[msg.sender];
    }
    
    /**
     * @dev 提前解除质押（需要支付手续费）
     */
    function earlyWithdraw() external nonReentrant hasStake {
        StakeInfo storage userStake = userStakes[msg.sender];
        require(block.timestamp < userStake.maturityTs, "Stake already matured");
        
        uint256 principal = userStake.amount;
        uint256 interest = calculateInterest(msg.sender);
        
        // 提前解除质押的手续费：损失50%的利息
        uint256 penalty = interest / 2;
        uint256 totalAmount = principal + (interest - penalty);
        _ensureTopUp(totalAmount);
        
        // 更新统计信息
        stakeStats.totalStaked -= principal;
        stakeStats.totalEarned += (interest - penalty);
        stakeStats.activeStakes--;
        
        // 从合约余额支付（本金+利息-罚金）
        require(meshToken.transfer(msg.sender, totalAmount), "Transfer failed");
        
        // 更新用户统计
        userTotalEarned[msg.sender] += (interest - penalty);
        
        emit Withdrawn(msg.sender, principal, interest - penalty);
        
        // 清除质押记录
        delete userStakes[msg.sender];
    }
    
    /**
     * @dev 领取利息（不解除质押）
     */
    function claimInterest() external nonReentrant hasStake {
        StakeInfo storage userStake = userStakes[msg.sender];
        uint256 interest = calculateInterest(msg.sender);
        require(interest > 0, "No interest to claim");
        _ensureTopUp(interest);
        
        // 更新最后领取时间
        userStake.lastClaimTime = block.timestamp;
        
        // 从合约余额支付利息
        require(meshToken.transfer(msg.sender, interest), "Transfer failed");
        
        // 更新统计信息
        stakeStats.totalEarned += interest;
        userTotalEarned[msg.sender] += interest;
        
        emit InterestClaimed(msg.sender, interest, block.timestamp);
    }
    
    /**
     * @dev 计算用户应得利息
     * @param _user 用户地址
     * @return 利息金额
     */
    function calculateInterest(address _user) public view returns (uint256) {
        StakeInfo memory userStake = userStakes[_user];
        if (userStake.amount == 0) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp - userStake.lastClaimTime;
        if (timeElapsed == 0) {
            return 0;
        }
        
        // 计算利息：本金 * APY * 时间 / (365天 * APY基数)
        uint256 interest = (userStake.amount * apy * timeElapsed) / (365 * SECONDS_IN_DAY * APY_BASE);
        
        return interest;
    }
    
    /**
     * @dev 获取用户质押信息
     * @param _user 用户地址
     */
    function getStakeInfo(address _user) external view returns (
        uint256 term,
        uint256 maturityTs,
        uint256 amount,
        uint256 startTime,
        uint256 lastClaimTime,
        uint256 currentInterest,
        uint256 totalEarned,
        bool isMatured
    ) {
        StakeInfo memory stake = userStakes[_user];
        term = stake.term;
        maturityTs = stake.maturityTs;
        amount = stake.amount;
        startTime = stake.startTime;
        lastClaimTime = stake.lastClaimTime;
        currentInterest = calculateInterest(_user);
        totalEarned = userTotalEarned[_user];
        isMatured = block.timestamp >= maturityTs;
    }
    
    /**
     * @dev 获取质押统计信息
     */
    function getStakeStats() external view returns (
        uint256 totalStaked,
        uint256 totalEarned,
        uint256 activeStakes,
        uint256 totalStakers,
        uint256 currentAPY
    ) {
        totalStaked = stakeStats.totalStaked;
        totalEarned = stakeStats.totalEarned;
        activeStakes = stakeStats.activeStakes;
        totalStakers = stakeStats.totalStakers;
        currentAPY = apy;
    }
    
    /**
     * @dev 更新APY（仅限所有者）
     * @param _newAPY 新的年化收益率
     */
    function updateAPY(uint256 _newAPY) external onlySafe {
        require(_newAPY > 0, "APY must be greater than 0");
        require(_newAPY <= 10000, "APY cannot exceed 100%");
        
        uint256 oldAPY = apy;
        apy = _newAPY;
        
        emit APYUpdated(oldAPY, _newAPY);
    }
    
    /**
     * @dev 更新基金会地址（仅限所有者）
     * @param _newFoundation 新的基金会地址
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

    function setMinContractBalance(uint256 _min) external onlySafe {
        emit MinContractBalanceUpdated(minContractBalance, _min);
        minContractBalance = _min;
    }

    function _ensureTopUp(uint256 pendingPayout) internal {
        if (foundationManager == address(0)) return;
        uint256 bal = meshToken.balanceOf(address(this));
        if (bal >= minContractBalance && bal >= pendingPayout) return;
        uint256 target = minContractBalance * 2;
        uint256 need = target > bal ? (target - bal) : 0;
        if (need < pendingPayout) {
            need = pendingPayout;
        }
        if (need == 0) return;
        emit AutoTopUpRequested(foundationManager, need);
        // 可选直接尝试调用（由治理预授权时可成功）
        try IFoundationManage(foundationManager).transferTo(address(this), need) {
        } catch {
            // 忽略失败，等待 Safe/Owner 执行
        }
    }
    
    /**
     * @dev 获取用户质押时间
     * @param _user 用户地址
     */
    function getStakeTime(address _user) external view returns (uint256) {
        StakeInfo memory stake = userStakes[_user];
        if (stake.amount == 0) {
            return 0;
        }
        return stake.maturityTs;
    }
    
    /**
     * @dev 检查用户是否有活跃质押
     * @param _user 用户地址
     */
    function hasActiveStake(address _user) external view returns (bool) {
        return userStakes[_user].amount > 0;
    }
    
    /**
     * @dev 获取质押到期时间
     * @param _user 用户地址
     */
    function getMaturityTime(address _user) external view returns (uint256) {
        return userStakes[_user].maturityTs;
    }
    
    /**
     * @dev 获取用户总质押金额
     * @param _user 用户地址
     */
    function getUserTotalStaked(address _user) external view returns (uint256) {
        return userTotalStaked[_user];
    }
    
    /**
     * @dev 获取用户总收益
     * @param _user 用户地址
     */
    function getUserTotalEarned(address _user) external view returns (uint256) {
        return userTotalEarned[_user];
    }
    
    /**
     * @dev 计算质押的TVL（总锁仓价值）
     * @param _price 代币价格（以wei为单位）
     */
    function calculateTVL(uint256 _price) external view returns (uint256) {
        return (stakeStats.totalStaked * _price) / 1e18;
    }
    
    /**
     * @dev 计算质押的收益率
     * @param _user 用户地址
     */
    function calculateStakeAPY(address _user) external view returns (uint256) {
        StakeInfo memory stake = userStakes[_user];
        if (stake.amount == 0) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp - stake.startTime;
        if (timeElapsed == 0) {
            return 0;
        }
        
        // 计算实际收益率
        uint256 totalEarned = userTotalEarned[_user] + calculateInterest(_user);
        uint256 apy = (totalEarned * 365 * SECONDS_IN_DAY * APY_BASE) / (stake.amount * timeElapsed);
        
        return apy;
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
}
