# Gnosis Safe 配置说明

## 环境变量配置

创建 `.env` 文件（不要提交到代码仓库）：

```bash
# 网络配置
NETWORK=BSC_TESTNET
RPC_URL=https://bsc-testnet.nodereal.io/v1/your-api-key
CHAIN_ID=97

# 部署账户（仅用于初始部署，不要存储私钥）
DEPLOYER_PRIVATE_KEY=0x...

# Gnosis Safe配置
SAFE_OWNERS=0xOwner1,0xOwner2,0xOwner3
SAFE_THRESHOLD=2
SAFE_FALLBACK_HANDLER=0x...

# 合约地址（部署后填写）
SAFE_ADDRESS=0x...
SAFE_MANAGER_ADDRESS=0x...
MESH_CONTRACT_ADDRESS=0x...
REWARD_CONTRACT_ADDRESS=0x...
STAKE_CONTRACT_ADDRESS=0x...

# 操作ID（用于测试）
OPERATION_ID=0x...

# API密钥
ETHERSCAN_API_KEY=your-etherscan-api-key
BSCSCAN_API_KEY=your-bscscan-api-key

# 硬件钱包配置
LEDGER_PATH=44'/60'/0'/0/0
TREZOR_PATH=44'/60'/0'/0/0

# 安全配置
EMERGENCY_CONTACT=0x...
BACKUP_SAFE_ADDRESS=0x...
```

## 部署步骤

### 1. 环境准备
```bash
# 安装依赖
npm install @gnosis.pm/safe-contracts @gnosis.pm/safe-core-sdk
npm install @safe-global/safe-core-sdk @safe-global/safe-deployments

# 配置环境变量
cp .env.example .env
# 编辑 .env 文件，填入实际值
```

### 2. 部署Gnosis Safe
```bash
# 部署Safe和SafeManager
npx hardhat run --network bsctest scripts/deploy-gnosis-safe.ts
```

### 3. 配置Safe权限
```bash
# 在Gnosis Safe Web界面添加Safe地址
# 配置所有者钱包和阈值
# 测试Safe功能
```

### 4. 集成到业务合约
```bash
# 部署业务合约
npx hardhat run --network bsctest scripts/deploy-split-contracts.ts

# 配置SafeManager
npx hardhat run --network bsctest scripts/configure-safe-manager.ts
```

## 使用流程

### 1. 提议操作
```bash
# 提议网格认领
npx hardhat run --network bsctest scripts/safe-operations.ts \
  --propose mesh-claim \
  --contract 0x... \
  --mesh-id E11396N2247

# 提议设置奖励
npx hardhat run --network bsctest scripts/safe-operations.ts \
  --propose reward-set \
  --contract 0x... \
  --users 0x...,0x... \
  --amounts 100,200
```

### 2. 确认操作
```bash
# 在Gnosis Safe Web界面确认操作
# 需要达到阈值数量的所有者签名
```

### 3. 执行操作
```bash
# 执行已确认的操作
npx hardhat run --network bsctest scripts/safe-operations.ts \
  --execute 0xoperationId...
```

## 安全最佳实践

### 1. 私钥管理
- 使用硬件钱包（Ledger/Trezor）
- 不在代码中存储私钥
- 使用环境变量管理敏感信息

### 2. 多签配置
- 设置合理的阈值（建议2/3或3/5）
- 使用不同的硬件钱包
- 定期轮换所有者

### 3. 操作管理
- 所有关键操作通过Safe执行
- 设置操作延迟时间
- 监控异常操作

### 4. 备份和恢复
- 备份Safe配置
- 设置备用Safe地址
- 记录恢复流程

## 故障排除

### 常见问题

1. **Safe部署失败**
   - 检查网络连接
   - 验证账户余额
   - 检查合约字节码

2. **操作执行失败**
   - 验证Safe权限
   - 检查操作参数
   - 确认网络状态

3. **签名验证失败**
   - 检查所有者地址
   - 验证阈值设置
   - 确认签名顺序

### 调试命令

```bash
# 检查Safe状态
npx hardhat run --network bsctest scripts/check-safe-status.ts

# 验证合约权限
npx hardhat run --network bsctest scripts/verify-permissions.ts

# 测试Safe功能
npx hardhat run --network bsctest scripts/test-safe-functions.ts
```

## 监控和维护

### 1. 定期检查
- Safe所有者状态
- 操作执行历史
- 合约权限设置

### 2. 更新维护
- 升级Safe版本
- 更新所有者列表
- 调整阈值设置

### 3. 安全审计
- 代码安全审查
- 权限配置检查
- 操作日志分析
