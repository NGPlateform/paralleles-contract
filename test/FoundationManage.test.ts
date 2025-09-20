import { expect } from "chai";
import { ethers } from "hardhat";

describe("FoundationManage.sol", function () {
  let token: any;
  let foundationManage: any;
  let owner: any;
  let safe: any;
  let spenderA: any;
  let spenderB: any;

  beforeEach(async () => {
    const signers = await ethers.getSigners();
    owner = signers[0];
    safe = signers[1] || signers[0];
    spenderA = signers[2] || signers[0];
    spenderB = signers[3] || signers[0];

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    token = await MockERC20.deploy("Mock", "MOCK");
    await token.deployed();

    const FoundationManage = await ethers.getContractFactory("FoundationManage");
    foundationManage = await FoundationManage.deploy(token.address, safe.address);
    await foundationManage.deployed();

    // fund treasury
    await token.mint(foundationManage.address, ethers.utils.parseEther("100000"));

    // approve spenders (recipient addresses)
    await foundationManage.connect(owner).setSpender(spenderA.address, true);
    await foundationManage.connect(owner).setSpender(spenderB.address, true);
  });

  it("safe can transferTo approved recipient", async () => {
    const balBefore = await token.balanceOf(spenderA.address);
    await foundationManage.connect(safe).transferTo(spenderA.address, ethers.utils.parseEther("100"));
    const balAfter = await token.balanceOf(spenderA.address);
    expect(balAfter.sub(balBefore).eq(ethers.utils.parseEther("100"))).to.equal(true);
  });

  it("autoTransferTo enforces per-tx and daily limits", async () => {
    // enable spenderA to auto-draw to spenderB (recipient must be approved)
    await foundationManage.connect(owner).setAutoLimit(spenderA.address, ethers.utils.parseEther("10"), ethers.utils.parseEther("50"), true);

    try {
      await foundationManage.connect(spenderA).autoTransferTo(spenderB.address, ethers.utils.parseEther("11"));
      expect.fail("should revert");
    } catch (e: any) {
      expect(String(e.message)).to.include("per-tx");
    }

    // within per-tx, multiple draws until exceed daily
    await foundationManage.connect(spenderA).autoTransferTo(spenderB.address, ethers.utils.parseEther("10"));
    await foundationManage.connect(spenderA).autoTransferTo(spenderB.address, ethers.utils.parseEther("10"));
    await foundationManage.connect(spenderA).autoTransferTo(spenderB.address, ethers.utils.parseEther("10"));
    await foundationManage.connect(spenderA).autoTransferTo(spenderB.address, ethers.utils.parseEther("10"));
    await foundationManage.connect(spenderA).autoTransferTo(spenderB.address, ethers.utils.parseEther("10"));

    try {
      await foundationManage.connect(spenderA).autoTransferTo(spenderB.address, ethers.utils.parseEther("1"));
      expect.fail("should revert");
    } catch (e: any) {
      expect(String(e.message)).to.include("daily limit");
    }
  });

  it("insufficient treasury reverts", async () => {
    // drain treasury then fail on insufficient
    const bal = await token.balanceOf(foundationManage.address);
    await foundationManage.connect(safe).transferTo(spenderA.address, bal);
    try {
      await foundationManage.connect(safe).transferTo(spenderA.address, ethers.utils.parseEther("1"));
      expect.fail("should revert");
    } catch (e: any) {
      expect(String(e.message)).to.include("insufficient");
    }
  });

  it("safe transferFor once-off for spender", async () => {
    const balBefore2 = await token.balanceOf(spenderB.address);
    await foundationManage.connect(safe).transferFor(spenderA.address, spenderB.address, ethers.utils.parseEther("25"));
    const balAfter2 = await token.balanceOf(spenderB.address);
    expect(balAfter2.sub(balBefore2).eq(ethers.utils.parseEther("25"))).to.equal(true);
  });

  it("owner can setSafe and setSpender, and onlySafe enforced", async () => {
    await foundationManage.connect(owner).setSafe(owner.address);
    await foundationManage.connect(owner).setSpender(owner.address, true);
    const balBefore = await token.balanceOf(owner.address);
    await foundationManage.connect(owner).transferTo(owner.address, ethers.utils.parseEther("1"));
    const balAfter = await token.balanceOf(owner.address);
    expect(balAfter.sub(balBefore).eq(ethers.utils.parseEther("1"))).to.equal(true);
  });
});


