const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LoanPool", function () {
  let loanPool;
  let collateralManager;
  let mockAsset;
  let nftOracle;
  let mockNFT;
  let owner;
  let user1;
  let user2;
  let liquidityProvider;

  beforeEach(async function () {
    [owner, user1, user2, liquidityProvider] = await ethers.getSigners();

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

    // Set up oracle
    await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("10"));

    // Provide initial liquidity
    await mockAsset.connect(liquidityProvider).approve(loanPool.address, ethers.utils.parseUnits("100000", 6));
    await loanPool.connect(liquidityProvider).provideLiquidity(ethers.utils.parseUnits("100000", 6));
  });

  describe("Deployment", function () {
    it("Should set the correct asset address", async function () {
      expect(await loanPool.asset()).to.equal(mockAsset.address);
    });

    it("Should set the correct collateral manager", async function () {
      expect(await loanPool.collateralManager()).to.equal(collateralManager.address);
    });

    it("Should initialize with zero values", async function () {
      expect(await loanPool.totalLiquidity()).to.equal(ethers.utils.parseUnits("100000", 6));
      expect(await loanPool.totalBorrowed()).to.equal(0);
      expect(await loanPool.totalShares()).to.equal(ethers.utils.parseUnits("100000", 6));
    });
  });

  describe("Liquidity Operations", function () {
    it("Should allow providing liquidity", async function () {
      const amount = ethers.utils.parseUnits("10000", 6);
      await mockAsset.connect(user1).approve(loanPool.address, amount);
      
      await expect(loanPool.connect(user1).provideLiquidity(amount))
        .to.emit(loanPool, "LiquidityProvided")
        .withArgs(user1.address, amount, amount);

      expect(await loanPool.totalLiquidity()).to.equal(ethers.utils.parseUnits("110000", 6));
      expect(await loanPool.liquidityShares(user1.address)).to.equal(amount);
    });

    it("Should allow withdrawing liquidity", async function () {
      const shares = ethers.utils.parseUnits("10000", 6);
      
      await expect(loanPool.connect(liquidityProvider).withdrawLiquidity(shares))
        .to.emit(loanPool, "LiquidityWithdrawn")
        .withArgs(liquidityProvider.address, shares, shares);

      expect(await loanPool.totalLiquidity()).to.equal(ethers.utils.parseUnits("90000", 6));
      expect(await loanPool.liquidityShares(liquidityProvider.address)).to.equal(ethers.utils.parseUnits("90000", 6));
    });

    it("Should reject withdrawal exceeding available shares", async function () {
      const excessiveShares = ethers.utils.parseUnits("200000", 6);
      
      await expect(
        loanPool.connect(liquidityProvider).withdrawLiquidity(excessiveShares)
      ).to.be.revertedWith("Insufficient shares");
    });
  });

  describe("Loan Operations", function () {
    let collateralId;

    beforeEach(async function () {
      // Set up collateral
      await mockNFT.connect(user1).mint(user1.address, 1);
      await mockNFT.connect(user1).approve(collateralManager.address, 1);
      
      const loanAmount = ethers.utils.parseEther("5");
      const tx = await collateralManager.connect(user1).depositCollateral(mockNFT.address, 1, loanAmount);
      const receipt = await tx.wait();
      collateralId = receipt.events[0].args.collateralId;
    });

    it("Should allow creating a loan", async function () {
      const loanAmount = ethers.utils.parseUnits("5000", 6);
      const duration = 30 * 24 * 60 * 60; // 30 days
      
      await expect(loanPool.connect(user1).createLoan(collateralId, loanAmount, duration))
        .to.emit(loanPool, "LoanCreated")
        .withArgs(1, user1.address, collateralId, loanAmount, await loanPool.calculateInterestRate());

      const loanInfo = await loanPool.getLoanInfo(1);
      expect(loanInfo.borrower).to.equal(user1.address);
      expect(loanInfo.principalAmount).to.equal(loanAmount);
      expect(loanInfo.isActive).to.be.true;
    });

    it("Should reject loan creation with insufficient liquidity", async function () {
      const excessiveAmount = ethers.utils.parseUnits("200000", 6);
      const duration = 30 * 24 * 60 * 60;
      
      await expect(
        loanPool.connect(user1).createLoan(collateralId, excessiveAmount, duration)
      ).to.be.revertedWith("Insufficient liquidity");
    });

    it("Should reject loan creation with inactive collateral", async function () {
      // Deactivate collateral
      await collateralManager.connect(owner).setLiquidationEngine(owner.address);
      
      const loanAmount = ethers.utils.parseUnits("5000", 6);
      const duration = 30 * 24 * 60 * 60;
      
      await expect(
        loanPool.connect(user1).createLoan(collateralId, loanAmount, duration)
      ).to.be.revertedWith("Collateral not active");
    });

    it("Should allow loan repayment", async function () {
      const loanAmount = ethers.utils.parseUnits("5000", 6);
      const duration = 30 * 24 * 60 * 60;
      
      await loanPool.connect(user1).createLoan(collateralId, loanAmount, duration);
      
      const repaymentAmount = ethers.utils.parseUnits("1000", 6);
      await mockAsset.connect(user1).approve(loanPool.address, repaymentAmount);
      
      await expect(loanPool.connect(user1).repayLoan(1, repaymentAmount))
        .to.emit(loanPool, "LoanRepaid")
        .withArgs(1, user1.address, repaymentAmount);

      const loanInfo = await loanPool.getLoanInfo(1);
      expect(loanInfo.totalRepaid).to.equal(repaymentAmount);
    });

    it("Should reject repayment from non-borrower", async function () {
      const loanAmount = ethers.utils.parseUnits("5000", 6);
      const duration = 30 * 24 * 60 * 60;
      
      await loanPool.connect(user1).createLoan(collateralId, loanAmount, duration);
      
      const repaymentAmount = ethers.utils.parseUnits("1000", 6);
      await mockAsset.connect(user2).approve(loanPool.address, repaymentAmount);
      
      await expect(
        loanPool.connect(user2).repayLoan(1, repaymentAmount)
      ).to.be.revertedWith("Not loan borrower");
    });
  });

  describe("Interest Calculation", function () {
    it("Should calculate interest rate based on utilization", async function () {
      const initialRate = await loanPool.calculateInterestRate();
      expect(initialRate).to.be.gt(0);

      // Create a loan to increase utilization
      await mockNFT.connect(user1).mint(user1.address, 1);
      await mockNFT.connect(user1).approve(collateralManager.address, 1);
      
      const loanAmount = ethers.utils.parseEther("5");
      const tx = await collateralManager.connect(user1).depositCollateral(mockNFT.address, 1, loanAmount);
      const receipt = await tx.wait();
      const collateralId = receipt.events[0].args.collateralId;
      
      await loanPool.connect(user1).createLoan(collateralId, ethers.utils.parseUnits("10000", 6), 30 * 24 * 60 * 60);
      
      const newRate = await loanPool.calculateInterestRate();
      expect(newRate).to.be.gt(initialRate);
    });

    it("Should calculate loan interest correctly", async function () {
      const loanAmount = ethers.utils.parseUnits("5000", 6);
      const duration = 30 * 24 * 60 * 60;
      
      await mockNFT.connect(user1).mint(user1.address, 1);
      await mockNFT.connect(user1).approve(collateralManager.address, 1);
      
      const collateralAmount = ethers.utils.parseEther("5");
      const tx = await collateralManager.connect(user1).depositCollateral(mockNFT.address, 1, collateralAmount);
      const receipt = await tx.wait();
      const collateralId = receipt.events[0].args.collateralId;
      
      await loanPool.connect(user1).createLoan(collateralId, loanAmount, duration);
      
      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]); // 7 days
      await ethers.provider.send("evm_mine");
      
      const interest = await loanPool.calculateInterest(1);
      expect(interest).to.be.gt(0);
    });
  });

  describe("Pool Information", function () {
    it("Should return correct pool info", async function () {
      const poolInfo = await loanPool.getPoolInfo();
      
      expect(poolInfo.asset).to.equal(mockAsset.address);
      expect(poolInfo.totalLiquidity).to.equal(ethers.utils.parseUnits("100000", 6));
      expect(poolInfo.totalBorrowed).to.equal(0);
      expect(poolInfo.utilizationRate).to.equal(0);
    });

    it("Should track user loans correctly", async function () {
      await mockNFT.connect(user1).mint(user1.address, 1);
      await mockNFT.connect(user1).approve(collateralManager.address, 1);
      
      const loanAmount = ethers.utils.parseEther("5");
      const tx = await collateralManager.connect(user1).depositCollateral(mockNFT.address, 1, loanAmount);
      const receipt = await tx.wait();
      const collateralId = receipt.events[0].args.collateralId;
      
      await loanPool.connect(user1).createLoan(collateralId, ethers.utils.parseUnits("5000", 6), 30 * 24 * 60 * 60);
      
      const userLoans = await loanPool.getUserLoans(user1.address);
      expect(userLoans.length).to.equal(1);
      expect(userLoans[0]).to.equal(1);
    });
  });
});
