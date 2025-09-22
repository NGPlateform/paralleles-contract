// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Meshes - 基于地理网格的ERC20代币系统
 * @dev 这是一个创新的代币系统，用户通过认领地理网格来获得代币奖励
 * 
 * 核心机制：
 * 1. 网格认领：用户认领地理网格（如E123N45），获得代币奖励
 * 2. 热度系统：网格被认领次数越多，热度越高，奖励越多
 * 3. 燃烧机制：重复认领需要燃烧代币，防止过度投机
 * 4. 时间衰减：代币供应量随时间衰减，模拟稀缺性
 * 5. 基金会分配：部分代币分配给基金会，支持生态发展
 * 
 * 安全特性：
 * - 重入保护：防止重入攻击
 * - 暂停机制：紧急情况下可暂停合约
 * - 访问控制：关键功能仅限治理地址调用
 * 
 * @author Parallels Team
 * @notice 本合约实现了基于地理网格的代币经济系统
 */
contract Meshes is ERC20, ReentrancyGuard, Pausable, Ownable {
    /**
     * @dev 用户认领信息结构体
     * @param user 认领用户地址
     * @param meshID 网格ID（如"E123N45"）
     * @param updateTs 最后更新时间戳
     * @param withdrawTs 最后提取时间戳
     */
    struct MintInfo {
        address user;        // 认领用户地址
        string meshID;       // 网格ID，格式为"E/W + 经度 + N/S + 纬度"
        uint256 updateTs;    // 最后更新时间戳
        uint256 withdrawTs;  // 最后提取时间戳
    }

    // ============ 时间相关常量 ============
    /** @dev 一天的秒数 */
    uint256 SECONDS_IN_DAY = 86400;
    
    /** @dev 总铸造持续时间：10年，用于计算代币衰减 */
    uint256 totalMintDuration = 10 * 365 * SECONDS_IN_DAY; // 10年
    
    // 已废弃的常量（保留用于历史记录）
    //    uint256 public constant MAX_TOTAL_SUPPLY = 81_000_000_000 * 10**18; // 81亿枚
    //    uint256 public constant MAX_MINT_PER_CALL = 100 * 10**18; // 每次铸造上限为100枚

    // ============ 燃烧机制参数 ============
    /** @dev 基础燃烧数量（wei单位），用于计算认领成本 */
    uint256 baseBurnAmount = 10;

    // ============ 代币铸造参数 ============
    /** @dev 当前日铸造因子，用于计算每日可铸造的代币数量 */
    uint256 public dailyMintFactor;
    
    /** @dev 记录上次更新的"相对创世"的日期索引，用于优化计算 */
    uint256 public lastUpdatedDay = 0;

    /**
     * @dev 燃烧缩放比例（千分位精度），表示对基础成本的乘数
     * @notice 0 表示关闭燃烧；1000 表示 1.000x；1000000 表示 1000.000x
     * @notice 范围 [0, 1_000_000]，用于动态调整燃烧成本
     */
    uint256 public burnScaleMilli = 0;

    // ============ 用户数据映射 ============
    /** @dev 用户认领信息映射：用户地址 => 网格ID => 认领信息 */
    mapping(address => mapping(string => MintInfo)) public userMints;
    
    /** @dev 网格申请计数：网格ID => 申请次数（避免数组膨胀） */
    mapping(string => uint32) public meshApplyCount;
    
    /** @dev 网格热度值：网格ID => 热度值（基于申请次数计算） */
    mapping(string => uint256) public degreeHeats;
    
    /** @dev 用户累计权重：用户地址 => 累计权重（影响代币奖励） */
    mapping(address => uint256) public userWeightSum;
    
    /** @dev 用户认领次数：用户地址 => 认领次数 */
    mapping(address => uint32) public userClaimCounts;
    
    /** @dev 用户上次提现日：用户地址 => 上次提现的"相对创世"的天索引 */
    mapping(address => uint256) public lastWithdrawDay;
    
    /** @dev 铸币者权限：用户地址 => 是否有铸币权限 */
    mapping(address => bool) private minters;
    
    // spendNonce 已弃用（旧多签相关）

    // legacy owner fields removed; governance via Gnosis Safe

    // ============ 系统状态变量 ============
    /** @dev 创世时间戳，用于计算相对时间 */
    uint256 public genesisTs;
    
    /** @dev 活跃铸币者数量 */
    uint256 public activeMinters;
    
    /** @dev 活跃网格数量（被认领的网格数） */
    uint256 public activeMeshes;
    
    /** @dev 总认领次数 */
    uint256 public claimMints;
    
    /** @dev 最大网格热度值（用于计算燃烧成本） */
    uint256 public maxMeshHeats;
    
    /** @dev 总燃烧代币数量 */
    uint256 public totalBurn;

    // ============ 地址配置 ============
    /** @dev 基金会地址，接收部分代币分配 */
    address public FoundationAddr;
    
    /** @dev 治理安全地址（Gnosis Safe），用于管理合约 */
    address public governanceSafe;
    
    // ============ 治理模式切换 ============
    /** @dev 治理模式：true=Safe治理，false=Owner治理 */
    bool public isSafeGovernance = false;
    
    /** @dev 治理模式切换锁定：一旦切换到Safe模式，无法回退到Owner模式 */
    bool public governanceLocked = false;

    // ============ 基金会分配机制 ============
    /** @dev 基金会待转池，累积待转给基金会的代币 */
    uint256 public pendingFoundationPool;
    
    /** @dev 上次基金会转账的小时索引 */
    uint256 public lastPayoutHour;
    
    /** @dev 小时秒数常量 */
    uint256 private constant HOUR_SECONDS = 3600;

    // ============ 用户余额与处理进度 ============
    /** @dev 用户未提现余额（用于"日衰减 50%"记账） */
    mapping(address => uint256) public carryBalance;
    
    /** @dev 用户已处理至的日索引（含），用于优化日衰减计算 */
    mapping(address => uint256) public lastProcessedDay;
    
    /** @dev 新用户第一次claim的时间戳，用于24小时提取限制 */
    mapping(address => uint256) public firstClaimTimestamp;

    // ============ 历史记录映射 ============
    /** @dev 每日铸造数量记录：日索引 => 铸造数量 */
    mapping(uint256 => uint256) public dayMintAmount;
    
    /** @dev 用户总铸造数量：用户地址 => 总铸造数量 */
    mapping(address => uint256) public userTotalMint;

    // ============ 事件定义 ============
    // 已废弃的事件（保留用于历史记录）
    //event ClaimMint(address indexed user, string indexed meshID, uint256 indexed time);
    
    /** @dev 网格热度更新事件：当网格被认领时触发 */
    event DegreeHeats(string indexed meshID, uint256 heat, uint256 len);
    
    /** @dev 用户代币铸造事件：当用户获得代币奖励时触发 */
    event UserMint(address indexed user, uint256 amount);
    
    /** @dev 用户提取事件：当用户提取代币时触发 */
    event UserWithdraw(address indexed user, uint256 amount);
    
    /** @dev 燃烧缩放比例更新事件：当燃烧成本调整时触发 */
    event BurnScaleUpdated(uint256 indexed oldMilli, uint256 indexed newMilli);
    
    /** @dev 基金会地址更新事件：当基金会地址变更时触发 */
    event FoundationAddressUpdated(address indexed oldAddress, address indexed newAddress);
    
    /** @dev 基金会费用累积事件：当基金会费用累积时触发 */
    event FoundationFeeAccrued(uint256 indexed amount, uint256 indexed time);
    
    /** @dev 基金会转账事件：当基金会收到代币时触发 */
    event FoundationPayout(uint256 indexed amount, uint256 indexed time);
    
    // ============ 开发者友好事件 ============
    /** @dev 网格认领事件：包含详细的认领信息，便于前端展示 */
    event MeshClaimed(
        address indexed user,      // 认领用户
        string indexed meshID,     // 网格ID
        int32 lon100,             // 经度（以0.01度为单位）
        int32 lat100,             // 纬度（以0.01度为单位）
        uint32 applyCount,        // 申请次数
        uint256 heat,             // 热度值
        uint256 costBurned        // 燃烧成本
    );
    
    /** @dev 用户权重更新事件：当用户权重变化时触发 */
    event UserWeightUpdated(address indexed user, uint256 newWeight, uint32 claimCount);
    
    /** @dev 提取处理事件：包含详细的提取信息，便于分析 */
    event WithdrawProcessed(
        address indexed user,      // 提取用户
        uint256 payout,           // 提取数量
        uint256 burned,           // 燃烧数量
        uint256 foundation,       // 基金会分配
        uint256 carryAfter,       // 提取后结转余额
        uint256 dayIndex          // 日索引
    );
    /** @dev 代币燃烧事件：当代币被燃烧时触发 */
    event TokensBurned(uint256 amount, uint8 reasonCode); // 1=claim_cost, 2=unclaimed_decay
    
    /** @dev 认领成本燃烧事件：当用户认领网格燃烧代币时触发 */
    event ClaimCostBurned(address indexed user, string indexed meshID, uint256 amount);
    
    /** @dev 年因子更新事件：当年衰减因子更新时触发 */
    event YearFactorUpdated(uint256 indexed yearIndex, uint256 factor1e10);
    
    /** @dev 未认领衰减应用事件：当应用日衰减时触发 */
    event UnclaimedDecayApplied(
        address indexed user,      // 用户地址
        uint256 daysProcessed,     // 处理的天数
        uint256 burned,           // 燃烧数量
        uint256 foundation,       // 基金会分配
        uint256 carryAfter        // 处理后的结转余额
    );
    
    /** @dev 治理安全地址更新事件：当治理地址变更时触发 */
    event GovernanceSafeUpdated(address indexed oldSafe, address indexed newSafe);
    
    /** @dev 治理模式切换事件：当治理模式变更时触发 */
    event GovernanceModeSwitched(bool indexed isSafeGovernance, address indexed caller, uint256 timestamp);
    
    /** @dev 治理模式锁定事件：当治理模式被锁定时触发 */
    event GovernanceModeLocked(bool indexed isSafeGovernance, address indexed caller, uint256 timestamp);

    // ============ 访问控制修饰符 ============
    /** @dev 仅限治理安全地址调用的修饰符 */
    modifier onlySafe() {
        require(msg.sender == governanceSafe, "Only Safe");
        _;
    }
    
    /** @dev 仅限当前治理者调用的修饰符（Owner或Safe） */
    modifier onlyGovernance() {
        if (isSafeGovernance) {
            require(msg.sender == governanceSafe, "Only Safe governance");
        } else {
            require(msg.sender == owner(), "Only Owner governance");
        }
        _;
    }
    
    /** @dev 仅限Owner调用的修饰符（无论治理模式） */
    modifier onlyContractOwner() {
        require(msg.sender == owner(), "Only Owner");
        _;
    }

    // ============ 预计算常量 ============
    /** @dev 预计算的 (1.2 ** n) 值，当 n < 30 时使用，用于优化计算 */
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

    /**
     * @dev 构造函数，初始化Mesh代币合约
     * @param _governanceSafe 治理安全地址，用于管理合约
     * 
     * 初始化过程：
     * 1. 设置代币名称和符号
     * 2. 记录创世时间戳
     * 3. 配置治理地址
     * 4. 初始化日铸造因子
     * 5. 设置基金会转账时间
     * 6. FoundationAddr 初始化为 address(0)，后续通过 setFoundationAddress 设置
     */
    constructor(
        address _governanceSafe
    ) ERC20("Mesh Token", "MESH") {
        require(_governanceSafe != address(0), "Invalid safe address");

        // 记录创世时间戳，用于计算相对时间
        genesisTs = block.timestamp;
        
        // 设置治理地址
        governanceSafe = _governanceSafe;
        // FoundationAddr 初始化为 address(0)，后续通过 setFoundationAddress 设置
        FoundationAddr = address(0);
        
        // 初始化日因子为首日值（1e10 = 1.0，表示100%）
        dailyMintFactor = 1e10;
        lastUpdatedDay = 0;
        
        // 设置基金会转账时间（按小时计算）
        lastPayoutHour = block.timestamp / HOUR_SECONDS;
    }

    // ============ 私有辅助函数 ============
    /**
     * @dev 计算"自创世以来"的天索引
     * @return 当前时间相对于创世时间的天数索引
     * @notice 用于计算日衰减因子和用户处理进度
     */
    function _currentDayIndex() private view returns (uint256) {
        return (block.timestamp - genesisTs) / SECONDS_IN_DAY;
    }

    /**
     * @dev 计算指定日期的日铸造因子
     * @param dayIndex 日索引（相对于创世时间）
     * @return 该日的铸造因子（1e10 = 100%）
     * 
     * 算法说明：
     * - 基础因子：F0 = 1e10 (100%)
     * - 年衰减：每年衰减10%，即乘以0.9
     * - 公式：Fd = F0 * (0.9 ^ yearIndex)
     * - 使用整数运算避免浮点数精度问题
     */
    function _dailyMintFactorForDay(uint256 dayIndex) private pure returns (uint256) {
        uint256 yearIndex = dayIndex / 365;
        
        // 快速幂（定点 1e10，不缩放底数，仅整数比例）
        // 预计算 0.9^n 的 1e10 定点：逐年乘以 0.9（用 9/10 近似）
        uint256 factor = 1e10;
        for (uint256 i = 0; i < yearIndex; i++) {
            factor = (factor * 9) / 10; // 每年衰减 10%
            if (factor == 0) break; // 防止下溢
        }
        return factor;
    }

    /**
     * @dev 计算日铸造因子的等差数列和
     * @param a 起始日索引（包含）
     * @param b 结束日索引（包含）
     * @return 该区间内所有日铸造因子的和
     * 
     * 算法说明：
     * - 使用等差数列求和公式：S = (first + last) * n / 2
     * - 其中 first 和 last 分别是起始和结束日的铸造因子
     * - n 是区间内的天数
     * - 使用整数运算避免精度损失
     */
    function _sumDailyMintFactor(uint256 a, uint256 b) private pure returns (uint256) {
        if (b < a) return 0; // 无效区间
        uint256 n = b - a + 1; // 区间内的天数
        uint256 first = _dailyMintFactorForDay(a); // 起始日因子
        uint256 last = _dailyMintFactorForDay(b);  // 结束日因子
        
        // 等差数列求和：(first + last) * n / 2，按整数下取
        return ((first + last) * n) / 2;
    }

    /**
     * @dev 设置燃烧缩放比例（仅限治理地址）
     * @param _milli 缩放比例（千分位精度），范围 [0, 1_000_000]
     * 
     * 功能说明：
     * - 0：关闭燃烧机制
     * - 1000：1.000x（正常燃烧）
     * - 1000000：1000.000x（高燃烧成本）
     * 
     * 使用场景：
     * - 调整认领成本，控制网格认领频率
     * - 在代币价格波动时调整燃烧成本
     * - 根据网络活跃度动态调整参数
     * 
     * 安全特性：
     * - 仅限治理地址调用
     * - 暂停时不可调用
     * - 范围检查防止异常值
     */
    function setBurnScale(uint256 _milli) external onlyGovernance whenNotPaused {
        require(_milli <= 1_000_000, "Scale too large");
        uint256 old = burnScaleMilli;
        burnScaleMilli = _milli;
        emit BurnScaleUpdated(old, _milli);
    }

    /**
     * @dev 更新基金会地址（仅限治理地址）
     * @param _newFoundationAddr 新的基金会地址
     * 
     * 功能说明：
     * - 更新接收代币分配的基金会地址
     * - 基金会地址用于接收系统分配的部分代币
     * - 支持生态发展和项目运营
     * 
     * 安全特性：
     * - 仅限治理地址调用
     * - 暂停时不可调用
     * - 地址验证：不能为零地址
     * - 重复检查：不能设置为相同地址
     * - 首次设置：从 address(0) 设置时跳过白名单检查
     * - 后续修改：需要白名单检查
     * - 事件记录：便于追踪地址变更
     */
    function setFoundationAddress(
        address _newFoundationAddr
    ) external onlyGovernance whenNotPaused {
        require(_newFoundationAddr != address(0), "Invalid foundation address");
        require(_newFoundationAddr != FoundationAddr, "Same foundation address");
        
        // 如果是首次设置（从 address(0) 设置），跳过白名单检查
        if (FoundationAddr == address(0)) {
            address oldFoundation = FoundationAddr;
            FoundationAddr = _newFoundationAddr;
            emit FoundationAddressUpdated(oldFoundation, _newFoundationAddr);
            return;
        }
        
        // 后续修改仍需白名单检查
        require(_isApprovedByCurrentTreasury(_newFoundationAddr), "New foundation not approved by treasury");
        address oldFoundationAddr = FoundationAddr;
        FoundationAddr = _newFoundationAddr;
        emit FoundationAddressUpdated(oldFoundationAddr, _newFoundationAddr);
    }

    // 仅用于只读校验：查询当前国库（若为合约且实现方法）对白名单的认可
    function _isApprovedByCurrentTreasury(address candidate) internal view returns (bool) {
        bytes4 sel = bytes4(keccak256("isRecipientApproved(address)"));
        (bool ok, bytes memory data) = FoundationAddr.staticcall(abi.encodeWithSelector(sel, candidate));
        if (!ok || data.length == 0) return false;
        return abi.decode(data, (bool));
    }

    /**
     * @dev 紧急暂停合约（仅限当前治理者）
     */
    function pause() external onlyGovernance {
        _pause();
    }

    /**
     * @dev 恢复合约（仅限当前治理者）
     */
    function unpause() external onlyGovernance {
        _unpause();
    }

    function setGovernanceSafe(address _newSafe) external onlyGovernance whenNotPaused {
        require(_newSafe != address(0), "Invalid safe");
        require(_newSafe != governanceSafe, "Same safe");
        address old = governanceSafe;
        governanceSafe = _newSafe;
        emit GovernanceSafeUpdated(old, _newSafe);
    }
    
    /**
     * @dev 切换到Safe治理模式（仅限Owner，且只能切换一次）
     * 
     * 功能说明：
     * - 将治理权限从Owner切换到Safe
     * - 一旦切换，无法回退到Owner模式
     * - 确保治理的去中心化和安全性
     * 
     * 安全特性：
     * - 仅限Owner调用
     * - 只能切换一次，防止重复切换
     * - 暂停时不可调用
     * - 事件记录：便于追踪治理模式变更
     */
    function switchToSafeGovernance() external onlyContractOwner whenNotPaused {
        require(!governanceLocked, "Governance already locked");
        require(governanceSafe != address(0), "Safe address not set");
        require(!isSafeGovernance, "Already in Safe governance");
        
        isSafeGovernance = true;
        governanceLocked = true;
        
        emit GovernanceModeSwitched(true, msg.sender, block.timestamp);
        emit GovernanceModeLocked(true, msg.sender, block.timestamp);
    }
    
    /**
     * @dev 获取当前治理信息
     * @return _isSafeGovernance 是否为Safe治理模式
     * @return _governanceLocked 治理模式是否已锁定
     * @return _currentGovernance 当前治理者地址
     */
    function getGovernanceInfo() external view returns (
        bool _isSafeGovernance,
        bool _governanceLocked,
        address _currentGovernance
    ) {
        _isSafeGovernance = isSafeGovernance;
        _governanceLocked = governanceLocked;
        _currentGovernance = isSafeGovernance ? governanceSafe : owner();
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
     * @dev 认领网格铸造权 - 核心功能函数
     * @param _meshID 网格ID，格式为"E/W + 经度 + N/S + 纬度"（如"E123N45"）
     * 
     * 功能说明：
     * 1. 验证网格ID格式和用户资格
     * 2. 计算并扣除认领成本（如果网格已被认领过）
     * 3. 更新网格热度和用户权重
     * 4. 记录认领信息
     * 5. 触发相关事件
     * 
     * 燃烧机制：
     * - 首次认领：免费
     * - 重复认领：需要燃烧代币，成本 = baseBurnAmount * (heat^2) / maxMeshHeats * burnScaleMilli / 1000
     * - 燃烧的代币会被永久销毁，减少总供应量
     * 
     * 安全特性：
     * - 重入保护：防止重入攻击
     * - 暂停机制：紧急情况下可暂停
     * - 输入验证：确保网格ID格式正确
     * - 重复检查：防止同一用户重复认领同一网格
     */
    function ClaimMesh(string memory _meshID) 
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

        if (burnScaleMilli > 0 && _len > 0) {
            uint256 denom = maxMeshHeats == 0 ? 1 : maxMeshHeats;
            uint256 heatForCost = degreeHeats[_meshID];
            if (heatForCost == 0) {
                heatForCost = calculateDegreeHeat(_len);
            }
            // heat 为 1e18 定点，成本按 base * (heat^2/1e18) / max
            uint256 scaledHeatSq = (heatForCost * heatForCost) / 1 ether;
            uint256 _amount = (baseBurnAmount * scaledHeatSq) / denom;
            // 应用缩放（千分位），允许 <1x 或 >1x
            _amount = (_amount * burnScaleMilli) / 1000;
            // 前端预换：仅检查余额足够
            require(balanceOf(msg.sender) >= _amount, "Insufficient to burn");

            totalBurn += _amount;
            _burn(msg.sender, _amount);
            emit TokensBurned(_amount, 1);
            emit ClaimCostBurned(msg.sender, _meshID, _amount);
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

        // 记录用户第一次claim的时间戳，用于24小时提取限制
        if (userClaimCounts[msg.sender] == 1) {
            firstClaimTimestamp[msg.sender] = block.timestamp;
            // 初始化处理进度
            uint256 currentDay = _currentDayIndex();
            lastProcessedDay[msg.sender] = currentDay;
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
            burnScaleMilli > 0 && _len > 0
                ? ((((baseBurnAmount * ((_degreeHeat * _degreeHeat) / 1 ether)) / (maxMeshHeats == 0 ? 1 : maxMeshHeats)) * burnScaleMilli) / 1000)
                : 0
        );

        if (!minters[msg.sender]) {
            activeMinters++;
            minters[msg.sender] = true;
        }

        claimMints++;

        //emit ClaimMint(msg.sender, _meshID, block.timestamp);

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

    /**
     * @dev 铸造代币（内部函数）
     */
    function mint(address user, uint256 amount) private {
        uint256 _today = _currentDayIndex();
        dayMintAmount[_today] += amount;
        _mint(user, amount);
    }

    /**
     * @dev 提取收益 - 用户提取代币奖励的核心函数
     * 
     * 功能说明：
     * 1. 验证用户是否有认领记录
     * 2. 检查提取时间限制（新用户24小时限制，旧用户日限制）
     * 3. 应用未认领代币的日衰减（50%）
     * 4. 计算并发放今日应得代币
     * 5. 更新用户状态和下次提取时间
     * 6. 触发基金会转账（如果满足条件）
     * 
     * 时间限制机制：
     * - 新用户：第一次claim后24小时内可提取，提取后设置下次提取时间为24小时后
     * - 旧用户：使用原有的日限制机制（每天只能提取一次）
     * 
     * 代币计算：
     * - 今日应得 = dailyMintFactor * userWeightSum / 1e10
     * - 总发放 = 结转余额 + 今日应得
     * - 结转余额会在日衰减中减少
     * 
     * 安全特性：
     * - 重入保护：防止重入攻击
     * - 暂停机制：紧急情况下可暂停
     * - 时间限制：防止频繁提取
     * - 余额检查：确保有足够的代币可提取
     */
    function withdraw() public nonReentrant whenNotPaused {
        uint256 dayIndex = _currentDayIndex();
        require(userClaimCounts[msg.sender] > 0, "No claims");
        
        // 新用户24小时提取限制逻辑
        uint256 firstClaimTime = firstClaimTimestamp[msg.sender];
        if (firstClaimTime > 0) {
            // 检查是否在第一次claim后24小时内
            require(block.timestamp <= firstClaimTime + 24 * HOUR_SECONDS, "First claim 24h limit exceeded");
        } else {
            // 兼容旧用户：使用原来的日限制
            require(dayIndex > lastWithdrawDay[msg.sender], "Daily receive");
        }

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
        
        // 设置下次提取时间：24小时后
        if (firstClaimTime > 0) {
            // 新用户：设置下次提取时间为24小时后
            firstClaimTimestamp[user] = block.timestamp + 24 * HOUR_SECONDS;
        } else {
            // 兼容旧用户：使用原来的日限制
            lastWithdrawDay[user] = dayIndex;
        }

        emit UserMint(user, payout);
        userTotalMint[user] += payout;

        emit WithdrawProcessed(user, payout, 0, 0, carryBalance[user], dayIndex);

        _maybePayoutFoundation();
    }

    /**
     * @dev 检查用户是否可以提取
     * @param user 用户地址
     * @return canWithdraw 是否可以提取
     * @return nextWithdrawTime 下次可提取时间（0表示使用日限制）
     */
    function canUserWithdraw(address user) public view returns (bool canWithdraw, uint256 nextWithdrawTime) {
        if (userClaimCounts[user] == 0) {
            return (false, 0);
        }
        
        uint256 firstClaimTime = firstClaimTimestamp[user];
        if (firstClaimTime > 0) {
            // 新用户：检查是否在24小时内
            uint256 timeLimit = firstClaimTime + 24 * HOUR_SECONDS;
            canWithdraw = block.timestamp <= timeLimit;
            nextWithdrawTime = timeLimit;
        } else {
            // 旧用户：使用日限制
            uint256 dayIndex = _currentDayIndex();
            canWithdraw = dayIndex > lastWithdrawDay[user];
            nextWithdrawTime = 0; // 表示使用日限制
        }
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
            totalBurn += burnedTotal;
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
        if (cnt == 0 || burnScaleMilli == 0) {
            costBurned = 0;
        } else {
            uint256 baseCost = (baseBurnAmount * heat * heat) / denom;
            costBurned = (baseCost * burnScaleMilli) / 1000;
        }
    }

    function getUserState(address _user) external view returns (
        uint256 weight,
        uint32 claimCount,
        uint256 carryBalance_,
        uint256 lastProcessedDay_
    ) {
        weight = userWeightSum[_user];
        claimCount = userClaimCounts[_user];
        carryBalance_ = carryBalance[_user];
        lastProcessedDay_ = lastProcessedDay[_user];
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
     * @dev 获取仪表板数据
     */
    function getDashboard()
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
        _treasury = balanceOf(address(this));
        _foundation = balanceOf(FoundationAddr);
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
