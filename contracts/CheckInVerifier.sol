// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title CheckInVerifier
 * @notice 位置打卡与寻宝资格的链上验证器，由链下 Chainlink 节点/作业回调写入结果
 * 机制概述：
 * 1) 用户或业务合约调用 requestCheckIn 发起位置校验请求，事件被链下 Chainlink Job 监听。
 * 2) 链下作业（通过定位服务与防作弊逻辑）判断是否满足 geofence/radius 条件。
 * 3) 作业以 oracle 身份调用 fulfillCheckIn，将 eligibility 结果上链。
 * 4) 奖励合约通过 isEligible(activityId,user) 读取结果，完成发奖 gating。
 */
contract CheckInVerifier is Ownable, ReentrancyGuard {
    struct CheckInRequest {
        address user;
        uint256 activityId; // 活动/关卡/寻宝编号
        int256 latE6;       // 纬度（放大 1e6）
        int256 lonE6;       // 经度（放大 1e6）
        uint256 radiusM;    // 半径（米）
        uint256 timestamp;  // 请求时间
        bool fulfilled;
    }

    // Chainlink 节点（或 OCR 聚合合约）的回调地址
    address public oracle;

    // requestId => 请求信息
    mapping(bytes32 => CheckInRequest) public requests;
    // activityId => user => 是否合格
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



