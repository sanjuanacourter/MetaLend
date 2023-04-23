// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IVirtualAssetManager {
    enum AssetType {
        NFT,
        VIRTUAL_REAL_ESTATE,
        GAMING_ASSET,
        METAVERSE_LAND,
        VIRTUAL_CURRENCY
    }

    struct VirtualAssetInfo {
        AssetType assetType;
        address assetContract;
        uint256 assetId;
        uint256 value;
        uint256 rarityScore;
        uint256 utilityScore;
        bool isActive;
        uint256 timestamp;
        string metadata;
    }

    struct AssetValuation {
        uint256 baseValue;
        uint256 rarityMultiplier;
        uint256 utilityMultiplier;
        uint256 marketMultiplier;
        uint256 finalValue;
        uint256 confidence;
    }

    event VirtualAssetRegistered(
        address indexed assetContract,
        uint256 indexed assetId,
        AssetType assetType,
        uint256 value
    );

    event AssetValuationUpdated(
        address indexed assetContract,
        uint256 indexed assetId,
        uint256 newValue,
        uint256 confidence
    );

    event AssetTypeSupported(AssetType assetType, bool supported);

    function registerVirtualAsset(
        address assetContract,
        uint256 assetId,
        AssetType assetType,
        string calldata metadata
    ) external returns (uint256 virtualAssetId);

    function updateAssetValuation(
        address assetContract,
        uint256 assetId,
        AssetType assetType
    ) external;

    function getAssetValuation(address assetContract, uint256 assetId)
        external
        view
        returns (AssetValuation memory);

    function getVirtualAssetInfo(uint256 virtualAssetId)
        external
        view
        returns (VirtualAssetInfo memory);

    function setAssetTypeSupport(AssetType assetType, bool supported) external;

    function isAssetTypeSupported(AssetType assetType) external view returns (bool);

    function calculateRarityScore(address assetContract, uint256 assetId)
        external
        view
        returns (uint256);

    function calculateUtilityScore(address assetContract, uint256 assetId)
        external
        view
        returns (uint256);

    function getMarketMultiplier(AssetType assetType) external view returns (uint256);
}
