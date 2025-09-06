# Parallels Contract 拆分架构说明

## 概述

原始的 `Meshes.sol` 合约已被拆分为三个独立的合约，每个合约负责特定的功能模块，提高了代码的可维护性和可扩展性。

## 合约架构

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Meshes      │    │     Reward      │    │      Stake      │
│   (核心合约)     │    │   (奖励合约)     │    │   (质押合约)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
   ┌─────────────────────────────────────────────────────────────┐
   │                    Foundation                               │
   │                 (基金会账户)                                 │
   └─────────────────────────────────────────────────────────────┘
```

## 1. Meshes 合约 (核心合约)

### 功能
- **网格认领**: `claimMint()` - 用户认领地理网格
- **收益提取**: `withdraw()` - 用户提取基于网格热度的收益
- **热度计算**: 基于参与人数的指数增长算法
- **代币铸造**: 支持10年铸造周期，最大供应量81亿枚

### 主要特性
- 继承自标准ERC20
- 支持PancakeSwap自动兑换
- 多签权限管理
- 动态铸造因子

### 核心函数
```solidity
function claimMint(string memory _meshID, uint256 autoSwap) external
function withdraw() public
function calculateDegreeHeat(uint256 _n) internal view returns (uint256)
```

## 2. Reward 合约 (奖励合约)

### 功能
- **奖励设置**: `setUserReward()` - 多签确认设置用户奖励
- **奖励查询**: `getRewardAmount()` - 获取用户奖励信息
- **奖励提取**: `withdraw()` / `withdrawAll()` - 从基金会账户提取奖励

### 主要特性
- 每日提取限制（10%）
- 多签验证机制
- 完整的奖励追踪
- 基金会地址可更新

### 核心函数
```solidity
function setUserReward(address[] calldata _users, uint256[] calldata _amounts, ...)
function getRewardAmount(address _user) external view returns (...)
function withdraw(uint256 _amount) external
function withdrawAll() external
```

## 3. Stake 合约 (质押合约)

### 功能
- **代币质押**: `stake()` - 质押代币获取利息
- **质押提取**: `withdraw()` - 到期后提取本金和利息
- **利息领取**: `claimInterest()` - 定期领取利息
- **提前解除**: `earlyWithdraw()` - 提前解除质押（有手续费）

### 主要特性
- 可配置APY（年化收益率）
- 支持1-365天质押期限
- 实时利息计算
- 质押统计和TVL计算

### 核心函数
```solidity
function stake(uint256 _amount, uint256 _term) external
function withdraw() external
function claimInterest() external
function calculateInterest(address _user) public view returns (uint256)
```

## 部署流程

### 1. 环境准备
```bash
npm install
# 配置私钥文件 local_privkeys.json
```

### 2. 部署合约
```bash
# 部署所有拆分后的合约
npx hardhat run --network bsctest scripts/deploy-split-contracts.ts

# 或分别部署
npx hardhat run --network bsctest scripts/deploy-meshes.ts
npx hardhat run --network bsctest scripts/deploy-reward.ts
npx hardhat run --network bsctest scripts/deploy-stake.ts
```

### 3. 部署顺序
1. **Meshes合约** - 核心代币合约
2. **Reward合约** - 依赖Meshes地址
3. **Stake合约** - 依赖Meshes地址

## 合约交互流程

### 用户认领网格
```
用户 → Meshes.claimMint() → 获得网格认领权
```

### 用户提取收益
```
用户 → Meshes.withdraw() → 获得基于热度的代币奖励
```

### 管理员设置奖励
```
管理员 → Reward.setUserReward() → 多签确认 → 设置用户奖励
```

### 用户提取奖励
```
用户 → Reward.withdraw() → 从基金会账户获得奖励
```

### 用户质押代币
```
用户 → Stake.stake() → 质押代币到合约 → 开始赚取利息
```

### 用户提取质押
```
用户 → Stake.withdraw() → 从基金会账户获得本金+利息
```

## 权限管理

### 多签要求
- 所有合约都使用相同的多签机制
- 需要超过50%的所有者签名确认
- 支持动态所有者管理

### 权限级别
- **所有者**: 可以更新配置参数
- **基金会**: 提供代币资金
- **用户**: 执行基本操作

## 安全特性

### 1. 重入攻击防护
- 使用OpenZeppelin的安全模式
- 状态更新在外部调用之前

### 2. 权限控制
- 多签验证关键操作
- 修饰符保护敏感函数

### 3. 输入验证
- 地址有效性检查
- 数值范围验证
- 数组长度匹配

### 4. 经济模型保护
- 每日提取限制
- 质押期限限制
- 提前解除手续费

## 升级和维护

### 合约升级
- Meshes合约支持逻辑升级
- Reward和Stake合约可重新部署

### 参数更新
- APY可通过多签更新
- 基金会地址可更新
- 所有者列表可更新

### 监控指标
- 总质押量 (TVL)
- 总收益分配
- 活跃用户数量
- 合约使用统计

## 测试

### 运行测试
```bash
# 运行所有测试
npx hardhat test

# 运行特定合约测试
npx hardhat test test/meshes.test.js
npx hardhat test test/reward.test.js
npx hardhat test test/stake.test.js
```

### 测试覆盖
- 基本功能测试
- 边界条件测试
- 权限控制测试
- Gas优化测试

## 网络支持

### 测试网
- BSC Testnet (ChainID: 97)
- Polygon Mumbai (ChainID: 80001)
- Avalanche Fuji (ChainID: 43113)

### 主网
- BSC Mainnet (ChainID: 56)
- Polygon (ChainID: 137)
- Avalanche (ChainID: 43114)

## 总结

拆分后的合约架构提供了以下优势：

1. **模块化设计**: 每个合约专注于特定功能
2. **易于维护**: 代码结构清晰，便于调试和更新
3. **灵活部署**: 可以独立部署和升级各个模块
4. **安全隔离**: 不同功能模块的风险相互隔离
5. **扩展性强**: 便于添加新功能和集成第三方服务

这种架构设计使得整个系统更加健壮和可维护，同时保持了原有的功能完整性。
