import { Contract, ContractReceipt, ethers } from "ethers";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import * as fs from "fs";
import { ContractInfo } from "./util_contractinfo";
import { DeployOptions, Libraries } from "hardhat-deploy/types";

import "@nomiclabs/hardhat-etherscan";
import { logtools } from "./util_log";

export class ContractTool {
  static async PassBlock(hre: HardhatRuntimeEnvironment, blockcount: number) {
    let name = hre.network.name;
    if (name == "hardhat") {
      let nowcount = await hre.ethers.provider.getBlockNumber();
      if (nowcount < blockcount) {
        //过块
        console.log("quick pass to block " + blockcount);
        for (let i = nowcount; i < blockcount; i++) {
          await hre.network.provider.send("evm_mine");
        }
      }
      console.log(
        "==done block " +
          name +
          "=" +
          (await hre.ethers.provider.getBlockNumber())
      );
    }
  }
  static GetEvent(recipt: ContractReceipt, eventname: string): any[] {
    let event = recipt.events?.find((d: any) => d.event == eventname);
    if (event == null || event.args == null)
      throw "error get event:" + eventname;
    return event.args as any[];
  }
  // private static deployfile = "deployinfo_bscmain.json";
  // private static deployfile = "deployinfo_rinkeby.json";

  private static deploygroups: GroupDeployInfo[] = [];

  static async LoadDeployInfo(hre: HardhatRuntimeEnvironment) {
    // let buffer = fs.readFileSync(ContractTool.deployfile);
    let buffer = fs.readFileSync(hre.network.name + "_deployinfo.json");
    let srcjson = JSON.parse(buffer.toString());
    ContractTool.deploygroups = srcjson["groups"] as GroupDeployInfo[];
  }
  static async DeployAll(hre: HardhatRuntimeEnvironment) {
    //logtools.RemoveAppend();
    console.log(hre);

    logtools.UpdateConfigFileName(hre);
    logtools.RemoveConfig();

    if (ContractTool.deploygroups.length == 0) ContractTool.LoadDeployInfo(hre);
    for (var key in ContractTool.deploygroups) {
      await ContractTool.DeployGroup(hre, ContractTool.deploygroups[key].group);
    }
  }
  static async DeployGroup(hre: HardhatRuntimeEnvironment, name: string) {
    console.log("==DeployGroup:" + name);
    if (ContractTool.deploygroups.length == 0) ContractTool.LoadDeployInfo(hre);

    let group: GroupDeployInfo | null = null;
    for (var key in ContractTool.deploygroups) {
      let _g = ContractTool.deploygroups[key];
      if (_g.group == name) group = _g;
    }

    if (group == null) {
      throw "not found group:" + name;
    }
    for (var key in group.contracts) {
      await ContractTool.DeployOne(hre, group.contracts[key]);
    }
    console.log("==DeployGroup:" + name + " done.");
  }
  static GetGroupNames(hre: HardhatRuntimeEnvironment): string[] {
    if (ContractTool.deploygroups.length == 0) ContractTool.LoadDeployInfo(hre);
    let names: string[] = [];
    for (var key in ContractTool.deploygroups) {
      names.push(ContractTool.deploygroups[key].group);
    }
    return names;
  }
  static GetGroup(
    hre: HardhatRuntimeEnvironment,
    name: string
  ): GroupDeployInfo | null {
    if (ContractTool.deploygroups.length == 0) ContractTool.LoadDeployInfo(hre);
    let group: GroupDeployInfo | null = null;
    for (var key in ContractTool.deploygroups) {
      let _g = ContractTool.deploygroups[key];
      if (_g.group == name) return _g;
    }
    return null;
  }
  static GetInfo(
    hre: HardhatRuntimeEnvironment,
    name: string
  ): ContractDeployInfo | null {
    if (ContractTool.deploygroups.length == 0) ContractTool.LoadDeployInfo(hre);
    let group: GroupDeployInfo | null = null;
    for (var key in ContractTool.deploygroups) {
      let _g = ContractTool.deploygroups[key];

      for (var ik in _g.contracts) {
        if (_g.contracts[ik].name == name) return _g.contracts[ik];
      }
    }
    return null;
  }
  static async DeployOne(
    hre: HardhatRuntimeEnvironment,
    info: ContractDeployInfo
  ) {
    if (ContractTool.deploygroups.length == 0) ContractTool.LoadDeployInfo(hre);
    console.log("deployone:" + JSON.stringify(info));
    console.log("--t1");
    let deployer = (await hre.getNamedAccounts())[info.deployer];
    console.log("--info:", info);
    console.log("--t2");
    let _args: string[] = [];
    for (var key in info.args) {
      _args.push(ContractTool.GetString(info.args[key]));
    }
    console.log("--t3");
    var op: DeployOptions = {
      from: deployer,
      args: _args,
      log: true,
      autoMine: true,
    };
    if (info.libraries != null) {
      op.libraries = {};
      for (var key in info.libraries) {
        op.libraries[key] = ContractTool.GetString(info.libraries[key]);
      }
    }
    await ContractInfo.Deploy(hre, info.name, op);
  }
  static async VerifyAll(hre: HardhatRuntimeEnvironment) {
    if (ContractTool.deploygroups.length == 0) ContractTool.LoadDeployInfo(hre);
    for (var key in ContractTool.deploygroups) {
      await ContractTool.VerifyGroup(hre, ContractTool.deploygroups[key].group);
    }
  }
  static async VerifyGroup(hre: HardhatRuntimeEnvironment, name: string) {
    console.log("==VerifyGroup:" + name);
    if (ContractTool.deploygroups.length == 0) ContractTool.LoadDeployInfo(hre);

    let group: GroupDeployInfo | null = null;
    for (var key in ContractTool.deploygroups) {
      let _g = ContractTool.deploygroups[key];
      if (_g.group == name) group = _g;
    }

    if (group == null) {
      throw "not found group:" + name;
    }
    for (var key in group.contracts) {
      try {
        await ContractTool.VerifyOne(hre, group.contracts[key]);
      } catch (e: any) {
        console.log("verify with error:" + e);
      }
    }
    console.log("==VerifyGroup:" + name + " done.");
  }
  static async VerifyOne(
    hre: HardhatRuntimeEnvironment,
    info: ContractDeployInfo
  ) {
    console.log("verify=" + info.name);
    let addr = ContractInfo.getContractAddress(info.name);
    let _args: string[] = [];
    for (var key in info.args) {
      _args.push(ContractTool.GetString(info.args[key]));
    }
    let vargs: VerificationSubtaskArgs = {
      address: addr,
      constructorArguments: _args,
    };
    if (info.verify != null) vargs.contract = info.verify;
    //from docs  { address: addr, constructorArguments: _args }
    let i = await hre.run("verify:verify", vargs);
  }
  private static GetString(src: string): string {
    console.log("=======", src);
    if (src.indexOf("str:") == 0) return src.substring(4);
    if (src.indexOf("addr:") == 0) {
      let name = src.substring(5);
      //console.log("get addr:" + name);
      return ContractInfo.getContractAddress(name);
    }
    return src;
  }
  static async ProxyUpdate(
    nameProxy: string,
    target: string
  ): Promise<ContractReceipt> {
    return await ContractTool.CallState(
      ContractInfo.getContract(nameProxy),
      "upgradeTo",
      ["addr:" + target]
    );
  }
  static async GetProxyContract(
    nameProxy: string,
    nameAbi: string
  ): Promise<Contract> {
    let cproxy = ContractInfo.getContract(nameProxy);
    let abi = await ContractInfo.getContractAbi(nameAbi);
    //console.log("abi="+abi);
    let c = new Contract(cproxy.address, abi);
    return c.connect(cproxy.signer);
  }
  static async CallState(
    c: Contract,
    func: string,
    args: any[]
  ): Promise<ContractReceipt> {
    for (var i = 0; i < args.length; i++) {
      if (typeof args[i] == "string") {
        let s: string = args[i];
        if (s.indexOf("addr:") == 0) {
          let name = s.substring(5);
          console.log("try get addr:" + name);
          let addr = ContractInfo.getContractAddress(s.substring(5));

          args[i] = addr;
        }
      }
    }
    let funcabi: ethers.utils.FunctionFragment = c.interface.getFunction(func);

    if (funcabi.stateMutability.includes("view") == true)
      throw "not a state function:" + func;

    let tran = await c.functions[func](...args);
    return tran.wait();
  }
  static async CallView(c: Contract, func: string, args: any[]): Promise<any> {
    for (var i = 0; i < args.length; i++) {
      if (typeof args[i] == "string") {
        let s: string = args[i];
        if (s.indexOf("addr:") == 0) {
          let name = s.substring(5);
          console.log("try get addr:" + name);
          let addr = ContractInfo.getContractAddress(s.substring(5));
          args[i] = addr;
        }
      }
    }
    let funcabi: ethers.utils.FunctionFragment = c.interface.getFunction(func);
    if (funcabi.stateMutability.includes("view") == false)
      throw "not a view function:" + func;
    //let r = c.functions[func](...args); old code
    let r = c[func](...args);

    return r;
  }
  static async GetWalletAddr(
    hre: HardhatRuntimeEnvironment,
    name: string
  ): Promise<string> {
    let accounds = await hre.getNamedAccounts();
    return accounds[name];
  }
}

interface VerificationSubtaskArgs {
  address: string;
  constructorArguments: any[];
  // Fully qualified name of the contract
  contract?: string;
  libraries?: Libraries;
}

class ContractDeployInfo {
  name: string = "";
  deployer: string = "";
  args: string[] = [];
  libraries?: { [id: string]: string };
  verify?: string;
}
class GroupDeployInfo {
  group: string = "";
  contracts: ContractDeployInfo[] = [];
}
