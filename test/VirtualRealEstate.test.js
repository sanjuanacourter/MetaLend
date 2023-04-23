const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VirtualRealEstate", function () {
  let virtualRealEstate;
  let owner;
  let user1;
  let user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    const VirtualRealEstate = await ethers.getContractFactory("VirtualRealEstate");
    virtualRealEstate = await VirtualRealEstate.deploy("Virtual Real Estate", "VRE");
    await virtualRealEstate.deployed();
  });

  describe("Deployment", function () {
    it("Should set the correct name and symbol", async function () {
      expect(await virtualRealEstate.name()).to.equal("Virtual Real Estate");
      expect(await virtualRealEstate.symbol()).to.equal("VRE");
    });

    it("Should set the correct owner", async function () {
      expect(await virtualRealEstate.owner()).to.equal(owner.address);
    });

    it("Should initialize with correct type multipliers", async function () {
      expect(await virtualRealEstate.typeMultipliers(0)).to.equal(10000); // RESIDENTIAL
      expect(await virtualRealEstate.typeMultipliers(1)).to.equal(12000); // COMMERCIAL
      expect(await virtualRealEstate.typeMultipliers(2)).to.equal(8000); // INDUSTRIAL
      expect(await virtualRealEstate.typeMultipliers(3)).to.equal(15000); // RECREATIONAL
      expect(await virtualRealEstate.typeMultipliers(4)).to.equal(5000); // LAND_ONLY
    });
  });

  describe("Property Minting", function () {
    it("Should allow owner to mint properties", async function () {
      const location = "Metaverse City Block 1";
      const size = 1000;
      const landValue = ethers.utils.parseEther("10");

      await expect(virtualRealEstate.mintProperty(
        user1.address,
        location,
        size,
        0, // RESIDENTIAL
        landValue
      )).to.emit(virtualRealEstate, "PropertyMinted")
        .withArgs(user1.address, 0, location, 0, landValue);

      expect(await virtualRealEstate.ownerOf(0)).to.equal(user1.address);
    });

    it("Should reject minting with duplicate location", async function () {
      const location = "Metaverse City Block 1";
      const size = 1000;
      const landValue = ethers.utils.parseEther("10");

      await virtualRealEstate.mintProperty(user1.address, location, size, 0, landValue);

      await expect(
        virtualRealEstate.mintProperty(user2.address, location, size, 0, landValue)
      ).to.be.revertedWith("Location already exists");
    });

    it("Should reject minting with zero land value", async function () {
      const location = "Metaverse City Block 1";
      const size = 1000;

      await expect(
        virtualRealEstate.mintProperty(user1.address, location, size, 0, 0)
      ).to.be.revertedWith("Invalid land value");
    });

    it("Should reject minting with zero size", async function () {
      const location = "Metaverse City Block 1";
      const landValue = ethers.utils.parseEther("10");

      await expect(
        virtualRealEstate.mintProperty(user1.address, location, 0, 0, landValue)
      ).to.be.revertedWith("Invalid size");
    });

    it("Should reject minting by non-owner", async function () {
      const location = "Metaverse City Block 1";
      const size = 1000;
      const landValue = ethers.utils.parseEther("10");

      await expect(
        virtualRealEstate.connect(user1).mintProperty(user2.address, location, size, 0, landValue)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Building Construction", function () {
    let tokenId;

    beforeEach(async function () {
      const location = "Metaverse City Block 1";
      const size = 1000;
      const landValue = ethers.utils.parseEther("10");

      await virtualRealEstate.mintProperty(user1.address, location, size, 0, landValue);
      tokenId = 0;
    });

    it("Should allow property owner to construct building", async function () {
      const buildingValue = ethers.utils.parseEther("5");
      const rentYield = 1000; // 10%

      await expect(virtualRealEstate.connect(user1).constructBuilding(
        tokenId,
        buildingValue,
        rentYield
      )).to.emit(virtualRealEstate, "BuildingConstructed")
        .withArgs(tokenId, buildingValue, rentYield);

      const propertyInfo = await virtualRealEstate.getPropertyInfo(tokenId);
      expect(propertyInfo.hasBuilding).to.be.true;
      expect(propertyInfo.buildingValue).to.equal(buildingValue);
      expect(propertyInfo.rentYield).to.equal(rentYield);
    });

    it("Should reject building construction by non-owner", async function () {
      const buildingValue = ethers.utils.parseEther("5");
      const rentYield = 1000;

      await expect(
        virtualRealEstate.connect(user2).constructBuilding(tokenId, buildingValue, rentYield)
      ).to.be.revertedWith("Not property owner");
    });

    it("Should reject building construction with zero value", async function () {
      const rentYield = 1000;

      await expect(
        virtualRealEstate.connect(user1).constructBuilding(tokenId, 0, rentYield)
      ).to.be.revertedWith("Invalid building value");
    });

    it("Should reject building construction with excessive rent yield", async function () {
      const buildingValue = ethers.utils.parseEther("5");
      const rentYield = 2001; // > 20%

      await expect(
        virtualRealEstate.connect(user1).constructBuilding(tokenId, buildingValue, rentYield)
      ).to.be.revertedWith("Rent yield too high");
    });

    it("Should reject duplicate building construction", async function () {
      const buildingValue = ethers.utils.parseEther("5");
      const rentYield = 1000;

      await virtualRealEstate.connect(user1).constructBuilding(tokenId, buildingValue, rentYield);

      await expect(
        virtualRealEstate.connect(user1).constructBuilding(tokenId, buildingValue, rentYield)
      ).to.be.revertedWith("Building already exists");
    });
  });

  describe("Property Information", function () {
    let tokenId;

    beforeEach(async function () {
      const location = "Metaverse City Block 1";
      const size = 1000;
      const landValue = ethers.utils.parseEther("10");

      await virtualRealEstate.mintProperty(user1.address, location, size, 0, landValue);
      tokenId = 0;
    });

    it("Should return correct property information", async function () {
      const propertyInfo = await virtualRealEstate.getPropertyInfo(tokenId);

      expect(propertyInfo.tokenId).to.equal(tokenId);
      expect(propertyInfo.location).to.equal("Metaverse City Block 1");
      expect(propertyInfo.size).to.equal(1000);
      expect(propertyInfo.propertyType).to.equal(0); // RESIDENTIAL
      expect(propertyInfo.hasBuilding).to.be.false;
    });

    it("Should return correct property value", async function () {
      const value = await virtualRealEstate.getPropertyValue(tokenId);
      expect(value).to.equal(ethers.utils.parseEther("10"));
    });

    it("Should calculate rent income correctly", async function () {
      const buildingValue = ethers.utils.parseEther("5");
      const rentYield = 1000; // 10%

      await virtualRealEstate.connect(user1).constructBuilding(tokenId, buildingValue, rentYield);

      const rentIncome = await virtualRealEstate.calculateRentIncome(tokenId);
      const expectedIncome = (buildingValue * rentYield) / 10000;
      expect(rentIncome).to.equal(expectedIncome);
    });

    it("Should return zero rent income for properties without buildings", async function () {
      const rentIncome = await virtualRealEstate.calculateRentIncome(tokenId);
      expect(rentIncome).to.equal(0);
    });
  });

  describe("Property Management", function () {
    beforeEach(async function () {
      // Mint properties of different types
      await virtualRealEstate.mintProperty(
        user1.address,
        "Residential Block 1",
        1000,
        0, // RESIDENTIAL
        ethers.utils.parseEther("10")
      );

      await virtualRealEstate.mintProperty(
        user2.address,
        "Commercial Block 1",
        2000,
        1, // COMMERCIAL
        ethers.utils.parseEther("20")
      );

      await virtualRealEstate.mintProperty(
        user1.address,
        "Industrial Block 1",
        5000,
        2, // INDUSTRIAL
        ethers.utils.parseEther("15")
      );
    });

    it("Should return properties by type", async function () {
      const residentialProperties = await virtualRealEstate.getPropertiesByType(0);
      expect(residentialProperties.length).to.equal(1);
      expect(residentialProperties[0]).to.equal(0);

      const commercialProperties = await virtualRealEstate.getPropertiesByType(1);
      expect(commercialProperties.length).to.equal(1);
      expect(commercialProperties[0]).to.equal(1);

      const industrialProperties = await virtualRealEstate.getPropertiesByType(2);
      expect(industrialProperties.length).to.equal(1);
      expect(industrialProperties[0]).to.equal(2);
    });

    it("Should return correct total supply", async function () {
      expect(await virtualRealEstate.getTotalSupply()).to.equal(3);
    });
  });

  describe("Owner Functions", function () {
    it("Should allow owner to update property values", async function () {
      const location = "Metaverse City Block 1";
      const size = 1000;
      const landValue = ethers.utils.parseEther("10");

      await virtualRealEstate.mintProperty(user1.address, location, size, 0, landValue);

      const newLandValue = ethers.utils.parseEther("15");
      const newBuildingValue = ethers.utils.parseEther("8");

      await expect(virtualRealEstate.updatePropertyValue(0, newLandValue, newBuildingValue))
        .to.emit(virtualRealEstate, "PropertyValueUpdated")
        .withArgs(0, newLandValue, newBuildingValue, newLandValue.add(newBuildingValue));

      const propertyInfo = await virtualRealEstate.getPropertyInfo(0);
      expect(propertyInfo.landValue).to.equal(newLandValue);
      expect(propertyInfo.buildingValue).to.equal(newBuildingValue);
      expect(propertyInfo.totalValue).to.equal(newLandValue.add(newBuildingValue));
    });

    it("Should allow owner to set type multipliers", async function () {
      await virtualRealEstate.setTypeMultiplier(0, 15000);
      expect(await virtualRealEstate.typeMultipliers(0)).to.equal(15000);
    });

    it("Should reject invalid type multipliers", async function () {
      await expect(
        virtualRealEstate.setTypeMultiplier(0, 0)
      ).to.be.revertedWith("Invalid multiplier");

      await expect(
        virtualRealEstate.setTypeMultiplier(0, 20001)
      ).to.be.revertedWith("Invalid multiplier");
    });

    it("Should allow owner to set base URI", async function () {
      const newBaseURI = "https://api.metalend.finance/metadata/";
      await virtualRealEstate.setBaseURI(newBaseURI);
      expect(await virtualRealEstate.baseURI()).to.equal(newBaseURI);
    });

    it("Should reject non-owner operations", async function () {
      await expect(
        virtualRealEstate.connect(user1).updatePropertyValue(0, ethers.utils.parseEther("15"), ethers.utils.parseEther("8"))
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        virtualRealEstate.connect(user1).setTypeMultiplier(0, 15000)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        virtualRealEstate.connect(user1).setBaseURI("https://example.com/")
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Token URI", function () {
    let tokenId;

    beforeEach(async function () {
      const location = "Metaverse City Block 1";
      const size = 1000;
      const landValue = ethers.utils.parseEther("10");

      await virtualRealEstate.mintProperty(user1.address, location, size, 0, landValue);
      tokenId = 0;
    });

    it("Should return correct token URI", async function () {
      const tokenURI = await virtualRealEstate.tokenURI(tokenId);
      expect(tokenURI).to.include("0?location=Metaverse City Block 1");
      expect(tokenURI).to.include("type=0");
      expect(tokenURI).to.include("value=");
    });

    it("Should reject URI query for non-existent token", async function () {
      await expect(
        virtualRealEstate.tokenURI(999)
      ).to.be.revertedWith("URI query for nonexistent token");
    });
  });
});
