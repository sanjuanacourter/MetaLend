const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CollateralManager", function () {
  let collateralManager;
  let nftOracle;
  let mockNFT;
  let owner;
  let user1;
  let user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy mock NFT contract
    const MockNFT = await ethers.getContractFactory("MockERC721");
    mockNFT = await MockNFT.deploy("Mock NFT", "MNFT");
    await mockNFT.deployed();

    // Deploy NFTOracle
    const NFTOracle = await ethers.getContractFactory("NFTOracle");
    const mockEthPriceFeed = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";
    nftOracle = await NFTOracle.deploy(mockEthPriceFeed);
    await nftOracle.deployed();

    // Deploy CollateralManager
    const CollateralManager = await ethers.getContractFactory("CollateralManager");
    collateralManager = await CollateralManager.deploy(nftOracle.address);
    await collateralManager.deployed();

    // Set up oracle with floor price
    await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("10"));
  });

  describe("Deployment", function () {
    it("Should set the correct oracle address", async function () {
      expect(await collateralManager.oracle()).to.equal(nftOracle.address);
    });

    it("Should set the correct liquidation threshold", async function () {
      expect(await collateralManager.LIQUIDATION_THRESHOLD()).to.equal(8000);
    });

    it("Should set the correct liquidation bonus", async function () {
      expect(await collateralManager.LIQUIDATION_BONUS()).to.equal(500);
    });
  });

  describe("Collateral Operations", function () {
    beforeEach(async function () {
      // Mint NFT to user1
      await mockNFT.connect(user1).mint(user1.address, 1);
      await mockNFT.connect(user1).approve(collateralManager.address, 1);
    });

    it("Should allow depositing collateral", async function () {
      const loanAmount = ethers.utils.parseEther("5");
      
      await expect(
        collateralManager.connect(user1).depositCollateral(mockNFT.address, 1, loanAmount)
      ).to.emit(collateralManager, "CollateralDeposited")
        .withArgs(user1.address, mockNFT.address, 1, await collateralManager.calculateCollateralValue(mockNFT.address, 1));

      // Check NFT ownership
      expect(await mockNFT.ownerOf(1)).to.equal(collateralManager.address);
    });

    it("Should reject deposit with invalid loan amount", async function () {
      await expect(
        collateralManager.connect(user1).depositCollateral(mockNFT.address, 1, 0)
      ).to.be.revertedWith("Invalid loan amount");
    });

    it("Should reject deposit exceeding liquidation threshold", async function () {
      const excessiveLoanAmount = ethers.utils.parseEther("15"); // Exceeds 80% of 10 ETH
      
      await expect(
        collateralManager.connect(user1).depositCollateral(mockNFT.address, 1, excessiveLoanAmount)
      ).to.be.revertedWith("Loan amount exceeds threshold");
    });

    it("Should prevent depositing same NFT twice", async function () {
      const loanAmount = ethers.utils.parseEther("5");
      
      await collateralManager.connect(user1).depositCollateral(mockNFT.address, 1, loanAmount);
      
      // Mint another NFT to user1
      await mockNFT.connect(user1).mint(user1.address, 2);
      await mockNFT.connect(user1).approve(collateralManager.address, 2);
      
      await expect(
        collateralManager.connect(user1).depositCollateral(mockNFT.address, 1, loanAmount)
      ).to.be.revertedWith("NFT already used as collateral");
    });
  });

  describe("Collateral Management", function () {
    let collateralId;

    beforeEach(async function () {
      // Mint NFT and deposit as collateral
      await mockNFT.connect(user1).mint(user1.address, 1);
      await mockNFT.connect(user1).approve(collateralManager.address, 1);
      
      const loanAmount = ethers.utils.parseEther("5");
      const tx = await collateralManager.connect(user1).depositCollateral(mockNFT.address, 1, loanAmount);
      const receipt = await tx.wait();
      collateralId = receipt.events[0].args.collateralId;
    });

    it("Should return correct collateral info", async function () {
      const collateralInfo = await collateralManager.getCollateralInfo(collateralId);
      
      expect(collateralInfo.nftContract).to.equal(mockNFT.address);
      expect(collateralInfo.tokenId).to.equal(1);
      expect(collateralInfo.isActive).to.be.true;
      expect(collateralInfo.liquidationThreshold).to.equal(8000);
    });

    it("Should check collateral health correctly", async function () {
      const isHealthy = await collateralManager.isCollateralHealthy(collateralId);
      expect(isHealthy).to.be.true;
    });

    it("Should track user collaterals", async function () {
      const userCollaterals = await collateralManager.getUserCollaterals(user1.address);
      expect(userCollaterals.length).to.equal(1);
      expect(userCollaterals[0]).to.equal(collateralId);
    });
  });

  describe("Access Control", function () {
    it("Should only allow owner to set liquidation engine", async function () {
      await expect(
        collateralManager.connect(user1).setLiquidationEngine(user2.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should only allow owner to set oracle", async function () {
      await expect(
        collateralManager.connect(user1).setOracle(user2.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});
