import { expect } from "chai";
import { ethers } from "hardhat";

const SECONDS_IN_DAY = 86400;

describe("Stake.sol", function () {
  let token: any;
  let stake: any;
  let foundation: any;
  let governanceSafe: any;
  let user1: any;

  async function increaseTime(seconds: number) {
    await ethers.provider.send("evm_increaseTime", [seconds]);
    await ethers.provider.send("evm_mine", []);
  }

  beforeEach(async () => {
    const signers = await ethers.getSigners();
    governanceSafe = signers[0];
    foundation = signers[1];
    user1 = signers[2];

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    token = await MockERC20.deploy("Mock", "MOCK");
    await token.deployed();

    const Stake = await ethers.getContractFactory("Stake");
    stake = await Stake.deploy(
      token.address,
      foundation.address,
      governanceSafe.address,
      1000 // 10% APY
    );
    await stake.deployed();

    // fund user and contract
    await token.mint(user1.address, ethers.utils.parseEther("1000"));
    await token.mint(stake.address, ethers.utils.parseEther("100"));
    await token.connect(user1).approve(stake.address, ethers.utils.parseEther("1000"));
  });

  it("stake then withdraw at maturity pays principal + interest", async () => {
    await stake.connect(user1).stake(ethers.utils.parseEther("100"), 10);

    await increaseTime(10 * SECONDS_IN_DAY);

    const balBefore = await token.balanceOf(user1.address);
    await stake.connect(user1).withdraw();
    const balAfter = await token.balanceOf(user1.address);

    expect(balAfter.gt(balBefore)).to.equal(true);
  });

  it("zero interest when no time elapsed and bounds on params", async () => {
    // zero elapsed interest
    await stake.connect(user1).stake(ethers.utils.parseEther("10"), 1);
    const info = await stake.getStakeInfo(user1.address);
    expect(info.currentInterest.eq ? info.currentInterest.eq(0) : info.currentInterest === 0).to.equal(true);

    // invalid term
    try {
      await stake.connect(user1).stake(ethers.utils.parseEther("1"), 0);
      expect.fail("should revert");
    } catch (e: any) {
      expect(String(e.message)).to.include("at least 1 day");
    }

    try {
      await stake.connect(user1).stake(ethers.utils.parseEther("1"), 366);
      expect.fail("should revert");
    } catch (e: any) {
      expect(String(e.message)).to.include("cannot exceed 1 year");
    }
  });

  it("claim interest without un-staking, then earlyWithdraw with penalty", async () => {
    await stake.connect(user1).stake(ethers.utils.parseEther("200"), 30);
    await increaseTime(5 * SECONDS_IN_DAY);
    const bal1 = await token.balanceOf(user1.address);
    await stake.connect(user1).claimInterest();
    const bal2 = await token.balanceOf(user1.address);
    expect(bal2.gt(bal1)).to.equal(true);

    await increaseTime(5 * SECONDS_IN_DAY);
    const bal3 = await token.balanceOf(user1.address);
    await stake.connect(user1).earlyWithdraw();
    const bal4 = await token.balanceOf(user1.address);
    expect(bal4.gt(bal3)).to.equal(true);
  });

  it("onlySafe updates management params", async () => {
    try {
      await stake.connect(user1).updateAPY(500);
      expect.fail("should revert");
    } catch (e: any) {
      expect(String(e.message)).to.include("Only Safe");
    }
    await stake.connect(governanceSafe).updateAPY(500);
    const stats = await stake.getStakeStats();
    expect(stats.currentAPY.eq ? stats.currentAPY.eq(500) : stats.currentAPY === 500).to.equal(true);

    try {
      await stake.connect(user1).updateFoundation(user1.address);
      expect.fail("should revert");
    } catch (e: any) {
      expect(String(e.message)).to.include("Only Safe");
    }
    await stake.connect(governanceSafe).updateFoundation(user1.address);
  });
});


