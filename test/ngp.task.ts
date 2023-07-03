import { BigNumber, ContractReceipt, ethers } from "ethers";
import { ContractInfo } from "../utils/util_contractinfo";
import { logtools } from "../utils/util_log";
import { task } from "hardhat/config";
import Web3 from "web3";
import "@nomiclabs/hardhat-etherscan";
import * as fs from "fs";

let owners = [
  "0x843076428Df85c8F7704a2Be73B0E1b1D5799D4d",
  "0xc4d97570A90096e9f8e23c58A1E7F528fDAa45e7",
  "0xac3D7D1CeDa1c6B4f25B25991f7401D441E13340",
];
let apyValue = 10;
let foundationAddr = "0xDD120c441ED22daC885C9167eaeFFA13522b4644";

export module extNGP {
  export function RegTasks() {
    task("NGP:initialize", "initialize").setAction(async ({}, _hre) => {
      logtools.logyellow("method == [NGP:initialize]");
      await ContractInfo.LoadFromFile(_hre);

      let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");
      logtools.logblue("ngpAddr = " + contrat.address);

      let tran = await contrat.initialize(owners, apyValue, foundationAddr);
      let recipt: ContractReceipt = await tran.wait();
      logtools.loggreen("result = [");
      logtools.loggreen("     hash = " + recipt.transactionHash);
      logtools.loggreen("     status = " + recipt.status);
      logtools.loggreen("]");
      logtools.logcyan(
        "矿工费" +
          ethers.utils.formatUnits(
            recipt.gasUsed.mul(5000000000),
            BigNumber.from("18")
          )
      );
    });
    task("NGP:claimMint", "claimMint").setAction(async ({}, _hre) => {
      logtools.logyellow("method == [NGP:claimMint]");
      await ContractInfo.LoadFromFile(_hre);

      let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");

      let tran = await contrat.claimMint("E11396N2247");
      let recipt: ContractReceipt = await tran.wait();
      logtools.loggreen("result = [");
      logtools.loggreen("     hash = " + recipt.transactionHash);
      logtools.loggreen("     status = " + recipt.status);
      logtools.loggreen("]");
      logtools.logcyan(
        "矿工费" +
          ethers.utils.formatUnits(
            recipt.gasUsed.mul(5000000000),
            BigNumber.from("18")
          )
      );
    });

    task("NGP:Receive", "Receive").setAction(async ({}, _hre) => {
      logtools.logyellow("method == [NGP:Receive]");
      await ContractInfo.LoadFromFile(_hre);

      let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");

      let tran = await contrat.Receive();
      let recipt: ContractReceipt = await tran.wait();
      logtools.loggreen("result = [");
      logtools.loggreen("     hash = " + recipt.transactionHash);
      logtools.loggreen("     status = " + recipt.status);
      logtools.loggreen("]");
      logtools.logcyan(
        "矿工费" +
          ethers.utils.formatUnits(
            recipt.gasUsed.mul(5000000000),
            BigNumber.from("18")
          )
      );
    });

    task("NGP:stake", "stake")
      .addPositionalParam("amount", "amount")
      .addPositionalParam("term", "term")
      .setAction(async ({ amount, term }, _hre) => {
        logtools.logyellow("method == [NGP:stake]");
        await ContractInfo.LoadFromFile(_hre);

        let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");

        amount = ethers.utils.parseEther(amount);

        console.log("===========amount==========:", amount);

        let tran = await contrat.stake(amount, term);
        let recipt: ContractReceipt = await tran.wait();
        logtools.loggreen("result = [");
        logtools.loggreen("     hash = " + recipt.transactionHash);
        logtools.loggreen("     status = " + recipt.status);
        logtools.loggreen("]");
        logtools.logcyan(
          "矿工费" +
            ethers.utils.formatUnits(
              recipt.gasUsed.mul(5000000000),
              BigNumber.from("18")
            )
        );
      });

    task("NGP:claimMintReward", "claimMintReward").setAction(
      async ({}, _hre) => {
        logtools.logyellow("method == [NGP:claimMintReward]");
        await ContractInfo.LoadFromFile(_hre);

        const [owner, addr1] = await _hre.ethers.getSigners();

        let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");

        let private2 =
          "0xb1a82552591c92f41e7d3b5bcfa346f10815fb8b9e709e4fb63345705d45cc62";

        let resu1 = await Sign(owner.address, private1);

        //claimMintReward(address _user,uint256 _amount,uint8[] memory vs, bytes32[] memory rs, bytes32[] memory ss)
        let amount = ethers.utils.parseEther("1");
        let tran = await contrat.claimMintReward(owner.address, amount);

        let recipt: ContractReceipt = await tran.wait();
        logtools.loggreen("result = [");
        logtools.loggreen("     hash = " + recipt.transactionHash);
        logtools.loggreen("     status = " + recipt.status);
        logtools.loggreen("]");
        logtools.logcyan(
          "矿工费" +
            ethers.utils.formatUnits(
              recipt.gasUsed.mul(5000000000),
              BigNumber.from("18")
            )
        );
      }
    );

    task("NGP:approve", "approve").setAction(async ({}, _hre) => {
      logtools.logyellow("method == [NGP:approve]");
      await ContractInfo.LoadFromFile(_hre);

      let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");

      console.log("========contrat========:", contrat.address);

      let tran = await contrat.approve(
        contrat.address,
        "100000000000000000000000000000000000000"
      );

      let recipt: ContractReceipt = await tran.wait();
      logtools.loggreen("result = [");
      logtools.loggreen("     hash = " + recipt.transactionHash);
      logtools.loggreen("     status = " + recipt.status);
      logtools.loggreen("]");
      logtools.logcyan(
        "矿工费" +
          ethers.utils.formatUnits(
            recipt.gasUsed.mul(5000000000),
            BigNumber.from("18")
          )
      );
    });

    task("NGP:getBurnAmount", "getBurnAmount").setAction(async ({}, _hre) => {
      logtools.logyellow("method == [NGP:getBurnAmount]");
      await ContractInfo.LoadFromFile(_hre);

      let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");

      let getBurnAmount = await contrat.getBurnAmount("E11402N2255");
      console.log("getBurnAmount:", getBurnAmount);
    });
    //706702000000000

    task("NGP:allowance", "allowance").setAction(async ({}, _hre) => {
      logtools.logyellow("method == [NGP:allowance]");
      await ContractInfo.LoadFromFile(_hre);

      let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");

      let MeshData = await contrat.allowance(
        "0x75bC9FBD1F907695A5ab823772F78981bE0BFC83",
        contrat.address
      );
      console.log("MeshData:", MeshData);
    });

    task("NGP:getMeshData", "getMeshData").setAction(async ({}, _hre) => {
      logtools.logyellow("method == [NGP:getMeshData]");
      await ContractInfo.LoadFromFile(_hre);

      let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");

      let MeshData = await contrat.getMeshData();
      console.log("MeshData:", MeshData);
    });

    task("NGP:getStakeInfo", "getStakeInfo").setAction(async ({}, _hre) => {
      logtools.logyellow("method == [NGP:getStakeInfo]");
      await ContractInfo.LoadFromFile(_hre);

      let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");

      let MeshData = await contrat.totalSupply();
      console.log("getStakeInfo:", MeshData);
    });

    task("NGP:getMeshDashboard", "getMeshDashboard").setAction(
      async ({}, _hre) => {
        logtools.logyellow("method == [NGP:getMeshDashboard]");
        await ContractInfo.LoadFromFile(_hre);

        let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");

        let getMeshDashboard = await contrat.getMeshDashboard();
        console.log("MeshData:", getMeshDashboard);
      }
    );

    task("NGP:getStakeInfo", "getStakeInfo").setAction(async ({}, _hre) => {
      logtools.logyellow("method == [NGP:getStakeInfo]");
      await ContractInfo.LoadFromFile(_hre);

      let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");

      let getMeshDashboard = await contrat.getStakeInfo(
        "0x75bC9FBD1F907695A5ab823772F78981bE0BFC83"
      );
      console.log("MeshData:", getMeshDashboard);
    });

    task("NGP:getEarthDashboard", "getEarthDashboard").setAction(
      async ({}, _hre) => {
        logtools.logyellow("method == [NGP:getEarthDashboard]");
        await ContractInfo.LoadFromFile(_hre);

        let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");

        let getEarthDashboard = await contrat.getEarthDashboard();
        console.log("MeshData:", getEarthDashboard);
      }
    );

    task("NGP:balanceOf", "balanceOf").setAction(async ({}, _hre) => {
      logtools.logyellow("method == [NGP:balanceOf]");
      await ContractInfo.LoadFromFile(_hre);

      let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");

      let getEarthDashboard = await contrat.balanceOf(
        "0x843076428Df85c8F7704a2Be73B0E1b1D5799D4d"
      );
      console.log("MeshData:", getEarthDashboard);
    });

    task("NGP:getStakeTime", "getStakeTime")
      .addPositionalParam("user", "user")
      .setAction(async ({ user }, _hre) => {
        logtools.logyellow("method == [NGP:getStakeTime]");
        await ContractInfo.LoadFromFile(_hre);

        let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");

        let MeshData = await contrat.getStakeTime(user);
        console.log("MeshData:", MeshData);
      });

    task("NGP:getNetworkEvents", "getNetworkEvents").setAction(
      async ({ user }, _hre) => {
        logtools.logyellow("method == [NGP:getNetworkEvents]");
        await ContractInfo.LoadFromFile(_hre);

        let contrat = await ContractInfo.getContractProxy("NGP", "NGPProxy");

        let NetworkEvents = await contrat.getNetworkEvents();
        console.log("NetworkEvents:", NetworkEvents);
      }
    );

    async function Sign(sender, privateKey) {
      let prefix = "\x19Ethereum Signed Message:\n32";

      let signingKey = new ethers.utils.SigningKey(privateKey);

      let newContract = await ContractInfo.getContractProxy("NGP", "NGPProxy");

      let spendNonce = await newContract.getSpendNonce();

      let messageHash = ethers.utils.keccak256(
        ethers.utils.solidityPack(
          ["address", "uint256", "uint256"],
          [sender, 5, spendNonce]
        )
      );

      console.log("spendNonce:", spendNonce);

      const msg = ethers.utils.keccak256(
        ethers.utils.solidityPack(["string", "bytes32"], [prefix, messageHash])
      );

      let signature = await signingKey.signDigest(msg);

      let { v, r, s } = signature;

      v = v - 27;

      return [v, r, s];
    }
  }
}
