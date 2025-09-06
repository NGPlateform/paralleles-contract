import { ethers } from "hardhat";
import { SafeOperations } from "./safe-operations";

/**
 * 链下自动化服务
 * 用于监控和执行Safe操作
 */
class AutomationService {
    private safeOps: SafeOperations;
    private isRunning: boolean = false;
    private executionInterval: number = 30000; // 30秒
    private maxBatchSize: number = 50;
    
    // 执行规则配置
    private executionRules = {
        meshClaim: {
            enabled: true,
            minInterval: 60000, // 1分钟
            maxGasPrice: ethers.utils.parseUnits("5", "gwei"),
            priority: 8
        },
        rewardSet: {
            enabled: true,
            minInterval: 300000, // 5分钟
            maxGasPrice: ethers.utils.parseUnits("10", "gwei"),
            priority: 6
        },
        stake: {
            enabled: true,
            minInterval: 120000, // 2分钟
            maxGasPrice: ethers.utils.parseUnits("8", "gwei"),
            priority: 7
        }
    };
    
    // 操作队列
    private operationQueue: Array<{
        id: string;
        type: string;
        data: any;
        priority: number;
        timestamp: number;
        retryCount: number;
    }> = [];
    
    // 执行历史
    private executionHistory: Map<string, {
        success: boolean;
        timestamp: number;
        gasUsed: number;
        error?: string;
    }> = new Map();
    
    constructor(safeAddress: string, safeManagerAddress: string) {
        this.safeOps = new SafeOperations(safeAddress, safeManagerAddress, []);
        this.loadConfiguration();
    }
    
    /**
     * 启动自动化服务
     */
    async start() {
        if (this.isRunning) {
            console.log("服务已在运行中");
            return;
        }
        
        console.log("启动自动化服务...");
        this.isRunning = true;
        
        // 启动监控循环
        this.startMonitoringLoop();
        
        // 启动执行循环
        this.startExecutionLoop();
        
        console.log("自动化服务已启动");
    }
    
    /**
     * 停止自动化服务
     */
    stop() {
        console.log("停止自动化服务...");
        this.isRunning = false;
    }
    
    /**
     * 启动监控循环
     */
    private startMonitoringLoop() {
        setInterval(async () => {
            if (!this.isRunning) return;
            
            try {
                await this.monitorNewOperations();
            } catch (error) {
                console.error("监控循环错误:", error);
            }
        }, 10000); // 每10秒监控一次
    }
    
    /**
     * 启动执行循环
     */
    private startExecutionLoop() {
        setInterval(async () => {
            if (!this.isRunning) return;
            
            try {
                await this.processOperationQueue();
            } catch (error) {
                console.error("执行循环错误:", error);
            }
        }, this.executionInterval);
    }
    
    /**
     * 监控新操作
     */
    private async monitorNewOperations() {
        // 这里应该监控区块链事件或API来获取新操作
        // 示例：监控用户提交的网格认领请求
        
        // 模拟监控逻辑
        const newOperations = await this.detectNewOperations();
        
        for (const operation of newOperations) {
            await this.queueOperation(operation);
        }
    }
    
    /**
     * 检测新操作（示例实现）
     */
    private async detectNewOperations(): Promise<any[]> {
        // 这里应该实现实际的检测逻辑
        // 例如：监控合约事件、API调用等
        
        const newOperations = [];
        
        // 模拟检测到新操作
        if (Math.random() > 0.8) { // 20%概率检测到新操作
            newOperations.push({
                type: "meshClaim",
                data: {
                    meshId: `E${Math.floor(Math.random() * 10000)}N${Math.floor(Math.random() * 10000)}`,
                    autoSwap: 0
                },
                priority: this.executionRules.meshClaim.priority
            });
        }
        
        return newOperations;
    }
    
    /**
     * 将操作加入队列
     */
    private async queueOperation(operation: any) {
        const operationId = this.generateOperationId(operation);
        
        // 检查是否已在队列中
        if (this.operationQueue.find(op => op.id === operationId)) {
            return;
        }
        
        const queuedOperation = {
            id: operationId,
            type: operation.type,
            data: operation.data,
            priority: operation.priority,
            timestamp: Date.now(),
            retryCount: 0
        };
        
        this.operationQueue.push(queuedOperation);
        
        // 按优先级排序
        this.sortQueueByPriority();
        
        console.log(`操作已加入队列: ${operationId} (${operation.type})`);
    }
    
    /**
     * 处理操作队列
     */
    private async processOperationQueue() {
        if (this.operationQueue.length === 0) {
            return;
        }
        
        console.log(`处理操作队列，当前队列长度: ${this.operationQueue.length}`);
        
        const batchSize = Math.min(this.maxBatchSize, this.operationQueue.length);
        const batch = this.operationQueue.splice(0, batchSize);
        
        let successCount = 0;
        
        for (const operation of batch) {
            try {
                const success = await this.executeOperation(operation);
                if (success) {
                    successCount++;
                }
            } catch (error) {
                console.error(`执行操作失败: ${operation.id}`, error);
                await this.handleOperationFailure(operation);
            }
        }
        
        console.log(`批量执行完成: ${successCount}/${batch.length} 成功`);
    }
    
    /**
     * 执行单个操作
     */
    private async executeOperation(operation: any): Promise<boolean> {
        try {
            // 检查执行规则
            if (!this.canExecuteOperation(operation)) {
                // 重新加入队列
                this.operationQueue.push(operation);
                return false;
            }
            
            // 检查Gas价格
            const currentGasPrice = await this.getCurrentGasPrice();
            if (currentGasPrice.gt(this.executionRules[operation.type]?.maxGasPrice || ethers.constants.MaxUint256)) {
                console.log(`Gas价格过高，跳过操作: ${operation.id}`);
                this.operationQueue.push(operation);
                return false;
            }
            
            console.log(`执行操作: ${operation.id} (${operation.type})`);
            
            let success = false;
            let gasUsed = 0;
            
            // 根据操作类型执行
            switch (operation.type) {
                case "meshClaim":
                    success = await this.executeMeshClaim(operation.data);
                    break;
                case "rewardSet":
                    success = await this.executeRewardSet(operation.data);
                    break;
                case "stake":
                    success = await this.executeStake(operation.data);
                    break;
                default:
                    console.warn(`未知操作类型: ${operation.type}`);
                    return false;
            }
            
            // 记录执行历史
            this.executionHistory.set(operation.id, {
                success,
                timestamp: Date.now(),
                gasUsed
            });
            
            return success;
            
        } catch (error) {
            console.error(`执行操作异常: ${operation.id}`, error);
            return false;
        }
    }
    
    /**
     * 执行网格认领
     */
    private async executeMeshClaim(data: any): Promise<boolean> {
        try {
            // 这里应该调用实际的Safe操作
            // const operationId = await this.safeOps.proposeMeshClaim(
            //     data.meshContract,
            //     data.meshId,
            //     data.autoSwap
            // );
            
            console.log(`网格认领提议成功: ${data.meshId}`);
            return true;
        } catch (error) {
            console.error("网格认领失败:", error);
            return false;
        }
    }
    
    /**
     * 执行奖励设置
     */
    private async executeRewardSet(data: any): Promise<boolean> {
        try {
            // 这里应该调用实际的Safe操作
            console.log(`奖励设置提议成功: ${data.users.length} 用户`);
            return true;
        } catch (error) {
            console.error("奖励设置失败:", error);
            return false;
        }
    }
    
    /**
     * 执行质押操作
     */
    private async executeStake(data: any): Promise<boolean> {
        try {
            // 这里应该调用实际的Safe操作
            console.log(`质押操作提议成功: ${data.amount} tokens for ${data.term} days`);
            return true;
        } catch (error) {
            console.error("质押操作失败:", error);
            return false;
        }
    }
    
    /**
     * 处理操作失败
     */
    private async handleOperationFailure(operation: any) {
        operation.retryCount++;
        
        if (operation.retryCount < 3) {
            // 重新加入队列，降低优先级
            operation.priority = Math.max(1, operation.priority - 1);
            this.operationQueue.push(operation);
            console.log(`操作重新加入队列: ${operation.id} (重试 ${operation.retryCount}/3)`);
        } else {
            console.log(`操作达到最大重试次数: ${operation.id}`);
            // 可以发送告警或记录到失败日志
        }
    }
    
    /**
     * 检查操作是否可以执行
     */
    private canExecuteOperation(operation: any): boolean {
        const rule = this.executionRules[operation.type];
        if (!rule || !rule.enabled) {
            return false;
        }
        
        // 检查执行间隔
        const timeSinceLastExecution = Date.now() - operation.timestamp;
        if (timeSinceLastExecution < rule.minInterval) {
            return false;
        }
        
        return true;
    }
    
    /**
     * 按优先级排序队列
     */
    private sortQueueByPriority() {
        this.operationQueue.sort((a, b) => b.priority - a.priority);
    }
    
    /**
     * 生成操作ID
     */
    private generateOperationId(operation: any): string {
        return ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ["string", "uint256", "uint256"],
                [operation.type, operation.timestamp, Math.random()]
            )
        );
    }
    
    /**
     * 获取当前Gas价格
     */
    private async getCurrentGasPrice(): Promise<ethers.BigNumber> {
        try {
            const provider = ethers.provider;
            return await provider.getGasPrice();
        } catch (error) {
            console.error("获取Gas价格失败:", error);
            return ethers.constants.Zero;
        }
    }
    
    /**
     * 加载配置
     */
    private loadConfiguration() {
        // 从环境变量或配置文件加载配置
        const config = {
            executionInterval: process.env.EXECUTION_INTERVAL || 30000,
            maxBatchSize: process.env.MAX_BATCH_SIZE || 50
        };
        
        this.executionInterval = parseInt(config.executionInterval.toString());
        this.maxBatchSize = parseInt(config.maxBatchSize.toString());
        
        console.log("配置已加载:", config);
    }
    
    /**
     * 获取服务状态
     */
    getStatus() {
        return {
            isRunning: this.isRunning,
            queueLength: this.operationQueue.length,
            executionHistory: this.executionHistory.size,
            lastExecution: this.executionInterval
        };
    }
    
    /**
     * 获取队列状态
     */
    getQueueStatus() {
        const status = {
            total: this.operationQueue.length,
            byType: {} as any,
            byPriority: {} as any
        };
        
        for (const operation of this.operationQueue) {
            // 按类型统计
            status.byType[operation.type] = (status.byType[operation.type] || 0) + 1;
            
            // 按优先级统计
            status.byPriority[operation.priority] = (status.byPriority[operation.priority] || 0) + 1;
        }
        
        return status;
    }
}

/**
 * 主函数 - 启动自动化服务
 */
async function main() {
    console.log("启动链下自动化服务...");
    
    // 从环境变量读取配置
    const safeAddress = process.env.SAFE_ADDRESS;
    const safeManagerAddress = process.env.SAFE_MANAGER_ADDRESS;
    
    if (!safeAddress || !safeManagerAddress) {
        console.error("请设置环境变量: SAFE_ADDRESS, SAFE_MANAGER_ADDRESS");
        process.exit(1);
    }
    
    // 创建自动化服务实例
    const automationService = new AutomationService(safeAddress, safeManagerAddress);
    
    // 启动服务
    await automationService.start();
    
    // 定期输出状态
    setInterval(() => {
        const status = automationService.getStatus();
        const queueStatus = automationService.getQueueStatus();
        
        console.log("服务状态:", status);
        console.log("队列状态:", queueStatus);
    }, 60000); // 每分钟输出一次状态
    
    // 优雅关闭
    process.on('SIGINT', () => {
        console.log("收到关闭信号，正在停止服务...");
        automationService.stop();
        process.exit(0);
    });
    
    console.log("自动化服务已启动，按 Ctrl+C 停止");
}

// 如果直接运行此脚本
if (require.main === module) {
    main().catch((error) => {
        console.error("服务启动失败:", error);
        process.exit(1);
    });
}

export { AutomationService };
