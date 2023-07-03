/**
 * @type import('hardhat/config').HardhatUserConfig
 */
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";

import "hardhat-abi-exporter";
import "hardhat-deploy";
//import * as env from "dotenv";
import { HardhatUserConfig } from "hardhat/types";
import * as fs from "fs";
import "hardhat-contract-sizer";

type ContractSizer = {
  contractSizer: {
    runOnCompile: boolean;
  };
};
type HardhatConfig = HardhatUserConfig & ContractSizer;

import { extTask } from "./hardhat.task";
import { extFoundation } from "./test/foundation.task";
import { extNGP } from "./test/ngp.task";
import { Sign } from "./test/sign.task";

console.log("config hardhat.");

extTask.RegTasks();
extFoundation.RegTasks();
extNGP.RegTasks();
Sign.RegTasks();

// get prikeyts from a json file
let buffer = fs.readFileSync("local_privkeys.json");

// let buffer = fs.readFileSync(
//   "/Volumes/KINGSTON/privkey/ulab/bscmain_privkeys.json"
// );
// let buffer = fs.readFileSync("rinkeby_privkeys.json");
// let buffer = fs.readFileSync("bsctest_privkeys.json");
// let buffer = fs.readFileSync("bscmain_privkeys.json");
let srcjson = JSON.parse(buffer.toString());

let namedkeys: { [id: string]: number } = srcjson["namedkeys"];
let onlykeys: string[] = srcjson["prikeys"] as string[];
let hardhat_prikeys = [];
for (var i = 0; i < onlykeys.length; i++)
  hardhat_prikeys.push({
    privateKey: onlykeys[i],
    balance: "99000000000000000000",
  });

const config: HardhatConfig = {
  solidity: {
    version: "0.8.8",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  contractSizer: {
    runOnCompile: true,
  },
  namedAccounts: namedkeys, //from json
  paths: {
    artifacts: "artifacts",
    deploy: "deploy",
    sources: "contracts",
    tests: "test",
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      accounts: hardhat_prikeys,
    },
    bsctest: {
      url: "https://bsc.getblock.io/aa12cf51-66b0-40a0-acef-68c538b3aacc/testnet/",
      // url: "https://bsc-testnet.nodereal.io/v1/c92486b30c634586b6864cd4f4361440",
      accounts: onlykeys,
      chainId: 97,
      live: true,
      saveDeployments: true,
      tags: ["staging"],
    },
    bscmain: {
      url: "https://bsc-dataseed2.binance.org/",
      accounts: onlykeys,
      chainId: 56,
      live: true,
      saveDeployments: true,
      tags: ["staging"],
    },
    polygon: {
      url: "https://polygon-rpc.com",
      accounts: onlykeys,
      chainId: 137,
      live: true,
      saveDeployments: true,
      tags: ["staging"],
      gas: 80000000,
      gasPrice: 8000000000,
    },
    polygon_test: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: onlykeys,
      chainId: 80001,
      live: true,
      saveDeployments: true,
      tags: ["staging"],
      gas: 80000000,
      gasPrice: 8000000000,
    },
    avalanche: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      accounts: onlykeys,
      chainId: 43114,
      live: true,
      saveDeployments: true,
      tags: ["staging"],
      gas: 800000000,
      gasPrice: 80000000000,
    },
    avalanche_test: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      accounts: onlykeys,
      chainId: 43113,
      live: true,
      saveDeployments: true,
      tags: ["staging"],
      gas: 8000000000,
      gasPrice: 800000000000,
    },
    goerli: {
      url: "https://eth-goerli.g.alchemy.com/v2/MuYCfm2woPaS-j4opSyasMdBsiGiWk0R",
      accounts: onlykeys,
      chainId: 5,
      live: true,
      saveDeployments: true,
      tags: ["staging"],
    },
    local: {
      url: "http://127.0.0.1:8545/",
      accounts: onlykeys,
      live: true,
      saveDeployments: true,
      tags: ["staging"],
      gas: 2500000,
      gasPrice: 8000000000,
    },
    forking: {
      url: "https://data-seed-prebsc-2-s1.binance.org:8545/",
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://bscscan.com/
    apiKey: "8RP2CMPTXGBTMBT1SDD2KS2C9H4NQ6AS79",
  },
  mocha: {
    timeout: 600000,
  },
};

export default config;
