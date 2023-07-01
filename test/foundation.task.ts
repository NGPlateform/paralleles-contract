import { BigNumber, ContractReceipt, ethers } from "ethers";
import { ContractInfo } from "../utils/util_contractinfo";
import { logtools } from "../utils/util_log";
import { task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import * as fs from "fs";

let owners = [
  "0xac3D7D1CeDa1c6B4f25B25991f7401D441E13340",
  "0xc4d97570A90096e9f8e23c58A1E7F528fDAa45e7",
  "0x843076428Df85c8F7704a2Be73B0E1b1D5799D4d",
];

export module extFoundation {
  export function RegTasks() {
    task("Foundation:initialize", "initialize").setAction(async ({}, _hre) => {
      logtools.logyellow("method == [Foundation:initialize]");
      await ContractInfo.LoadFromFile(_hre);

      let contrat = await ContractInfo.getContract("Foundation");
      logtools.logblue("Foundation = " + contrat.address);

      let ngpAddr = await ContractInfo.getContractProxy("NGP", "NGPProxy");

      logtools.logblue("ngpAddr = " + ngpAddr.address);

      let tran = await contrat.initialize(owners, ngpAddr.address);
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
  }
}
