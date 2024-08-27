// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IPancakeRouter02.sol";

contract Meshes is ERC20 {
    struct MintInfo {
        address user;
        string meshID;
        uint256 updateTs;
        uint256 withdrawTs;
    }

    uint256 SECONDS_IN_DAY = 86400;
    uint256 totalMintDuration = 10 * 365 * SECONDS_IN_DAY; // 10年
    uint256 public constant MAX_TOTAL_SUPPLY = 81_000_000_000 * 10**18; // 81亿枚
    uint256 public constant MAX_MINT_PER_CALL = 100 * 10**18; // 每次铸造上限为100枚
    uint256 baseBurnAmount = 10;
    uint256 baseMintAmount = 1;

    uint256 public dailyMintFactor;
    uint256 public lastUpdatedDay = 0; // 记录上次更新的日期索引

    bool public burnSwitch = false; // 控制是否启用burn操作

    mapping(address => mapping(string => MintInfo)) public userMints;
    mapping(string => address[]) public userApplys;
    mapping(string => uint256) public degreeHeats;
    mapping(address => string[]) public userClaims;
    mapping(address => uint256) public awardAmount;
    mapping(address => uint256) public awardWithdrawAmount;
    mapping(address => bool) private minters;
    uint256 private spendNonce;

    mapping(address => bool) private isOwner;
    address[] private owners;
    uint256 private signRequired;

    uint256 public genesisTs;
    uint256 public activeMinters;
    uint256 public activeMeshes;
    uint256 public claimMints;
    uint256 public maxMeshHeats;
    uint256 public totalBurn;

    struct StakeInfo {
        uint256 term;
        uint256 maturityTs;
        uint256 amount;
    }

    uint256 public apy;
    uint256 public activeStakes;
    uint256 public totalStaked;
    uint256 public treasuryValue;

    uint256 public totalEarn;
    mapping(address => StakeInfo) public userStakes;

    address public FoundationAddr;
    IPancakeRouter02 public pancakeRouter;

    mapping(address => uint256) public stakeValues;
    mapping(uint256 => uint256) public dayMintAmount;
    mapping(uint256 => uint256) public dayStaked;
    mapping(uint256 => uint256) public dayUnStaked;
    mapping(address => uint256) public userTotalMint;
    mapping(address => mapping(uint256 => bool)) public dayReceived;

    event ClaimMint(address user, string meshID, uint256 time);
    event DegreeHeats(string meshID, uint256 heat, uint256 len);
    event UserMint(address user);

    event Staked(address indexed user, uint256 amount, uint256 term);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);

    modifier isOnlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    // Precomputed values for (1.2 ** n) when n < 30
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

    constructor(
        address[] memory _owners,
        uint256 _apy,
        address _foundationAddr,
        address _pancakeRouter
    ) ERC20("Mesh Token", "MESH") {
        for (uint256 i = 0; i < _owners.length; i++) {
            //onwer should be distinct, and non-zero
            address _owner = _owners[i];
            if (isOwner[_owner] || _owner == address(0x0)) {
                revert();
            }

            isOwner[_owner] = true;
            owners.push(_owner);
        }

        genesisTs = block.timestamp;
        apy = _apy;
        FoundationAddr = _foundationAddr;
        signRequired = _owners.length / 2 + 1;
        pancakeRouter = IPancakeRouter02(_pancakeRouter);
    }

    function setPancakeRouterAddress(address _newPancakeRouter)
        external
        isOnlyOwner
    {
        require(_newPancakeRouter != address(0), "Invalid address");
        pancakeRouter = IPancakeRouter02(_newPancakeRouter);
    }

    function setBurnSwitch(bool _burnSwitch) external isOnlyOwner {
        burnSwitch = _burnSwitch;
    }

    function ClaimMesh(string memory _meshID, uint256 autoSwap) external {
        MintInfo memory mintInfo = userMints[msg.sender][_meshID];

        require(mintInfo.updateTs == 0, "Already claim");

        uint256 _len = userApplys[_meshID].length;
        if (0 == _len) {
            activeMeshes++;
        }

        if (burnSwitch && _len > 0) {
            uint256 _amount = (baseBurnAmount *
                degreeHeats[_meshID] *
                degreeHeats[_meshID]) / maxMeshHeats;
            uint256 userBalance = balanceOf(msg.sender);

            // 检查用户余额是否足够，如果不足则通过 PancakeSwap 兑换
            if (userBalance < _amount) {
                uint256 deficit = _amount - userBalance;
                require(autoSwap >= deficit, "Insufficient swap amount");

                // 调用 PancakeSwap 路由合约来兑换 BNB 为 MESH
                swapBNBForMesh(deficit);
            }

            // 再次检查余额是否足够
            require(balanceOf(msg.sender) >= _amount, "Insufficient to burn");

            totalBurn += _amount;
            _burn(msg.sender, _amount);
        }

        mintInfo.meshID = _meshID;
        mintInfo.user = msg.sender;
        mintInfo.updateTs = block.timestamp;
        mintInfo.withdrawTs = block.timestamp;
        userMints[msg.sender][_meshID] = mintInfo;
        userApplys[_meshID].push(msg.sender);

        uint256 _degreeHeat = calculateDegreeHeat(_len);
        degreeHeats[_meshID] = _degreeHeat;
        if (_degreeHeat > maxMeshHeats) {
            maxMeshHeats = _degreeHeat;
        }

        emit DegreeHeats(_meshID, _degreeHeat, _len);

        userClaims[msg.sender].push(_meshID);

        if (!minters[msg.sender]) {
            activeMinters++;
            minters[msg.sender] = true;
        }

        claimMints++;

        emit ClaimMint(msg.sender, _meshID, block.timestamp);
    }

    function calculateDegreeHeat(uint256 _n) internal view returns (uint256) {
        if (_n < 30) {
            return precomputedDegreeHeats[_n];
        } else {
            uint256 base = 1.2 ether; // Representing 1.2 as a fixed-point number with 18 decimals
            uint256 result = precomputedDegreeHeats[29]; // Start from the precomputed value for n = 29

            for (uint256 i = 30; i <= _n; i++) {
                result = (result * base) / 1 ether; // Multiply and then divide by 1 ether to maintain precision
            }

            return result;
        }
    }

    function swapBNBForMesh(uint256 meshAmount) private {
        address[] memory path = new address[](2);
        path[0] = pancakeRouter.WETH(); // BNB
        path[1] = address(this); // MESH

        uint256 deadline = block.timestamp + 15; // 设置一个合理的截止时间

        pancakeRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: msg.value
        }(meshAmount, path, msg.sender, deadline); // 使用传递的 BNB 数量
    }

    function mint(address user, uint256 amount) private {
        require(amount <= MAX_MINT_PER_CALL, "Mint amount exceeds limit");
        require(
            totalSupply() + amount <= MAX_TOTAL_SUPPLY,
            "Total supply exceeds maximum limit"
        );

        uint256 _today = (block.timestamp - genesisTs) / SECONDS_IN_DAY;

        dayMintAmount[_today] += amount;

        _mint(user, amount);
    }

    function MintMeshes() public {
        uint256 elapsedTime = block.timestamp - genesisTs;
        require(elapsedTime <= totalMintDuration, "Minting period over");

        // 检查今天是否已经更新过 dailyMintFactor
        uint256 dayIndex = block.timestamp / SECONDS_IN_DAY; // 当前日期索引
        if (dayIndex != lastUpdatedDay) {
            uint256 timeDecayFactor = (elapsedTime * 1e10) / totalMintDuration; // 使用 1e18 放大基数

            // 更新 dailyMintFactor
            dailyMintFactor = 1e10 - (baseMintAmount * timeDecayFactor); // 使用 1e18 缩小基数
            lastUpdatedDay = dayIndex; // 更新上次更新日期
        }

        require(!dayReceived[msg.sender][dayIndex], "Daily receive");
        require(userClaims[msg.sender].length > 0, "No claims");

        // 记录用户已经收到奖励
        dayReceived[msg.sender][dayIndex] = true;

        uint256 sumDegreeHeats = 0;
        uint256 claimsLength = userClaims[msg.sender].length; // 缓存长度到内存中

        // 使用内存来减少存储读取
        for (uint256 i = 0; i < claimsLength; i++) {
            sumDegreeHeats += degreeHeats[userClaims[msg.sender][i]];
        }

        // 计算最终的 _amount
        uint256 _amount = (dailyMintFactor * sumDegreeHeats) / 1e10;

        require(_amount > 0, "Zero mint");

        // 铸造代币
        mint(msg.sender, _amount);
        // mint(FoundationAddr, _amount / 10);

        emit UserMint(msg.sender);

        // 合并状态更新以减少 gas
        userTotalMint[msg.sender] += _amount;
    }

    function SetUsersAward(
        address[] calldata _users,
        uint256[] calldata _awards,
        uint256 _totalAward,
        uint8[] memory vs,
        bytes32[] memory rs,
        bytes32[] memory ss
    ) public isOnlyOwner {
        require(validSignature(msg.sender, vs, rs, ss), "invalid signatures");
        spendNonce = spendNonce + 1;

        uint256 _len = _users.length;

        require(_len == _awards.length, "error length");

        for (uint256 i = 0; i < _len; i++) {
            awardAmount[_users[i]] = _awards[i];
        }

        treasuryValue += _totalAward;
    }

    function GetAward() public {
        uint256 _amount = awardAmount[msg.sender];

        require(_amount > 0, "No award");
        require(
            !dayReceived[msg.sender][block.timestamp / SECONDS_IN_DAY],
            "day receive"
        );

        dayReceived[msg.sender][block.timestamp / SECONDS_IN_DAY] = true;

        _amount = (_amount * 10) / 100;

        userTotalMint[msg.sender] += _amount;

        awardAmount[msg.sender] = 9 * _amount;

        mint(msg.sender, _amount);
        emit UserMint(msg.sender);
    }

    function Stake(uint256 amount, uint256 term) external {
        require(balanceOf(msg.sender) >= amount, "MESH: check balance");
        require(amount > 0, "MESH: amount > 0");
        require(term >= 1, "MESH: term >= 1");
        require(userStakes[msg.sender].amount == 0, "MESH: stake exists"); // 已经质押过了

        // burn staked NGP
        transfer(address(this), amount);
        // create NGP Stake
        _createStake(amount, term); // 创建质押数据

        uint256 _today = (block.timestamp - genesisTs) / SECONDS_IN_DAY;

        dayStaked[_today] += amount;

        emit Staked(msg.sender, amount, term);
    }

    function Withdraw() external {
        StakeInfo memory userStake = userStakes[msg.sender];
        require(userStake.amount > 0, "MESH: no stake");
        require(userStake.maturityTs <= block.timestamp, "maturityTs");
        // 计算质押奖励
        uint256 stackAward = _calculateStakeAward(
            userStake.amount,
            userStake.term,
            userStake.maturityTs
        );

        uint256 unLockValue = userStake.amount + stackAward;

        uint256 _today = (block.timestamp - genesisTs) / SECONDS_IN_DAY;

        stakeValues[msg.sender] += stackAward;

        totalEarn += stackAward;

        activeStakes--;
        totalStaked -= userStake.amount;

        dayUnStaked[_today] += unLockValue;

        mint(msg.sender, unLockValue);
        emit Withdrawn(msg.sender, userStake.amount, stackAward);
        delete userStakes[msg.sender];
    }

    function _calculateStakeAward(
        uint256 amount,
        uint256 term,
        uint256 maturityTs
    ) private view returns (uint256) {
        if (block.timestamp > maturityTs) {
            uint256 rate = (apy * term * 10) / 365;
            return amount * rate;
        }
        return 0;
    }

    function _createStake(uint256 amount, uint256 term) private {
        userStakes[msg.sender] = StakeInfo({
            term: term, // days
            maturityTs: block.timestamp + term * SECONDS_IN_DAY, // time
            amount: amount
        });

        activeStakes++;
        totalStaked += amount;
    }

    function validSignature(
        address _sender,
        uint8[] memory vs,
        bytes32[] memory rs,
        bytes32[] memory ss
    ) public view returns (bool) {
        require(vs.length == rs.length, "vs.length == rs.length");
        require(rs.length == ss.length, "rs.length == ss.length");
        require(vs.length <= owners.length, "vs.length <= owners.length");
        require(vs.length >= signRequired, "vs.length >= signRequired");
        bytes32 message = _messageToRecover(_sender);
        address[] memory addrs = new address[](vs.length);
        for (uint256 i = 0; i < vs.length; i++) {
            //recover the address associated with the public key from elliptic curve signature or return zero on error
            addrs[i] = ecrecover(message, vs[i] + 27, rs[i], ss[i]);
        }

        require(_distinctOwners(addrs), "_distinctOwners");
        return true;
    }

    function _messageToRecover(address _sender) private view returns (bytes32) {
        bytes32 hashedUnsignedMessage = generateMessageToSign(_sender);
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        return keccak256(abi.encodePacked(prefix, hashedUnsignedMessage));
    }

    function generateMessageToSign(address _sender)
        private
        view
        returns (bytes32)
    {
        //the sequence should match generateMultiSigV2 in JS
        bytes32 message = keccak256(
            abi.encodePacked(_sender, block.chainid, spendNonce)
        );
        return message;
    }

    function _distinctOwners(address[] memory addrs)
        private
        view
        returns (bool)
    {
        if (addrs.length > owners.length) {
            return false;
        }
        for (uint256 i = 0; i < addrs.length; i++) {
            if (!isOwner[addrs[i]]) {
                return false;
            }
            //address should be distinct
            for (uint256 j = 0; j < i; j++) {
                if (addrs[i] == addrs[j]) {
                    return false;
                }
            }
        }
        return true;
    }

    function getSpendNonce() external view returns (uint256) {
        return spendNonce;
    }

    function addSpendNonce() external {
        spendNonce++;
    }

    function getUserClaimCount(address _user) external view returns (uint256) {
        return userClaims[_user].length;
    }

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

    function getEarthDashboard()
        external
        view
        returns (
            uint256 _totalSupply,
            uint256 _liquidSupply,
            uint256 _destruction,
            uint256 _totalStaked,
            uint256 _treasury,
            uint256 _foundation
        )
    {
        _totalSupply = totalSupply();
        _liquidSupply = _totalSupply - balanceOf(address(this));
        _destruction = totalBurn;
        _totalStaked = totalStaked;
        _treasury = treasuryValue;
        _foundation = balanceOf(FoundationAddr);
    }

    function getRewardAmount(address _user)
        external
        view
        returns (
            uint256 _userTotalMint,
            uint256 _userWithdraw,
            uint256 _userUnWithdraw
        )
    {
        _userTotalMint = userTotalMint[_user];
        _userWithdraw = awardWithdrawAmount[_user];
        _userUnWithdraw = awardAmount[_user];
    }

    function getStakeInfo(address _user)
        external
        view
        returns (
            uint256 tvl,
            uint256 revenue,
            uint256 earned,
            uint256 claimable,
            uint256 totalApy,
            uint256 staked,
            uint256 totalEarnValue,
            uint256 offTokenStake
        )
    {
        uint256 price = 1; // get price?
        tvl = totalStaked * price;
        revenue = totalEarn * price;
        earned = totalEarn;
        if (userStakes[_user].maturityTs <= block.timestamp) {
            claimable = userStakes[_user].amount;
        } else {
            claimable = 0;
        }

        totalApy = apy;
        staked = userStakes[_user].amount;
        totalEarnValue = stakeValues[_user];

        uint256 totalSupply = totalSupply();
        if (totalSupply != 0) {
            offTokenStake = (totalStaked * 1000000) / totalSupply;
        }
    }

    function getNetworkEvents()
        external
        view
        returns (
            uint256 _genesisTs,
            uint256[] memory _totalMint,
            uint256[] memory _staked,
            uint256[] memory _unstaked
        )
    {
        uint256 _today = (block.timestamp - genesisTs) / SECONDS_IN_DAY;
        _totalMint = new uint256[](_today);
        _staked = new uint256[](_today);
        _unstaked = new uint256[](_today);

        _genesisTs = genesisTs;

        for (uint256 i = 0; i < _today; i++) {
            _totalMint[i] = dayMintAmount[i];
            _staked[i] = dayStaked[i];
            _unstaked[i] = dayUnStaked[i];
        }
    }

    function getStakeTime(address user) external view returns (uint256 ts) {
        if (userStakes[user].amount == 0) {
            ts = 0;
        }

        ts = userStakes[user].maturityTs;
    }

    function getClaimTsAmount(address _user, string calldata _meshID)
        public
        view
        returns (int256 count, uint256 _amount)
    {
        if (userMints[_user][_meshID].withdrawTs != 0) {
            count = -1;
        } else {
            count = int256(userApplys[_meshID].length);
            _amount = degreeHeats[_meshID] / 10;
        }
    }
}
