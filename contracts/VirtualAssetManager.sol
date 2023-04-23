// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./interfaces/IVirtualAssetManager.sol";

contract VirtualAssetManager is IVirtualAssetManager, ReentrancyGuard, Ownable {
    mapping(uint256 => VirtualAssetInfo) public virtualAssets;
    mapping(address => mapping(uint256 => uint256)) public assetToVirtualId;
    mapping(AssetType => bool) public supportedAssetTypes;
    mapping(AssetType => uint256) public marketMultipliers;
    
    uint256 public nextVirtualAssetId = 1;
    address public oracle;
    
    // Valuation parameters
    uint256 public constant RARITY_WEIGHT = 3000; // 30%
    uint256 public constant UTILITY_WEIGHT = 4000; // 40%
    uint256 public constant MARKET_WEIGHT = 3000; // 30%
    uint256 public constant PRECISION = 10000;

    modifier onlyOracle() {
        require(msg.sender == oracle, "Only oracle");
        _;
    }

    constructor(address _oracle) {
        oracle = _oracle;
        
        // Initialize market multipliers
        marketMultipliers[AssetType.NFT] = 10000; // 1x
        marketMultipliers[AssetType.VIRTUAL_REAL_ESTATE] = 12000; // 1.2x
        marketMultipliers[AssetType.GAMING_ASSET] = 8000; // 0.8x
        marketMultipliers[AssetType.METAVERSE_LAND] = 15000; // 1.5x
        marketMultipliers[AssetType.VIRTUAL_CURRENCY] = 5000; // 0.5x
        
        // Set initial supported types
        supportedAssetTypes[AssetType.NFT] = true;
        supportedAssetTypes[AssetType.VIRTUAL_REAL_ESTATE] = true;
        supportedAssetTypes[AssetType.GAMING_ASSET] = true;
        supportedAssetTypes[AssetType.METAVERSE_LAND] = true;
        supportedAssetTypes[AssetType.VIRTUAL_CURRENCY] = true;
    }

    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
    }

    function registerVirtualAsset(
        address assetContract,
        uint256 assetId,
        AssetType assetType,
        string calldata metadata
    ) external override nonReentrant returns (uint256 virtualAssetId) {
        require(supportedAssetTypes[assetType], "Asset type not supported");
        require(assetContract != address(0), "Invalid asset contract");
        require(assetToVirtualId[assetContract][assetId] == 0, "Asset already registered");

        // Verify asset ownership
        if (assetType == AssetType.NFT || assetType == AssetType.VIRTUAL_REAL_ESTATE || assetType == AssetType.METAVERSE_LAND) {
            require(IERC721(assetContract).ownerOf(assetId) == msg.sender, "Not asset owner");
        } else if (assetType == AssetType.GAMING_ASSET || assetType == AssetType.VIRTUAL_CURRENCY) {
            require(IERC1155(assetContract).balanceOf(msg.sender, assetId) > 0, "No asset balance");
        }

        virtualAssetId = nextVirtualAssetId++;
        virtualAssets[virtualAssetId] = VirtualAssetInfo({
            assetType: assetType,
            assetContract: assetContract,
            assetId: assetId,
            value: 0, // Will be set by oracle
            rarityScore: 0,
            utilityScore: 0,
            isActive: true,
            timestamp: block.timestamp,
            metadata: metadata
        });

        assetToVirtualId[assetContract][assetId] = virtualAssetId;

        emit VirtualAssetRegistered(assetContract, assetId, assetType, 0);
        return virtualAssetId;
    }

    function updateAssetValuation(
        address assetContract,
        uint256 assetId,
        AssetType assetType
    ) external override onlyOracle {
        uint256 virtualAssetId = assetToVirtualId[assetContract][assetId];
        require(virtualAssetId > 0, "Asset not registered");

        VirtualAssetInfo storage asset = virtualAssets[virtualAssetId];
        require(asset.isActive, "Asset not active");

        AssetValuation memory valuation = calculateAssetValuation(assetContract, assetId, assetType);
        asset.value = valuation.finalValue;
        asset.rarityScore = valuation.rarityMultiplier;
        asset.utilityScore = valuation.utilityMultiplier;

        emit AssetValuationUpdated(assetContract, assetId, valuation.finalValue, valuation.confidence);
    }

    function getAssetValuation(address assetContract, uint256 assetId)
        external
        view
        override
        returns (AssetValuation memory)
    {
        uint256 virtualAssetId = assetToVirtualId[assetContract][assetId];
        require(virtualAssetId > 0, "Asset not registered");

        VirtualAssetInfo memory asset = virtualAssets[virtualAssetId];
        return calculateAssetValuation(assetContract, assetId, asset.assetType);
    }

    function getVirtualAssetInfo(uint256 virtualAssetId)
        external
        view
        override
        returns (VirtualAssetInfo memory)
    {
        return virtualAssets[virtualAssetId];
    }

    function setAssetTypeSupport(AssetType assetType, bool supported) external override onlyOwner {
        supportedAssetTypes[assetType] = supported;
        emit AssetTypeSupported(assetType, supported);
    }

    function isAssetTypeSupported(AssetType assetType) external view override returns (bool) {
        return supportedAssetTypes[assetType];
    }

    function calculateRarityScore(address assetContract, uint256 assetId)
        external
        view
        override
        returns (uint256)
    {
        // In a real implementation, this would query external rarity APIs
        // For now, return a mock score based on assetId
        return (assetId % 100) + 1; // Score between 1-100
    }

    function calculateUtilityScore(address assetContract, uint256 assetId)
        external
        view
        override
        returns (uint256)
    {
        // In a real implementation, this would analyze utility metrics
        // For now, return a mock score based on assetId
        return ((assetId * 7) % 100) + 1; // Score between 1-100
    }

    function getMarketMultiplier(AssetType assetType) external view override returns (uint256) {
        return marketMultipliers[assetType];
    }

    function setMarketMultiplier(AssetType assetType, uint256 multiplier) external onlyOwner {
        require(multiplier > 0 && multiplier <= 20000, "Invalid multiplier"); // Max 2x
        marketMultipliers[assetType] = multiplier;
    }

    function calculateAssetValuation(
        address assetContract,
        uint256 assetId,
        AssetType assetType
    ) internal view returns (AssetValuation memory) {
        uint256 rarityScore = this.calculateRarityScore(assetContract, assetId);
        uint256 utilityScore = this.calculateUtilityScore(assetContract, assetId);
        uint256 marketMultiplier = marketMultipliers[assetType];

        // Base value calculation (mock implementation)
        uint256 baseValue = (assetId % 1000 + 1) * 1e18; // 1-1000 ETH

        // Apply multipliers
        uint256 rarityMultiplier = (rarityScore * 20000) / 100; // 0.2x to 2x
        uint256 utilityMultiplier = (utilityScore * 15000) / 100; // 0.15x to 1.5x

        // Calculate final value
        uint256 finalValue = (baseValue * rarityMultiplier * utilityMultiplier * marketMultiplier) / (PRECISION * PRECISION * PRECISION);

        // Calculate confidence based on data availability
        uint256 confidence = 8000; // 80% base confidence

        return AssetValuation({
            baseValue: baseValue,
            rarityMultiplier: rarityMultiplier,
            utilityMultiplier: utilityMultiplier,
            marketMultiplier: marketMultiplier,
            finalValue: finalValue,
            confidence: confidence
        });
    }

    function getVirtualAssetCount() external view returns (uint256) {
        return nextVirtualAssetId - 1;
    }

    function getVirtualAssetByContract(address assetContract, uint256 assetId)
        external
        view
        returns (uint256)
    {
        return assetToVirtualId[assetContract][assetId];
    }

    function deactivateVirtualAsset(uint256 virtualAssetId) external onlyOwner {
        require(virtualAssetId > 0 && virtualAssetId < nextVirtualAssetId, "Invalid asset ID");
        virtualAssets[virtualAssetId].isActive = false;
    }

    function batchUpdateValuations(
        address[] calldata assetContracts,
        uint256[] calldata assetIds,
        AssetType[] calldata assetTypes
    ) external onlyOracle {
        require(
            assetContracts.length == assetIds.length &&
            assetIds.length == assetTypes.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < assetContracts.length; i++) {
            this.updateAssetValuation(assetContracts[i], assetIds[i], assetTypes[i]);
        }
    }
}
