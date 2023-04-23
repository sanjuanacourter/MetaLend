// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ILoanPool.sol";
import "./interfaces/ICollateralManager.sol";

contract LoanPool is ILoanPool, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_UTILIZATION = 9500; // 95%
    uint256 public constant RESERVE_FACTOR = 1000; // 10%
    uint256 public constant PRECISION = 10000;

    IERC20 public immutable asset;
    ICollateralManager public collateralManager;
    
    mapping(uint256 => LoanInfo) public loans;
    mapping(address => uint256[]) public userLoans;
    mapping(address => uint256) public liquidityShares;
    
    uint256 public nextLoanId = 1;
    uint256 public totalLiquidity;
    uint256 public totalBorrowed;
    uint256 public totalReserves;
    uint256 public totalShares;

    modifier onlyCollateralManager() {
        require(msg.sender == address(collateralManager), "Only collateral manager");
        _;
    }

    constructor(address _asset, address _collateralManager) {
        asset = IERC20(_asset);
        collateralManager = ICollateralManager(_collateralManager);
    }

    function createLoan(
        uint256 collateralId,
        uint256 amount,
        uint256 duration
    ) external override nonReentrant returns (uint256 loanId) {
        require(amount > 0, "Invalid loan amount");
        require(duration > 0, "Invalid duration");
        
        // Check if collateral exists and is healthy
        ICollateralManager.CollateralInfo memory collateral = collateralManager.getCollateralInfo(collateralId);
        require(collateral.isActive, "Collateral not active");
        
        // Check if there's enough liquidity
        require(amount <= getAvailableLiquidity(), "Insufficient liquidity");
        
        // Calculate interest rate based on utilization
        uint256 interestRate = calculateInterestRate();
        
        loanId = nextLoanId++;
        loans[loanId] = LoanInfo({
            borrower: msg.sender,
            collateralId: collateralId,
            principalAmount: amount,
            interestRate: interestRate,
            startTime: block.timestamp,
            maturityTime: block.timestamp + duration,
            isActive: true,
            totalRepaid: 0
        });

        userLoans[msg.sender].push(loanId);
        totalBorrowed += amount;

        // Transfer loan amount to borrower
        asset.safeTransfer(msg.sender, amount);

        emit LoanCreated(loanId, msg.sender, collateralId, amount, interestRate);
        return loanId;
    }

    function repayLoan(uint256 loanId, uint256 amount) external override nonReentrant {
        LoanInfo storage loan = loans[loanId];
        require(loan.isActive, "Loan not active");
        require(msg.sender == loan.borrower, "Not loan borrower");
        require(amount > 0, "Invalid repayment amount");

        uint256 totalDebt = calculateTotalDebt(loanId);
        uint256 repaymentAmount = amount > totalDebt ? totalDebt : amount;

        loan.totalRepaid += repaymentAmount;
        totalBorrowed -= repaymentAmount;

        // Transfer repayment from borrower
        asset.safeTransferFrom(msg.sender, address(this), repaymentAmount);

        // Add to reserves
        uint256 reserveAmount = (repaymentAmount * RESERVE_FACTOR) / PRECISION;
        totalReserves += reserveAmount;

        // Check if loan is fully repaid
        if (loan.totalRepaid >= totalDebt) {
            loan.isActive = false;
            // Notify collateral manager to release collateral
        }

        emit LoanRepaid(loanId, msg.sender, repaymentAmount);
    }

    function provideLiquidity(uint256 amount) external override nonReentrant returns (uint256 shares) {
        require(amount > 0, "Invalid amount");
        
        // Calculate shares based on current total value
        if (totalShares == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalLiquidity;
        }

        liquidityShares[msg.sender] += shares;
        totalShares += shares;
        totalLiquidity += amount;

        // Transfer liquidity from provider
        asset.safeTransferFrom(msg.sender, address(this), amount);

        emit LiquidityProvided(msg.sender, amount, shares);
        return shares;
    }

    function withdrawLiquidity(uint256 shares) external override nonReentrant {
        require(shares > 0, "Invalid shares");
        require(shares <= liquidityShares[msg.sender], "Insufficient shares");

        uint256 amount = (shares * totalLiquidity) / totalShares;
        require(amount <= getAvailableLiquidity(), "Insufficient liquidity");

        liquidityShares[msg.sender] -= shares;
        totalShares -= shares;
        totalLiquidity -= amount;

        // Transfer liquidity to provider
        asset.safeTransfer(msg.sender, amount);

        emit LiquidityWithdrawn(msg.sender, amount, shares);
    }

    function getLoanInfo(uint256 loanId) external view override returns (LoanInfo memory) {
        return loans[loanId];
    }

    function getPoolInfo() external view override returns (PoolInfo memory) {
        return PoolInfo({
            asset: address(asset),
            totalLiquidity: totalLiquidity,
            totalBorrowed: totalBorrowed,
            utilizationRate: totalLiquidity > 0 ? (totalBorrowed * PRECISION) / totalLiquidity : 0,
            baseInterestRate: calculateInterestRate(),
            reserveFactor: RESERVE_FACTOR
        });
    }

    function calculateInterest(uint256 loanId) public view override returns (uint256) {
        LoanInfo memory loan = loans[loanId];
        if (!loan.isActive) return 0;

        uint256 timeElapsed = block.timestamp - loan.startTime;
        return (loan.principalAmount * loan.interestRate * timeElapsed) / (365 days * PRECISION);
    }

    function calculateTotalDebt(uint256 loanId) public view returns (uint256) {
        LoanInfo memory loan = loans[loanId];
        if (!loan.isActive) return 0;

        uint256 interest = calculateInterest(loanId);
        return loan.principalAmount + interest;
    }

    function isLoanHealthy(uint256 loanId) public view override returns (bool) {
        LoanInfo memory loan = loans[loanId];
        if (!loan.isActive) return true;

        // Check if loan is past maturity
        if (block.timestamp > loan.maturityTime) return false;

        // Check if collateral is still healthy
        return collateralManager.isCollateralHealthy(loan.collateralId);
    }

    function calculateInterestRate() public view returns (uint256) {
        if (totalLiquidity == 0) return 500; // 5% base rate

        uint256 utilization = (totalBorrowed * PRECISION) / totalLiquidity;
        
        // Base rate + utilization-based rate
        uint256 baseRate = 500; // 5%
        uint256 utilizationRate = (utilization * 2000) / PRECISION; // Up to 20%
        
        return baseRate + utilizationRate;
    }

    function getAvailableLiquidity() public view returns (uint256) {
        return totalLiquidity - totalBorrowed;
    }

    function getUserLoans(address user) external view returns (uint256[] memory) {
        return userLoans[user];
    }

    function getLoanCount() external view returns (uint256) {
        return nextLoanId - 1;
    }
}
