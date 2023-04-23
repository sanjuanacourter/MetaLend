// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILiquidationEngine {
    struct LiquidationInfo {
        uint256 collateralId;
        address borrower;
        uint256 debtAmount;
        uint256 collateralValue;
        uint256 liquidationBonus;
        bool isLiquidated;
        uint256 timestamp;
    }

    event LiquidationTriggered(
        uint256 indexed collateralId,
        address indexed borrower,
        uint256 debtAmount,
        uint256 collateralValue
    );

    event LiquidationCompleted(
        uint256 indexed collateralId,
        address indexed liquidator,
        uint256 liquidatedAmount,
        uint256 bonusAmount
    );

    event LiquidationParametersUpdated(
        uint256 newLiquidationThreshold,
        uint256 newLiquidationBonus,
        uint256 newLiquidationDelay
    );

    function triggerLiquidation(uint256 collateralId) external;

    function executeLiquidation(uint256 collateralId) external;

    function isLiquidationEligible(uint256 collateralId)
        external
        view
        returns (bool);

    function calculateLiquidationBonus(uint256 collateralValue)
        external
        view
        returns (uint256);

    function getLiquidationInfo(uint256 collateralId)
        external
        view
        returns (LiquidationInfo memory);

    function updateLiquidationParameters(
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        uint256 liquidationDelay
    ) external;
}
