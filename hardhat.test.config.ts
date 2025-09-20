import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.8",
    settings: {
      optimizer: { enabled: true, runs: 200 },
    },
  },
  defaultNetwork: "hardhat",
  paths: {
    sources: "contracts",
    tests: "test",
    cache: "cache",
    artifacts: "artifacts",
  },
  mocha: { timeout: 600000 },
};

export default config;


