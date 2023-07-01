import { BigNumber, ContractReceipt, ethers } from "ethers";
import { ContractInfo } from "../utils/util_contractinfo";
import { logtools } from "../utils/util_log";
import { task } from "hardhat/config";
import Web3 from "web3";
import "@nomiclabs/hardhat-etherscan";
import * as fs from "fs";

let privateKey =
  "0x53a493af39d3f8ea6801d163a85b671097eb41115a0b0aec1e24dfffd4b045bb";

export module Sign {
  export function RegTasks() {
    task("Sign:verifyEcrecover", "verifyEcrecover").setAction(
      async ({}, _hre) => {
        let messageHash = ethers.utils.solidityKeccak256(
          ["address", "address", "uint32", "address", "uint32", "bool"],
          [
            "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            100000,
            "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            1,
            false,
          ]
        );

        let prefix = "\x19Ethereum Signed Message:\n32";

        const msg = ethers.utils.keccak256(
          ethers.utils.solidityPack(
            ["string", "bytes32"],
            [prefix, messageHash]
          )
        );

        let signingKey = new ethers.utils.SigningKey(privateKey);

        let signature = await signingKey.signDigest(msg);

        let { v, r, s } = signature;

        //恢复签名地址
        const recoveredAddress = ethers.utils.recoverAddress(msg, signature);
        console.log("前端恢复签名者:", recoveredAddress);

        logtools.logyellow("method == [Sign:verifyEcrecover]");
        await ContractInfo.LoadFromFile(_hre);

        let contrat = await ContractInfo.getContract("SIGN");
        //verifyEcrecover(bytes32  messageHash, uint8 v, bytes32 r, bytes32 s)
        let MeshData = await contrat.verifyEcrecover(messageHash, v, r, s);
        console.log("合约恢复签名者:", MeshData);
      }
    );
  }
}
