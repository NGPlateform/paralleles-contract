// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./SafeManager.sol";

/**
 * @title AutomatedExecutor
 * @dev 自动化执行器，用于自动执行Safe操作
 */
contract AutomatedExecutor is AccessControl, ReentrancyGuard, Pausable {
    
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    SafeManager public safeManager;
    
    // 执行规则配置
    struct ExecutionRule {
        bool enabled;           // 是否启用
        uint256 minInterval;    // 最小执行间隔
        uint256 maxGasPrice;    // 最大Gas价格
        uint256 maxBatchSize;   // 最大批量大小
        uint256 lastExecution;  // 上次执行时间
    }
    
    // 操作队列
    struct QueuedOperation {
        bytes32 operationId;
        uint256 priority;       // 优先级 (1-10, 10最高)
        uint256 timestamp;      // 入队时间
        bool executed;          // 是否已执行
        uint256 retryCount;     // 重试次数
        uint256 maxRetries;     // 最大重试次数
    }
    
    mapping(bytes32 => ExecutionRule) public executionRules;
    mapping(bytes32 => QueuedOperation) public queuedOperations;
    bytes32[] public operationQueue;
    
    uint256 public constant MAX_RETRIES = 3;
    uint256 public constant MAX_QUEUE_SIZE = 1000;
    
    event OperationQueued(bytes32 indexed operationId, uint256 priority);
    event OperationExecuted(bytes32 indexed operationId, bool success);
    event ExecutionRuleUpdated(bytes32 indexed ruleId, bool enabled, uint256 minInterval);
    event BatchExecuted(uint256 count, uint256 successCount);
    
    modifier onlyExecutor() {
        require(hasRole(EXECUTOR_ROLE, msg.sender), "AutomatedExecutor: Only executor can call");
        _;
    }
    
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "AutomatedExecutor: Only admin can call");
        _;
    }
    
    constructor(address _safeManager) {
        safeManager = SafeManager(_safeManager);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        
        // 初始化默认执行规则
        _initializeDefaultRules();
    }
    
    /**
     * @dev 初始化默认执行规则
     */
    function _initializeDefaultRules() private {
        // 网格认领规则
        executionRules[keccak256("MESH_CLAIM")] = ExecutionRule({
            enabled: true,
            minInterval: 1 minutes,
            maxGasPrice: 5 gwei,
            maxBatchSize: 50,
            lastExecution: 0
        });
        
        // 奖励设置规则
        executionRules[keccak256("REWARD_SET")] = ExecutionRule({
            enabled: true,
            minInterval: 5 minutes,
            maxGasPrice: 10 gwei,
            maxBatchSize: 100,
            lastExecution: 0
        });
        
        // 质押操作规则
        executionRules[keccak256("STAKE")] = ExecutionRule({
            enabled: true,
            minInterval: 2 minutes,
            maxGasPrice: 8 gwei,
            maxBatchSize: 30,
            lastExecution: 0
        });
    }
    
    /**
     * @dev 将操作加入队列
     */
    function queueOperation(
        bytes32 _operationId,
        uint256 _priority
    ) external onlyExecutor returns (bool) {
        require(_priority >= 1 && _priority <= 10, "Invalid priority");
        require(operationQueue.length < MAX_QUEUE_SIZE, "Queue full");
        require(!queuedOperations[_operationId].executed, "Operation already executed");
        
        // 检查操作是否已存在
        if (queuedOperations[_operationId].timestamp > 0) {
            return false;
        }
        
        queuedOperations[_operationId] = QueuedOperation({
            operationId: _operationId,
            priority: _priority,
            timestamp: block.timestamp,
            executed: false,
            retryCount: 0,
            maxRetries: MAX_RETRIES
        });
        
        operationQueue.push(_operationId);
        
        emit OperationQueued(_operationId, _priority);
        return true;
    }
    
    /**
     * @dev 批量执行队列中的操作
     */
    function executeBatch(uint256 _maxCount) external onlyExecutor nonReentrant returns (uint256 successCount) {
        require(_maxCount > 0, "Invalid batch size");
        require(!paused(), "Contract is paused");
        
        uint256 executedCount = 0;
        successCount = 0;
        
        // 按优先级排序队列
        _sortQueueByPriority();
        
        for (uint256 i = 0; i < operationQueue.length && executedCount < _maxCount; i++) {
            bytes32 operationId = operationQueue[i];
            QueuedOperation storage operation = queuedOperations[operationId];
            
            if (operation.executed || operation.retryCount >= operation.maxRetries) {
                continue;
            }
            
            // 检查执行规则
            if (!_canExecuteOperation(operationId)) {
                continue;
            }
            
            // 尝试执行操作
            try this.executeSingleOperation(operationId) {
                operation.executed = true;
                successCount++;
            } catch {
                operation.retryCount++;
                if (operation.retryCount >= operation.maxRetries) {
                    // 达到最大重试次数，标记为失败
                    operation.executed = true;
                }
            }
            
            executedCount++;
        }
        
        // 清理已执行的操作
        _cleanupExecutedOperations();
        
        emit BatchExecuted(executedCount, successCount);
        return successCount;
    }
    
    /**
     * @dev 执行单个操作
     */
    function executeSingleOperation(bytes32 _operationId) external onlyExecutor {
        QueuedOperation storage operation = queuedOperations[_operationId];
        require(operation.timestamp > 0, "Operation not found");
        require(!operation.executed, "Operation already executed");
        require(operation.retryCount < operation.maxRetries, "Max retries reached");
        
        // 检查执行规则
        require(_canExecuteOperation(_operationId), "Execution rules not met");
        
        // 通过SafeManager执行操作
        (bool success, ) = safeManager.executeOperation(_operationId);
        
        if (success) {
            operation.executed = true;
            emit OperationExecuted(_operationId, true);
        } else {
            operation.retryCount++;
            emit OperationExecuted(_operationId, false);
        }
    }
    
    /**
     * @dev 检查操作是否可以执行
     */
    function _canExecuteOperation(bytes32 _operationId) private view returns (bool) {
        // 获取操作类型
        SafeManager.OperationType opType = _getOperationType(_operationId);
        bytes32 ruleId = keccak256(abi.encodePacked("RULE_", uint256(opType)));
        
        ExecutionRule storage rule = executionRules[ruleId];
        if (!rule.enabled) {
            return false;
        }
        
        // 检查执行间隔
        if (block.timestamp - rule.lastExecution < rule.minInterval) {
            return false;
        }
        
        // 检查Gas价格
        if (tx.gasprice > rule.maxGasPrice) {
            return false;
        }
        
        return true;
    }
    
    /**
     * @dev 获取操作类型（简化实现）
     */
    function _getOperationType(bytes32 _operationId) private view returns (SafeManager.OperationType) {
        // 这里需要根据实际的SafeManager实现来获取操作类型
        // 暂时返回默认值
        return SafeManager.OperationType.MESH_CLAIM;
    }
    
    /**
     * @dev 按优先级排序队列
     */
    function _sortQueueByPriority() private {
        // 简单的冒泡排序，实际项目中可以使用更高效的算法
        for (uint256 i = 0; i < operationQueue.length - 1; i++) {
            for (uint256 j = 0; j < operationQueue.length - i - 1; j++) {
                if (queuedOperations[operationQueue[j]].priority < 
                    queuedOperations[operationQueue[j + 1]].priority) {
                    bytes32 temp = operationQueue[j];
                    operationQueue[j] = operationQueue[j + 1];
                    operationQueue[j + 1] = temp;
                }
            }
        }
    }
    
    /**
     * @dev 清理已执行的操作
     */
    function _cleanupExecutedOperations() private {
        uint256 i = 0;
        while (i < operationQueue.length) {
            if (queuedOperations[operationQueue[i]].executed) {
                // 移除已执行的操作
                operationQueue[i] = operationQueue[operationQueue.length - 1];
                operationQueue.pop();
                delete queuedOperations[operationQueue[i]];
            } else {
                i++;
            }
        }
    }
    
    /**
     * @dev 更新执行规则
     */
    function updateExecutionRule(
        bytes32 _ruleId,
        bool _enabled,
        uint256 _minInterval,
        uint256 _maxGasPrice,
        uint256 _maxBatchSize
    ) external onlyAdmin {
        executionRules[_ruleId] = ExecutionRule({
            enabled: _enabled,
            minInterval: _minInterval,
            maxGasPrice: _maxGasPrice,
            maxBatchSize: _maxBatchSize,
            lastExecution: executionRules[_ruleId].lastExecution
        });
        
        emit ExecutionRuleUpdated(_ruleId, _enabled, _minInterval);
    }
    
    /**
     * @dev 获取队列状态
     */
    function getQueueStatus() external view returns (
        uint256 totalQueued,
        uint256 pendingExecutions,
        uint256 failedOperations
    ) {
        totalQueued = operationQueue.length;
        uint256 pending = 0;
        uint256 failed = 0;
        
        for (uint256 i = 0; i < operationQueue.length; i++) {
            QueuedOperation storage operation = queuedOperations[operationQueue[i]];
            if (!operation.executed) {
                pending++;
                if (operation.retryCount >= operation.maxRetries) {
                    failed++;
                }
            }
        }
        
        pendingExecutions = pending;
        failedOperations = failed;
    }
    
    /**
     * @dev 获取操作详情
     */
    function getOperationDetails(bytes32 _operationId) external view returns (
        uint256 priority,
        uint256 timestamp,
        bool executed,
        uint256 retryCount,
        uint256 maxRetries
    ) {
        QueuedOperation storage operation = queuedOperations[_operationId];
        return (
            operation.priority,
            operation.timestamp,
            operation.executed,
            operation.retryCount,
            operation.maxRetries
        );
    }
    
    /**
     * @dev 紧急暂停
     */
    function emergencyPause() external onlyAdmin {
        _pause();
    }
    
    /**
     * @dev 紧急恢复
     */
    function emergencyResume() external onlyAdmin {
        _unpause();
    }
    
    /**
     * @dev 设置SafeManager地址
     */
    function setSafeManager(address _safeManager) external onlyAdmin {
        require(_safeManager != address(0), "Invalid address");
        safeManager = SafeManager(_safeManager);
    }
}
