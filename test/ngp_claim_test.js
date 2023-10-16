const meshManagementABI = [
  {
    inputs: [],
    name: "addSpendNonce",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "Approval",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "approve",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "_number",
        type: "string",
      },
    ],
    name: "claimMint",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "string",
        name: "number",
        type: "string",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "time",
        type: "uint256",
      },
    ],
    name: "ClaimMint",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "string",
        name: "number",
        type: "string",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "time",
        type: "uint256",
      },
    ],
    name: "ClaimMintReward",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "subtractedValue",
        type: "uint256",
      },
    ],
    name: "decreaseAllowance",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "number",
        type: "string",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "heat",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "len",
        type: "uint256",
      },
    ],
    name: "DegreeHeats",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "addedValue",
        type: "uint256",
      },
    ],
    name: "increaseAllowance",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address[]",
        name: "_owners",
        type: "address[]",
      },
      {
        internalType: "uint256",
        name: "_apy",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "_foundationAddr",
        type: "address",
      },
    ],
    name: "initialize",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint8",
        name: "version",
        type: "uint8",
      },
    ],
    name: "Initialized",
    type: "event",
  },
  {
    inputs: [],
    name: "Receive",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address[]",
        name: "_users",
        type: "address[]",
      },
      {
        internalType: "uint256[]",
        name: "_withdrawAmounts",
        type: "uint256[]",
      },
      {
        internalType: "uint256",
        name: "_totalUnwithdrawAmounts",
        type: "uint256",
      },
      {
        internalType: "uint8[]",
        name: "vs",
        type: "uint8[]",
      },
      {
        internalType: "bytes32[]",
        name: "rs",
        type: "bytes32[]",
      },
      {
        internalType: "bytes32[]",
        name: "ss",
        type: "bytes32[]",
      },
    ],
    name: "SetUserReward",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "term",
        type: "uint256",
      },
    ],
    name: "stake",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "term",
        type: "uint256",
      },
    ],
    name: "Staked",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "transfer",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "transferFrom",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "user",
        type: "address",
      },
    ],
    name: "UserReceive",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "number",
        type: "string",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "UserUnWithDrawEvent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "number",
        type: "string",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "UserWithDrawEvent",
    type: "event",
  },
  {
    inputs: [],
    name: "withdraw",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "reward",
        type: "uint256",
      },
    ],
    name: "Withdrawn",
    type: "event",
  },
  {
    inputs: [],
    name: "activeMinters",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "activeNumbers",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "activeStakes",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        internalType: "address",
        name: "spender",
        type: "address",
      },
    ],
    name: "allowance",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "apy",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "balanceOf",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "claimMints",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "dayClaimed",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "dayClaims",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "dayReceived",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "dayReceivedAmount",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "dayStaked",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "daySupply",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "dayUnStaked",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "decimals",
    outputs: [
      {
        internalType: "uint8",
        name: "",
        type: "uint8",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    name: "degreeHeats",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "destructions",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "FoundationAddr",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "genesisTs",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_user",
        type: "address",
      },
      {
        internalType: "string",
        name: "_number",
        type: "string",
      },
    ],
    name: "getClaimTsAmount",
    outputs: [
      {
        internalType: "int256",
        name: "count",
        type: "int256",
      },
      {
        internalType: "uint256",
        name: "_amount",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getEarthDashboard",
    outputs: [
      {
        internalType: "uint256",
        name: "_totalSupply",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "liquidSupply",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "destruction",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "totalStaked",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "treasury",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "foundation",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getMeshDashboard",
    outputs: [
      {
        internalType: "uint256",
        name: "participants",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "totalclaimMints",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "claimedMesh",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "maxHeats",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "sinceGenesis",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getMeshData",
    outputs: [
      {
        internalType: "uint256",
        name: "userCounts",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "launchData",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "totalMinted",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "liquidSupply",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getNetworkEvents",
    outputs: [
      {
        internalType: "uint256",
        name: "_genesisTs",
        type: "uint256",
      },
      {
        internalType: "uint256[]",
        name: "_received",
        type: "uint256[]",
      },
      {
        internalType: "uint256[]",
        name: "_staked",
        type: "uint256[]",
      },
      {
        internalType: "uint256[]",
        name: "_unstaked",
        type: "uint256[]",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_user",
        type: "address",
      },
    ],
    name: "getRewardAmount",
    outputs: [
      {
        internalType: "uint256",
        name: "_userTotalAmount",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_userWithdraw",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "_userUnWithdraw",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getSpendNonce",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_user",
        type: "address",
      },
    ],
    name: "getStakeInfo",
    outputs: [
      {
        internalType: "uint256",
        name: "tvl",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "revenue",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "earned",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "claimable",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "totalApy",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "staked",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "totalEarnValue",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "offEarthStake",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "user",
        type: "address",
      },
    ],
    name: "getStakeTime",
    outputs: [
      {
        internalType: "uint256",
        name: "ts",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "maxMeshHeats",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "name",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "rankWithdrawAmount",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "SECONDS_IN_DAY",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "stakeValues",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "symbol",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "totalEarn",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "totalNGPStaked",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "totalSupply",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "totalUnWithDraws",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "totalWithDraws",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "treasuryValue",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "unWithDrawAmount",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "unWithdraws",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "userApplys",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    name: "userMints",
    outputs: [
      {
        internalType: "address",
        name: "user",
        type: "address",
      },
      {
        internalType: "string",
        name: "number",
        type: "string",
      },
      {
        internalType: "uint256",
        name: "updateTs",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "withdrawTs",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "userNumbers",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "userStakes",
    outputs: [
      {
        internalType: "uint256",
        name: "term",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "maturityTs",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "userWithdraws",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_sender",
        type: "address",
      },
      {
        internalType: "uint8[]",
        name: "vs",
        type: "uint8[]",
      },
      {
        internalType: "bytes32[]",
        name: "rs",
        type: "bytes32[]",
      },
      {
        internalType: "bytes32[]",
        name: "ss",
        type: "bytes32[]",
      },
    ],
    name: "validSignature",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "withdrawAmount",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

const { ethers } = require("ethers");
const cluster = require("cluster");

const PRIVATE_KEY =
  "ddc17d572c0359ba191849aa70ad4b63730cf1fd464b480c5b460a8f8d323e54";

function getRandomLatLon() {
  const lat = Math.floor(Math.random() * 18000) - 9000;
  const lon = Math.floor(Math.random() * 36000) - 18000;
  return { lat, lon };
}

function formatNumberForClaimMint(lat, lon) {
  const latPrefix = lat >= 0 ? "N" : "S";
  const lonPrefix = lon >= 0 ? "E" : "W";
  return `${lonPrefix}${100 * Math.abs(lon / 1000).toFixed(2)}${latPrefix}${
    100 * Math.abs(lat / 1000).toFixed(2)
  }`;
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const meshManagementAddress = "0x297A60578fd0e13076BF06CFeb2BBCD74F2680D2";

const RPC_URLS = [
  "https://goerli.infura.io/v3/410184d8b4a84614b3f2b81a5e78bcd0"
];

function getRandomRpcUrl() {
  const randomIndex = Math.floor(Math.random() * RPC_URLS.length);
  return RPC_URLS[randomIndex];
}

async function testClaim(lat, lon) {
  let timings = [];
  let gasUsages = [];

  // Set the provider to a random RPC URL
  const provider = new ethers.providers.JsonRpcProvider(getRandomRpcUrl());
  const signer = new ethers.Wallet(PRIVATE_KEY, provider); // Create a signer associated with the new provider
  const meshManagementInstance = new ethers.Contract(
    meshManagementAddress,
    meshManagementABI,
    signer
  ); // Use the new signer to create the contract instance

  try {
    for (let i = 0; i < 1; i++) {
      const formattedNumber = formatNumberForClaimMint(lat, lon);
      console.log(
        `===================Start claimMint test for number: ${formattedNumber} =====================`
      );

      const startTime = Date.now();
      const tx = await meshManagementInstance.claimMint(formattedNumber, {
        gasLimit: 30000000,
      });
      const receipt = await tx.wait();
      const endTime = Date.now();

      console.log(`Attempt: ${i + 1}`);
      const gasUsed = receipt.gasUsed.toString();
      console.log(`Gas: ${gasUsed}`);

      timings.push(endTime - startTime);
      gasUsages.push(gasUsed);
    }
  } catch (error) {
    if (error.code === "TRANSACTION_REPLACED") {
      console.error(
        "Transaction was replaced. Waiting for a while before retrying..."
      );
      await new Promise((resolve) => setTimeout(resolve, 10000)); // wait for 10 seconds
      return await testClaim(lat, lon); // retry the function
    } else {
      console.error(
        `Error calling claimMint for number: ${formatNumberForClaimMint(
          lat,
          lon
        )}`,
        error
      );
    }
  }

  return { timings, gasUsages };
}

async function runTestsForThread(threadNumber) {
  let totalTimings = [0];
  let totalGasUsages = [0];

  for (let i = 0; i < 1000; i++) {
    console.log(`Thread ${threadNumber}`);
    const { lat, lon } = getRandomLatLon();
    const { timings, gasUsages } = await testClaim(lat, lon);

    totalTimings[0] += timings[0];
    totalGasUsages[0] += parseInt(gasUsages[0]);
  }

  console.log(
    `Thread ${threadNumber} - Average time: ${totalTimings[0] / 10}ms`
  );
  console.log(
    `Thread ${threadNumber} - Average gas: ${totalGasUsages[0] / 10}`
  );
}

async function startThreads() {
  const threadCount = 3;
  for (let i = 0; i < threadCount; i++) {
    console.log(`*** Thread ${threadCount} start:`);
    runTestsForThread(i);

    await sleep(10000); // 每个线程错开10秒
  }
}

startThreads();
