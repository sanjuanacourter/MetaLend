// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./interfaces/ICollateralManager.sol";

contract CollateralManager is ICollateralManager, ReentrancyGuard, Ownable {
    uint256 public constant LIQUIDATION_THRESHOLD = 8000; // 80%
    uint256 public constant LIQUIDATION_BONUS = 500; // 5%
    uint256 public constant PRECISION = 10000;

    mapping(uint256 => CollateralInfo) public collaterals;
    mapping(address => mapping(uint256 => uint256)) public collateralIds; // nftContract => tokenId => collateralId
    mapping(address => uint256[]) public userCollaterals;
    
    uint256 public nextCollateralId = 1;
    address public oracle;
    address public liquidationEngine;

    modifier onlyLiquidationEngine() {
        require(msg.sender == liquidationEngine, "Only liquidation engine");
        _;
    }

    constructor(address _oracle) {
        oracle = _oracle;
    }

    function setLiquidationEngine(address _liquidationEngine) external onlyOwner {
        liquidationEngine = _liquidationEngine;
    }

    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
    }

    function depositCollateral(
        address nftContract,
        uint256 tokenId,
        uint256 loanAmount
    ) external override nonReentrant returns (uint256 collateralId) {
        require(nftContract != address(0), "Invalid NFT contract");
        require(loanAmount > 0, "Invalid loan amount");
        
        // Check if NFT is already used as collateral
        require(collateralIds[nftContract][tokenId] == 0, "NFT already used as collateral");

        // Transfer NFT to this contract
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        // Calculate collateral value
        uint256 collateralValue = calculateCollateralValue(nftContract, tokenId);
        require(collateralValue > 0, "Invalid collateral value");

        // Check loan-to-value ratio
        require(
            (loanAmount * PRECISION) / collateralValue <= LIQUIDATION_THRESHOLD,
            "Loan amount exceeds threshold"
        );

        collateralId = nextCollateralId++;
        collaterals[collateralId] = CollateralInfo({
            nftContract: nftContract,
            tokenId: tokenId,
            collateralValue: collateralValue,
            liquidationThreshold: LIQUIDATION_THRESHOLD,
            isActive: true,
            timestamp: block.timestamp
        });

        collateralIds[nftContract][tokenId] = collateralId;
        userCollaterals[msg.sender].push(collateralId);

        emit CollateralDeposited(msg.sender, nftContract, tokenId, collateralValue);
        return collateralId;
    }

    function withdrawCollateral(uint256 collateralId) external override nonReentrant {
        CollateralInfo storage collateral = collaterals[collateralId];
        require(collateral.isActive, "Collateral not active");
        require(collateral.nftContract != address(0), "Collateral does not exist");

        // Check if caller is the owner (this would need to be tracked separately in a real implementation)
        // For now, we'll allow withdrawal if no active loans exist
        require(isCollateralHealthy(collateralId), "Collateral not healthy");

        collateral.isActive = false;
        IERC721(collateral.nftContract).transferFrom(
            address(this),
            msg.sender,
            collateral.tokenId
        );

        emit CollateralWithdrawn(msg.sender, collateral.nftContract, collateral.tokenId);
    }

    function liquidateCollateral(uint256 collateralId) external override onlyLiquidationEngine {
        CollateralInfo storage collateral = collaterals[collateralId];
        require(collateral.isActive, "Collateral not active");

        collateral.isActive = false;

        emit CollateralLiquidated(
            msg.sender,
            collateral.nftContract,
            collateral.tokenId,
            msg.sender
        );
    }

    function getCollateralInfo(uint256 collateralId)
        external
        view
        override
        returns (CollateralInfo memory)
    {
        return collaterals[collateralId];
    }

    function isCollateralHealthy(uint256 collateralId)
        public
        view
        override
        returns (bool)
    {
        CollateralInfo memory collateral = collaterals[collateralId];
        if (!collateral.isActive) return false;

        // In a real implementation, this would check against active loan amounts
        // For now, we'll return true if collateral exists and is active
        return collateral.nftContract != address(0);
    }

    function calculateCollateralValue(address nftContract, uint256 tokenId)
        public
        view
        override
        returns (uint256)
    {
        // In a real implementation, this would query an oracle for NFT floor price
        // For now, we'll return a mock value based on tokenId
        // This should be replaced with actual oracle integration
        return (tokenId % 1000 + 1) * 1e18; // Mock value between 1-1000 ETH
    }

    function getUserCollaterals(address user) external view returns (uint256[] memory) {
        return userCollaterals[user];
    }

    function getCollateralCount() external view returns (uint256) {
        return nextCollateralId - 1;
    }
}
