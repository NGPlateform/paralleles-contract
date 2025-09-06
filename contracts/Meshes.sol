// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Meshes is ERC20, ReentrancyGuard, Pausable {
    struct MintInfo {
        address user;
        string meshID;
        uint256 updateTs;
        uint256 withdrawTs;
    }

    uint256 SECONDS_IN_DAY = 86400;
    uint256 totalMintDuration = 10 * 365 * SECONDS_IN_DAY; // 10年
//    uint256 public constant MAX_TOTAL_SUPPLY = 81_000_000_000 * 10**18; // 81亿枚
//    uint256 public constant MAX_MINT_PER_CALL = 100 * 10**18; // 每次铸造上限为100枚
    uint256 baseBurnAmount = 10;
    // baseMintAmount 不再使用（原线性日因子参数），留空以避免误用

    uint256 public dailyMintFactor;
    uint256 public lastUpdatedDay = 0; // 记录上次更新的“相对创世”的日期索引

    bool public burnSwitch = false; // 控制是否启用burn操作

    mapping(address => mapping(string => MintInfo)) public userMints;
    // 原 userApplys[string] => address[] 改为申请计数器，避免数组膨胀
    mapping(string => uint32) public meshApplyCount;
    mapping(string => uint256) public degreeHeats;
    // 原 userClaims[address] => string[] 改为用户累计权重与计数
    mapping(address => uint256) public userWeightSum;
    mapping(address => uint32) public userClaimCounts;
    // 用户上一次提现的“相对创世”的天索引
    mapping(address => uint256) public lastWithdrawDay;
    mapping(address => bool) private minters;
    // spendNonce 已弃用（旧多签相关）

    // legacy owner fields removed; governance via Gnosis Safe

    uint256 public genesisTs;
    uint256 public activeMinters;
    uint256 public activeMeshes;
    uint256 public claimMints;
    uint256 public maxMeshHeats;
    uint256 public totalBurn;

    address public FoundationAddr;
    address public governanceSafe;

    // 基金会待转池与小时转账
    uint256 public pendingFoundationPool;
    uint256 public lastPayoutHour;
    uint256 private constant HOUR_SECONDS = 3600;

    // 未提现余额与处理进度（用于“日衰减 50%”记账）
    mapping(address => uint256) public carryBalance;
    mapping(address => uint256) public lastProcessedDay; // 已处理至的日索引（含）

    mapping(uint256 => uint256) public dayMintAmount;
    mapping(address => uint256) public userTotalMint;

    // 优化的事件定义，添加indexed参数
    event ClaimMint(address indexed user, string indexed meshID, uint256 indexed time);
    event DegreeHeats(string indexed meshID, uint256 heat, uint256 len);
    event UserMint(address indexed user, uint256 amount);
    event UserWithdraw(address indexed user, uint256 amount);
    event BurnSwitchUpdated(bool indexed oldValue, bool indexed newValue);
    event FoundationAddressUpdated(address indexed oldAddress, address indexed newAddress);
    event FoundationFeeAccrued(uint256 indexed amount, uint256 indexed time);
    event FoundationPayout(uint256 indexed amount, uint256 indexed time);
    // New developer-friendly events
    event MeshClaimed(
        address indexed user,
        string indexed meshID,
        int32 lon100,
        int32 lat100,
        uint32 applyCount,
        uint256 heat,
        uint256 costBurned
    );
    event UserWeightUpdated(address indexed user, uint256 newWeight, uint32 claimCount);
    event WithdrawProcessed(
        address indexed user,
        uint256 payout,
        uint256 burned,
        uint256 foundation,
        uint256 carryAfter,
        uint256 dayIndex
    );
    event TokensBurned(uint256 amount, uint8 reasonCode); // 1=claim_cost, 2=unclaimed_decay
    event YearFactorUpdated(uint256 indexed yearIndex, uint256 factor1e10);
    event UnclaimedDecayApplied(
        address indexed user,
        uint256 daysProcessed,
        uint256 burned,
        uint256 foundation,
        uint256 carryAfter
    );
    event GovernanceSafeUpdated(address indexed oldSafe, address indexed newSafe);

    modifier onlySafe() {
        require(msg.sender == governanceSafe, "Only Safe");
        _;
    }

    // legacy isOnlyOwner removed

    modifier whenNotPaused() {
        require(!paused(), "Contract is paused");
        _;
    }

    // Precomputed values for (1.2 ** n) when n < 30
    uint256[] private precomputedDegreeHeats = [
        1 ether,
        1.2 ether,
        1.44 ether,
        1.728 ether,
        2.0736 ether,
        2.48832 ether,
        2.985984 ether,
        3.5831808 ether,
        4.29981696 ether,
        5.159780352 ether,
        6.1917364224 ether,
        7.43008370688 ether,
        8.916100448256 ether,
        10.6993205379072 ether,
        12.83918464548864 ether,
        15.407021574586368 ether,
        18.48842588950364 ether,
        22.186111067404368 ether,
        26.623333280885244 ether,
        31.947999937062296 ether,
        38.33759992447475 ether,
        46.0051199093697 ether,
        55.20614389124364 ether,
        66.24737266949237 ether,
        79.49684720339084 ether,
        95.39621664406896 ether,
        114.47545997288273 ether,
        137.3705519674593 ether,
        164.84466236095116 ether,
        197.81359483314138 ether
    ];

    constructor(
        address _foundationAddr,
        address _governanceSafe
    ) ERC20("Mesh Token", "MESH") {
        require(_foundationAddr != address(0), "Invalid foundation address");
        require(_governanceSafe != address(0), "Invalid safe address");

        genesisTs = block.timestamp;
        FoundationAddr = _foundationAddr;
        governanceSafe = _governanceSafe;
        // 初始化日因子为首日值
        dailyMintFactor = 1e10;
        lastUpdatedDay = 0;
        lastPayoutHour = block.timestamp / HOUR_SECONDS;
    }

    // 计算“自创世以来”的天索引
    function _currentDayIndex() private view returns (uint256) {
        return (block.timestamp - genesisTs) / SECONDS_IN_DAY;
    }

    // 年度 10% 衰减：Fd = F0 * (0.9 ^ yearIndex)，F0 = 1e10
    function _dailyMintFactorForDay(uint256 dayIndex) private pure returns (uint256) {
        uint256 yearIndex = dayIndex / 365;
        // 快速幂（定点 1e10，不缩放底数，仅整数比例）
        // 预计算 0.9^n 的 1e10 定点：逐年乘以 0.9（用 9/10 近似）
        uint256 factor = 1e10;
        for (uint256 i = 0; i < yearIndex; i++) {
            factor = (factor * 9) / 10; // 每年衰减 10%
            if (factor == 0) break;
        }
        return factor;
    }

    // 求和 F(a..b) 等差数列和，闭区间；若 a>b 返回 0
    function _sumDailyMintFactor(uint256 a, uint256 b) private view returns (uint256) {
        if (b < a) return 0;
        uint256 n = b - a + 1;
        uint256 first = _dailyMintFactorForDay(a);
        uint256 last = _dailyMintFactorForDay(b);
        // (first + last) * n / 2，按整数下取
        return ((first + last) * n) / 2;
    }

    /**
     * @dev 设置燃烧开关（仅限所有者）
     */
    function setBurnSwitch(
        bool _burnSwitch
    ) external onlySafe whenNotPaused {
        bool oldValue = burnSwitch;
        burnSwitch = _burnSwitch;
        emit BurnSwitchUpdated(oldValue, _burnSwitch);
    }

    /**
     * @dev 更新Foundation地址（仅限所有者）
     */
    function setFoundationAddress(
        address _newFoundationAddr
    ) external onlySafe whenNotPaused {
        require(_newFoundationAddr != address(0), "Invalid foundation address");
        require(_newFoundationAddr != FoundationAddr, "Same foundation address");
        address oldFoundation = FoundationAddr;
        FoundationAddr = _newFoundationAddr;
        emit FoundationAddressUpdated(oldFoundation, _newFoundationAddr);
    }

    /**
     * @dev 紧急暂停合约（仅限所有者）
     */
    function pause() external onlySafe {
        _pause();
    }

    /**
     * @dev 恢复合约（仅限所有者）
     */
    function unpause() external onlySafe {
        _unpause();
    }

    function setGovernanceSafe(address _newSafe) external onlySafe whenNotPaused {
        require(_newSafe != address(0), "Invalid safe");
        require(_newSafe != governanceSafe, "Same safe");
        address old = governanceSafe;
        governanceSafe = _newSafe;
        emit GovernanceSafeUpdated(old, _newSafe);
    }

    /**
     * @dev 验证网格ID格式
     */
    function isValidMeshID(string memory _meshID) public pure returns (bool) {
        bytes memory b = bytes(_meshID);
        if (b.length < 3 || b.length > 32) {
            return false;
        }
        // 规则：^[EW][0-9]+[NS][0-9]+$
        if (!(b[0] == bytes1("E") || b[0] == bytes1("W"))) {
            return false;
        }
        uint256 i = 1;
        uint256 sep = type(uint256).max; // 记录 N/S 的位置
        for (; i < b.length; i++) {
            bytes1 c = b[i];
            if (c == bytes1("N") || c == bytes1("S")) {
                sep = i;
                break;
            }
            if (c < bytes1("0") || c > bytes1("9")) {
                return false;
            }
        }
        if (sep == type(uint256).max) {
            return false; // 未找到 N/S 分隔符
        }
        if (sep == 1) {
            return false; // 经度数字缺失
        }
        if (sep + 1 >= b.length) {
            return false; // 纬度数字缺失
        }
        // 校验纬度部分均为数字
        for (uint256 j = sep + 1; j < b.length; j++) {
            bytes1 c2 = b[j];
            if (c2 < bytes1("0") || c2 > bytes1("9")) {
                return false;
            }
        }
        // 解析数值并检查范围：|lon*100| < 18000, |lat*100| <= 9000
        uint256 lonAbs = 0;
        for (uint256 k = 1; k < sep; k++) {
            lonAbs = lonAbs * 10 + (uint8(b[k]) - uint8(bytes1("0")));
            if (lonAbs >= 18000) {
                // 经度上限为 17999（对应 [-180,180) 的 0.01 度网格）
                return false;
            }
        }
        uint256 latAbs = 0;
        for (uint256 m = sep + 1; m < b.length; m++) {
            latAbs = latAbs * 10 + (uint8(b[m]) - uint8(bytes1("0")));
            if (latAbs > 9000) {
                // 纬度上限为 9000（对应 [-90,90] 的 0.01 度网格）
                return false;
            }
        }
        return true;
    }

    /**
     * @dev 认领网格铸造权
     */
    function claimMint(string memory _meshID) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        // 输入验证
        require(bytes(_meshID).length > 0, "MeshID cannot be empty");
        require(isValidMeshID(_meshID), "Invalid meshID format");
        
        MintInfo memory mintInfo = userMints[msg.sender][_meshID];

        require(mintInfo.updateTs == 0, "Already claim");

        uint256 _len = meshApplyCount[_meshID];
        if (0 == _len) {
            activeMeshes++;
        }

        if (burnSwitch && _len > 0) {
            uint256 _amount = (baseBurnAmount *
                degreeHeats[_meshID] *
                degreeHeats[_meshID]) / maxMeshHeats;
            // 前端预换：仅检查余额足够
            require(balanceOf(msg.sender) >= _amount, "Insufficient to burn");

            totalBurn += _amount;
            _burn(msg.sender, _amount);
            emit TokensBurned(_amount, 1);
        }

        // 在增加权重之前，先把历史未领（按天）结算到昨天，确保新权重只影响今天及以后
        uint256 cd = _currentDayIndex();
        if (cd > 0) {
            _applyUnclaimedDecay(msg.sender, cd);
        }

        mintInfo.meshID = _meshID;
        mintInfo.user = msg.sender;
        mintInfo.updateTs = block.timestamp;
        mintInfo.withdrawTs = block.timestamp;
        userMints[msg.sender][_meshID] = mintInfo;
        // 更新网格热度（按当前参与人数）
        uint256 _degreeHeat = calculateDegreeHeat(_len);
        degreeHeats[_meshID] = _degreeHeat;
        if (_degreeHeat > maxMeshHeats) {
            maxMeshHeats = _degreeHeat;
        }

        emit DegreeHeats(_meshID, _degreeHeat, _len);

        // 用户累计权重 +1 次认领（影响今天之后）
        userClaimCounts[msg.sender] += 1;
        userWeightSum[msg.sender] += _degreeHeat;
        emit UserWeightUpdated(msg.sender, userWeightSum[msg.sender], userClaimCounts[msg.sender]);

        // 更新用户首次认领的上次提现日，避免追溯罚没
        if (userClaimCounts[msg.sender] == 1) {
            uint256 cd = _currentDayIndex();
            if (cd > 0) {
                lastWithdrawDay[msg.sender] = cd - 1;
                lastProcessedDay[msg.sender] = cd - 1;
            } else {
                lastWithdrawDay[msg.sender] = 0;
                lastProcessedDay[msg.sender] = 0;
            }
        }

        // 递增网格申请计数
        meshApplyCount[_meshID] = uint32(_len + 1);

        // 解析 lon/lat（以 0.01 度为单位），若解析失败则返回 (0,0)
        (int32 lon100, int32 lat100) = _parseMeshId(_meshID);
        emit MeshClaimed(
            msg.sender,
            _meshID,
            lon100,
            lat100,
            uint32(_len + 1),
            _degreeHeat,
            burnSwitch && _len > 0 ? (baseBurnAmount * _degreeHeat * _degreeHeat) / (maxMeshHeats == 0 ? 1 : maxMeshHeats) : 0
        );

        if (!minters[msg.sender]) {
            activeMinters++;
            minters[msg.sender] = true;
        }

        claimMints++;

        emit ClaimMint(msg.sender, _meshID, block.timestamp);

        // 触发按小时基金会转出（用户发起，承担 gas）
        _maybePayoutFoundation();
    }

    function calculateDegreeHeat(uint256 _n) internal view returns (uint256) {
        if (_n < 30) {
            return precomputedDegreeHeats[_n];
        } else {
            // 防止线性循环 DoS：使用闭式近似（截断到 n=60 上限）
            if (_n > 60) {
                _n = 60;
            }
            uint256 base = 1.2 ether;
            uint256 result = precomputedDegreeHeats[29];
            for (uint256 i = 30; i <= _n; i++) {
                result = (result * base) / 1 ether;
            }
            return result;
        }
    }

    // 已移除 Pancake 自动换币逻辑（前端预换）

    /**
     * @dev 铸造代币（内部函数）
     */
    function mint(address user, uint256 amount) private {
        uint256 _today = _currentDayIndex();
        dayMintAmount[_today] += amount;
        _mint(user, amount);
    }

    /**
     * @dev 提取收益（添加重入保护）
     */
    function withdraw() public nonReentrant whenNotPaused {
        uint256 elapsedTime = block.timestamp - genesisTs;
        require(elapsedTime <= totalMintDuration, "Minting period over");

        uint256 dayIndex = _currentDayIndex();
        require(userClaimCounts[msg.sender] > 0, "No claims");
        require(dayIndex > lastWithdrawDay[msg.sender], "Daily receive");

        // 更新今日 dailyMintFactor（与创世对齐）
        if (dayIndex != lastUpdatedDay) {
            dailyMintFactor = _dailyMintFactorForDay(dayIndex);
            lastUpdatedDay = dayIndex;
        }

        address user = msg.sender;
        uint256 weight = userWeightSum[user];
        require(weight > 0, "Zero weight");

        // 先对未领余额做“日衰减 50%”的懒结算（逐日推进到昨天）
        _applyUnclaimedDecay(user, dayIndex);

        // 处理今日领取：今日应得 + 结转余额一次性发放
        uint256 todayAmount = (dailyMintFactor * weight) / 1e10;
        uint256 payout = carryBalance[user] + todayAmount;
        require(payout > 0, "Zero mint");

        // 发放并清零结转
        mint(user, payout);
        carryBalance[user] = 0;
        lastProcessedDay[user] = dayIndex;
        lastWithdrawDay[user] = dayIndex;

        emit UserMint(user, payout);
        userTotalMint[user] += payout;

        emit WithdrawProcessed(user, payout, 0, 0, carryBalance[user], dayIndex);

        _maybePayoutFoundation();
    }

    function _maybePayoutFoundation() private {
        uint256 currentHour = block.timestamp / HOUR_SECONDS;
        if (currentHour > lastPayoutHour && pendingFoundationPool > 0) {
            uint256 amount = pendingFoundationPool;
            pendingFoundationPool = 0;
            lastPayoutHour = currentHour;
            _transfer(address(this), FoundationAddr, amount);
            emit FoundationPayout(amount, block.timestamp);
        }
    }

    // 任何人可发起的基金会出账触发器（无外部程序依赖，gas 由调用者承担）
    function payoutFoundationIfDue() external nonReentrant whenNotPaused {
        _maybePayoutFoundation();
    }

    // 按天精确推进未领余额的“日衰减 50%”直至 upToDay-1
    function _applyUnclaimedDecay(address user, uint256 upToDay) private {
        uint256 fromDay = lastProcessedDay[user];
        if (fromDay >= upToDay) {
            return;
        }
        uint256 weight = userWeightSum[user];
        if (weight == 0) {
            lastProcessedDay[user] = upToDay - 1;
            return;
        }
        uint256 daysProcessed = 0;
        uint256 burnedTotal = 0;
        uint256 foundationTotal = 0;
        uint256 carry = carryBalance[user];
        for (uint256 d = fromDay; d < upToDay; d++) {
            uint256 factorD = _dailyMintFactorForDay(d);
            uint256 Rd = (factorD * weight) / 1e10;
            uint256 Xd = carry + Rd;
            if (Xd > 0) {
                uint256 burnD = (Xd * 40) / 100;
                uint256 fundD = (Xd * 10) / 100;
                carry = Xd - burnD - fundD; // 50% 结转
                burnedTotal += burnD;
                foundationTotal += fundD;
            }
            daysProcessed++;
        }
        if (burnedTotal > 0) {
            mint(address(this), burnedTotal);
            _burn(address(this), burnedTotal);
            emit TokensBurned(burnedTotal, 2);
        }
        if (foundationTotal > 0) {
            mint(address(this), foundationTotal);
            pendingFoundationPool += foundationTotal;
            emit FoundationFeeAccrued(foundationTotal, block.timestamp);
        }
        carryBalance[user] = carry;
        lastProcessedDay[user] = upToDay - 1;
        emit UnclaimedDecayApplied(user, daysProcessed, burnedTotal, foundationTotal, carry);
    }

    /**
     * @dev 验证多签签名
     */
    // Legacy multi-sig validation removed in favor of Safe-based governance

    // Legacy ecrecover helpers removed

    /**
     * @dev 获取消费nonce（仅限所有者）
     */
    function getSpendNonce() external pure returns (uint256) {
        return 0;
    }

    // ===================== Developer-friendly VIEWs (skeletons) =====================
    function getCurrentDayYear() external view returns (uint256 dayIndex, uint256 yearIndex, uint256 factor1e10) {
        dayIndex = _currentDayIndex();
        yearIndex = dayIndex / 365;
        // placeholder: current linear factor; will switch to yearly-decay factor in next phase
        factor1e10 = dailyMintFactor;
    }

    function getMeshInfo(string calldata _meshID) external view returns (
        uint32 applyCount,
        uint256 heat,
        int32 lon100,
        int32 lat100
    ) {
        applyCount = meshApplyCount[_meshID];
        heat = degreeHeats[_meshID];
        (lon100, lat100) = _parseMeshId(_meshID);
    }

    function quoteClaimCost(string calldata _meshID) external view returns (uint256 heat, uint256 costBurned) {
        uint32 cnt = meshApplyCount[_meshID];
        heat = calculateDegreeHeat(cnt);
        uint256 denom = maxMeshHeats == 0 ? 1 : maxMeshHeats;
        costBurned = burnSwitch && cnt > 0 ? (baseBurnAmount * heat * heat) / denom : 0;
    }

    function getUserState(address _user) external view returns (
        uint256 weight,
        uint32 claimCount,
        uint256 carryBalance,
        uint256 lastProcessedDay
    ) {
        weight = userWeightSum[_user];
        claimCount = userClaimCounts[_user];
        // carryBalance & lastProcessedDay are placeholders for next-phase accounting
        carryBalance = 0;
        lastProcessedDay = lastWithdrawDay[_user];
    }

    function previewWithdraw(address _user) external view returns (
        uint256 payoutToday,
        uint256 carryBefore,
        uint256 carryAfterIfNoWithdraw,
        uint256 burnTodayIfNoWithdraw,
        uint256 foundationTodayIfNoWithdraw,
        uint256 dayIndex
    ) {
        dayIndex = _currentDayIndex();
        uint256 weight = userWeightSum[_user];
        uint256 factor = _dailyMintFactorForDay(dayIndex);
        payoutToday = (factor * weight) / 1e10;
        carryBefore = carryBalance[_user];
        // 严格按天的“若不提现”模拟：仅计算今天一次
        uint256 Xd = carryBefore + payoutToday;
        burnTodayIfNoWithdraw = (Xd * 40) / 100;
        foundationTodayIfNoWithdraw = (Xd * 10) / 100;
        carryAfterIfNoWithdraw = Xd - burnTodayIfNoWithdraw - foundationTodayIfNoWithdraw;
    }

    // ===================== Internal utils =====================
    function _parseMeshId(string memory _meshID) private pure returns (int32 lon100, int32 lat100) {
        bytes memory b = bytes(_meshID);
        if (b.length < 3) {
            return (0, 0);
        }
        int8 signLon = 1;
        if (b[0] == bytes1("W")) signLon = -1;
        uint256 i = 1;
        uint256 sep = type(uint256).max;
        for (; i < b.length; i++) {
            bytes1 c = b[i];
            if (c == bytes1("N") || c == bytes1("S")) { sep = i; break; }
        }
        if (sep == type(uint256).max || sep == 1 || sep + 1 >= b.length) {
            return (0, 0);
        }
        uint256 lonAbs = 0;
        for (uint256 k = 1; k < sep; k++) { lonAbs = lonAbs * 10 + (uint8(b[k]) - uint8(bytes1("0"))); }
        int8 signLat = 1;
        if (b[sep] == bytes1("S")) signLat = -1;
        uint256 latAbs = 0;
        for (uint256 m = sep + 1; m < b.length; m++) { latAbs = latAbs * 10 + (uint8(b[m]) - uint8(bytes1("0"))); }
        if (lonAbs >= 18000 || latAbs > 9000) {
            return (0, 0);
        }
        lon100 = int32(int256(int(signLon) * int(lonAbs)));
        lat100 = int32(int256(int(signLat) * int(latAbs)));
    }

    /**
     * @dev 增加消费nonce（仅限所有者）
     */
    // legacy addSpendNonce removed

    /**
     * @dev 获取用户认领数量
     */
    function getUserClaimCount(address _user) external view returns (uint256) {
        return userClaimCounts[_user];
    }

    /**
     * @dev 获取用户所有网格ID
     */
    function getUserMeshes(address _user) external view returns (string[] memory) {
        // 存储结构已变更：兼容返回空数组
        string[] memory empty;
        return empty;
    }

    /**
     * @dev 获取网格数据统计
     */
    function getMeshData()
        external
        view
        returns (
            uint256 userCounts,
            uint256 launchData,
            uint256 totalMinted,
            uint256 liquidSupply
        )
    {
        userCounts = activeMinters;
        launchData = (block.timestamp - genesisTs) / SECONDS_IN_DAY;
        totalMinted = totalSupply();
        liquidSupply = totalMinted - balanceOf(address(this));
    }

    /**
     * @dev 获取网格仪表板数据
     */
    function getMeshDashboard()
        external
        view
        returns (
            uint256 participants,
            uint256 totalclaimMints,
            uint256 claimedMesh,
            uint256 maxHeats,
            uint256 sinceGenesis
        )
    {
        participants = activeMinters;
        totalclaimMints = claimMints;
        claimedMesh = activeMeshes;
        maxHeats = maxMeshHeats;
        sinceGenesis = (block.timestamp - genesisTs) / SECONDS_IN_DAY;
    }

    /**
     * @dev 获取地球仪表板数据
     */
    function getEarthDashboard()
        external
        view
        returns (
            uint256 _totalSupply,
            uint256 _liquidSupply,
            uint256 _destruction,
            uint256 _treasury,
            uint256 _foundation
        )
    {
        _totalSupply = totalSupply();
        _liquidSupply = _totalSupply - balanceOf(address(this));
        _destruction = totalBurn;
        _treasury = 0; // 已移除质押相关
        _foundation = balanceOf(FoundationAddr);
    }

    /**
     * @dev 获取用户认领时间戳和金额
     */
    function getClaimTsAmount(address _user, string calldata _meshID)
        public
        view
        returns (int256 count, uint256 _amount)
    {
        // 兼容：返回当前网格已有申请次数与固定比例
        count = int256(uint256(meshApplyCount[_meshID]));
            _amount = degreeHeats[_meshID] / 10;
    }

    /**
     * @dev 获取合约状态信息
     */
    function getContractStatus() external view returns (
        bool _paused,
        uint256 _totalSupply,
        uint256 _activeMinters,
        uint256 _activeMeshes,
        uint256 _totalBurn
    ) {
        _paused = paused();
        _totalSupply = totalSupply();
        _activeMinters = activeMinters;
        _activeMeshes = activeMeshes;
        _totalBurn = totalBurn;
    }
}
