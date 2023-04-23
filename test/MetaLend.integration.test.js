const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MetaLend Integration Tests", function () {
  let metaLend;
  let collateralManager;
  let loanPool;
  let liquidationEngine;
  let nftOracle;
  let mockAsset;
  let mockNFT;
  let owner;
  let borrower;
  let lender;
  let liquidator;

  beforeEach(async function () {
    [owner, borrower, lender, liquidator] = await ethers.getSigners();

    // Deploy mock contracts
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    mockAsset = await MockERC20.deploy("Mock USDC", "USDC", 6, ethers.utils.parseUnits("1000000", 6));
    await mockAsset.deployed();

    const MockERC721 = await ethers.getContractFactory("MockERC721");
    mockNFT = await MockERC721.deploy("Mock NFT", "MNFT");
    await mockNFT.deployed();

    // Deploy oracle
    const NFTOracle = await ethers.getContractFactory("NFTOracle");
    const mockEthPriceFeed = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";
    nftOracle = await NFTOracle.deploy(mockEthPriceFeed);
    await nftOracle.deployed();

    // Deploy core contracts
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

    // Deploy main contract
    const MetaLend = await ethers.getContractFactory("MetaLend");
    metaLend = await MetaLend.deploy(
      collateralManager.address,
      loanPool.address,
      liquidationEngine.address,
      nftOracle.address
    );
    await metaLend.deployed();

    // Initialize protocol
    await metaLend.initializeProtocol();

    // Set up supported assets and collections
    await metaLend.setSupportedAsset(mockAsset.address, true);
    await metaLend.setSupportedNFTCollection(mockNFT.address, true);
    await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("10"));

    // Provide initial liquidity
    await mockAsset.connect(lender).approve(metaLend.address, ethers.utils.parseUnits("100000", 6));
    await metaLend.connect(lender).provideLiquidity(mockAsset.address, ethers.utils.parseUnits("100000", 6));
  });

  describe("Complete Lending Flow", function () {
    it("Should complete full deposit-collateral-and-borrow flow", async function () {
      // Mint NFT to borrower
      await mockNFT.connect(borrower).mint(borrower.address, 1);
      await mockNFT.connect(borrower).approve(metaLend.address, 1);

      const loanAmount = ethers.utils.parseUnits("5000", 6);
      const duration = 30 * 24 * 60 * 60; // 30 days

      // Execute combined operation
      const tx = await metaLend.connect(borrower).depositCollateralAndBorrow(
        mockNFT.address,
        1,
        mockAsset.address,
        loanAmount,
        duration
      );
      const receipt = await tx.wait();

      // Check events
      const collateralEvent = receipt.events.find(e => e.event === "CollateralDeposited");
      const loanEvent = receipt.events.find(e => e.event === "LoanCreated");

      expect(collateralEvent).to.not.be.undefined;
      expect(loanEvent).to.not.be.undefined;

      // Verify state
      const collateralId = collateralEvent.args.collateralId;
      const loanId = loanEvent.args.loanId;

      const collateralInfo = await metaLend.getCollateralInfo(collateralId);
      const loanInfo = await metaLend.getLoanInfo(loanId);

      expect(collateralInfo.nftContract).to.equal(mockNFT.address);
      expect(collateralInfo.tokenId).to.equal(1);
      expect(loanInfo.borrower).to.equal(borrower.address);
      expect(loanInfo.principalAmount).to.equal(loanAmount);
    });

    it("Should complete full repay-and-withdraw flow", async function () {
      // Set up loan first
      await mockNFT.connect(borrower).mint(borrower.address, 1);
      await mockNFT.connect(borrower).approve(metaLend.address, 1);

      const loanAmount = ethers.utils.parseUnits("5000", 6);
      const duration = 30 * 24 * 60 * 60;

      const tx = await metaLend.connect(borrower).depositCollateralAndBorrow(
        mockNFT.address,
        1,
        mockAsset.address,
        loanAmount,
        duration
      );
      const receipt = await tx.wait();

      const loanId = receipt.events.find(e => e.event === "LoanCreated").args.loanId;

      // Repay full loan amount
      const totalDebt = await loanPool.calculateTotalDebt(loanId);
      await mockAsset.connect(borrower).approve(metaLend.address, totalDebt);

      await expect(metaLend.connect(borrower).repayLoanAndWithdrawCollateral(loanId, totalDebt))
        .to.emit(metaLend, "CollateralWithdrawn");

      // Verify NFT is returned to borrower
      expect(await mockNFT.ownerOf(1)).to.equal(borrower.address);
    });
  });

  describe("Liquidation Flow", function () {
    let collateralId;
    let loanId;

    beforeEach(async function () {
      // Set up loan
      await mockNFT.connect(borrower).mint(borrower.address, 1);
      await mockNFT.connect(borrower).approve(metaLend.address, 1);

      const loanAmount = ethers.utils.parseUnits("5000", 6);
      const duration = 30 * 24 * 60 * 60;

      const tx = await metaLend.connect(borrower).depositCollateralAndBorrow(
        mockNFT.address,
        1,
        mockAsset.address,
        loanAmount,
        duration
      );
      const receipt = await tx.wait();

      collateralId = receipt.events.find(e => e.event === "CollateralDeposited").args.collateralId;
      loanId = receipt.events.find(e => e.event === "LoanCreated").args.loanId;
    });

    it("Should complete full liquidation flow", async function () {
      // Simulate price drop
      await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("3"));

      // Trigger liquidation
      await expect(metaLend.triggerLiquidation(collateralId))
        .to.emit(liquidationEngine, "LiquidationTriggered");

      // Fast forward past delay
      await ethers.provider.send("evm_increaseTime", [3601]);
      await ethers.provider.send("evm_mine");

      // Execute liquidation
      const liquidationInfo = await metaLend.getLiquidationInfo(collateralId);
      const liquidationAmount = liquidationInfo.debtAmount.add(liquidationInfo.liquidationBonus);

      await mockAsset.connect(liquidator).approve(metaLend.address, liquidationAmount);

      await expect(metaLend.connect(liquidator).executeLiquidation(collateralId))
        .to.emit(liquidationEngine, "LiquidationCompleted");

      // Verify NFT is transferred to liquidator
      expect(await mockNFT.ownerOf(1)).to.equal(liquidator.address);
    });

    it("Should reject liquidation for healthy collateral", async function () {
      // Keep price above threshold
      await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("8"));

      await expect(
        metaLend.triggerLiquidation(collateralId)
      ).to.be.revertedWith("Not eligible for liquidation");
    });
  });

  describe("Protocol State Management", function () {
    it("Should track protocol information correctly", async function () {
      const protocolInfo = await metaLend.getProtocolInfo();

      expect(protocolInfo.totalLiquidity).to.equal(ethers.utils.parseUnits("100000", 6));
      expect(protocolInfo.totalLoansOutstanding).to.equal(0);
      expect(protocolInfo.activeCollaterals).to.equal(0);
      expect(protocolInfo.activeLoans).to.equal(0);
    });

    it("Should track user positions correctly", async function () {
      // Set up loan
      await mockNFT.connect(borrower).mint(borrower.address, 1);
      await mockNFT.connect(borrower).approve(metaLend.address, 1);

      const loanAmount = ethers.utils.parseUnits("5000", 6);
      const duration = 30 * 24 * 60 * 60;

      await metaLend.connect(borrower).depositCollateralAndBorrow(
        mockNFT.address,
        1,
        mockAsset.address,
        loanAmount,
        duration
      );

      // Check user positions
      const userCollaterals = await metaLend.getUserCollaterals(borrower.address);
      const userLoans = await metaLend.getUserLoans(borrower.address);

      expect(userCollaterals.length).to.equal(1);
      expect(userLoans.length).to.equal(1);
    });

    it("Should check collateral and loan health correctly", async function () {
      // Set up loan
      await mockNFT.connect(borrower).mint(borrower.address, 1);
      await mockNFT.connect(borrower).approve(metaLend.address, 1);

      const loanAmount = ethers.utils.parseUnits("5000", 6);
      const duration = 30 * 24 * 60 * 60;

      const tx = await metaLend.connect(borrower).depositCollateralAndBorrow(
        mockNFT.address,
        1,
        mockAsset.address,
        loanAmount,
        duration
      );
      const receipt = await tx.wait();

      const collateralId = receipt.events.find(e => e.event === "CollateralDeposited").args.collateralId;
      const loanId = receipt.events.find(e => e.event === "LoanCreated").args.loanId;

      // Check health
      expect(await metaLend.isCollateralHealthy(collateralId)).to.be.true;
      expect(await metaLend.isLoanHealthy(loanId)).to.be.true;

      // Simulate price drop
      await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("3"));

      // Collateral should still be healthy (not liquidated yet)
      expect(await metaLend.isCollateralHealthy(collateralId)).to.be.true;
      expect(await metaLend.isLoanHealthy(loanId)).to.be.true;
    });
  });

  describe("Multi-User Scenarios", function () {
    it("Should handle multiple borrowers and lenders", async function () {
      // Add more liquidity providers
      await mockAsset.connect(owner).approve(metaLend.address, ethers.utils.parseUnits("50000", 6));
      await metaLend.connect(owner).provideLiquidity(mockAsset.address, ethers.utils.parseUnits("50000", 6));

      // Multiple borrowers
      for (let i = 1; i <= 3; i++) {
        await mockNFT.connect(borrower).mint(borrower.address, i);
        await mockNFT.connect(borrower).approve(metaLend.address, i);

        const loanAmount = ethers.utils.parseUnits("3000", 6);
        const duration = 30 * 24 * 60 * 60;

        await metaLend.connect(borrower).depositCollateralAndBorrow(
          mockNFT.address,
          i,
          mockAsset.address,
          loanAmount,
          duration
        );
      }

      // Check protocol state
      const protocolInfo = await metaLend.getProtocolInfo();
      expect(protocolInfo.activeCollaterals).to.equal(3);
      expect(protocolInfo.activeLoans).to.equal(3);
      expect(protocolInfo.totalLoansOutstanding).to.equal(ethers.utils.parseUnits("9000", 6));
    });

    it("Should handle partial repayments", async function () {
      // Set up loan
      await mockNFT.connect(borrower).mint(borrower.address, 1);
      await mockNFT.connect(borrower).approve(metaLend.address, 1);

      const loanAmount = ethers.utils.parseUnits("5000", 6);
      const duration = 30 * 24 * 60 * 60;

      const tx = await metaLend.connect(borrower).depositCollateralAndBorrow(
        mockNFT.address,
        1,
        mockAsset.address,
        loanAmount,
        duration
      );
      const receipt = await tx.wait();

      const loanId = receipt.events.find(e => e.event === "LoanCreated").args.loanId;

      // Partial repayment
      const partialAmount = ethers.utils.parseUnits("2000", 6);
      await mockAsset.connect(borrower).approve(metaLend.address, partialAmount);

      await metaLend.connect(borrower).repayLoanAndWithdrawCollateral(loanId, partialAmount);

      // Loan should still be active
      const loanInfo = await metaLend.getLoanInfo(loanId);
      expect(loanInfo.isActive).to.be.true;
      expect(loanInfo.totalRepaid).to.equal(partialAmount);
    });
  });

  describe("Error Handling", function () {
    it("Should reject operations with unsupported assets", async function () {
      const unsupportedAsset = owner.address; // Use EOA as unsupported asset

      await mockNFT.connect(borrower).mint(borrower.address, 1);
      await mockNFT.connect(borrower).approve(metaLend.address, 1);

      await expect(
        metaLend.connect(borrower).depositCollateralAndBorrow(
          mockNFT.address,
          1,
          unsupportedAsset,
          ethers.utils.parseUnits("5000", 6),
          30 * 24 * 60 * 60
        )
      ).to.be.revertedWith("Asset not supported");
    });

    it("Should reject operations with unsupported NFT collections", async function () {
      const unsupportedNFT = owner.address; // Use EOA as unsupported NFT

      await expect(
        metaLend.connect(borrower).depositCollateralAndBorrow(
          unsupportedNFT,
          1,
          mockAsset.address,
          ethers.utils.parseUnits("5000", 6),
          30 * 24 * 60 * 60
        )
      ).to.be.revertedWith("NFT collection not supported");
    });

    it("Should reject liquidity operations with wrong asset", async function () {
      const wrongAsset = owner.address;

      await expect(
        metaLend.connect(lender).provideLiquidity(wrongAsset, ethers.utils.parseUnits("10000", 6))
      ).to.be.revertedWith("Asset not supported");
    });
  });
});
