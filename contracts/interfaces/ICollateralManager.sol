// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICollateralManager {
    struct CollateralInfo {
        address nftContract;
        uint256 tokenId;
        uint256 collateralValue;
        uint256 liquidationThreshold;
        bool isActive;
        uint256 timestamp;
    }

    event CollateralDeposited(
        address indexed borrower,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 collateralValue
    );

    event CollateralWithdrawn(
        address indexed borrower,
        address indexed nftContract,
        uint256 indexed tokenId
    );

    event CollateralLiquidated(
        address indexed borrower,
        address indexed nftContract,
        uint256 indexed tokenId,
        address liquidator
    );

    function depositCollateral(
        address nftContract,
        uint256 tokenId,
        uint256 loanAmount
    ) external returns (uint256 collateralId);

    function withdrawCollateral(uint256 collateralId) external;

    function liquidateCollateral(uint256 collateralId) external;

    function getCollateralInfo(uint256 collateralId)
        external
        view
        returns (CollateralInfo memory);

    function isCollateralHealthy(uint256 collateralId)
        external
        view
        returns (bool);

    function calculateCollateralValue(address nftContract, uint256 tokenId)
        external
        view
        returns (uint256);
}
