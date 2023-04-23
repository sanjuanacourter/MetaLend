// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./interfaces/ICollateralManager.sol";
import "./interfaces/IVirtualAssetManager.sol";
import "./VirtualAssetManager.sol";

contract EnhancedCollateralManager is ICollateralManager, ReentrancyGuard, Ownable {
    uint256 public constant LIQUIDATION_THRESHOLD = 8000; // 80%
    uint256 public constant LIQUIDATION_BONUS = 500; // 5%
    uint256 public constant PRECISION = 10000;

    struct EnhancedCollateralInfo {
        address assetContract;
        uint256 assetId;
        uint256 collateralValue;
        uint256 liquidationThreshold;
        bool isActive;
        uint256 timestamp;
        IVirtualAssetManager.AssetType assetType;
        uint256 virtualAssetId;
        uint256 rarityScore;
        uint256 utilityScore;
    }

    mapping(uint256 => EnhancedCollateralInfo) public collaterals;
    mapping(address => mapping(uint256 => uint256)) public collateralIds;
    mapping(address => uint256[]) public userCollaterals;
    
    uint256 public nextCollateralId = 1;
    address public oracle;
    address public liquidationEngine;
    VirtualAssetManager public virtualAssetManager;

    modifier onlyLiquidationEngine() {
        require(msg.sender == liquidationEngine, "Only liquidation engine");
        _;
    }

    constructor(address _oracle, address _virtualAssetManager) {
        oracle = _oracle;
        virtualAssetManager = VirtualAssetManager(_virtualAssetManager);
    }

    function setLiquidationEngine(address _liquidationEngine) external onlyOwner {
        liquidationEngine = _liquidationEngine;
    }

    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
    }

    function depositCollateral(
        address assetContract,
        uint256 assetId,
        uint256 loanAmount
    ) external override nonReentrant returns (uint256 collateralId) {
        require(assetContract != address(0), "Invalid asset contract");
        require(loanAmount > 0, "Invalid loan amount");
        
        // Check if asset is already used as collateral
        require(collateralIds[assetContract][assetId] == 0, "Asset already used as collateral");

        // Get virtual asset information
        uint256 virtualAssetId = virtualAssetManager.getVirtualAssetByContract(assetContract, assetId);
        require(virtualAssetId > 0, "Asset not registered in virtual asset manager");

        IVirtualAssetManager.VirtualAssetInfo memory virtualAsset = virtualAssetManager.getVirtualAssetInfo(virtualAssetId);
        require(virtualAsset.isActive, "Virtual asset not active");

        // Transfer asset to this contract
        if (virtualAsset.assetType == IVirtualAssetManager.AssetType.NFT ||
            virtualAsset.assetType == IVirtualAssetManager.AssetType.VIRTUAL_REAL_ESTATE ||
            virtualAsset.assetType == IVirtualAssetManager.AssetType.METAVERSE_LAND) {
            IERC721(assetContract).transferFrom(msg.sender, address(this), assetId);
        } else {
            IERC1155(assetContract).safeTransferFrom(msg.sender, address(this), assetId, 1, "");
        }

        // Calculate collateral value using virtual asset manager
        uint256 collateralValue = calculateCollateralValue(assetContract, assetId);
        require(collateralValue > 0, "Invalid collateral value");

        // Check loan-to-value ratio
        require(
            (loanAmount * PRECISION) / collateralValue <= LIQUIDATION_THRESHOLD,
            "Loan amount exceeds threshold"
        );

        collateralId = nextCollateralId++;
        collaterals[collateralId] = EnhancedCollateralInfo({
            assetContract: assetContract,
            assetId: assetId,
            collateralValue: collateralValue,
            liquidationThreshold: LIQUIDATION_THRESHOLD,
            isActive: true,
            timestamp: block.timestamp,
            assetType: virtualAsset.assetType,
            virtualAssetId: virtualAssetId,
            rarityScore: virtualAsset.rarityScore,
            utilityScore: virtualAsset.utilityScore
        });

        collateralIds[assetContract][assetId] = collateralId;
        userCollaterals[msg.sender].push(collateralId);

        emit CollateralDeposited(msg.sender, assetContract, assetId, collateralValue);
        return collateralId;
    }

    function depositVirtualAssetCollateral(
        address assetContract,
        uint256 assetId,
        IVirtualAssetManager.AssetType assetType,
        string calldata metadata,
        uint256 loanAmount
    ) external nonReentrant returns (uint256 collateralId) {
        require(assetContract != address(0), "Invalid asset contract");
        require(loanAmount > 0, "Invalid loan amount");
        
        // Register virtual asset if not already registered
        uint256 virtualAssetId = virtualAssetManager.getVirtualAssetByContract(assetContract, assetId);
        if (virtualAssetId == 0) {
            virtualAssetId = virtualAssetManager.registerVirtualAsset(assetContract, assetId, assetType, metadata);
        }

        // Deposit as collateral
        return depositCollateral(assetContract, assetId, loanAmount);
    }

    function withdrawCollateral(uint256 collateralId) external override nonReentrant {
        EnhancedCollateralInfo storage collateral = collaterals[collateralId];
        require(collateral.isActive, "Collateral not active");
        require(collateral.assetContract != address(0), "Collateral does not exist");

        // Check if caller is the owner (this would need to be tracked separately in a real implementation)
        require(isCollateralHealthy(collateralId), "Collateral not healthy");

        collateral.isActive = false;

        // Transfer asset back to owner
        if (collateral.assetType == IVirtualAssetManager.AssetType.NFT ||
            collateral.assetType == IVirtualAssetManager.AssetType.VIRTUAL_REAL_ESTATE ||
            collateral.assetType == IVirtualAssetManager.AssetType.METAVERSE_LAND) {
            IERC721(collateral.assetContract).transferFrom(
                address(this),
                msg.sender,
                collateral.assetId
            );
        } else {
            IERC1155(collateral.assetContract).safeTransferFrom(
                address(this),
                msg.sender,
                collateral.assetId,
                1,
                ""
            );
        }

        emit CollateralWithdrawn(msg.sender, collateral.assetContract, collateral.assetId);
    }

    function liquidateCollateral(uint256 collateralId) external override onlyLiquidationEngine {
        EnhancedCollateralInfo storage collateral = collaterals[collateralId];
        require(collateral.isActive, "Collateral not active");

        collateral.isActive = false;

        emit CollateralLiquidated(
            msg.sender,
            collateral.assetContract,
            collateral.assetId,
            msg.sender
        );
    }

    function getCollateralInfo(uint256 collateralId)
        external
        view
        override
        returns (ICollateralManager.CollateralInfo memory)
    {
        EnhancedCollateralInfo memory enhancedCollateral = collaterals[collateralId];
        return ICollateralManager.CollateralInfo({
            nftContract: enhancedCollateral.assetContract,
            tokenId: enhancedCollateral.assetId,
            collateralValue: enhancedCollateral.collateralValue,
            liquidationThreshold: enhancedCollateral.liquidationThreshold,
            isActive: enhancedCollateral.isActive,
            timestamp: enhancedCollateral.timestamp
        });
    }

    function getEnhancedCollateralInfo(uint256 collateralId)
        external
        view
        returns (EnhancedCollateralInfo memory)
    {
        return collaterals[collateralId];
    }

    function isCollateralHealthy(uint256 collateralId)
        public
        view
        override
        returns (bool)
    {
        EnhancedCollateralInfo memory collateral = collaterals[collateralId];
        if (!collateral.isActive) return false;

        // In a real implementation, this would check against active loan amounts
        // For now, we'll return true if collateral exists and is active
        return collateral.assetContract != address(0);
    }

    function calculateCollateralValue(address assetContract, uint256 assetId)
        public
        view
        override
        returns (uint256)
    {
        uint256 virtualAssetId = virtualAssetManager.getVirtualAssetByContract(assetContract, assetId);
        if (virtualAssetId == 0) return 0;

        IVirtualAssetManager.VirtualAssetInfo memory virtualAsset = virtualAssetManager.getVirtualAssetInfo(virtualAssetId);
        return virtualAsset.value;
    }

    function updateCollateralValuation(uint256 collateralId) external {
        EnhancedCollateralInfo storage collateral = collaterals[collateralId];
        require(collateral.isActive, "Collateral not active");

        // Update valuation in virtual asset manager
        virtualAssetManager.updateAssetValuation(
            collateral.assetContract,
            collateral.assetId,
            collateral.assetType
        );

        // Update collateral value
        collateral.collateralValue = calculateCollateralValue(collateral.assetContract, collateral.assetId);
    }

    function getUserCollaterals(address user) external view returns (uint256[] memory) {
        return userCollaterals[user];
    }

    function getCollateralCount() external view returns (uint256) {
        return nextCollateralId - 1;
    }

    function getCollateralsByAssetType(IVirtualAssetManager.AssetType assetType)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory result = new uint256[](nextCollateralId - 1);
        uint256 count = 0;
        
        for (uint256 i = 1; i < nextCollateralId; i++) {
            if (collaterals[i].assetType == assetType && collaterals[i].isActive) {
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

    function batchUpdateValuations(uint256[] calldata collateralIds) external {
        for (uint256 i = 0; i < collateralIds.length; i++) {
            this.updateCollateralValuation(collateralIds[i]);
        }
    }
}
