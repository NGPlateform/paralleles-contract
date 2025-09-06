# Parallels Contracts（最新版本）运行机制与部署维护文档

本文件描述当前最新版合约集合：`Meshes`, `Reward`, `FoundationManage`, `Stake`, `CheckInVerifier` 的架构、运行机制、部署与维护方法。已弃用/老版本（如 `NGP`, 旧代理合约等）不在本文范围内。

## 1. 合约总览

- `Meshes`（ERC20）: 网格认领与增发规则的核心代币合约（代币名: Mesh Token, 符号: MESH）。
- `Reward`: 基于活动/打卡结果的奖励发放与每日限领控制，内置简化多签（owners+阈值）。
- `FoundationManage`: Mesh 国库资金的管控与拨付（由 Gnosis Safe 进行二次授权控制）。
- `Stake`: 简单固定期限质押，线性年化收益，自动向国库申请补偿以维持合约余额。
- `CheckInVerifier`: 链下位置校验回写合约（Chainlink 作业/Oracle 回调写入是否合格）。

### 1.1 角色与权限

- Gnosis Safe（记为 `SAFE`）: 作为治理与国库权限来源。
  - `Meshes`: 关键操作由 `onlySafe` 执行（暂停/解冻、设置基金会地址、切换治理 Safe 等）。
  - `FoundationManage`: `owner` 拥有者（部署者）可设置 `safeAddress`，常规转账函数受 `onlySafe` 保护；支持按 `spender` 配置“小额自动划拨”限额。
  - `Reward`: 管理与配置操作经 `onlySafe` 执行（`setUserReward`、`updateFoundation`、`setFoundationManager`、`setCheckInVerifier`、`setMinFoundationBalance`、`addSpendNonce`）；提供 `setGovernanceSafe` 用于迁移治理。
  - `Stake`: 管理与配置操作经 `onlySafe` 执行（`updateAPY`、`updateFoundation`、`setFoundationManager`、`setMinContractBalance`、`addSpendNonce`）；提供 `setGovernanceSafe` 用于迁移治理。
- Oracle（`CheckInVerifier.oracle`）: 允许链下任务回调 `fulfillCheckIn` 写入资格结果。

## 2. 运行机制

### 2.1 Meshes（ERC20 增发与网格机制）

- 创世时间 `genesisTs` 确定后，系统以“天”为粒度推进；年度增发因子按年 10% 衰减：
  - 当天的日因子 `dailyMintFactor = 1e10 * 0.9^yearIndex`（近似用 9/10 累乘实现）。
- 网格认领 `claimMint(meshID)`：
  - 校验 `meshID` 格式：`^[EW][0-9]+[NS][0-9]+$`，经纬度范围 |lon*100| < 18000，|lat*100| ≤ 9000。
  - 按网格累计申请人数 `n` 计算热度 `degreeHeats(meshID)`（前 30 用预计算，之后有上限与近似）。
  - 可选启用认领“燃烧成本”开关 `burnSwitch`：若网格已有申请者，需按 `(baseBurnAmount * heat^2 / maxMeshHeats)` 从认领者余额烧毁（随热度非线性增长）。
  - 记录用户权重：每认领一次，用户权重加上该网格热度；权重决定每日产出分配。
- 提现 `withdraw()`：
  - 今日应得 = `dailyMintFactor * userWeight / 1e10`。
  - 懒处理“未领取余额日衰减 50%”：逐日推进到昨天，对每一日的应得+结转执行：烧毁 40%，拨付基金会 10%，结转 50%。
  - 今日提现发放（包含结转）后清零结转并记账，当日仅一次。
- 基金会池拨付：
  - 日衰减产生的 10% 部分先增发到合约自身，累计到 `pendingFoundationPool`；
  - 每小时边界触发 `_maybePayoutFoundation()` 将累计额转给 `FoundationAddr`（也可外部主动触发）。
- 主要可视函数：`getMeshData`, `getMeshDashboard`, `getEarthDashboard`, `quoteClaimCost`, `previewWithdraw` 等。

安全性与治理：
- `pause/unpause`、`setFoundationAddress`、`setBurnSwitch`、`setGovernanceSafe` 仅 `SAFE` 可调。
- 代币销毁全部通过标准 `_burn`；日衰减中的“销毁”和“基金融资”均以增发到自身再处理，事件透明可追踪。

### 2.2 FoundationManage（国库管控）

- 保存 `meshToken`（MESH）实例与 `safeAddress`。
- `approvedSpenders` 用于“允许向哪些地址主动划拨”（按接收地址判断）。
- 资金拨付（经 Safe 审批）：
  - `transferTo(to, amount)`: 仅 `onlySafe` 调用，且要求 `approvedSpenders[to] == true` 或 `to == owner()`。
  - `transferFor(spender, to, amount)`: 仅 `onlySafe` 调用，且要求 `approvedSpenders[spender] == true`。
- 小额自动化（无需 Safe，限额内）：
  - `setAutoLimit(spender, maxPerTx, maxDaily, enabled)`: 由 `owner` 配置某 `spender` 的单笔与当日累计限额；天粒度按 `block.timestamp / 1 days` 自动重置。
  - `autoTransferTo(to, amount)`: 由 `spender` 自行调用，在限额内直接划拨；要求 `approvedSpenders[to] == true` 或 `to == owner()`。
- 常见用法：
  - 为 `Stake` 合约地址与 `foundationAddr` 分别启用 `approvedSpenders[stake] = true`、`approvedSpenders[foundationAddr] = true`，
    以支持 `Stake` 主动补仓与 `Reward` 场景下对基金会热钱账户的补仓。
  - 如需提升自动化：为 `Reward` 或 `Stake` 配置 `setAutoLimit(Reward/Stake, maxPerTx, maxDaily, true)`，使其在小额范围内可直接调用 `autoTransferTo`。

### 2.3 Reward（按打卡资格发放奖励）

- `setUserReward(users, amounts, total, signatures)`: 由 Safe 调用（`onlySafe`），批量累加用户“可领取总额”。签名数组参数仅为接口兼容，合约内不再校验。
- 每日领取限制：用户每天只能领取一次，且当日最多领取其“总额度”的 10%（`DAILY_WITHDRAW_LIMIT_PERCENT=10`）。
- 领取走 `meshToken.transferFrom(foundationAddr, user, amount)`：
  - 需要 `foundationAddr` 对 Reward 合约提前授权足够的 MESH 额度（`approve`）。
- `rewardActivityWinner(s)`: 在 `CheckInVerifier` 判定 `eligible(activityId,user)==true` 时，
  按活动对用户累加奖励额度；同时触发 `_ensureTopUp` 请求由 `FoundationManage` 补仓至 `foundationAddr`（补仓本身按限额/或经 Safe）。

### 2.4 Stake（固定期限质押）

- `stake(amount, termDays)`: 创建单笔质押（每地址仅一笔并行），期限 1~365 天。
- 利息为线性年化：`interest = principal * apy * timeElapsed / (365d * 1e4)`；`apy` 以基点计（10000=100%）。
- 支持 `claimInterest()` 按已过时间领取利息；`withdraw()` 到期提本息；`earlyWithdraw()` 提前赎回损失 50% 已产生利息。
- 管理参数由 Safe 调用（`onlySafe`）。
- 合约余额不足时，`_ensureTopUp` 会通过 `FoundationManage.transferTo(address(this), need)` 申请补仓（需预先允许 `approvedSpenders[stake]=true`；如配置了 `setAutoLimit(Stake, ...)`，可在限额内由 Stake 直接 `autoTransferTo`）。

### 2.5 CheckInVerifier（位置打卡资格）

- `requestCheckIn(activityId, latE6, lonE6, radiusM)`: 产生请求事件，链下监听后计算是否满足地理范围与风控；
- 链下节点作为 `oracle` 回调 `fulfillCheckIn(requestId, isEligible)` 写入结果；
- 业务方在 `Reward` 合约内调用 `isEligible(activityId, user)` 完成发奖门控。

## 3. 部署与初始化

以下为“从零部署并初始化”的建议流程（以 Hardhat 为例）。

### 3.1 先决条件

- Node.js 与 NPM；
- 已配置好 Hardhat 网络与私钥；
- 一个 Gnosis Safe 地址（可先在前端创建 Safe，再在链上使用该地址）。

```bash
cd parallels-contract
npm install
```

### 3.2 部署顺序与参数

1) 部署 `Meshes`

- 构造参数：`foundationAddr`, `governanceSafe`。
- 建议将 `foundationAddr` 指向一个国库地址（也可以是 Safe），`governanceSafe` 为治理 Safe。

2) 部署 `FoundationManage`

- 构造参数：`meshToken`(=Meshes 地址), `safeAddress`(=治理 Safe)。

3) 部署 `Reward`

- 构造参数：`owners[]`, `meshToken`(=Meshes 地址), `foundationAddr`（与 Meshes 中一致）。

4) 部署 `Stake`

- 构造参数：`owners[]`, `meshToken`(=Meshes 地址), `foundationAddr`, `initialAPY`(基点)。

5) 部署 `CheckInVerifier`

- 构造参数：`oracle`（Chainlink 节点/OCR 回调地址，可后续 `setOracle` 更新）。

> 注：仓库 `scripts/deploy-complete-system.ts` 等示例脚本存在旧参数签名，请以本 README 的构造参数为准或自行调整脚本后使用。

### 3.3 初始化与权限配置

建议在部署后按如下顺序进行一次性初始化（伪代码/命令示例）：

1) Meshes 基础治理

```bash
# 可选：开启/关闭认领燃烧成本
# meshes.setBurnSwitch(true/false)

# 可选：更新基金会地址（如需变更）
# meshes.setFoundationAddress(<foundationAddr>)

# 可选：更新治理 Safe（如需迁移）
# meshes.setGovernanceSafe(<newSafe>)

# 可选：紧急控制
# meshes.pause()
# meshes.unpause()
```

2) FoundationManage 授权接收方与小额自动化

```bash
# 由 owner 调用
foundationManage.setSafe(<SAFE>)

# 允许 Stake 合约作为划拨接收方
foundationManage.setSpender(<StakeAddress>, true)

# 允许基金会热钱地址作为划拨接收方（Reward 的补仓使用 transferTo(foundationAddr, ..)）
foundationManage.setSpender(<foundationAddr>, true)

# （可选）如使用 transferFor 路径，也可对 Reward 合约地址开启：
# foundationManage.setSpender(<RewardAddress>, true)

# （可选）小额自动化：为 Reward 或 Stake 设置限额（单笔/当日），限额内可由其自行调用 autoTransferTo
foundationManage.setAutoLimit(<RewardAddress>, <maxPerTx>, <maxDaily>, true)
foundationManage.setAutoLimit(<StakeAddress>, <maxPerTx>, <maxDaily>, true)
```

3) Reward 初始化

```bash
# 指定 FoundationManage 地址与最低余额阈值
reward.setFoundationManager(<FoundationManageAddress>)
reward.setMinFoundationBalance(<minBalance>)

# 迁移治理到 Safe（重要）
reward.setGovernanceSafe(<SAFE>)

# 指定打卡校验合约
reward.setCheckInVerifier(<CheckInVerifierAddress>)

# 关键：从 foundationAddr（通常由 SAFE 管理）对 Reward 执行代币授权
# 在 Gnosis Safe 前端，提交一笔 MeshToken.approve(Reward, amount) 交易
```

4) Stake 初始化

```bash
stake.setFoundationManager(<FoundationManageAddress>)
stake.setMinContractBalance(<minBalance>)

# 迁移治理到 Safe（重要）
stake.setGovernanceSafe(<SAFE>)

# 需要为 Stake 合约开启 FoundationManage 的接收方授权（见步骤 2）
```

5) CheckInVerifier 初始化

```bash
checkInVerifier.setOracle(<oracle>) # 如部署时未设置或需更换
```

### 3.4 验证与辅助

- 使用 `Meshes.getMeshDashboard()/getEarthDashboard()` 验证系统指标；
- 在 Safe 前端查看 `FoundationManage` 的调用记录与代币转账；
- 事件订阅：`MeshClaimed`、`WithdrawProcessed`、`FoundationPayout`、`ActivityRewarded`、`AutoTopUpRequested` 等。

## 4. 运维与最佳实践

### 4.1 日常运维要点

- 监控基金会与合约余额：
  - `Meshes.pendingFoundationPool` 与每小时拨付事件；
  - `Reward.minFoundationBalance` 与 `AutoTopUpRequested` 事件；
  - `Stake.minContractBalance` 与 `AutoTopUpRequested` 事件。
- 监控用户提现与衰减：
  - 每日提现限制在 Reward；
  - Meshes 的日衰减事件 `UnclaimedDecayApplied`/`TokensBurned`/`FoundationFeeAccrued`。
- Gnosis Safe 管理：
  - 定期审阅 `SAFE` owners 与阈值；
  - 遇到重大变更使用 Safe 多签执行（暂停、地址更换、授权调整）。

### 4.2 安全与权限

- 将所有高权限操作置于 Safe 之下；
- Reward 的领取使用 `transferFrom`，务必由 `foundationAddr` 对 Reward 授权足够额度；
- FoundationManage 的 `approvedSpenders` 按接收地址控制，谨慎开启、定期复核；
- 如启用小额自动化，请合理设置 `setAutoLimit(spender, maxPerTx, maxDaily, true)` 并持续监控；超过限额的操作需通过 Safe。
- 出现异常时：
  - `Meshes.pause()` 可快速冻结认领与提现入口；
  - 撤销 Reward 的 `approve` 以临时冻结奖励提现路径。

### 4.3 版本升级/变更

- 现版合约未采用可升级代理；如需升级，请部署新版本并通过 Safe 迁移：
  - Meshes：设置新合约的 `FoundationAddr`、`governanceSafe` 并在前端切换读取；
  - Reward/Stake：迁移 owners、参数，关闭旧合约授权与补仓；
  - FoundationManage：在新合约地址上重新设置 `safeAddress` 与 `approvedSpenders`；
  - CheckInVerifier：更新 `oracle` 或替换地址，并在 Reward 中更新 `setCheckInVerifier`。

## 5. 常见命令示例（Hardhat）

```bash
# 测试
npx hardhat test

# 验证（以 Meshes 为例）
npx hardhat verify --network <network> <MeshesAddress> <foundationAddr> <governanceSafe>

# 交互（示例）：
# npx hardhat console --network <network>
# const m = await ethers.getContractAt("Meshes", "<addr>");
# (await m.getMeshDashboard())
```

## 6. 事件速查

- Meshes: `MeshClaimed`, `DegreeHeats`, `UserMint`, `WithdrawProcessed`, `TokensBurned`, `FoundationFeeAccrued`, `FoundationPayout`, `GovernanceSafeUpdated`。
- FoundationManage: `SafeUpdated`, `SpenderApproved`, `TransferExecuted`, `AutoLimitUpdated`。
- Reward: `RewardSet`, `RewardWithdrawn`, `ActivityRewarded`, `ActivityBatchRewarded`, `FoundationManagerUpdated`, `MinFoundationBalanceUpdated`, `AutoTopUpRequested`。
- Stake: `Staked`, `Withdrawn`, `InterestClaimed`, `APYUpdated`, `FoundationManagerUpdated`, `MinContractBalanceUpdated`, `AutoTopUpRequested`。
- CheckInVerifier: `OracleUpdated`, `CheckInRequested`, `CheckInFulfilled`。

——

本文件对应的说明基于当前仓库中的最新合约代码（`Meshes.sol`, `Reward.sol`, `FoundationManage.sol`, `Stake.sol`, `CheckInVerifier.sol`）。若与脚本/前端存在参数差异，请以本说明的构造参数与初始化顺序为准，或先更新脚本后再执行自动化部署。