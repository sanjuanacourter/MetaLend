const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VirtualAssetManager", function () {
  let virtualAssetManager;
  let nftOracle;
  let mockNFT;
  let mockERC1155;
  let owner;
  let user1;

  beforeEach(async function () {
    [owner, user1] = await ethers.getSigners();

    // Deploy mock contracts
    const MockERC721 = await ethers.getContractFactory("MockERC721");
    mockNFT = await MockERC721.deploy("Mock NFT", "MNFT");
    await mockNFT.deployed();

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    mockERC1155 = await MockERC20.deploy("Mock ERC1155", "M1155", 0, 0);
    await mockERC1155.deployed();

    // Deploy oracle
    const NFTOracle = await ethers.getContractFactory("NFTOracle");
    const mockEthPriceFeed = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";
    nftOracle = await NFTOracle.deploy(mockEthPriceFeed);
    await nftOracle.deployed();

    // Deploy VirtualAssetManager
    const VirtualAssetManager = await ethers.getContractFactory("VirtualAssetManager");
    virtualAssetManager = await VirtualAssetManager.deploy(nftOracle.address);
    await virtualAssetManager.deployed();
  });

  describe("Deployment", function () {
    it("Should set the correct oracle address", async function () {
      expect(await virtualAssetManager.oracle()).to.equal(nftOracle.address);
    });

    it("Should initialize market multipliers correctly", async function () {
      expect(await virtualAssetManager.getMarketMultiplier(0)).to.equal(10000); // NFT
      expect(await virtualAssetManager.getMarketMultiplier(1)).to.equal(12000); // VIRTUAL_REAL_ESTATE
      expect(await virtualAssetManager.getMarketMultiplier(2)).to.equal(8000); // GAMING_ASSET
      expect(await virtualAssetManager.getMarketMultiplier(3)).to.equal(15000); // METAVERSE_LAND
      expect(await virtualAssetManager.getMarketMultiplier(4)).to.equal(5000); // VIRTUAL_CURRENCY
    });

    it("Should initialize supported asset types", async function () {
      for (let i = 0; i < 5; i++) {
        expect(await virtualAssetManager.isAssetTypeSupported(i)).to.be.true;
      }
    });
  });

  describe("Asset Registration", function () {
    beforeEach(async function () {
      // Mint NFT to user1
      await mockNFT.connect(user1).mint(user1.address, 1);
    });

    it("Should allow registering NFT assets", async function () {
      const metadata = "Test NFT metadata";
      
      await expect(virtualAssetManager.connect(user1).registerVirtualAsset(
        mockNFT.address,
        1,
        0, // NFT
        metadata
      )).to.emit(virtualAssetManager, "VirtualAssetRegistered")
        .withArgs(mockNFT.address, 1, 0, 0);

      const virtualAssetInfo = await virtualAssetManager.getVirtualAssetInfo(1);
      expect(virtualAssetInfo.assetContract).to.equal(mockNFT.address);
      expect(virtualAssetInfo.assetId).to.equal(1);
      expect(virtualAssetInfo.assetType).to.equal(0);
      expect(virtualAssetInfo.metadata).to.equal(metadata);
    });

    it("Should reject registration of unsupported asset types", async function () {
      await mockNFT.connect(user1).mint(user1.address, 2);
      
      await expect(
        virtualAssetManager.connect(user1).registerVirtualAsset(
          mockNFT.address,
          2,
          5, // Invalid asset type
          "metadata"
        )
      ).to.be.revertedWith("Asset type not supported");
    });

    it("Should reject registration of non-owned assets", async function () {
      await expect(
        virtualAssetManager.connect(owner).registerVirtualAsset(
          mockNFT.address,
          1, // Owned by user1
          0,
          "metadata"
        )
      ).to.be.revertedWith("Not asset owner");
    });

    it("Should reject duplicate asset registration", async function () {
      await virtualAssetManager.connect(user1).registerVirtualAsset(
        mockNFT.address,
        1,
        0,
        "metadata"
      );

      await expect(
        virtualAssetManager.connect(user1).registerVirtualAsset(
          mockNFT.address,
          1,
          0,
          "metadata"
        )
      ).to.be.revertedWith("Asset already registered");
    });
  });

  describe("Asset Valuation", function () {
    beforeEach(async function () {
      await mockNFT.connect(user1).mint(user1.address, 1);
      await virtualAssetManager.connect(user1).registerVirtualAsset(
        mockNFT.address,
        1,
        0,
        "metadata"
      );
    });

    it("Should calculate asset valuation correctly", async function () {
      const valuation = await virtualAssetManager.getAssetValuation(mockNFT.address, 1);
      
      expect(valuation.baseValue).to.be.gt(0);
      expect(valuation.rarityMultiplier).to.be.gt(0);
      expect(valuation.utilityMultiplier).to.be.gt(0);
      expect(valuation.marketMultiplier).to.equal(10000);
      expect(valuation.finalValue).to.be.gt(0);
      expect(valuation.confidence).to.equal(8000);
    });

    it("Should update asset valuation", async function () {
      await expect(virtualAssetManager.connect(owner).updateAssetValuation(
        mockNFT.address,
        1,
        0
      )).to.emit(virtualAssetManager, "AssetValuationUpdated");

      const virtualAssetInfo = await virtualAssetManager.getVirtualAssetInfo(1);
      expect(virtualAssetInfo.value).to.be.gt(0);
    });

    it("Should reject valuation update from non-oracle", async function () {
      await expect(
        virtualAssetManager.connect(user1).updateAssetValuation(
          mockNFT.address,
          1,
          0
        )
      ).to.be.revertedWith("Only oracle");
    });
  });

  describe("Rarity and Utility Scoring", function () {
    beforeEach(async function () {
      await mockNFT.connect(user1).mint(user1.address, 1);
      await virtualAssetManager.connect(user1).registerVirtualAsset(
        mockNFT.address,
        1,
        0,
        "metadata"
      );
    });

    it("Should calculate rarity score", async function () {
      const rarityScore = await virtualAssetManager.calculateRarityScore(mockNFT.address, 1);
      expect(rarityScore).to.be.gt(0);
      expect(rarityScore).to.be.lte(100);
    });

    it("Should calculate utility score", async function () {
      const utilityScore = await virtualAssetManager.calculateUtilityScore(mockNFT.address, 1);
      expect(utilityScore).to.be.gt(0);
      expect(utilityScore).to.be.lte(100);
    });
  });

  describe("Asset Type Management", function () {
    it("Should allow owner to set asset type support", async function () {
      await expect(virtualAssetManager.setAssetTypeSupport(0, false))
        .to.emit(virtualAssetManager, "AssetTypeSupported")
        .withArgs(0, false);

      expect(await virtualAssetManager.isAssetTypeSupported(0)).to.be.false;
    });

    it("Should reject non-owner asset type changes", async function () {
      await expect(
        virtualAssetManager.connect(user1).setAssetTypeSupport(0, false)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Market Multiplier Management", function () {
    it("Should allow owner to set market multipliers", async function () {
      await virtualAssetManager.setMarketMultiplier(0, 15000);
      expect(await virtualAssetManager.getMarketMultiplier(0)).to.equal(15000);
    });

    it("Should reject invalid market multipliers", async function () {
      await expect(
        virtualAssetManager.setMarketMultiplier(0, 0)
      ).to.be.revertedWith("Invalid multiplier");

      await expect(
        virtualAssetManager.setMarketMultiplier(0, 20001)
      ).to.be.revertedWith("Invalid multiplier");
    });

    it("Should reject non-owner market multiplier changes", async function () {
      await expect(
        virtualAssetManager.connect(user1).setMarketMultiplier(0, 15000)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Batch Operations", function () {
    beforeEach(async function () {
      // Register multiple assets
      for (let i = 1; i <= 3; i++) {
        await mockNFT.connect(user1).mint(user1.address, i);
        await virtualAssetManager.connect(user1).registerVirtualAsset(
          mockNFT.address,
          i,
          0,
          `metadata${i}`
        );
      }
    });

    it("Should allow batch valuation updates", async function () {
      const assetContracts = [mockNFT.address, mockNFT.address, mockNFT.address];
      const assetIds = [1, 2, 3];
      const assetTypes = [0, 0, 0];

      await expect(virtualAssetManager.batchUpdateValuations(
        assetContracts,
        assetIds,
        assetTypes
      )).to.emit(virtualAssetManager, "AssetValuationUpdated");
    });

    it("Should reject batch update with mismatched arrays", async function () {
      const assetContracts = [mockNFT.address, mockNFT.address];
      const assetIds = [1, 2, 3];
      const assetTypes = [0, 0];

      await expect(
        virtualAssetManager.batchUpdateValuations(
          assetContracts,
          assetIds,
          assetTypes
        )
      ).to.be.revertedWith("Array length mismatch");
    });
  });

  describe("Asset Management", function () {
    beforeEach(async function () {
      await mockNFT.connect(user1).mint(user1.address, 1);
      await virtualAssetManager.connect(user1).registerVirtualAsset(
        mockNFT.address,
        1,
        0,
        "metadata"
      );
    });

    it("Should return correct virtual asset count", async function () {
      expect(await virtualAssetManager.getVirtualAssetCount()).to.equal(1);
    });

    it("Should return correct virtual asset ID by contract", async function () {
      const virtualAssetId = await virtualAssetManager.getVirtualAssetByContract(mockNFT.address, 1);
      expect(virtualAssetId).to.equal(1);
    });

    it("Should allow owner to deactivate virtual assets", async function () {
      await virtualAssetManager.deactivateVirtualAsset(1);
      
      const virtualAssetInfo = await virtualAssetManager.getVirtualAssetInfo(1);
      expect(virtualAssetInfo.isActive).to.be.false;
    });

    it("Should reject deactivation of invalid asset ID", async function () {
      await expect(
        virtualAssetManager.deactivateVirtualAsset(0)
      ).to.be.revertedWith("Invalid asset ID");

      await expect(
        virtualAssetManager.deactivateVirtualAsset(2)
      ).to.be.revertedWith("Invalid asset ID");
    });
  });
});
