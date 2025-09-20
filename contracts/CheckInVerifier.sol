// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title CheckInVerifier - 位置打卡验证器合约
 * @dev 位置打卡与寻宝资格的链上验证器，由链下Chainlink节点/作业回调写入结果
 * 
 * 核心功能：
 * 1. 位置验证：验证用户是否在指定位置范围内
 * 2. 活动资格：判断用户是否满足特定活动的参与条件
 * 3. 防作弊机制：通过链下验证防止位置伪造
 * 4. 结果存储：将验证结果存储在链上供其他合约查询
 * 
 * 工作机制：
 * 1. 用户或业务合约调用requestCheckIn发起位置校验请求
 * 2. 事件被链下Chainlink Job监听
 * 3. 链下作业通过定位服务和防作弊逻辑判断是否满足条件
 * 4. 作业以oracle身份调用fulfillCheckIn，将结果上链
 * 5. 奖励合约通过isEligible(activityId,user)读取结果
 * 
 * 安全特性：
 * - 重入保护：防止重入攻击
 * - 访问控制：仅限Owner和Oracle调用
 * - 数据验证：确保位置数据的有效性
 * - 防重放：防止重复验证
 * 
 * @author Parallels Team
 * @notice 本合约实现了基于位置的活动资格验证系统
 */
contract CheckInVerifier is Ownable, ReentrancyGuard {
    /**
     * @dev 打卡请求结构体
     * @param user 用户地址
     * @param activityId 活动/关卡/寻宝编号
     * @param latE6 纬度（放大1e6，如123456表示12.3456度）
     * @param lonE6 经度（放大1e6，如123456表示12.3456度）
     * @param radiusM 验证半径（米）
     * @param timestamp 请求时间戳
     * @param fulfilled 是否已完成验证
     */
    struct CheckInRequest {
        address user;        // 用户地址
        uint256 activityId;  // 活动/关卡/寻宝编号
        int256 latE6;        // 纬度（放大1e6）
        int256 lonE6;        // 经度（放大1e6）
        uint256 radiusM;     // 验证半径（米）
        uint256 timestamp;   // 请求时间戳
        bool fulfilled;      // 是否已完成验证
    }

    // ============ 合约地址配置 ============
    /** @dev Chainlink节点（或OCR聚合合约）的回调地址 */
    address public oracle;

    // ============ 数据映射 ============
    /** @dev 打卡请求映射：请求ID => 请求信息 */
    mapping(bytes32 => CheckInRequest) public requests;
    
    /** @dev 用户资格映射：活动ID => 用户地址 => 是否合格 */
    mapping(uint256 => mapping(address => bool)) public eligible;

    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event CheckInRequested(
        bytes32 indexed requestId,
        address indexed user,
        uint256 indexed activityId,
        int256 latE6,
        int256 lonE6,
        uint256 radiusM,
        uint256 timestamp
    );
    event CheckInFulfilled(
        bytes32 indexed requestId,
        address indexed user,
        uint256 indexed activityId,
        bool eligible
    );

    modifier onlyOracle() {
        require(msg.sender == oracle, "CheckInVerifier: only oracle");
        _;
    }

    constructor(address _oracle) {
        require(_oracle != address(0), "CheckInVerifier: invalid oracle");
        oracle = _oracle;
    }

    function setOracle(address _newOracle) external onlyOwner {
        require(_newOracle != address(0), "CheckInVerifier: invalid oracle");
        address old = oracle;
        oracle = _newOracle;
        emit OracleUpdated(old, _newOracle);
    }

    /**
     * @notice 发起位置校验请求
     * @dev 通常由前端/合约代表用户调用；链下监听该事件并回调 fulfillCheckIn
     */
    function requestCheckIn(
        uint256 activityId,
        int256 latE6,
        int256 lonE6,
        uint256 radiusM
    ) external nonReentrant returns (bytes32 requestId) {
        require(radiusM > 0, "CheckInVerifier: radiusM=0");
        requestId = keccak256(
            abi.encodePacked(msg.sender, activityId, latE6, lonE6, radiusM, block.timestamp)
        );
        CheckInRequest storage r = requests[requestId];
        require(r.timestamp == 0, "CheckInVerifier: duplicate");
        r.user = msg.sender;
        r.activityId = activityId;
        r.latE6 = latE6;
        r.lonE6 = lonE6;
        r.radiusM = radiusM;
        r.timestamp = block.timestamp;

        emit CheckInRequested(requestId, msg.sender, activityId, latE6, lonE6, radiusM, block.timestamp);
    }

    /**
     * @notice 链下 Chainlink 作业回调写入判定结果
     */
    function fulfillCheckIn(bytes32 requestId, bool isEligible) external onlyOracle nonReentrant {
        CheckInRequest storage r = requests[requestId];
        require(r.timestamp != 0, "CheckInVerifier: request not found");
        require(!r.fulfilled, "CheckInVerifier: already fulfilled");
        r.fulfilled = true;

        if (isEligible) {
            eligible[r.activityId][r.user] = true;
        }

        emit CheckInFulfilled(requestId, r.user, r.activityId, isEligible);
    }

    function isEligible(uint256 activityId, address user) external view returns (bool) {
        return eligible[activityId][user];
    }
}




