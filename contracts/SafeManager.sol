// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title SafeManager
 * @dev 管理Gnosis Safe多签钱包的集成
 */
contract SafeManager is Ownable, ReentrancyGuard, Pausable {
    
    // Gnosis Safe地址
    address public safeAddress;
    
    // 操作类型枚举
    enum OperationType {
        MESH_CLAIM,      // 网格认领
        MESH_WITHDRAW,   // 网格收益提取
        REWARD_SET,      // 设置奖励
        REWARD_WITHDRAW, // 提取奖励
        STAKE,           // 质押
        STAKE_WITHDRAW,  // 质押提取
        EMERGENCY_PAUSE, // 紧急暂停
        EMERGENCY_RESUME // 紧急恢复
    }
    
    // 操作状态
    struct Operation {
        OperationType opType;
        address target;
        bytes data;
        uint256 timestamp;
        bool executed;
        string description;
    }
    
    // 操作映射
    mapping(bytes32 => Operation) public operations;
    
    // 操作计数器
    uint256 public operationCount;
    
    // 事件
    event SafeAddressUpdated(address indexed oldSafe, address indexed newSafe);
    event OperationProposed(
        bytes32 indexed operationId,
        OperationType opType,
        address target,
        string description
    );
    event OperationExecuted(bytes32 indexed operationId);
    event OperationCancelled(bytes32 indexed operationId);
    
    // 修饰符
    modifier onlySafe() {
        require(msg.sender == safeAddress, "SafeManager: Only Safe can call");
        _;
    }
    
    modifier operationExists(bytes32 operationId) {
        require(operations[operationId].timestamp > 0, "SafeManager: Operation does not exist");
        _;
    }
    
    modifier operationNotExecuted(bytes32 operationId) {
        require(!operations[operationId].executed, "SafeManager: Operation already executed");
        _;
    }
    
    constructor(address _safeAddress) {
        require(_safeAddress != address(0), "SafeManager: Invalid Safe address");
        safeAddress = _safeAddress;
    }
    
    /**
     * @dev 更新Safe地址（仅限所有者）
     */
    function updateSafeAddress(address _newSafeAddress) external onlyOwner {
        require(_newSafeAddress != address(0), "SafeManager: Invalid Safe address");
        require(_newSafeAddress != safeAddress, "SafeManager: Same Safe address");
        
        address oldSafe = safeAddress;
        safeAddress = _newSafeAddress;
        
        emit SafeAddressUpdated(oldSafe, _newSafeAddress);
    }
    
    /**
     * @dev 提议操作（仅限Safe）
     */
    function proposeOperation(
        OperationType _opType,
        address _target,
        bytes calldata _data,
        string calldata _description
    ) external onlySafe returns (bytes32) {
        require(_target != address(0), "SafeManager: Invalid target address");
        
        bytes32 operationId = keccak256(
            abi.encodePacked(
                _opType,
                _target,
                _data,
                block.timestamp,
                operationCount
            )
        );
        
        operations[operationId] = Operation({
            opType: _opType,
            target: _target,
            data: _data,
            timestamp: block.timestamp,
            executed: false,
            description: _description
        });
        
        operationCount++;
        
        emit OperationProposed(operationId, _opType, _target, _description);
        
        return operationId;
    }
    
    /**
     * @dev 执行操作（仅限Safe）
     */
    function executeOperation(bytes32 _operationId) 
        external 
        onlySafe 
        operationExists(_operationId) 
        operationNotExecuted(_operationId)
        nonReentrant 
        returns (bool success, bytes memory returnData) 
    {
        Operation storage operation = operations[_operationId];
        
        // 执行操作
        (success, returnData) = operation.target.call(operation.data);
        
        if (success) {
            operation.executed = true;
            emit OperationExecuted(_operationId);
        }
        
        return (success, returnData);
    }
    
    /**
     * @dev 取消操作（仅限Safe）
     */
    function cancelOperation(bytes32 _operationId) 
        external 
        onlySafe 
        operationExists(_operationId) 
        operationNotExecuted(_operationId) 
    {
        delete operations[_operationId];
        emit OperationCancelled(_operationId);
    }
    
    /**
     * @dev 获取操作信息
     */
    function getOperation(bytes32 _operationId) 
        external 
        view 
        returns (
            OperationType opType,
            address target,
            bytes memory data,
            uint256 timestamp,
            bool executed,
            string memory description
        ) 
    {
        Operation memory operation = operations[_operationId];
        return (
            operation.opType,
            operation.target,
            operation.data,
            operation.timestamp,
            operation.executed,
            operation.description
        );
    }
    
    /**
     * @dev 检查操作是否有效
     */
    function isValidOperation(bytes32 _operationId) external view returns (bool) {
        Operation memory operation = operations[_operationId];
        return operation.timestamp > 0 && !operation.executed;
    }
    
    /**
     * @dev 获取操作计数
     */
    function getOperationCount() external view returns (uint256) {
        return operationCount;
    }
    
    /**
     * @dev 紧急暂停（仅限Safe）
     */
    function emergencyPause() external onlySafe {
        _pause();
    }
    
    /**
     * @dev 紧急恢复（仅限Safe）
     */
    function emergencyResume() external onlySafe {
        _unpause();
    }
    
    /**
     * @dev 批量执行操作
     */
    function batchExecuteOperations(bytes32[] calldata _operationIds) 
        external 
        onlySafe 
        nonReentrant 
        returns (bool[] memory successes, bytes[] memory returnDatas) 
    {
        uint256 length = _operationIds.length;
        successes = new bool[](length);
        returnDatas = new bytes[](length);
        
        for (uint256 i = 0; i < length; i++) {
            bytes32 operationId = _operationIds[i];
            
            if (operations[operationId].timestamp > 0 && !operations[operationId].executed) {
                Operation storage operation = operations[operationId];
                
                (bool success, bytes memory returnData) = operation.target.call(operation.data);
                
                if (success) {
                    operation.executed = true;
                    emit OperationExecuted(operationId);
                }
                
                successes[i] = success;
                returnDatas[i] = returnData;
            } else {
                successes[i] = false;
            }
        }
    }
    
    /**
     * @dev 获取待执行操作列表
     */
    function getPendingOperations(uint256 _startIndex, uint256 _endIndex) 
        external 
        view 
        returns (bytes32[] memory pendingIds, Operation[] memory pendingOps) 
    {
        require(_startIndex < _endIndex, "SafeManager: Invalid index range");
        require(_endIndex <= operationCount, "SafeManager: Index out of range");
        
        uint256 count = _endIndex - _startIndex;
        pendingIds = new bytes32[](count);
        pendingOps = new Operation[](count);
        
        uint256 pendingCount = 0;
        for (uint256 i = _startIndex; i < _endIndex; i++) {
            // 这里需要遍历所有操作来找到待执行的
            // 实际实现中可能需要维护一个待执行操作列表
        }
        
        // 调整数组大小
        assembly {
            mstore(pendingIds, pendingCount)
            mstore(pendingOps, pendingCount)
        }
    }
}
