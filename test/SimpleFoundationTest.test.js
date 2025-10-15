const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Foundation地址修改简化测试", function () {
    let meshes;
    let owner, safe, foundation1, foundation2;

    beforeEach(async function () {
        const signers = await ethers.getSigners();
        owner = signers[0];
        safe = signers[1];
        foundation1 = signers[2];
        foundation2 = signers[3];
        
        const Meshes = await ethers.getContractFactory("Meshes");
        meshes = await Meshes.deploy(safe.address);
        await meshes.deployed();
    });

    it("应该能够首次设置Foundation地址", async function () {
        const initialFoundation = await meshes.FoundationAddr();
        expect(initialFoundation).to.equal(ethers.constants.AddressZero);
        
        await meshes.setFoundationAddress(foundation1.address);
        const foundationAfter = await meshes.FoundationAddr();
        expect(foundationAfter).to.equal(foundation1.address);
    });

    it("在Owner治理模式下应该能够多次修改Foundation地址", async function () {
        // 首次设置
        await meshes.setFoundationAddress(foundation1.address);
        expect(await meshes.FoundationAddr()).to.equal(foundation1.address);
        
        // 第二次修改 - 使用不同的地址
        const foundation2Address = "0x1234567890123456789012345678901234567890";
        await meshes.setFoundationAddress(foundation2Address);
        expect(await meshes.FoundationAddr()).to.equal(foundation2Address);
    });

    it("不能设置为相同的Foundation地址", async function () {
        await meshes.setFoundationAddress(foundation1.address);
        
        await expect(
            meshes.setFoundationAddress(foundation1.address)
        ).to.be.revertedWith("Same foundation address");
    });

    it("不能设置为零地址", async function () {
        await expect(
            meshes.setFoundationAddress(ethers.constants.AddressZero)
        ).to.be.revertedWith("Invalid foundation address");
    });
});
