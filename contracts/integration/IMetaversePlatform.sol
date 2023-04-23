// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IMetaversePlatform {
    struct PlatformInfo {
        string name;
        string version;
        address platformContract;
        bool isActive;
        uint256 integrationFee;
        uint256 totalAssets;
        uint256 totalUsers;
        uint256 timestamp;
    }

    struct AssetIntegration {
        address assetContract;
        uint256 assetId;
        string platformAssetId;
        bool isIntegrated;
        uint256 platformValue;
        uint256 lastSync;
    }

    struct UserProfile {
        address user;
        string platformUserId;
        uint256 totalAssets;
        uint256 totalValue;
        bool isVerified;
        uint256 lastActivity;
    }

    event PlatformRegistered(
        address indexed platformContract,
        string name,
        string version,
        uint256 integrationFee
    );

    event AssetIntegrated(
        address indexed assetContract,
        uint256 indexed assetId,
        string platformAssetId,
        uint256 platformValue
    );

    event AssetSyncUpdated(
        address indexed assetContract,
        uint256 indexed assetId,
        uint256 newValue,
        uint256 timestamp
    );

    event UserProfileCreated(
        address indexed user,
        string platformUserId,
        bool isVerified
    );

    event PlatformDeactivated(address indexed platformContract);

    function registerPlatform(
        string calldata name,
        string calldata version,
        address platformContract,
        uint256 integrationFee
    ) external returns (uint256 platformId);

    function integrateAsset(
        address assetContract,
        uint256 assetId,
        string calldata platformAssetId,
        uint256 platformValue
    ) external returns (bool);

    function updateAssetSync(
        address assetContract,
        uint256 assetId,
        uint256 newValue
    ) external;

    function createUserProfile(
        address user,
        string calldata platformUserId,
        bool isVerified
    ) external;

    function deactivatePlatform(address platformContract) external;

    function getPlatformInfo(address platformContract) external view returns (PlatformInfo memory);

    function getAssetIntegration(address assetContract, uint256 assetId)
        external
        view
        returns (AssetIntegration memory);

    function getUserProfile(address user) external view returns (UserProfile memory);

    function isPlatformActive(address platformContract) external view returns (bool);

    function isAssetIntegrated(address assetContract, uint256 assetId) external view returns (bool);

    function getPlatformAssets(address platformContract) external view returns (uint256);

    function getPlatformUsers(address platformContract) external view returns (uint256);

    function calculatePlatformValue(address platformContract) external view returns (uint256);
}
