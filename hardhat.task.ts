import { BigNumber, ContractReceipt, ethers } from "ethers";

import { task } from "hardhat/config";
import { ContractInfo } from "./utils/util_contractinfo";
import { ContractTool } from "./utils/util_contracttool";
import { InitTool } from "./utils/util_inittool";
import { logtools } from "./utils/util_log";
import "@nomiclabs/hardhat-etherscan";

export module extTask {
  export function RegTasks() {
    //在这里配置一些hardhat命令,deploytool里不应该有东西，全在这
    task("xbalance", "blance of one addr")
      .addPositionalParam("addrname", "like 'deployer'") //直接跟在命令后的参数
      .setAction(async ({ addrname }, _hre) => {
        await ContractInfo.LoadFromFile(_hre);
        let name = addrname;
        console.log("name=" + name);
        let addr = (await _hre.getNamedAccounts())[name];
        console.log("addr=" + addr);
        let signer = await _hre.ethers.getSigner(addr);
        console.log(_hre.ethers);
        let blanceof: BigNumber = await signer.getBalance();
        console.log("balanceof=" + ethers.utils.formatEther(blanceof));
      });

    //在这里配置一些hardhat命令,deploytool里不应该有东西，全在这
    task("xchainid", "chainid").setAction(async ({}, _hre) => {
      await ContractInfo.LoadFromFile(_hre);
      let addr = (await _hre.getNamedAccounts())["deployer"];
      console.log("addr=" + addr);
      let signer = await _hre.ethers.getSigner(addr);
      console.log(_hre.ethers);
      let chainid = await signer.getChainId();
      console.log("chainid=" + chainid);
    });

    task("xdeploy", "deplay contracts")
      .addPositionalParam("type", "[all|group|one]")
      .addOptionalPositionalParam("name")
      .setAction(async ({ type, name }, _hre) => {
        await ContractInfo.LoadFromFile(_hre);
        let _name = name as string;
        console.log("xdeploy:" + type + "," + _name);
        if (type == "all") {
          await ContractTool.DeployAll(_hre);
        } else if (type == "group") {
          await ContractTool.DeployGroup(_hre, _name);
        } else if (type == "one") {
          let info = ContractTool.GetInfo(_hre, _name);
          if (info == null) throw "not found contract.";
          await ContractTool.DeployOne(_hre, info);
        } else {
          throw "not support this type.";
        }
      });

    task("xverify", "verify contracts")
      .addPositionalParam("type", "[all|group|one]")
      .addOptionalPositionalParam("name")
      .setAction(async ({ type, name }, _hre) => {
        await ContractInfo.LoadFromFile(_hre);
        let _name = name as string;
        console.log("xverify:" + type + "," + _name);
        if (type == "all") {
          await ContractTool.DeployAll(_hre);
          await ContractTool.VerifyAll(_hre);
        } else if (type == "group") {
          await ContractTool.DeployGroup(_hre, _name);
          await ContractTool.VerifyGroup(_hre, _name);
        } else if (type == "one") {
          let info = ContractTool.GetInfo(_hre, _name);
          if (info == null) throw "not found contract.";
          await ContractTool.DeployOne(_hre, info);
          await ContractTool.VerifyOne(_hre, info);
        } else {
          throw "not support this type.";
        }
      });

    task("xcheck", "check contracts")
      .addPositionalParam("type", "[all|group|one]")
      .addOptionalPositionalParam("name")
      .setAction(async ({ type, name }, _hre) => {
        await ContractInfo.LoadFromFile(_hre);
        console.log("==xcheck");

        await ContractInfo.LoadFromFile(_hre);
        InitTool.RegInitFuncs(_hre);

        let _name = name as string;
        console.log("xcheck:" + type + "," + _name);
        if (type == "all") {
          await InitTool.CheckFunc_All(_hre);
        } else if (type == "group") {
          await InitTool.CheckFunc_Group(_hre, _name);
        } else if (type == "one") {
          await InitTool.CheckFunc_One(_hre, _name);
        } else {
          throw "not support this type.";
        }
      });

    task("xinit", "init contracts")
      .addPositionalParam("type", "[all|group|one]")
      .addOptionalPositionalParam("name")
      .setAction(async ({ type, name }, _hre) => {
        await ContractInfo.LoadFromFile(_hre);
        console.log("==xinit");

        if (_hre.network.name == "hardhat") {
          //本地测试合约是没有的，必须跑一遍
          await ContractTool.DeployAll(_hre);
          InitTool.inittwice = true;
        }
        await ContractInfo.LoadFromFile(_hre);
        InitTool.RegInitFuncs(_hre);

        let _name = name as string;
        console.log("xinit:" + type + "," + _name);
        if (type == "all") {
          await InitTool.InitFunc_All(_hre);
        } else if (type == "group") {
          await InitTool.InitFunc_Group(_hre, _name);
        } else if (type == "one") {
          await InitTool.InitFunc_One(_hre, _name);
        } else {
          throw "not support this type.";
        }
      });

    task("xupgrade", "xproxy upgrade functions")
      .addPositionalParam("admin", "Admin Contract's Name")
      .addPositionalParam("proxy", "Proxy Contract's Name")
      .addPositionalParam("target", "Target Contract's Name or Addr")
      .setAction(async ({ admin, proxy, target }, _hre) => {
        await ContractInfo.LoadFromFile(_hre);
        console.log("==xupgrade");
        await ContractInfo.LoadFromFile(_hre);
        let admincontrat = await ContractInfo.getContract(admin);
        let proxycontrat = await ContractInfo.getContract(proxy);

        let target_addr = "";
        if (target.indexOf("0x") == true) {
          target_addr = target;
        } else {
          target_addr = await ContractInfo.getContractAddress(target);
        }
        logtools.logblue("admin=" + admincontrat.address);
        logtools.logblue("proxy=" + proxycontrat.address);
        logtools.logblue("target=" + target_addr);

        if (admincontrat.address == undefined || admincontrat.address == "")
          throw "not right admin";
        if (proxycontrat.address == undefined || proxycontrat.address == "")
          throw "not right proxy";
        if (target_addr == "" || target_addr == null) throw "not right target";

        let tran = await admincontrat.upgrade(
          proxycontrat.address,
          target_addr
        );
        let recipt: ContractReceipt = await tran.wait();
        console.log("changestate=" + recipt.status);
      });
  }
}
