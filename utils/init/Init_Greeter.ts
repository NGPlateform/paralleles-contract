import { Contract, ContractReceipt } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { ContractInfo } from "../util_contractinfo";
import { ContractTool } from "../util_contracttool";
import { logtools } from "../util_log";


export async function Init_Greeter(hre: HardhatRuntimeEnvironment): Promise<boolean> {

    let c = ContractInfo.getContract("Greeter");
    await ContractTool.CallState(c, "setGreeting", ["hello"]);
    console.log("donothing");

    return true;
}
export async function Check_Greeter(hre: HardhatRuntimeEnvironment): Promise<boolean> {
    let resultvar = true;

    let c = ContractInfo.getContract("Greeter");
    let r = await ContractTool.CallView(c, "greet", []);
    console.log("greet=" + r);


    return resultvar;
}