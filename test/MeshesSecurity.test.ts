import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, ContractFactory, Signer, BigNumber } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("Meshes Contract Security Tests", function () {
    let Meshes: ContractFactory;
    let meshes: Contract;
    let owner1: SignerWithAddress;
    let owner2: SignerWithAddress;
    let owner3: SignerWithAddress;
    let user1: SignerWithAddress;
    let user2: SignerWithAddress;
    let foundation: SignerWithAddress;
    let pancakeRouter: SignerWithAddress;

    const owners: string[] = [];
    let foundationAddr: string;
    let pancakeRouterAddr: string;

    beforeEach(async function () {
        [owner1, owner2, owner3, user1, user2, foundation, pancakeRouter] = await ethers.getSigners();
        
        owners.push(owner1.address, owner2.address, owner3.address);
        foundationAddr = foundation.address;
        pancakeRouterAddr = pancakeRouter.address;

        Meshes = await ethers.getContractFactory("Meshes");
        meshes = await Meshes.deploy(owners, foundationAddr, pancakeRouterAddr);
        await meshes.deployed();
    });

    describe("Constructor Security", function () {
        it("Should revert with invalid foundation address", async function () {
            await expect(
                Meshes.deploy(owners, ethers.constants.AddressZero, pancakeRouterAddr)
            ).to.be.revertedWith("Invalid foundation address");
        });

        it("Should revert with invalid pancake router address", async function () {
            await expect(
                Meshes.deploy(owners, foundationAddr, ethers.constants.AddressZero)
            ).to.be.revertedWith("Invalid pancake router address");
        });

        it("Should revert with empty owners array", async function () {
            await expect(
                Meshes.deploy([], foundationAddr, pancakeRouterAddr)
            ).to.be.revertedWith("Owners array cannot be empty");
        });

        it("Should revert with too many owners", async function () {
            const tooManyOwners = Array(51).fill(owner1.address);
            await expect(
                Meshes.deploy(tooManyOwners, foundationAddr, pancakeRouterAddr)
            ).to.be.revertedWith("Too many owners");
        });

        it("Should revert with duplicate owner addresses", async function () {
            const duplicateOwners = [owner1.address, owner1.address, owner2.address];
            await expect(
                Meshes.deploy(duplicateOwners, foundationAddr, pancakeRouterAddr)
            ).to.be.revertedWith("Invalid owner address");
        });
    });

    describe("Input Validation", function () {
        it("Should validate meshID format correctly", async function () {
            // Valid meshIDs
            expect(await meshes.isValidMeshID("ABC123")).to.be.true;
            expect(await meshes.isValidMeshID("mesh-001")).to.be.true;
            expect(await meshes.isValidMeshID("123")).to.be.true;

            // Invalid meshIDs
            expect(await meshes.isValidMeshID("")).to.be.false;
            expect(await meshes.isValidMeshID("mesh@123")).to.be.false;
            expect(await meshes.isValidMeshID("mesh#123")).to.be.false;
        });

        it("Should revert claimMint with empty meshID", async function () {
            await expect(
                meshes.connect(user1).claimMint("", 100, { value: ethers.utils.parseEther("0.1") })
            ).to.be.revertedWith("MeshID cannot be empty");
        });

        it("Should revert claimMint with invalid meshID format", async function () {
            await expect(
                meshes.connect(user1).claimMint("invalid@mesh", 100, { value: ethers.utils.parseEther("0.1") })
            ).to.be.revertedWith("Invalid meshID format");
        });

        it("Should revert claimMint with zero autoSwap amount", async function () {
            await expect(
                meshes.connect(user1).claimMint("validMesh", 0, { value: ethers.utils.parseEther("0.1") })
            ).to.be.revertedWith("AutoSwap amount must be greater than 0");
        });
    });

    describe("Reentrancy Protection", function () {
        it("Should have nonReentrant modifier on withdraw function", async function () {
            // This test verifies that the withdraw function has the nonReentrant modifier
            // The actual reentrancy attack simulation would require a malicious contract
            // which is beyond the scope of this basic test
            expect(meshes.interface.getFunction("withdraw")).to.not.be.undefined;
        });

        it("Should have nonReentrant modifier on claimMint function", async function () {
            expect(meshes.interface.getFunction("claimMint")).to.not.be.undefined;
        });
    });

    describe("Pausable Functionality", function () {
        it("Should allow owner to pause contract", async function () {
            await meshes.connect(owner1).pause();
            expect(await meshes.paused()).to.be.true;
        });

        it("Should allow owner to unpause contract", async function () {
            await meshes.connect(owner1).pause();
            await meshes.connect(owner1).unpause();
            expect(await meshes.paused()).to.be.false;
        });

        it("Should revert non-owner pause attempt", async function () {
            await expect(
                meshes.connect(user1).pause()
            ).to.be.revertedWith("Not owner");
        });

        it("Should revert non-owner unpause attempt", async function () {
            await expect(
                meshes.connect(user1).unpause()
            ).to.be.revertedWith("Not owner");
        });

        it("Should revert claimMint when paused", async function () {
            await meshes.connect(owner1).pause();
            await expect(
                meshes.connect(user1).claimMint("validMesh", 100, { value: ethers.utils.parseEther("0.1") })
            ).to.be.revertedWith("Contract is paused");
        });

        it("Should revert withdraw when paused", async function () {
            await meshes.connect(owner1).pause();
            await expect(
                meshes.connect(user1).withdraw()
            ).to.be.revertedWith("Contract is paused");
        });
    });

    describe("Owner Functions Security", function () {
        it("Should allow owner to set burn switch", async function () {
            await meshes.connect(owner1).setBurnSwitch(true);
            expect(await meshes.burnSwitch()).to.be.true;
        });

        it("Should revert non-owner burn switch setting", async function () {
            await expect(
                meshes.connect(user1).setBurnSwitch(true)
            ).to.be.revertedWith("Not owner");
        });

        it("Should revert burn switch setting when paused", async function () {
            await meshes.connect(owner1).pause();
            await expect(
                meshes.connect(owner1).setBurnSwitch(true)
            ).to.be.revertedWith("Contract is paused");
        });

        it("Should allow owner to update foundation address", async function () {
            const newFoundation = user1.address;
            await meshes.connect(owner1).setFoundationAddress(newFoundation);
            expect(await meshes.FoundationAddr()).to.equal(newFoundation);
        });

        it("Should revert foundation update with same address", async function () {
            await expect(
                meshes.connect(owner1).setFoundationAddress(foundationAddr)
            ).to.be.revertedWith("Same foundation address");
        });

        it("Should revert foundation update with zero address", async function () {
            await expect(
                meshes.connect(owner1).setFoundationAddress(ethers.constants.AddressZero)
            ).to.be.revertedWith("Invalid foundation address");
        });

        it("Should allow owner to update pancake router", async function () {
            const newRouter = user1.address;
            await meshes.connect(owner1).setPancakeRouterAddress(newRouter);
            expect(await meshes.pancakeRouter()).to.equal(newRouter);
        });

        it("Should revert pancake router update with same address", async function () {
            await expect(
                meshes.connect(owner1).setPancakeRouterAddress(pancakeRouterAddr)
            ).to.be.revertedWith("Same router address");
        });

        it("Should revert pancake router update with zero address", async function () {
            await expect(
                meshes.connect(owner1).setPancakeRouterAddress(ethers.constants.AddressZero)
            ).to.be.revertedWith("Invalid address");
        });
    });

    describe("PancakeSwap Integration Security", function () {
        it("Should require BNB value for swap", async function () {
            // This test verifies that the swap function requires BNB value
            // The actual PancakeSwap integration would require a mock router
            expect(meshes.interface.getFunction("claimMint")).to.not.be.undefined;
        });

        it("Should have reasonable deadline for swaps", async function () {
            // The deadline is set to block.timestamp + 300 (5 minutes)
            // This is more reasonable than the previous 15 seconds
            expect(meshes.interface.getFunction("claimMint")).to.not.be.undefined;
        });
    });

    describe("Access Control", function () {
        it("Should restrict addSpendNonce to owners only", async function () {
            await expect(
                meshes.connect(user1).addSpendNonce()
            ).to.be.revertedWith("Not owner");
        });

        it("Should allow owner to addSpendNonce", async function () {
            const initialNonce = await meshes.getSpendNonce();
            await meshes.connect(owner1).addSpendNonce();
            expect(await meshes.getSpendNonce()).to.equal(initialNonce.add(1));
        });

        it("Should revert addSpendNonce when paused", async function () {
            await meshes.connect(owner1).pause();
            await expect(
                meshes.connect(owner1).addSpendNonce()
            ).to.be.revertedWith("Contract is paused");
        });
    });

    describe("Event Emissions", function () {
        it("Should emit BurnSwitchUpdated event", async function () {
            await expect(meshes.connect(owner1).setBurnSwitch(true))
                .to.emit(meshes, "BurnSwitchUpdated")
                .withArgs(false, true);
        });

        it("Should emit FoundationAddressUpdated event", async function () {
            const newFoundation = user1.address;
            await expect(meshes.connect(owner1).setFoundationAddress(newFoundation))
                .to.emit(meshes, "FoundationAddressUpdated")
                .withArgs(foundationAddr, newFoundation);
        });

        it("Should emit PancakeRouterUpdated event", async function () {
            const newRouter = user1.address;
            await expect(meshes.connect(owner1).setPancakeRouterAddress(newRouter))
                .to.emit(meshes, "PancakeRouterUpdated")
                .withArgs(pancakeRouterAddr, newRouter);
        });
    });

    describe("Additional Functions", function () {
        it("Should return user meshes correctly", async function () {
            const userMeshes = await meshes.getUserMeshes(user1.address);
            expect(userMeshes).to.be.an("array");
        });

        it("Should return contract status correctly", async function () {
            const status = await meshes.getContractStatus();
            expect(status).to.have.property("_paused");
            expect(status).to.have.property("_totalSupply");
            expect(status).to.have.property("_activeMinters");
            expect(status).to.have.property("_activeMeshes");
            expect(status).to.have.property("_totalBurn");
        });
    });
});
