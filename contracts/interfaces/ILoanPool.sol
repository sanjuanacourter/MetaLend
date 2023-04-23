// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILoanPool {
    struct LoanInfo {
        address borrower;
        uint256 collateralId;
        uint256 principalAmount;
        uint256 interestRate;
        uint256 startTime;
        uint256 maturityTime;
        bool isActive;
        uint256 totalRepaid;
    }

    struct PoolInfo {
        address asset;
        uint256 totalLiquidity;
        uint256 totalBorrowed;
        uint256 utilizationRate;
        uint256 baseInterestRate;
        uint256 reserveFactor;
    }

    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 collateralId,
        uint256 principalAmount,
        uint256 interestRate
    );

    event LoanRepaid(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 amount
    );

    event LiquidityProvided(
        address indexed provider,
        uint256 amount,
        uint256 shares
    );

    event LiquidityWithdrawn(
        address indexed provider,
        uint256 amount,
        uint256 shares
    );

    function createLoan(
        uint256 collateralId,
        uint256 amount,
        uint256 duration
    ) external returns (uint256 loanId);

    function repayLoan(uint256 loanId, uint256 amount) external;

    function provideLiquidity(uint256 amount) external returns (uint256 shares);

    function withdrawLiquidity(uint256 shares) external;

    function getLoanInfo(uint256 loanId) external view returns (LoanInfo memory);

    function getPoolInfo() external view returns (PoolInfo memory);

    function calculateInterest(uint256 loanId) external view returns (uint256);

    function isLoanHealthy(uint256 loanId) external view returns (bool);
}
