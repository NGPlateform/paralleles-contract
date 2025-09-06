import { ethers } from "hardhat";
import { Safe, SafeTransactionDataPartial } from "@safe-global/safe-core-sdk";
import { SafeTransaction } from "@safe-global/safe-core-sdk-types";

/**
 * Safe操作管理脚本
 */
class SafeOperations {
    private safe: Safe;
    private safeManager: any;
    private signers: ethers.Signer[];

    constructor(safeAddress: string, safeManagerAddress: string, signers: ethers.Signer[]) {
        this.signers = signers;
        this.initializeContracts(safeAddress, safeManagerAddress);
    }

    private async initializeContracts(safeAddress: string, safeManagerAddress: string) {
        // 初始化SafeManager合约
        const SafeManager = await ethers.getContractFactory("SafeManager");
        this.safeManager = SafeManager.attach(safeManagerAddress);

        // 初始化Safe SDK
        // 注意：这里需要根据实际的Safe SDK版本进行调整
        console.log("Safe操作管理器已初始化");
    }

    /**
     * 提议网格认领操作
     */
    async proposeMeshClaim(meshContract: string, meshId: string, autoSwap: number) {
        console.log(`提议网格认领操作: ${meshId}`);
        
        // 编码函数调用数据
        const data = ethers.utils.defaultAbiCoder.encode(
            ["string", "uint256"],
            [meshId, autoSwap]
        );

        // 提议操作
        const tx = await this.safeManager.proposeOperation(
            0, // MESH_CLAIM
            meshContract,
            data,
            `Claim mesh: ${meshId}`
        );

        const receipt = await tx.wait();
        const operationId = receipt.events?.find(
            (event: any) => event.event === "OperationProposed"
        )?.args?.operationId;

        console.log(`操作已提议，ID: ${operationId}`);
        return operationId;
    }

    /**
     * 提议设置用户奖励
     */
    async proposeSetUserReward(
        rewardContract: string, 
        users: string[], 
        amounts: number[]
    ) {
        console.log("提议设置用户奖励操作");
        
        // 编码函数调用数据
        const data = ethers.utils.defaultAbiCoder.encode(
            ["address[]", "uint256[]"],
            [users, amounts]
        );

        // 提议操作
        const tx = await this.safeManager.proposeOperation(
            2, // REWARD_SET
            rewardContract,
            data,
            `Set user rewards for ${users.length} users`
        );

        const receipt = await tx.wait();
        const operationId = receipt.events?.find(
            (event: any) => event.event === "OperationProposed"
        )?.args?.operationId;

        console.log(`操作已提议，ID: ${operationId}`);
        return operationId;
    }

    /**
     * 提议质押操作
     */
    async proposeStake(
        stakeContract: string, 
        amount: string, 
        term: number
    ) {
        console.log(`提议质押操作: ${amount} tokens for ${term} days`);
        
        // 编码函数调用数据
        const data = ethers.utils.defaultAbiCoder.encode(
            ["uint256", "uint256"],
            [ethers.utils.parseEther(amount), term]
        );

        // 提议操作
        const tx = await this.safeManager.proposeOperation(
            4, // STAKE
            stakeContract,
            data,
            `Stake ${amount} tokens for ${term} days`
        );

        const receipt = await tx.wait();
        const operationId = receipt.events?.find(
            (event: any) => event.event === "OperationProposed"
        )?.args?.operationId;

        console.log(`操作已提议，ID: ${operationId}`);
        return operationId;
    }

    /**
     * 执行操作
     */
    async executeOperation(operationId: string) {
        console.log(`执行操作: ${operationId}`);
        
        const tx = await this.safeManager.executeOperation(operationId);
        const receipt = await tx.wait();
        
        if (receipt.status === 1) {
            console.log(`操作执行成功: ${operationId}`);
            return true;
        } else {
            console.log(`操作执行失败: ${operationId}`);
            return false;
        }
    }

    /**
     * 批量执行操作
     */
    async batchExecuteOperations(operationIds: string[]) {
        console.log(`批量执行 ${operationIds.length} 个操作`);
        
        const tx = await this.safeManager.batchExecuteOperations(operationIds);
        const receipt = await tx.wait();
        
        if (receipt.status === 1) {
            console.log("批量操作执行成功");
            return true;
        } else {
            console.log("批量操作执行失败");
            return false;
        }
    }

    /**
     * 获取操作信息
     */
    async getOperationInfo(operationId: string) {
        const operation = await this.safeManager.getOperation(operationId);
        
        const operationTypes = [
            "MESH_CLAIM", "MESH_WITHDRAW", "REWARD_SET", "REWARD_WITHDRAW",
            "STAKE", "STAKE_WITHDRAW", "EMERGENCY_PAUSE", "EMERGENCY_RESUME"
        ];

        return {
            operationId,
            type: operationTypes[operation.opType],
            target: operation.target,
            data: operation.data,
            timestamp: new Date(operation.timestamp * 1000).toISOString(),
            executed: operation.executed,
            description: operation.description
        };
    }

    /**
     * 获取待执行操作列表
     */
    async getPendingOperations() {
        const operationCount = await this.safeManager.getOperationCount();
        const pendingOperations = [];

        for (let i = 0; i < operationCount.toNumber(); i++) {
            // 这里需要实现获取所有操作的逻辑
            // 由于合约限制，可能需要其他方式获取
        }

        return pendingOperations;
    }

    /**
     * 紧急暂停
     */
    async emergencyPause() {
        console.log("执行紧急暂停");
        
        const tx = await this.safeManager.emergencyPause();
        const receipt = await tx.wait();
        
        if (receipt.status === 1) {
            console.log("紧急暂停执行成功");
            return true;
        } else {
            console.log("紧急暂停执行失败");
            return false;
        }
    }

    /**
     * 紧急恢复
     */
    async emergencyResume() {
        console.log("执行紧急恢复");
        
        const tx = await this.safeManager.emergencyResume();
        const receipt = await tx.wait();
        
        if (receipt.status === 1) {
            console.log("紧急恢复执行成功");
            return true;
        } else {
            console.log("紧急恢复执行失败");
            return false;
        }
    }
}

/**
 * 主函数 - 演示Safe操作
 */
async function main() {
    console.log("Safe操作管理演示");

    // 从环境变量或配置文件读取地址
    const safeAddress = process.env.SAFE_ADDRESS;
    const safeManagerAddress = process.env.SAFE_MANAGER_ADDRESS;
    
    if (!safeAddress || !safeManagerAddress) {
        console.error("请设置环境变量: SAFE_ADDRESS, SAFE_MANAGER_ADDRESS");
        process.exit(1);
    }

    // 获取签名者
    const signers = await ethers.getSigners();
    
    // 初始化Safe操作管理器
    const safeOps = new SafeOperations(safeAddress, safeManagerAddress, signers);

    try {
        // 示例：提议网格认领操作
        const meshContract = process.env.MESH_CONTRACT_ADDRESS;
        if (meshContract) {
            const operationId = await safeOps.proposeMeshClaim(
                meshContract,
                "E11396N2247",
                0
            );
            console.log(`网格认领操作提议成功，ID: ${operationId}`);
        }

        // 示例：获取操作信息
        const operationId = process.env.OPERATION_ID;
        if (operationId) {
            const operationInfo = await safeOps.getOperationInfo(operationId);
            console.log("操作信息:", operationInfo);
        }

        // 示例：执行操作
        if (operationId) {
            const success = await safeOps.executeOperation(operationId);
            console.log(`操作执行结果: ${success ? "成功" : "失败"}`);
        }

    } catch (error) {
        console.error("操作执行过程中发生错误:", error);
    }
}

// 如果直接运行此脚本
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

export { SafeOperations };
