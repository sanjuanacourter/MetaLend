const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LiquidationEngine", function () {
  let liquidationEngine;
  let collateralManager;
  let loanPool;
  let mockAsset;
  let nftOracle;
  let mockNFT;
  let owner;
  let user1;
  let liquidator;

  beforeEach(async function () {
    [owner, user1, liquidator] = await ethers.getSigners();

    // Deploy mock contracts
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    mockAsset = await MockERC20.deploy("Mock USDC", "USDC", 6, ethers.utils.parseUnits("1000000", 6));
    await mockAsset.deployed();

    const MockERC721 = await ethers.getContractFactory("MockERC721");
    mockNFT = await MockERC721.deploy("Mock NFT", "MNFT");
    await mockNFT.deployed();

    const NFTOracle = await ethers.getContractFactory("NFTOracle");
    const mockEthPriceFeed = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";
    nftOracle = await NFTOracle.deploy(mockEthPriceFeed);
    await nftOracle.deployed();

    const CollateralManager = await ethers.getContractFactory("CollateralManager");
    collateralManager = await CollateralManager.deploy(nftOracle.address);
    await collateralManager.deployed();

    const LoanPool = await ethers.getContractFactory("LoanPool");
    loanPool = await LoanPool.deploy(mockAsset.address, collateralManager.address);
    await loanPool.deployed();

    const LiquidationEngine = await ethers.getContractFactory("LiquidationEngine");
    liquidationEngine = await LiquidationEngine.deploy(
      collateralManager.address,
      loanPool.address,
      mockAsset.address
    );
    await liquidationEngine.deployed();

    // Set up cross-contract references
    await collateralManager.setLiquidationEngine(liquidationEngine.address);

    // Set up oracle
    await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("10"));

    // Provide liquidity
    await mockAsset.connect(owner).approve(loanPool.address, ethers.utils.parseUnits("100000", 6));
    await loanPool.connect(owner).provideLiquidity(ethers.utils.parseUnits("100000", 6));
  });

  describe("Deployment", function () {
    it("Should set the correct collateral manager", async function () {
      expect(await liquidationEngine.collateralManager()).to.equal(collateralManager.address);
    });

    it("Should set the correct loan pool", async function () {
      expect(await liquidationEngine.loanPool()).to.equal(loanPool.address);
    });

    it("Should set the correct asset", async function () {
      expect(await liquidationEngine.asset()).to.equal(mockAsset.address);
    });

    it("Should initialize with correct parameters", async function () {
      expect(await liquidationEngine.liquidationThreshold()).to.equal(8000);
      expect(await liquidationEngine.liquidationBonus()).to.equal(500);
      expect(await liquidationEngine.liquidationDelay()).to.equal(3600); // 1 hour
    });
  });

  describe("Liquidation Parameters", function () {
    it("Should allow owner to update liquidation parameters", async function () {
      await expect(
        liquidationEngine.updateLiquidationParameters(7500, 600, 7200)
      ).to.emit(liquidationEngine, "LiquidationParametersUpdated")
        .withArgs(7500, 600, 7200);

      expect(await liquidationEngine.liquidationThreshold()).to.equal(7500);
      expect(await liquidationEngine.liquidationBonus()).to.equal(600);
      expect(await liquidationEngine.liquidationDelay()).to.equal(7200);
    });

    it("Should reject invalid liquidation threshold", async function () {
      await expect(
        liquidationEngine.updateLiquidationParameters(0, 500, 3600)
      ).to.be.revertedWith("Invalid threshold");

      await expect(
        liquidationEngine.updateLiquidationParameters(10001, 500, 3600)
      ).to.be.revertedWith("Invalid threshold");
    });

    it("Should reject invalid liquidation bonus", async function () {
      await expect(
        liquidationEngine.updateLiquidationParameters(8000, 0, 3600)
      ).to.be.revertedWith("Invalid bonus");

      await expect(
        liquidationEngine.updateLiquidationParameters(8000, 2001, 3600)
      ).to.be.revertedWith("Invalid bonus");
    });

    it("Should reject excessive liquidation delay", async function () {
      await expect(
        liquidationEngine.updateLiquidationParameters(8000, 500, 25 * 3600)
      ).to.be.revertedWith("Delay too long");
    });

    it("Should reject non-owner parameter updates", async function () {
      await expect(
        liquidationEngine.connect(user1).updateLiquidationParameters(7500, 600, 7200)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Liquidation Process", function () {
    let collateralId;

    beforeEach(async function () {
      // Set up collateral and loan
      await mockNFT.connect(user1).mint(user1.address, 1);
      await mockNFT.connect(user1).approve(collateralManager.address, 1);
      
      const loanAmount = ethers.utils.parseEther("5");
      const tx = await collateralManager.connect(user1).depositCollateral(mockNFT.address, 1, loanAmount);
      const receipt = await tx.wait();
      collateralId = receipt.events[0].args.collateralId;
      
      await loanPool.connect(user1).createLoan(collateralId, ethers.utils.parseUnits("5000", 6), 30 * 24 * 60 * 60);
    });

    it("Should trigger liquidation for eligible collateral", async function () {
      // Simulate price drop by updating oracle with lower price
      await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("3")); // Below threshold
      
      await expect(liquidationEngine.triggerLiquidation(collateralId))
        .to.emit(liquidationEngine, "LiquidationTriggered");

      const liquidationInfo = await liquidationEngine.getLiquidationInfo(collateralId);
      expect(liquidationInfo.collateralId).to.equal(collateralId);
      expect(liquidationInfo.isLiquidated).to.be.false;
    });

    it("Should reject liquidation trigger for healthy collateral", async function () {
      // Keep price above threshold
      await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("8"));
      
      await expect(
        liquidationEngine.triggerLiquidation(collateralId)
      ).to.be.revertedWith("Not eligible for liquidation");
    });

    it("Should execute liquidation after delay", async function () {
      // Trigger liquidation
      await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("3"));
      await liquidationEngine.triggerLiquidation(collateralId);
      
      // Fast forward past delay
      await ethers.provider.send("evm_increaseTime", [3601]); // Just over 1 hour
      await ethers.provider.send("evm_mine");
      
      // Prepare liquidation payment
      const liquidationInfo = await liquidationEngine.getLiquidationInfo(collateralId);
      const liquidationAmount = liquidationInfo.debtAmount.add(liquidationInfo.liquidationBonus);
      
      await mockAsset.connect(liquidator).approve(liquidationEngine.address, liquidationAmount);
      
      await expect(liquidationEngine.connect(liquidator).executeLiquidation(collateralId))
        .to.emit(liquidationEngine, "LiquidationCompleted");

      const updatedLiquidationInfo = await liquidationEngine.getLiquidationInfo(collateralId);
      expect(updatedLiquidationInfo.isLiquidated).to.be.true;
    });

    it("Should reject liquidation execution before delay", async function () {
      // Trigger liquidation
      await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("3"));
      await liquidationEngine.triggerLiquidation(collateralId);
      
      // Try to execute immediately (before delay)
      const liquidationInfo = await liquidationEngine.getLiquidationInfo(collateralId);
      const liquidationAmount = liquidationInfo.debtAmount.add(liquidationInfo.liquidationBonus);
      
      await mockAsset.connect(liquidator).approve(liquidationEngine.address, liquidationAmount);
      
      await expect(
        liquidationEngine.connect(liquidator).executeLiquidation(collateralId)
      ).to.be.revertedWith("Liquidation delay not met");
    });

    it("Should reject liquidation execution of already liquidated collateral", async function () {
      // Trigger and execute liquidation
      await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("3"));
      await liquidationEngine.triggerLiquidation(collateralId);
      
      await ethers.provider.send("evm_increaseTime", [3601]);
      await ethers.provider.send("evm_mine");
      
      const liquidationInfo = await liquidationEngine.getLiquidationInfo(collateralId);
      const liquidationAmount = liquidationInfo.debtAmount.add(liquidationInfo.liquidationBonus);
      
      await mockAsset.connect(liquidator).approve(liquidationEngine.address, liquidationAmount);
      await liquidationEngine.connect(liquidator).executeLiquidation(collateralId);
      
      // Try to execute again
      await expect(
        liquidationEngine.connect(liquidator).executeLiquidation(collateralId)
      ).to.be.revertedWith("Already liquidated");
    });
  });

  describe("Liquidation Calculations", function () {
    it("Should calculate liquidation bonus correctly", async function () {
      const collateralValue = ethers.utils.parseEther("10");
      const bonus = await liquidationEngine.calculateLiquidationBonus(collateralValue);
      const expectedBonus = collateralValue.mul(500).div(10000); // 5%
      expect(bonus).to.equal(expectedBonus);
    });

    it("Should check liquidation eligibility correctly", async function () {
      // Set up collateral
      await mockNFT.connect(user1).mint(user1.address, 1);
      await mockNFT.connect(user1).approve(collateralManager.address, 1);
      
      const loanAmount = ethers.utils.parseEther("5");
      const tx = await collateralManager.connect(user1).depositCollateral(mockNFT.address, 1, loanAmount);
      const receipt = await tx.wait();
      const collateralId = receipt.events[0].args.collateralId;
      
      await loanPool.connect(user1).createLoan(collateralId, ethers.utils.parseUnits("5000", 6), 30 * 24 * 60 * 60);
      
      // Check eligibility with healthy collateral
      await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("8"));
      expect(await liquidationEngine.isLiquidationEligible(collateralId)).to.be.false;
      
      // Check eligibility with unhealthy collateral
      await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("3"));
      expect(await liquidationEngine.isLiquidationEligible(collateralId)).to.be.true;
    });
  });

  describe("Liquidation Status", function () {
    let collateralId;

    beforeEach(async function () {
      await mockNFT.connect(user1).mint(user1.address, 1);
      await mockNFT.connect(user1).approve(collateralManager.address, 1);
      
      const loanAmount = ethers.utils.parseEther("5");
      const tx = await collateralManager.connect(user1).depositCollateral(mockNFT.address, 1, loanAmount);
      const receipt = await tx.wait();
      collateralId = receipt.events[0].args.collateralId;
      
      await loanPool.connect(user1).createLoan(collateralId, ethers.utils.parseUnits("5000", 6), 30 * 24 * 60 * 60);
    });

    it("Should track liquidation delay correctly", async function () {
      await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("3"));
      await liquidationEngine.triggerLiquidation(collateralId);
      
      let delay = await liquidationEngine.getLiquidationDelay(collateralId);
      expect(delay).to.be.gt(0);
      
      // Fast forward past delay
      await ethers.provider.send("evm_increaseTime", [3601]);
      await ethers.provider.send("evm_mine");
      
      delay = await liquidationEngine.getLiquidationDelay(collateralId);
      expect(delay).to.equal(0);
    });

    it("Should track liquidation pending status", async function () {
      expect(await liquidationEngine.isLiquidationPending(collateralId)).to.be.false;
      
      await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("3"));
      await liquidationEngine.triggerLiquidation(collateralId);
      
      expect(await liquidationEngine.isLiquidationPending(collateralId)).to.be.true;
      
      // Execute liquidation
      await ethers.provider.send("evm_increaseTime", [3601]);
      await ethers.provider.send("evm_mine");
      
      const liquidationInfo = await liquidationEngine.getLiquidationInfo(collateralId);
      const liquidationAmount = liquidationInfo.debtAmount.add(liquidationInfo.liquidationBonus);
      
      await mockAsset.connect(liquidator).approve(liquidationEngine.address, liquidationAmount);
      await liquidationEngine.connect(liquidator).executeLiquidation(collateralId);
      
      expect(await liquidationEngine.isLiquidationPending(collateralId)).to.be.false;
    });
  });
});
