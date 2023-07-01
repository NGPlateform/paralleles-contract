import { ContractTool } from "../utils/util_contracttool";
export class DeployTool {

    //读取旧的合约信息，可用于check & update & init
    //也可用于调用一些非本项目合约
    //会被Deploy和Verify覆盖
    static async InitFromDeployInfo(filename: string) {
        // TO DO : 从已发布的合约信息文件中，初始化DepolyTool.contractinfos等信息
    }

    //检查合约状态&初始化合约
    
    //检查合约状态
    static async CheckContractStatus_All() {
        throw "nom implentment yet."
    }
    static async CheckContractStatus_Group() {
        throw "nom implentment yet."
    }
    static async CheckContractStatus_One() {
        throw "nom implentment yet."
    }

    //初始化合约
    static async InitContract_All() {
        throw "nom implentment yet."
    }
    static async InitContract_Group(name:string) {
        throw "nom implentment yet."
    }
    static async InitContract_One(name:string) {
        throw "nom implentment yet."
    }
    
    static async UpdateContract(proxy:string,inst:string) {
        // TO DO : 更新指定合约至指定版本
    }


    //部署合约
    //直接走task了
    // static async DeployContract_All(name: string) {
    //     await ContractTool.DeployAll();
    // }
    // static async DeployContract_Group(name: string) {
    //     await ContractTool.DeployGroup(name);
    // }
    // static async DeployContract_One(name: string) {
    //     let info = ContractTool.GetInfo(name);
    //     if (info != null)
    //         await ContractTool.DeployOne(info);
    // }




    //校验合约
    // static async VerifyContract_All() {
    //     //验证合约之前先部署，这玩意儿需要是一套
    //     await ContractTool.DeployAll(hre);

    //     let groups = ContractTool.GetGroupNames();
    //     for (var i in groups) {
    //         DeployTool.VerifyContract_Group(groups[i]);
    //     }
    // }
    // static async VerifyContract_Group(name: string) {
    //     await ContractTool.DeployAll();
        
    //     let group = ContractTool.GetGroup(name);
    //     if (group != null)
    //         for (var k in group.contracts) {
    //             let info = group.contracts[k];
    //             await ContractTool.VerifyOne(info);
    //         }
    // }
    // static async VerifyContract_One(name:string)
    // {
    //     await ContractTool.DeployAll();

    //     let info = ContractTool.GetInfo(name);
    //     if (info != null)
    //         await ContractTool.DeployOne(info);
    // }

}