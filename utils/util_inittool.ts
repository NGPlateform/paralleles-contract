import { Contract, ContractReceipt } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ContractInfo } from "./util_contractinfo";
import { ContractTool } from "./util_contracttool";

import { RegAll } from "./init/Init_Reg";
import { logtools } from "./util_log";
export class InitTool
{
    static RegInitFuncs(hre: HardhatRuntimeEnvironment)
    {
        //init all names;
        InitTool.mapInitFunc = {};
        try
        {
            let names = ContractTool.GetGroupNames(hre);
            for (var d in names)
            {
                console.log("group=" + names[d]);
                let group = ContractTool.GetGroup(hre,names[d]);
                if (group != null)
                {
                    for (var i = 0; i < group?.contracts.length; i++)
                    {
                        let name = group.contracts[i].name;
                        //console.log("nsmr=" + name);
                        InitTool.mapInitFunc[name] = new InitFunc();
                    }
                }
            }
        }
        catch (e: any)
        {
            console.log("error:" + e);
        }

        RegAll();


        console.log("reg end.");
    }
    static async CheckFunc_All(hre: HardhatRuntimeEnvironment)
    {
        let names = ContractTool.GetGroupNames(hre);
        for (var d in names)
        {
            await InitTool.CheckFunc_Group(hre, names[d]);
        }
    }
    static async CheckFunc_Group(hre: HardhatRuntimeEnvironment, name: string)
    {
        logtools.logcyan("==InitFunc_Group:" + name)
        let group = ContractTool.GetGroup(hre,name);
        if (group != null)
        {
            for (var i = 0; i < group?.contracts.length; i++)
            {
                let name = group.contracts[i].name;
                await InitTool.CheckFunc_One(hre, name);
            }
        }
        logtools.logcyan("==InitFunc_Group:" + name + " End");
    }
    //init 两次，为了方便测试是否有重复问题

    static async CheckFunc_One(hre: HardhatRuntimeEnvironment, name: string)
    {
        if (InitTool.mapInitFunc[name] == undefined)
        {
            logtools.logred("..not have contract init func:" + name);
            return false;
        }
        let func = InitTool.mapInitFunc[name];
        if (func.checkcall == null)
        {
            logtools.logyellow("..no check call:" + name);
            return false;
        }
        else
        {
            let result = false;
            logtools.logcyan("  --check:" + name + "{")
            try
            {
                result = await func.checkcall(hre);
            }
            catch (e: any)
            {
                console.log("..error:" + e);
                result = false;
            }
            if (result)
                logtools.logcyan("  }end check:" + name + " result=" + result);
            else
                logtools.logred("  }end check:" + name + " result=" + result);

        }
    }
    static async InitFunc_All(hre: HardhatRuntimeEnvironment)
    {
        let names = ContractTool.GetGroupNames(hre);
        for (var d in names)
        {
            await InitTool.InitFunc_Group(hre, names[d]);
        }
    }
    static async InitFunc_Group(hre: HardhatRuntimeEnvironment, name: string)
    {
        logtools.logcyan("==InitFunc_Group:" + name + "{")
        let group = ContractTool.GetGroup(hre,name);
        if (group != null)
        {
            for (var i = 0; i < group?.contracts.length; i++)
            {
                let name = group.contracts[i].name;
                await InitTool.InitFunc_One(hre, name);
            }
        }
        logtools.logcyan("}InitFunc_Group:" + name + " End");
    }
    //init 两次，为了方便测试是否有重复问题
    static inittwice: boolean = false;
    static async InitFunc_One(hre: HardhatRuntimeEnvironment, name: string)
    {
        if (InitTool.mapInitFunc[name] == undefined || InitTool.mapInitFunc[name].hadreg == false)
        {
            logtools.logred("..not reg init call:" + name);
            return false;
        }
        let func = InitTool.mapInitFunc[name];
        if (func.initcall == null)
        {
            logtools.logyellow("..no init call:" + name);
            return false;
        }
        else
        {
            let result = false;

            logtools.logcyan("  --init:" + name + "{")
            // try {

            result = await func.initcall(hre);
            // }
            // catch (e: any) {
            //     console.log("error:" + e);
            //     result = false;
            // }
            if (InitTool.inittwice)
            {
                // try {
                result = await func.initcall(hre);
                // }
                // catch (e: any) {
                //     console.log("error:" + e);
                //     result = false;
                // }
            }

            if (result)
                logtools.logcyan("  }end init:" + name + " result=" + result);
            else
                logtools.logred("  }end init:" + name + " result=" + result);
        }
    }
    private static mapInitFunc: { [id: string]: InitFunc } = {}
    public static Reg(name: string
        , init?: (hre: HardhatRuntimeEnvironment) => Promise<boolean>
        , check?: (hre: HardhatRuntimeEnvironment) => Promise<boolean>)
    {

        if (InitTool.mapInitFunc[name] == undefined)
            throw "do not have this contract.";

        InitTool.mapInitFunc[name].initcall = init;
        InitTool.mapInitFunc[name].checkcall = check;
        InitTool.mapInitFunc[name].hadreg = true;
    }

}

class InitFunc
{
    initcall?: (hre: HardhatRuntimeEnvironment) => Promise<boolean>;
    checkcall?: (hre: HardhatRuntimeEnvironment) => Promise<boolean>;
    hadreg: boolean = false;
}