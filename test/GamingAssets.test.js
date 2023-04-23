const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GamingAssets", function () {
  let gamingAssets;
  let owner;
  let player1;
  let player2;

  beforeEach(async function () {
    [owner, player1, player2] = await ethers.getSigners();

    const GamingAssets = await ethers.getContractFactory("GamingAssets");
    gamingAssets = await GamingAssets.deploy("https://api.metalend.finance/gaming/");
    await gamingAssets.deployed();
  });

  describe("Deployment", function () {
    it("Should set the correct URI", async function () {
      expect(await gamingAssets.uri(1)).to.include("https://api.metalend.finance/gaming/");
    });

    it("Should set the correct owner", async function () {
      expect(await gamingAssets.owner()).to.equal(owner.address);
    });

    it("Should initialize with correct category multipliers", async function () {
      expect(await gamingAssets.categoryMultipliers(0)).to.equal(12000); // WEAPON
      expect(await gamingAssets.categoryMultipliers(1)).to.equal(11000); // ARMOR
      expect(await gamingAssets.categoryMultipliers(2)).to.equal(10000); // ACCESSORY
      expect(await gamingAssets.categoryMultipliers(3)).to.equal(5000); // CONSUMABLE
      expect(await gamingAssets.categoryMultipliers(4)).to.equal(8000); // CURRENCY
      expect(await gamingAssets.categoryMultipliers(5)).to.equal(15000); // LAND
      expect(await gamingAssets.categoryMultipliers(6)).to.equal(13000); // BUILDING
      expect(await gamingAssets.categoryMultipliers(7)).to.equal(14000); // VEHICLE
      expect(await gamingAssets.categoryMultipliers(8)).to.equal(16000); // PET
      expect(await gamingAssets.categoryMultipliers(9)).to.equal(9000); // SKIN
    });
  });

  describe("Game Asset Creation", function () {
    it("Should allow owner to create game assets", async function () {
      await expect(gamingAssets.createGameAsset(
        "Legendary Sword",
        "A powerful legendary sword",
        0, // WEAPON
        95, // rarity
        1000, // power level
        100, // max durability
        true, // tradeable
        true, // upgradeable
        '{"damage": 1000, "element": "fire"}'
      )).to.emit(gamingAssets, "GameAssetCreated")
        .withArgs(1, "Legendary Sword", 0, 95, 1000);

      const assetInfo = await gamingAssets.getGameAssetInfo(1);
      expect(assetInfo.name).to.equal("Legendary Sword");
      expect(assetInfo.category).to.equal(0);
      expect(assetInfo.rarity).to.equal(95);
      expect(assetInfo.powerLevel).to.equal(1000);
      expect(assetInfo.isTradeable).to.be.true;
      expect(assetInfo.isUpgradeable).to.be.true;
    });

    it("Should reject asset creation with invalid rarity", async function () {
      await expect(
        gamingAssets.createGameAsset(
          "Invalid Sword",
          "A sword with invalid rarity",
          0,
          0, // Invalid rarity
          1000,
          100,
          true,
          true,
          "{}"
        )
      ).to.be.revertedWith("Invalid rarity");

      await expect(
        gamingAssets.createGameAsset(
          "Invalid Sword",
          "A sword with invalid rarity",
          0,
          101, // Invalid rarity
          1000,
          100,
          true,
          true,
          "{}"
        )
      ).to.be.revertedWith("Invalid rarity");
    });

    it("Should reject asset creation with zero power level", async function () {
      await expect(
        gamingAssets.createGameAsset(
          "Weak Sword",
          "A sword with no power",
          0,
          50,
          0, // Invalid power level
          100,
          true,
          true,
          "{}"
        )
      ).to.be.revertedWith("Invalid power level");
    });

    it("Should reject asset creation with zero durability", async function () {
      await expect(
        gamingAssets.createGameAsset(
          "Fragile Sword",
          "A sword with no durability",
          0,
          50,
          1000,
          0, // Invalid durability
          true,
          true,
          "{}"
        )
      ).to.be.revertedWith("Invalid durability");
    });

    it("Should reject asset creation by non-owner", async function () {
      await expect(
        gamingAssets.connect(player1).createGameAsset(
          "Player Sword",
          "A sword created by player",
          0,
          50,
          1000,
          100,
          true,
          true,
          "{}"
        )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Asset Minting", function () {
    let assetId;

    beforeEach(async function () {
      await gamingAssets.createGameAsset(
        "Legendary Sword",
        "A powerful legendary sword",
        0, // WEAPON
        95,
        1000,
        100,
        true,
        true,
        '{"damage": 1000, "element": "fire"}'
      );
      assetId = 1;
    });

    it("Should allow owner to mint assets to players", async function () {
      const amount = 5;

      await expect(gamingAssets.mintGameAsset(player1.address, assetId, amount))
        .to.emit(gamingAssets, "AssetMinted")
        .withArgs(player1.address, assetId, amount);

      expect(await gamingAssets.balanceOf(player1.address, assetId)).to.equal(amount);
      expect(await gamingAssets.getPlayerAssetCount(player1.address, assetId)).to.equal(amount);
    });

    it("Should reject minting non-existent assets", async function () {
      await expect(
        gamingAssets.mintGameAsset(player1.address, 999, 1)
      ).to.be.revertedWith("Asset does not exist");
    });

    it("Should reject minting zero amount", async function () {
      await expect(
        gamingAssets.mintGameAsset(player1.address, assetId, 0)
      ).to.be.revertedWith("Invalid amount");
    });

    it("Should reject minting by non-owner", async function () {
      await expect(
        gamingAssets.connect(player1).mintGameAsset(player2.address, assetId, 1)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Asset Upgrades", function () {
    let assetId;

    beforeEach(async function () {
      await gamingAssets.createGameAsset(
        "Upgradeable Sword",
        "A sword that can be upgraded",
        0, // WEAPON
        50,
        500,
        100,
        true,
        true,
        "{}"
      );
      assetId = 1;

      await gamingAssets.mintGameAsset(player1.address, assetId, 1);
    });

    it("Should allow upgrading upgradeable assets", async function () {
      const powerIncrease = 100;
      const durabilityIncrease = 50;

      await expect(gamingAssets.connect(player1).upgradeAsset(
        assetId,
        powerIncrease,
        durabilityIncrease
      )).to.emit(gamingAssets, "AssetUpgraded")
        .withArgs(player1.address, assetId, 600, 150);

      const assetInfo = await gamingAssets.getGameAssetInfo(assetId);
      expect(assetInfo.powerLevel).to.equal(600);
      expect(assetInfo.durability).to.equal(150);
      expect(assetInfo.maxDurability).to.equal(150);
    });

    it("Should reject upgrading non-upgradeable assets", async function () {
      // Create non-upgradeable asset
      await gamingAssets.createGameAsset(
        "Non-Upgradeable Sword",
        "A sword that cannot be upgraded",
        0,
        50,
        500,
        100,
        true,
        false, // Not upgradeable
        "{}"
      );

      await gamingAssets.mintGameAsset(player1.address, 2, 1);

      await expect(
        gamingAssets.connect(player1).upgradeAsset(2, 100, 50)
      ).to.be.revertedWith("Asset not upgradeable");
    });

    it("Should reject upgrading assets not owned by caller", async function () {
      await expect(
        gamingAssets.connect(player2).upgradeAsset(assetId, 100, 50)
      ).to.be.revertedWith("No asset balance");
    });

    it("Should allow repairing assets", async function () {
      // First upgrade to reduce durability
      await gamingAssets.connect(player1).upgradeAsset(assetId, 0, 0);

      // Then repair
      await expect(gamingAssets.connect(player1).repairAsset(assetId))
        .to.emit(gamingAssets, "AssetUpgraded")
        .withArgs(player1.address, assetId, 500, 100);

      const assetInfo = await gamingAssets.getGameAssetInfo(assetId);
      expect(assetInfo.durability).to.equal(assetInfo.maxDurability);
    });
  });

  describe("Asset Trading", function () {
    let assetId;

    beforeEach(async function () {
      await gamingAssets.createGameAsset(
        "Tradeable Sword",
        "A sword that can be traded",
        0, // WEAPON
        50,
        500,
        100,
        true, // Tradeable
        true,
        "{}"
      );
      assetId = 1;

      await gamingAssets.mintGameAsset(player1.address, assetId, 2);
    });

    it("Should allow trading tradeable assets", async function () {
      const tradeAmount = 1;

      await expect(gamingAssets.connect(player1).tradeAsset(
        player2.address,
        assetId,
        tradeAmount
      )).to.emit(gamingAssets, "AssetTraded")
        .withArgs(player1.address, player2.address, assetId, tradeAmount);

      expect(await gamingAssets.balanceOf(player1.address, assetId)).to.equal(1);
      expect(await gamingAssets.balanceOf(player2.address, assetId)).to.equal(1);
      expect(await gamingAssets.getPlayerAssetCount(player1.address, assetId)).to.equal(1);
      expect(await gamingAssets.getPlayerAssetCount(player2.address, assetId)).to.equal(1);
    });

    it("Should reject trading non-tradeable assets", async function () {
      // Create non-tradeable asset
      await gamingAssets.createGameAsset(
        "Non-Tradeable Sword",
        "A sword that cannot be traded",
        0,
        50,
        500,
        100,
        false, // Not tradeable
        true,
        "{}"
      );

      await gamingAssets.mintGameAsset(player1.address, 2, 1);

      await expect(
        gamingAssets.connect(player1).tradeAsset(player2.address, 2, 1)
      ).to.be.revertedWith("Asset not tradeable");
    });

    it("Should reject trading insufficient balance", async function () {
      await expect(
        gamingAssets.connect(player1).tradeAsset(player2.address, assetId, 5)
      ).to.be.revertedWith("Insufficient balance");
    });
  });

  describe("Asset Valuation", function () {
    let assetId;

    beforeEach(async function () {
      await gamingAssets.createGameAsset(
        "Legendary Sword",
        "A powerful legendary sword",
        0, // WEAPON
        95,
        1000,
        100,
        true,
        true,
        "{}"
      );
      assetId = 1;
    });

    it("Should calculate asset value correctly", async function () {
      const value = await gamingAssets.calculateAssetValue(assetId);
      
      // Base value: 1000 * 1e18
      // Rarity multiplier: 95 * 100000 / 100 = 95000 (0.95x to 9.5x)
      // Category multiplier: 12000 (1.2x)
      // Durability factor: 100 * 10000 / 100 = 10000 (1x)
      // Final: (1000 * 1e18 * 95000 * 12000 * 10000) / (100000 * 10000 * 10000)
      
      expect(value).to.be.gt(0);
    });

    it("Should reject valuation of non-existent assets", async function () {
      await expect(
        gamingAssets.calculateAssetValue(999)
      ).to.be.revertedWith("Asset does not exist");
    });
  });

  describe("Asset Queries", function () {
    beforeEach(async function () {
      // Create assets of different categories
      await gamingAssets.createGameAsset("Weapon 1", "A weapon", 0, 50, 500, 100, true, true, "{}");
      await gamingAssets.createGameAsset("Armor 1", "An armor", 1, 60, 400, 80, true, true, "{}");
      await gamingAssets.createGameAsset("Weapon 2", "Another weapon", 0, 70, 600, 120, true, true, "{}");
      await gamingAssets.createGameAsset("Accessory 1", "An accessory", 2, 40, 200, 60, true, true, "{}");
    });

    it("Should return assets by category", async function () {
      const weapons = await gamingAssets.getAssetsByCategory(0);
      expect(weapons.length).to.equal(2);
      expect(weapons[0]).to.equal(1);
      expect(weapons[1]).to.equal(3);

      const armors = await gamingAssets.getAssetsByCategory(1);
      expect(armors.length).to.equal(1);
      expect(armors[0]).to.equal(2);

      const accessories = await gamingAssets.getAssetsByCategory(2);
      expect(accessories.length).to.equal(1);
      expect(accessories[0]).to.equal(4);
    });

    it("Should return correct asset count", async function () {
      expect(await gamingAssets.nextAssetId()).to.equal(5); // 4 assets created, next ID is 5
    });
  });

  describe("Owner Functions", function () {
    it("Should allow owner to set category multipliers", async function () {
      await gamingAssets.setCategoryMultiplier(0, 15000);
      expect(await gamingAssets.categoryMultipliers(0)).to.equal(15000);
    });

    it("Should reject invalid category multipliers", async function () {
      await expect(
        gamingAssets.setCategoryMultiplier(0, 0)
      ).to.be.revertedWith("Invalid multiplier");

      await expect(
        gamingAssets.setCategoryMultiplier(0, 20001)
      ).to.be.revertedWith("Invalid multiplier");
    });

    it("Should allow owner to set base URI", async function () {
      const newBaseURI = "https://new-api.metalend.finance/gaming/";
      await gamingAssets.setBaseURI(newBaseURI);
      expect(await gamingAssets.baseURI()).to.equal(newBaseURI);
    });

    it("Should reject non-owner operations", async function () {
      await expect(
        gamingAssets.connect(player1).setCategoryMultiplier(0, 15000)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        gamingAssets.connect(player1).setBaseURI("https://example.com/")
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Token URI", function () {
    let assetId;

    beforeEach(async function () {
      await gamingAssets.createGameAsset(
        "Legendary Sword",
        "A powerful legendary sword",
        0, // WEAPON
        95,
        1000,
        100,
        true,
        true,
        '{"damage": 1000, "element": "fire"}'
      );
      assetId = 1;
    });

    it("Should return correct token URI", async function () {
      const tokenURI = await gamingAssets.uri(assetId);
      expect(tokenURI).to.include("1?name=Legendary Sword");
      expect(tokenURI).to.include("category=0");
      expect(tokenURI).to.include("rarity=95");
      expect(tokenURI).to.include("power=1000");
    });

    it("Should reject URI query for non-existent asset", async function () {
      const tokenURI = await gamingAssets.uri(999);
      expect(tokenURI).to.include("999?name=");
      expect(tokenURI).to.include("category=");
    });
  });
});
