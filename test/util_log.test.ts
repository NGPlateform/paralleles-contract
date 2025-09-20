import * as fs from 'fs';
import { logtools } from '../utils/util_log';

jest.mock('fs');

describe('logtools', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // @ts-ignore
    fs.readFileSync.mockImplementation(() => Buffer.from('{}'));
  });

  test('loggreen should call console.log with green color', () => {
    const spy = jest.spyOn(console, 'log').mockImplementation(() => {});
    logtools.loggreen('hello');
    expect(spy).toHaveBeenCalled();
    spy.mockRestore();
  });

  test('UpdateConfigFileName should set configfile', () => {
    const hre: any = { network: { name: 'testnet' } };
    const spy = jest.spyOn(console, 'log').mockImplementation(() => {});
    logtools.UpdateConfigFileName(hre);
    expect(spy).toHaveBeenCalledWith('configfile=testnet_deployresult.json');
    spy.mockRestore();
  });

  test('SetContract should write JSON with contracts field', () => {
    // @ts-ignore
    fs.writeFileSync.mockImplementation(() => {});
    (logtools as any).configfile = 'tmp.json';
    logtools.SetContract('Name', 'deployer', '0xabc' as any, ['abi'], ['func'], '0x');
    expect(fs.writeFileSync).toHaveBeenCalled();
  });

  test('Append should call fs.appendFile', () => {
    // @ts-ignore
    fs.appendFile.mockImplementation((_f, _d, cb) => cb());
    logtools.Append('line');
    expect(fs.appendFile).toHaveBeenCalled();
  });
});


