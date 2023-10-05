//SPDX-License-Identifier: MIT

pragma solidity 0.8.8;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

abstract contract MeshAreaBase {
    bytes[] public meshData;

    int256 public minLat;
    int256 public maxLat;
    int256 public minLon;
    int256 public maxLon;

    constructor(
        int256 _minLat,
        int256 _maxLat,
        int256 _minLon,
        int256 _maxLon
    ) {
        meshData = new bytes[](100);
        minLat = _minLat;
        maxLat = _maxLat;
        minLon = _minLon;
        maxLon = _maxLon;
    }

    function computeMeshID(int256 lat, int256 lon)
        internal
        virtual pure 
        returns (uint256);

    function firstClaim(int256 lat, int256 lon) public returns (int8) {
        require(
            lon >= minLon && lon <= maxLon && lat >= minLat && lat <= maxLat,
            "Invalid latitude or longitude"
        );

        uint256 meshID = computeMeshID(lat, lon);

        uint256 subAreaIndex = meshID / 1620000;
        if (meshData[subAreaIndex].length == 0) {
            meshData[subAreaIndex] = new bytes(202500);
        }

        uint256 index = (meshID % 1620000) / 8;
        uint256 offset = (meshID % 1620000) % 8;
        uint8 mask = uint8(1 << offset);
        uint8 meshByte = uint8(meshData[subAreaIndex][index]);

        if ((meshByte & mask) == 0) {
            meshData[subAreaIndex][index] = bytes1(meshByte | mask);
            return 0;
        } else {
            return 1;
        }
    }

    function getClaimCount(int256 lat, int256 lon) public view returns (uint8) {
        require(
            lon >= minLon && lon <= maxLon && lat >= minLat && lat <= maxLat,
            "Invalid latitude or longitude"
        );

        uint256 meshID = computeMeshID(lat, lon);
        uint256 subAreaIndex = meshID / 1620000;
        uint256 index = (meshID % 1620000) / 8;
        uint256 offset = (meshID % 1620000) % 8;

        if (meshData[subAreaIndex].length == 0) {
            return 0;
        }

        uint8 mask = uint8(1 << offset);
        uint8 meshByte = uint8(meshData[subAreaIndex][index]);

        if ((meshByte & mask) == 0) {
            return 0;
        } else {
            return 1;
        }
    }
}

contract MeshArea1 is MeshAreaBase {
    constructor() MeshAreaBase(-8999, 8999, 0, 8999) {}

    function computeMeshID(int256 lat, int256 lon)
        internal
        virtual
        override pure 
        returns (uint256)
    {
        return uint256(lat + 9000) + uint256(lon * 18000);
    }
}

contract MeshArea2 is MeshAreaBase {
    constructor() MeshAreaBase(-8999, 8999, 9000,17999) {}

    function computeMeshID(int256 lat, int256 lon)
        internal
        virtual
        override pure 
        returns (uint256)
    {
        return uint256(lat + 9000) + uint256(lon * 18000);
    }
}

contract MeshArea3 is MeshAreaBase {
    constructor() MeshAreaBase(-8999, 8999, -8999, 0) {}

    function computeMeshID(int256 lat, int256 lon)
        internal
        virtual
        override pure 
        returns (uint256)
    {
        return uint256(lat + 9000) + uint256((0 - lon) * 18000);
    }
}

contract MeshArea4 is MeshAreaBase {
    constructor() MeshAreaBase(-8999, 8999, -17999, -9000) {}

    function computeMeshID(int256 lat, int256 lon)
        internal
        virtual
        override pure 
        returns (uint256)
    {
        return uint256(lat + 9000) + uint256((9000 - lon) * 18000);
    }
}

// 创建 MultiClaim 智能合约用于管理第1次之后的数据
contract MultiClaim {
    struct ClaimInfo {
        uint8 claimCount; // uint8 or uint16?
    }

    // 使用双重映射来存储经纬度对应的 MeshID 的声明信息
    mapping(int256 => mapping(int256 => ClaimInfo)) claimedMeshes;

    function claimMesh(int256 lat, int256 lon) public {
        // 修正 require 语句的条件
        require(
            lon > -18000 && lon < 18000 && lat > -9000 && lat < 9000,
            "Invalid lat or lon"
        );

        // 获取当前经纬度的声明信息
        ClaimInfo storage info = claimedMeshes[lat][lon];

        // 如果当前经纬度未被声明，初始化声明信息
        if (info.claimCount == 0) {
            info.claimCount = 1;
        } else {
            info.claimCount++;
        }
    }

    function getClaimCount(int256 lat, int256 lon)
        public
        view
        returns (ClaimInfo memory)
    {
        // 获取当前经纬度的声明信息
        ClaimInfo memory info = claimedMeshes[lat][lon];
        return info;
    }
}

contract MeshManagement {
    MeshArea1 public area1;
    MeshArea2 public area2;
    MeshArea3 public area3;
    MeshArea4 public area4;

    MultiClaim public multiClaim;

    constructor(
        address _area1,
        address _area2,
        address _area3,
        address _area4,
        address _multiClaim
    ) {
        area1 = MeshArea1(_area1);
        area2 = MeshArea2(_area2);
        area3 = MeshArea3(_area3);
        area4 = MeshArea4(_area4);
        multiClaim = MultiClaim(_multiClaim);
    }

    function getClaimCount(int256 lat, int256 lon) public view returns (uint8) {
        uint8 areaClaimStatus = 0;
        if (lat >= -8999 && lat <= 8999) {
            if (lon >= 0 && lon <= 8999) {
                areaClaimStatus = area1.getClaimCount(lat, lon);
            } else if (lon >= 9000 && lon <= 17999) {
                areaClaimStatus = area2.getClaimCount(lat, lon);
            } else if (lon >= -8999 && lon <= 0) {
                areaClaimStatus = area3.getClaimCount(lat, lon);
            } else if (lon >= -17999 && lon <= -9000) {
                areaClaimStatus = area4.getClaimCount(lat, lon);
            } else {
                revert("Invalid longitude");
            }
        } else {
            revert("Invalid latitude");
        }

        if (areaClaimStatus == 1) {
            MultiClaim.ClaimInfo memory info = multiClaim.getClaimCount(
                lat,
                lon
            );
            return info.claimCount;
        } else {
            return 0;
        }
    }

    function claim(int256 lat, int256 lon) public {
        int8 result;
        if (lat >= -8999 && lat <= 8999) {
            if (lon >= 0 && lon <= 8999) {
                result = area1.firstClaim(lat, lon);
            } else if (lon >= 9000 && lon <= 17999) {
                result = area2.firstClaim(lat, lon);
            } else if (lon >= -8999 && lon <= 0) {
                result = area3.firstClaim(lat, lon);
            } else if (lon >= -17999 && lon <= -9000) {
                result = area4.firstClaim(lat, lon);
            } else {
                revert("Invalid longitude");
            }
        } else {
            revert("Invalid latitude");
        }

        if (result == 1) {
            multiClaim.claimMesh(lat, lon);
        }
    }
}

contract NGP is ERC20Upgradeable {
    // ... [保留 NGP 合约的总体结构]

    // 添加 MeshManagement 的引用
    MeshManagement public meshManagement;

    uint256 public daySupply;

   // mapping(address => mapping(string => MintInfo)) public userMints;

    mapping(string => address[]) public userApplys;

    mapping(string => uint256) public degreeHeats;

    mapping(address => string[]) public userNumbers;

    mapping(address => uint256) public withdrawAmount;

    mapping(address => uint256) public unWithDrawAmount;

    mapping(address => uint256) public rankWithdrawAmount;

    mapping(address => bool) private minters;

    uint256 private spendNonce;

    mapping(address => bool) private isOwner;

    address[] private owners;

    uint256 private required;

    uint256 public genesisTs;

    uint256 public activeMinters;

    uint256 public activeNumbers;

    uint256 public claimMints;

    uint256 public maxMeshHeats;

    uint256 public destructions;

    uint256 public SECONDS_IN_DAY;

    struct StakeInfo {
        uint256 term;
        uint256 maturityTs;
        uint256 amount;
    }

    uint256 public apy;

    uint256 public activeStakes;
    uint256 public totalNGPStaked;

    uint256 public totalEarn;

    mapping(address => StakeInfo) public userStakes;

    mapping(uint256 => uint256) public dayClaims;

    mapping(uint256 => bool) public dayClaimed;

    uint256 public treasuryValue;

    address public FoundationAddr;

    mapping(address => uint256) public stakeValues;

    //当日铸造NGP
    mapping(uint256 => uint256) public dayReceived;

    //当日质押NGP
    mapping(uint256 => uint256) public dayStaked;

    //当日解锁NGP
    mapping(uint256 => uint256) public dayUnStaked;

    mapping(address => uint256) public unWithdraws;

    mapping(address => uint256) public userWithdraws;

    mapping(string => mapping(address => uint256)) public totalWithDraws;
    mapping(string => mapping(address => uint256)) public totalUnWithDraws;

    mapping(address => mapping(uint256 => bool)) public dayReceivedAmount;

    event ClaimMint(address user, string number, uint256 time);

    event ClaimMintReward(address user, string number, uint256 time);

    event Staked(address indexed user, uint256 amount, uint256 term);

    event Withdrawn(address indexed user, uint256 amount, uint256 reward);

    event DegreeHeats(string number, uint256 heat, uint256 len);

    event UserWithDrawEvent(string number, uint256 amount);

    event UserUnWithDrawEvent(string number, uint256 amount);

    event UserReceive(address user);

    modifier isOnlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    function initialize(
        address[] calldata _owners,
        uint256 _apy,
        address _foundationAddr,
        address _meshManagement // 新增参数
    ) external initializer {
        __ERC20_init("TERRA Token", "TERRA");

        // 初始化 MeshManagement 的引用
        meshManagement = MeshManagement(_meshManagement);

        for (uint256 i = 0; i < _owners.length; i++) {
            //onwer should be distinct, and non-zero
            address _owner = _owners[i];
            if (isOwner[_owner] || _owner == address(0x0)) {
                revert();
            }

            isOwner[_owner] = true;
            owners.push(_owner);
        }

        required = _owners.length / 2 + 1;

        SECONDS_IN_DAY = 3_600 * 24;

        genesisTs = block.timestamp;

        apy = _apy;

        FoundationAddr = _foundationAddr;
    }

    function claimMesh(int256 lat, int256 lon) external {
        // 使用 (lat, lon) 作为唯一标识
        //bytes32 meshId = keccak256(abi.encodePacked(lat, lon));

        // 先进行 Mesh 的声明
        meshManagement.claim(lat, lon);

        // 从 meshManagement 的 getClaimCount 方法中获取 claimCount
        uint16 _n = meshManagement.getClaimCount(lat, lon);

        // 计算 degreeHeats
        uint256 _degreeHeats = (6667 * 106**_n * 10**11) / (100**_n);

        // 假设有一个函数 calculateDestructions 来根据 degreeHeats 计算 destructions
        uint256 destruct = calculateDestructions(_degreeHeats);

        if (destructions > 0) {
            _burn(msg.sender, destruct);
        }

        claimMints++;

        // Todo: emit ClaimMint(msg.sender, meshId, block.timestamp);
    }

    // 假设的 calculateDestructions 函数，您可能需要根据实际逻辑进行调整
    function calculateDestructions(uint256 degreeOfHeats)
        private
        pure 
        returns (uint256)
    {
        // 这里是一个简单的示例，您可能需要根据实际的逻辑进行调整
        return degreeOfHeats / 10;
    }

    function SetUserReward(
        address[] calldata _users,
        uint256[] calldata _withdrawAmounts,
        uint256 _totalUnwithdrawAmounts,
        uint8[] memory vs,
        bytes32[] memory rs,
        bytes32[] memory ss
    ) public isOnlyOwner {
        require(validSignature(msg.sender, vs, rs, ss), "invalid signatures");
        spendNonce = spendNonce + 1;

        uint256 _len = _users.length;

        require(_len == _withdrawAmounts.length, "error length");

        for (uint256 i = 0; i < _len; i++) {
            withdrawAmount[_users[i]] = _withdrawAmounts[i];
        }

        treasuryValue += _totalUnwithdrawAmounts;

        _mint(FoundationAddr, (treasuryValue * 10) / 100);
        treasuryValue = (treasuryValue * 90) / 100;
    }

    function getRewardAmount(address _user)
        external
        view
        returns (
            uint256 _userTotalAmount,
            uint256 _userWithdraw,
            uint256 _userUnWithdraw
        )
    {
        _userTotalAmount = userWithdraws[_user];
        _userWithdraw = withdrawAmount[_user];
        _userUnWithdraw = unWithDrawAmount[_user];
    }

    function Receive() public {
        uint256 _amount = withdrawAmount[msg.sender];

        require(_amount > 0, "amount > 0");
        require(
            !dayReceivedAmount[msg.sender][block.timestamp / SECONDS_IN_DAY],
            "day receive"
        );

        dayReceivedAmount[msg.sender][block.timestamp / SECONDS_IN_DAY] = true;

        _amount = (_amount * 10) / 100;

        userWithdraws[msg.sender] += _amount;

        withdrawAmount[msg.sender] = 9 * _amount;

        _mint(msg.sender, _amount);
        emit UserReceive(msg.sender);
    }

    function stake(uint256 amount, uint256 term) external {
        require(balanceOf(msg.sender) >= amount, "TERA: Not enough balance");
        require(amount > 0, "TERA: amount > 0");
        require(term >= 1, "TERA: term >= 1");
        require(userStakes[msg.sender].amount == 0, "TERA: Stake exists"); // 已经质押过了

        // burn staked NGP
        transfer(address(this), amount);
        // create NGP Stake
        _createStake(amount, term); // 创建质押数据

        uint256 _today = (block.timestamp - genesisTs) / SECONDS_IN_DAY;

        dayStaked[_today] += amount;

        emit Staked(msg.sender, amount, term);
    }

    function withdraw() external {
        StakeInfo memory userStake = userStakes[msg.sender];
        require(userStake.amount > 0, "TERA: no stake exists");
        require(userStake.maturityTs <= block.timestamp, "maturityTs");
        // 计算质押奖励
        uint256 ngpReward = _calculateStakeReward(
            userStake.amount,
            userStake.term,
            userStake.maturityTs
        );

        uint256 unLockValue = userStake.amount + ngpReward;

        uint256 _today = (block.timestamp - genesisTs) / SECONDS_IN_DAY;

        stakeValues[msg.sender] += ngpReward;

        totalEarn += ngpReward;

        activeStakes--;
        totalNGPStaked -= userStake.amount;

        dayUnStaked[_today] += unLockValue;

        mint(msg.sender, unLockValue);
        emit Withdrawn(msg.sender, userStake.amount, ngpReward);
        delete userStakes[msg.sender];
    }

    function _calculateStakeReward(
        uint256 amount,
        uint256 term,
        uint256 maturityTs
    ) private view returns (uint256) {
        if (block.timestamp > maturityTs) {
            uint256 rate = (apy * term) / 365;
            return amount * rate;
        }
        return 0;
    }

    function _createStake(uint256 amount, uint256 term) private {
        userStakes[msg.sender] = StakeInfo({
            term: term, // 天数
            maturityTs: block.timestamp + term * SECONDS_IN_DAY, // 到期时间
            amount: amount // 数量
        });

        activeStakes++; // 活跃质押者数量
        totalNGPStaked += amount; // 总的质押数量
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
        require(vs.length >= required, "vs.length >= required");
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
        claimedMesh = activeNumbers;
        maxHeats = maxMeshHeats;
        sinceGenesis = (block.timestamp - genesisTs) / SECONDS_IN_DAY;
    }

    function getEarthDashboard()
        external
        view
        returns (
            uint256 _totalSupply,
            uint256 liquidSupply,
            uint256 destruction,
            uint256 totalStaked,
            uint256 treasury,
            uint256 foundation
        )
    {
        _totalSupply = totalSupply();
        liquidSupply = _totalSupply - balanceOf(address(this));
        destruction = destructions;
        totalStaked = totalNGPStaked;
        treasury = treasuryValue;
        foundation = balanceOf(FoundationAddr);
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
            uint256 offEarthStake
        )
    {
        uint256 price = 0;
        tvl = totalNGPStaked * price;
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
        //当前质押锁定EARTH数量 / 已经累计铸造出来的EARTH总数量。
        uint256 totalSupply = totalSupply();
        if (totalSupply != 0) {
            offEarthStake = (totalNGPStaked * 1000000) / totalSupply;
        }
    }

    function mint(address user, uint256 amount) private {
        uint256 _today = (block.timestamp - genesisTs) / SECONDS_IN_DAY;

        dayReceived[_today] += amount;
        _mint(user, amount);
    }

    function getNetworkEvents()
        external
        view
        returns (
            uint256 _genesisTs,
            uint256[] memory _received,
            uint256[] memory _staked,
            uint256[] memory _unstaked
        )
    {
        uint256 _today = (block.timestamp - genesisTs) / SECONDS_IN_DAY;
        _received = new uint256[](_today);
        _staked = new uint256[](_today);
        _unstaked = new uint256[](_today);

        _genesisTs = genesisTs;

        for (uint256 i = 0; i < _today; i++) {
            _received[i] = dayReceived[i];
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

    function getClaimTsAmount(address _user, string calldata _number)
        public
        view
        returns (int256 count, uint256 _amount)
    {
        //if (userMints[_user][_number].withdrawTs != 0) {
        //    count = -1;
        //} else {
            count = int256(userApplys[_number].length);
            _amount = degreeHeats[_number] / 10;
        //}
    }
}
