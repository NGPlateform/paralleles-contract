
import { InitTool } from "../util_inittool";
//avatar
import { Init_Greeter, Check_Greeter } from "./Init_Greeter";

export function RegAll()
{   //group avatar
    InitTool.Reg("Greeter", Init_Greeter, Check_Greeter);
 
}