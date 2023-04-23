// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract GamingAssets is ERC1155, Ownable {
    using Strings for uint256;

    struct GameAsset {
        uint256 assetId;
        string name;
        string description;
        AssetCategory category;
        uint256 rarity;
        uint256 powerLevel;
        uint256 durability;
        uint256 maxDurability;
        bool isTradeable;
        bool isUpgradeable;
        uint256 mintTimestamp;
        string gameMetadata;
    }

    enum AssetCategory {
        WEAPON,
        ARMOR,
        ACCESSORY,
        CONSUMABLE,
        CURRENCY,
        LAND,
        BUILDING,
        VEHICLE,
        PET,
        SKIN
    }

    mapping(uint256 => GameAsset) public gameAssets;
    mapping(AssetCategory => uint256) public categoryMultipliers;
    mapping(address => mapping(uint256 => uint256)) public playerAssets;
    
    uint256 public nextAssetId = 1;
    string public baseURI;
    
    event GameAssetCreated(
        uint256 indexed assetId,
        string name,
        AssetCategory category,
        uint256 rarity,
        uint256 powerLevel
    );
    
    event AssetMinted(
        address indexed player,
        uint256 indexed assetId,
        uint256 amount
    );
    
    event AssetUpgraded(
        address indexed player,
        uint256 indexed assetId,
        uint256 newPowerLevel,
        uint256 newDurability
    );
    
    event AssetTraded(
        address indexed from,
        address indexed to,
        uint256 indexed assetId,
        uint256 amount
    );

    constructor(string memory uri) ERC1155(uri) {
        // Initialize category multipliers
        categoryMultipliers[AssetCategory.WEAPON] = 12000; // 1.2x
        categoryMultipliers[AssetCategory.ARMOR] = 11000; // 1.1x
        categoryMultipliers[AssetCategory.ACCESSORY] = 10000; // 1x
        categoryMultipliers[AssetCategory.CONSUMABLE] = 5000; // 0.5x
        categoryMultipliers[AssetCategory.CURRENCY] = 8000; // 0.8x
        categoryMultipliers[AssetCategory.LAND] = 15000; // 1.5x
        categoryMultipliers[AssetCategory.BUILDING] = 13000; // 1.3x
        categoryMultipliers[AssetCategory.VEHICLE] = 14000; // 1.4x
        categoryMultipliers[AssetCategory.PET] = 16000; // 1.6x
        categoryMultipliers[AssetCategory.SKIN] = 9000; // 0.9x
    }

    function createGameAsset(
        string calldata name,
        string calldata description,
        AssetCategory category,
        uint256 rarity,
        uint256 powerLevel,
        uint256 maxDurability,
        bool isTradeable,
        bool isUpgradeable,
        string calldata gameMetadata
    ) external onlyOwner returns (uint256) {
        require(rarity > 0 && rarity <= 100, "Invalid rarity");
        require(powerLevel > 0, "Invalid power level");
        require(maxDurability > 0, "Invalid durability");

        uint256 assetId = nextAssetId++;
        
        gameAssets[assetId] = GameAsset({
            assetId: assetId,
            name: name,
            description: description,
            category: category,
            rarity: rarity,
            powerLevel: powerLevel,
            durability: maxDurability,
            maxDurability: maxDurability,
            isTradeable: isTradeable,
            isUpgradeable: isUpgradeable,
            mintTimestamp: block.timestamp,
            gameMetadata: gameMetadata
        });

        emit GameAssetCreated(assetId, name, category, rarity, powerLevel);
        return assetId;
    }

    function mintGameAsset(
        address player,
        uint256 assetId,
        uint256 amount
    ) external onlyOwner {
        require(gameAssets[assetId].assetId != 0, "Asset does not exist");
        require(amount > 0, "Invalid amount");

        _mint(player, assetId, amount, "");
        playerAssets[player][assetId] += amount;

        emit AssetMinted(player, assetId, amount);
    }

    function upgradeAsset(
        uint256 assetId,
        uint256 powerIncrease,
        uint256 durabilityIncrease
    ) external {
        require(gameAssets[assetId].assetId != 0, "Asset does not exist");
        require(gameAssets[assetId].isUpgradeable, "Asset not upgradeable");
        require(balanceOf(msg.sender, assetId) > 0, "No asset balance");

        GameAsset storage asset = gameAssets[assetId];
        asset.powerLevel += powerIncrease;
        asset.durability = asset.maxDurability + durabilityIncrease;
        asset.maxDurability += durabilityIncrease;

        emit AssetUpgraded(msg.sender, assetId, asset.powerLevel, asset.durability);
    }

    function repairAsset(uint256 assetId) external {
        require(gameAssets[assetId].assetId != 0, "Asset does not exist");
        require(balanceOf(msg.sender, assetId) > 0, "No asset balance");

        GameAsset storage asset = gameAssets[assetId];
        asset.durability = asset.maxDurability;

        emit AssetUpgraded(msg.sender, assetId, asset.powerLevel, asset.durability);
    }

    function tradeAsset(
        address to,
        uint256 assetId,
        uint256 amount
    ) external {
        require(gameAssets[assetId].assetId != 0, "Asset does not exist");
        require(gameAssets[assetId].isTradeable, "Asset not tradeable");
        require(balanceOf(msg.sender, assetId) >= amount, "Insufficient balance");

        _safeTransferFrom(msg.sender, to, assetId, amount, "");
        playerAssets[msg.sender][assetId] -= amount;
        playerAssets[to][assetId] += amount;

        emit AssetTraded(msg.sender, to, assetId, amount);
    }

    function calculateAssetValue(uint256 assetId) external view returns (uint256) {
        require(gameAssets[assetId].assetId != 0, "Asset does not exist");
        
        GameAsset memory asset = gameAssets[assetId];
        uint256 categoryMultiplier = categoryMultipliers[asset.category];
        
        // Base value calculation
        uint256 baseValue = asset.powerLevel * 1e18;
        
        // Apply rarity multiplier (1x to 10x)
        uint256 rarityMultiplier = (asset.rarity * 100000) / 100;
        
        // Apply category multiplier
        uint256 finalValue = (baseValue * rarityMultiplier * categoryMultiplier) / (100000 * 10000);
        
        // Apply durability factor
        uint256 durabilityFactor = (asset.durability * 10000) / asset.maxDurability;
        finalValue = (finalValue * durabilityFactor) / 10000;
        
        return finalValue;
    }

    function getPlayerAssetCount(address player, uint256 assetId) external view returns (uint256) {
        return playerAssets[player][assetId];
    }

    function getGameAssetInfo(uint256 assetId) external view returns (GameAsset memory) {
        require(gameAssets[assetId].assetId != 0, "Asset does not exist");
        return gameAssets[assetId];
    }

    function getAssetsByCategory(AssetCategory category) external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](nextAssetId - 1);
        uint256 count = 0;
        
        for (uint256 i = 1; i < nextAssetId; i++) {
            if (gameAssets[i].category == category) {
                result[count] = i;
                count++;
            }
        }
        
        // Resize array to actual count
        uint256[] memory finalResult = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            finalResult[i] = result[i];
        }
        
        return finalResult;
    }

    function setCategoryMultiplier(AssetCategory category, uint256 multiplier) external onlyOwner {
        require(multiplier > 0 && multiplier <= 20000, "Invalid multiplier");
        categoryMultipliers[category] = multiplier;
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    function uri(uint256 assetId) public view override returns (string memory) {
        require(gameAssets[assetId].assetId != 0, "URI query for nonexistent asset");
        
        GameAsset memory asset = gameAssets[assetId];
        return string(abi.encodePacked(
            baseURI,
            assetId.toString(),
            "?name=",
            asset.name,
            "&category=",
            uint256(asset.category).toString(),
            "&rarity=",
            asset.rarity.toString(),
            "&power=",
            asset.powerLevel.toString()
        ));
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
