// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ILiquidationEngine.sol";
import "./interfaces/ICollateralManager.sol";
import "./interfaces/ILoanPool.sol";

contract LiquidationEngine is ILiquidationEngine, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 public liquidationThreshold = 8000; // 80%
    uint256 public liquidationBonus = 500; // 5%
    uint256 public liquidationDelay = 1 hours;
    uint256 public constant PRECISION = 10000;

    ICollateralManager public collateralManager;
    ILoanPool public loanPool;
    IERC20 public asset;

    mapping(uint256 => LiquidationInfo) public liquidations;
    mapping(uint256 => uint256) public liquidationTimestamps;

    modifier onlyAuthorized() {
        require(
            msg.sender == owner() || 
            msg.sender == address(collateralManager) ||
            msg.sender == address(loanPool),
            "Not authorized"
        );
        _;
    }

    constructor(
        address _collateralManager,
        address _loanPool,
        address _asset
    ) {
        collateralManager = ICollateralManager(_collateralManager);
        loanPool = ILoanPool(_loanPool);
        asset = IERC20(_asset);
    }

    function triggerLiquidation(uint256 collateralId) external override {
        require(isLiquidationEligible(collateralId), "Not eligible for liquidation");
        
        ICollateralManager.CollateralInfo memory collateral = collateralManager.getCollateralInfo(collateralId);
        require(collateral.isActive, "Collateral not active");

        // Calculate debt amount (this would need to be tracked in a real implementation)
        uint256 debtAmount = calculateDebtAmount(collateralId);
        
        liquidations[collateralId] = LiquidationInfo({
            collateralId: collateralId,
            borrower: msg.sender,
            debtAmount: debtAmount,
            collateralValue: collateral.collateralValue,
            liquidationBonus: calculateLiquidationBonus(collateral.collateralValue),
            isLiquidated: false,
            timestamp: block.timestamp
        });

        liquidationTimestamps[collateralId] = block.timestamp;

        emit LiquidationTriggered(collateralId, msg.sender, debtAmount, collateral.collateralValue);
    }

    function executeLiquidation(uint256 collateralId) external override nonReentrant {
        LiquidationInfo storage liquidation = liquidations[collateralId];
        require(!liquidation.isLiquidated, "Already liquidated");
        require(
            block.timestamp >= liquidationTimestamps[collateralId] + liquidationDelay,
            "Liquidation delay not met"
        );

        ICollateralManager.CollateralInfo memory collateral = collateralManager.getCollateralInfo(collateralId);
        require(collateral.isActive, "Collateral not active");

        liquidation.isLiquidated = true;

        // Calculate liquidation amounts
        uint256 liquidationAmount = liquidation.debtAmount + liquidation.liquidationBonus;
        uint256 liquidatorReward = liquidation.liquidationBonus;

        // Transfer liquidation amount from liquidator
        asset.safeTransferFrom(msg.sender, address(this), liquidationAmount);

        // Transfer collateral NFT to liquidator
        collateralManager.liquidateCollateral(collateralId);

        // Transfer liquidator reward
        asset.safeTransfer(msg.sender, liquidatorReward);

        emit LiquidationCompleted(collateralId, msg.sender, liquidationAmount, liquidatorReward);
    }

    function isLiquidationEligible(uint256 collateralId) public view override returns (bool) {
        ICollateralManager.CollateralInfo memory collateral = collateralManager.getCollateralInfo(collateralId);
        
        if (!collateral.isActive) return false;

        // Check if collateral value has dropped below threshold
        uint256 currentValue = collateralManager.calculateCollateralValue(
            collateral.nftContract,
            collateral.tokenId
        );
        
        uint256 debtAmount = calculateDebtAmount(collateralId);
        uint256 thresholdValue = (debtAmount * PRECISION) / liquidationThreshold;

        return currentValue < thresholdValue;
    }

    function calculateLiquidationBonus(uint256 collateralValue) public view override returns (uint256) {
        return (collateralValue * liquidationBonus) / PRECISION;
    }

    function getLiquidationInfo(uint256 collateralId) external view override returns (LiquidationInfo memory) {
        return liquidations[collateralId];
    }

    function updateLiquidationParameters(
        uint256 _liquidationThreshold,
        uint256 _liquidationBonus,
        uint256 _liquidationDelay
    ) external override onlyOwner {
        require(_liquidationThreshold > 0 && _liquidationThreshold <= PRECISION, "Invalid threshold");
        require(_liquidationBonus > 0 && _liquidationBonus <= 2000, "Invalid bonus"); // Max 20%
        require(_liquidationDelay <= 24 hours, "Delay too long");

        liquidationThreshold = _liquidationThreshold;
        liquidationBonus = _liquidationBonus;
        liquidationDelay = _liquidationDelay;

        emit LiquidationParametersUpdated(_liquidationThreshold, _liquidationBonus, _liquidationDelay);
    }

    function calculateDebtAmount(uint256 collateralId) internal view returns (uint256) {
        // In a real implementation, this would query the loan pool for active loans
        // For now, we'll return a mock value
        ICollateralManager.CollateralInfo memory collateral = collateralManager.getCollateralInfo(collateralId);
        return (collateral.collateralValue * 7000) / PRECISION; // Assume 70% LTV
    }

    function getLiquidationDelay(uint256 collateralId) external view returns (uint256) {
        if (liquidationTimestamps[collateralId] == 0) return 0;
        
        uint256 elapsed = block.timestamp - liquidationTimestamps[collateralId];
        return elapsed >= liquidationDelay ? 0 : liquidationDelay - elapsed;
    }

    function isLiquidationPending(uint256 collateralId) external view returns (bool) {
        return liquidationTimestamps[collateralId] > 0 && !liquidations[collateralId].isLiquidated;
    }
}
