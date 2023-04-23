// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IMetaversePlatform.sol";

contract MetaversePlatformManager is IMetaversePlatform, ReentrancyGuard, Ownable {
    mapping(address => PlatformInfo) public platforms;
    mapping(address => mapping(uint256 => AssetIntegration)) public assetIntegrations;
    mapping(address => UserProfile) public userProfiles;
    mapping(address => uint256) public platformAssetCounts;
    mapping(address => uint256) public platformUserCounts;
    
    address[] public registeredPlatforms;
    uint256 public nextPlatformId = 1;
    
    uint256 public constant MAX_INTEGRATION_FEE = 1000; // 10%
    uint256 public constant PRECISION = 10000;

    modifier onlyRegisteredPlatform(address platformContract) {
        require(platforms[platformContract].isActive, "Platform not registered");
        _;
    }

    modifier onlyPlatformOwner(address platformContract) {
        require(msg.sender == platforms[platformContract].platformContract, "Not platform owner");
        _;
    }

    function registerPlatform(
        string calldata name,
        string calldata version,
        address platformContract,
        uint256 integrationFee
    ) external override onlyOwner nonReentrant returns (uint256 platformId) {
        require(platformContract != address(0), "Invalid platform contract");
        require(integrationFee <= MAX_INTEGRATION_FEE, "Integration fee too high");
        require(!platforms[platformContract].isActive, "Platform already registered");

        platformId = nextPlatformId++;
        platforms[platformContract] = PlatformInfo({
            name: name,
            version: version,
            platformContract: platformContract,
            isActive: true,
            integrationFee: integrationFee,
            totalAssets: 0,
            totalUsers: 0,
            timestamp: block.timestamp
        });

        registeredPlatforms.push(platformContract);

        emit PlatformRegistered(platformContract, name, version, integrationFee);
        return platformId;
    }

    function integrateAsset(
        address assetContract,
        uint256 assetId,
        string calldata platformAssetId,
        uint256 platformValue
    ) external override onlyRegisteredPlatform(msg.sender) nonReentrant returns (bool) {
        require(assetContract != address(0), "Invalid asset contract");
        require(platformValue > 0, "Invalid platform value");
        require(!assetIntegrations[assetContract][assetId].isIntegrated, "Asset already integrated");

        assetIntegrations[assetContract][assetId] = AssetIntegration({
            assetContract: assetContract,
            assetId: assetId,
            platformAssetId: platformAssetId,
            isIntegrated: true,
            platformValue: platformValue,
            lastSync: block.timestamp
        });

        platformAssetCounts[msg.sender]++;
        platforms[msg.sender].totalAssets++;

        emit AssetIntegrated(assetContract, assetId, platformAssetId, platformValue);
        return true;
    }

    function updateAssetSync(
        address assetContract,
        uint256 assetId,
        uint256 newValue
    ) external override onlyRegisteredPlatform(msg.sender) nonReentrant {
        require(assetIntegrations[assetContract][assetId].isIntegrated, "Asset not integrated");
        require(newValue > 0, "Invalid value");

        AssetIntegration storage integration = assetIntegrations[assetContract][assetId];
        integration.platformValue = newValue;
        integration.lastSync = block.timestamp;

        emit AssetSyncUpdated(assetContract, assetId, newValue, block.timestamp);
    }

    function createUserProfile(
        address user,
        string calldata platformUserId,
        bool isVerified
    ) external override onlyRegisteredPlatform(msg.sender) nonReentrant {
        require(user != address(0), "Invalid user address");
        require(bytes(platformUserId).length > 0, "Invalid platform user ID");

        userProfiles[user] = UserProfile({
            user: user,
            platformUserId: platformUserId,
            totalAssets: 0,
            totalValue: 0,
            isVerified: isVerified,
            lastActivity: block.timestamp
        });

        platformUserCounts[msg.sender]++;
        platforms[msg.sender].totalUsers++;

        emit UserProfileCreated(user, platformUserId, isVerified);
    }

    function updateUserProfile(
        address user,
        uint256 totalAssets,
        uint256 totalValue
    ) external onlyRegisteredPlatform(msg.sender) {
        require(userProfiles[user].user != address(0), "User profile not found");

        UserProfile storage profile = userProfiles[user];
        profile.totalAssets = totalAssets;
        profile.totalValue = totalValue;
        profile.lastActivity = block.timestamp;
    }

    function deactivatePlatform(address platformContract) external override onlyOwner {
        require(platforms[platformContract].isActive, "Platform not active");

        platforms[platformContract].isActive = false;
        emit PlatformDeactivated(platformContract);
    }

    function getPlatformInfo(address platformContract) external view override returns (PlatformInfo memory) {
        return platforms[platformContract];
    }

    function getAssetIntegration(address assetContract, uint256 assetId)
        external
        view
        override
        returns (AssetIntegration memory)
    {
        return assetIntegrations[assetContract][assetId];
    }

    function getUserProfile(address user) external view override returns (UserProfile memory) {
        return userProfiles[user];
    }

    function isPlatformActive(address platformContract) external view override returns (bool) {
        return platforms[platformContract].isActive;
    }

    function isAssetIntegrated(address assetContract, uint256 assetId) external view override returns (bool) {
        return assetIntegrations[assetContract][assetId].isIntegrated;
    }

    function getPlatformAssets(address platformContract) external view override returns (uint256) {
        return platformAssetCounts[platformContract];
    }

    function getPlatformUsers(address platformContract) external view override returns (uint256) {
        return platformUserCounts[platformContract];
    }

    function calculatePlatformValue(address platformContract) external view override returns (uint256) {
        uint256 totalValue = 0;
        
        // This would iterate through all integrated assets and sum their values
        // For now, return a mock calculation
        uint256 assetCount = platformAssetCounts[platformContract];
        return assetCount * 1e18; // Mock value calculation
    }

    function getRegisteredPlatforms() external view returns (address[] memory) {
        return registeredPlatforms;
    }

    function getPlatformCount() external view returns (uint256) {
        return registeredPlatforms.length;
    }

    function getPlatformById(uint256 platformId) external view returns (address) {
        require(platformId > 0 && platformId < nextPlatformId, "Invalid platform ID");
        return registeredPlatforms[platformId - 1];
    }

    function batchIntegrateAssets(
        address[] calldata assetContracts,
        uint256[] calldata assetIds,
        string[] calldata platformAssetIds,
        uint256[] calldata platformValues
    ) external onlyRegisteredPlatform(msg.sender) {
        require(
            assetContracts.length == assetIds.length &&
            assetIds.length == platformAssetIds.length &&
            platformAssetIds.length == platformValues.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < assetContracts.length; i++) {
            this.integrateAsset(assetContracts[i], assetIds[i], platformAssetIds[i], platformValues[i]);
        }
    }

    function getIntegrationStats() external view returns (
        uint256 totalPlatforms,
        uint256 totalAssets,
        uint256 totalUsers,
        uint256 activePlatforms
    ) {
        totalPlatforms = registeredPlatforms.length;
        activePlatforms = 0;
        totalAssets = 0;
        totalUsers = 0;

        for (uint256 i = 0; i < registeredPlatforms.length; i++) {
            address platform = registeredPlatforms[i];
            if (platforms[platform].isActive) {
                activePlatforms++;
                totalAssets += platformAssetCounts[platform];
                totalUsers += platformUserCounts[platform];
            }
        }
    }

    function setMaxIntegrationFee(uint256 newMaxFee) external onlyOwner {
        require(newMaxFee <= 2000, "Max fee too high"); // Max 20%
        // This would update the constant, but constants can't be changed
        // In a real implementation, this would be a state variable
    }
}
