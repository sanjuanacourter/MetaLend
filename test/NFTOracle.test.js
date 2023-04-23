const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFTOracle", function () {
  let nftOracle;
  let mockNFT;
  let owner;
  let user1;

  beforeEach(async function () {
    [owner, user1] = await ethers.getSigners();

    // Deploy mock NFT contract
    const MockERC721 = await ethers.getContractFactory("MockERC721");
    mockNFT = await MockERC721.deploy("Mock NFT", "MNFT");
    await mockNFT.deployed();

    // Deploy NFTOracle
    const NFTOracle = await ethers.getContractFactory("NFTOracle");
    const mockEthPriceFeed = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";
    nftOracle = await NFTOracle.deploy(mockEthPriceFeed);
    await nftOracle.deployed();
  });

  describe("Deployment", function () {
    it("Should set the correct ETH price feed", async function () {
      expect(await nftOracle.ethPriceFeed()).to.equal(mockEthPriceFeed);
    });

    it("Should initialize with correct constants", async function () {
      expect(await nftOracle.PRICE_VALIDITY_DURATION()).to.equal(3600); // 1 hour
      expect(await nftOracle.MAX_PRICE_DEVIATION()).to.equal(2000); // 20%
    });
  });

  describe("Collection Management", function () {
    it("Should allow owner to set collection support", async function () {
      await expect(nftOracle.setCollectionSupport(mockNFT.address, true))
        .to.emit(nftOracle, "CollectionSupported")
        .withArgs(mockNFT.address, true);

      expect(await nftOracle.supportedCollections(mockNFT.address)).to.be.true;
    });

    it("Should reject non-owner collection support changes", async function () {
      await expect(
        nftOracle.connect(user1).setCollectionSupport(mockNFT.address, true)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should check collection support correctly", async function () {
      expect(await nftOracle.isCollectionSupported(mockNFT.address)).to.be.false;
      
      await nftOracle.setCollectionSupport(mockNFT.address, true);
      expect(await nftOracle.isCollectionSupported(mockNFT.address)).to.be.true;
    });
  });

  describe("Floor Price Management", function () {
    beforeEach(async function () {
      await nftOracle.setCollectionSupport(mockNFT.address, true);
    });

    it("Should allow owner to update floor price", async function () {
      const floorPrice = ethers.utils.parseEther("10");
      
      await expect(nftOracle.updateFloorPrice(mockNFT.address, floorPrice))
        .to.emit(nftOracle, "FloorPriceUpdated")
        .withArgs(mockNFT.address, floorPrice);

      expect(await nftOracle.floorPrices(mockNFT.address)).to.equal(floorPrice);
    });

    it("Should reject floor price update for unsupported collection", async function () {
      const floorPrice = ethers.utils.parseEther("10");
      
      await expect(
        nftOracle.updateFloorPrice(user1.address, floorPrice)
      ).to.be.revertedWith("Collection not supported");
    });

    it("Should reject zero floor price", async function () {
      await expect(
        nftOracle.updateFloorPrice(mockNFT.address, 0)
      ).to.be.revertedWith("Invalid floor price");
    });

    it("Should reject non-owner floor price updates", async function () {
      const floorPrice = ethers.utils.parseEther("10");
      
      await expect(
        nftOracle.connect(user1).updateFloorPrice(mockNFT.address, floorPrice)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should return correct floor price", async function () {
      const floorPrice = ethers.utils.parseEther("15");
      await nftOracle.updateFloorPrice(mockNFT.address, floorPrice);
      
      expect(await nftOracle.getCollectionFloorPrice(mockNFT.address)).to.equal(floorPrice);
    });
  });

  describe("NFT Price Management", function () {
    beforeEach(async function () {
      await nftOracle.setCollectionSupport(mockNFT.address, true);
      await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("10"));
    });

    it("Should allow owner to update NFT price", async function () {
      const tokenId = 1;
      const price = ethers.utils.parseEther("12");
      
      await expect(nftOracle.updateNFTPrice(mockNFT.address, tokenId, price))
        .to.emit(nftOracle, "PriceUpdated")
        .withArgs(mockNFT.address, tokenId, price);

      const priceData = await nftOracle.nftPrices(mockNFT.address, tokenId);
      expect(priceData.price).to.equal(price);
      expect(priceData.isValid).to.be.true;
    });

    it("Should reject price update for unsupported collection", async function () {
      const tokenId = 1;
      const price = ethers.utils.parseEther("12");
      
      await expect(
        nftOracle.updateNFTPrice(user1.address, tokenId, price)
      ).to.be.revertedWith("Collection not supported");
    });

    it("Should reject zero price", async function () {
      const tokenId = 1;
      
      await expect(
        nftOracle.updateNFTPrice(mockNFT.address, tokenId, 0)
      ).to.be.revertedWith("Invalid price");
    });

    it("Should reject excessive price deviation", async function () {
      const tokenId = 1;
      const initialPrice = ethers.utils.parseEther("10");
      const excessivePrice = ethers.utils.parseEther("15"); // 50% increase
      
      await nftOracle.updateNFTPrice(mockNFT.address, tokenId, initialPrice);
      
      await expect(
        nftOracle.updateNFTPrice(mockNFT.address, tokenId, excessivePrice)
      ).to.be.revertedWith("Price deviation too high");
    });

    it("Should allow reasonable price deviation", async function () {
      const tokenId = 1;
      const initialPrice = ethers.utils.parseEther("10");
      const newPrice = ethers.utils.parseEther("11"); // 10% increase
      
      await nftOracle.updateNFTPrice(mockNFT.address, tokenId, initialPrice);
      
      await expect(nftOracle.updateNFTPrice(mockNFT.address, tokenId, newPrice))
        .to.emit(nftOracle, "PriceUpdated");
    });

    it("Should reject non-owner price updates", async function () {
      const tokenId = 1;
      const price = ethers.utils.parseEther("12");
      
      await expect(
        nftOracle.connect(user1).updateNFTPrice(mockNFT.address, tokenId, price)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Price Retrieval", function () {
    beforeEach(async function () {
      await nftOracle.setCollectionSupport(mockNFT.address, true);
      await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("10"));
    });

    it("Should return specific NFT price when valid", async function () {
      const tokenId = 1;
      const price = ethers.utils.parseEther("12");
      
      await nftOracle.updateNFTPrice(mockNFT.address, tokenId, price);
      
      expect(await nftOracle.getNFTPrice(mockNFT.address, tokenId)).to.equal(price);
    });

    it("Should fallback to floor price when NFT price is invalid", async function () {
      const tokenId = 1;
      const floorPrice = ethers.utils.parseEther("10");
      
      // Don't set specific price, should fallback to floor price
      expect(await nftOracle.getNFTPrice(mockNFT.address, tokenId)).to.equal(floorPrice);
    });

    it("Should fallback to floor price when NFT price is expired", async function () {
      const tokenId = 1;
      const price = ethers.utils.parseEther("12");
      const floorPrice = ethers.utils.parseEther("10");
      
      await nftOracle.updateNFTPrice(mockNFT.address, tokenId, price);
      
      // Fast forward past validity duration
      await ethers.provider.send("evm_increaseTime", [3601]); // Just over 1 hour
      await ethers.provider.send("evm_mine");
      
      expect(await nftOracle.getNFTPrice(mockNFT.address, tokenId)).to.equal(floorPrice);
    });

    it("Should check price validity correctly", async function () {
      const tokenId = 1;
      const price = ethers.utils.parseEther("12");
      
      await nftOracle.updateNFTPrice(mockNFT.address, tokenId, price);
      
      expect(await nftOracle.isPriceValid(mockNFT.address, tokenId)).to.be.true;
      
      // Fast forward past validity duration
      await ethers.provider.send("evm_increaseTime", [3601]);
      await ethers.provider.send("evm_mine");
      
      expect(await nftOracle.isPriceValid(mockNFT.address, tokenId)).to.be.false;
    });
  });

  describe("Batch Operations", function () {
    beforeEach(async function () {
      await nftOracle.setCollectionSupport(mockNFT.address, true);
    });

    it("Should allow batch price updates", async function () {
      const tokenIds = [1, 2, 3];
      const prices = [
        ethers.utils.parseEther("12"),
        ethers.utils.parseEther("15"),
        ethers.utils.parseEther("8")
      ];
      
      await nftOracle.batchUpdatePrices(mockNFT.address, tokenIds, prices);
      
      for (let i = 0; i < tokenIds.length; i++) {
        expect(await nftOracle.getNFTPrice(mockNFT.address, tokenIds[i])).to.equal(prices[i]);
      }
    });

    it("Should reject batch update with mismatched array lengths", async function () {
      const tokenIds = [1, 2];
      const prices = [ethers.utils.parseEther("12")];
      
      await expect(
        nftOracle.batchUpdatePrices(mockNFT.address, tokenIds, prices)
      ).to.be.revertedWith("Array length mismatch");
    });

    it("Should reject non-owner batch updates", async function () {
      const tokenIds = [1, 2];
      const prices = [
        ethers.utils.parseEther("12"),
        ethers.utils.parseEther("15")
      ];
      
      await expect(
        nftOracle.connect(user1).batchUpdatePrices(mockNFT.address, tokenIds, prices)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("USD Price Conversion", function () {
    beforeEach(async function () {
      await nftOracle.setCollectionSupport(mockNFT.address, true);
      await nftOracle.updateFloorPrice(mockNFT.address, ethers.utils.parseEther("10"));
    });

    it("Should convert ETH price to USD", async function () {
      const tokenId = 1;
      const priceInETH = ethers.utils.parseEther("10");
      
      await nftOracle.updateNFTPrice(mockNFT.address, tokenId, priceInETH);
      
      const priceInUSD = await nftOracle.getNFTPriceInUSD(mockNFT.address, tokenId);
      expect(priceInUSD).to.be.gt(0);
    });

    it("Should handle floor price USD conversion", async function () {
      const tokenId = 1;
      const priceInUSD = await nftOracle.getNFTPriceInUSD(mockNFT.address, tokenId);
      expect(priceInUSD).to.be.gt(0);
    });
  });
});
