// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./CollateralManager.sol";
import "./LoanPool.sol";
import "./LiquidationEngine.sol";
import "./oracles/NFTOracle.sol";

contract MetaLend is ReentrancyGuard, Ownable {
    struct ProtocolInfo {
        uint256 totalCollateralValue;
        uint256 totalLoansOutstanding;
        uint256 totalLiquidity;
        uint256 activeCollaterals;
        uint256 activeLoans;
    }

    CollateralManager public collateralManager;
    LoanPool public loanPool;
    LiquidationEngine public liquidationEngine;
    NFTOracle public nftOracle;
    
    mapping(address => bool) public supportedAssets;
    mapping(address => bool) public supportedNFTCollections;
    
    uint256 public protocolFee = 100; // 1%
    uint256 public constant PRECISION = 10000;
    
    event ProtocolInitialized(
        address collateralManager,
        address loanPool,
        address liquidationEngine,
        address nftOracle
    );
    
    event AssetSupported(address indexed asset, bool supported);
    event NFTCollectionSupported(address indexed collection, bool supported);
    event ProtocolFeeUpdated(uint256 newFee);

    constructor(
        address _collateralManager,
        address _loanPool,
        address _liquidationEngine,
        address _nftOracle
    ) {
        collateralManager = CollateralManager(_collateralManager);
        loanPool = LoanPool(_loanPool);
        liquidationEngine = LiquidationEngine(_liquidationEngine);
        nftOracle = NFTOracle(_nftOracle);
        
        emit ProtocolInitialized(
            _collateralManager,
            _loanPool,
            _liquidationEngine,
            _nftOracle
        );
    }

    function initializeProtocol() external onlyOwner {
        // Set up cross-contract references
        collateralManager.setLiquidationEngine(address(liquidationEngine));
        liquidationEngine.updateLiquidationParameters(8000, 500, 1 hours);
    }

    function setSupportedAsset(address asset, bool supported) external onlyOwner {
        supportedAssets[asset] = supported;
        emit AssetSupported(asset, supported);
    }

    function setSupportedNFTCollection(address collection, bool supported) external onlyOwner {
        supportedNFTCollections[collection] = supported;
        nftOracle.setCollectionSupport(collection, supported);
        emit NFTCollectionSupported(collection, supported);
    }

    function setProtocolFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee too high"); // Max 10%
        protocolFee = newFee;
        emit ProtocolFeeUpdated(newFee);
    }

    function depositCollateralAndBorrow(
        address nftContract,
        uint256 tokenId,
        address asset,
        uint256 loanAmount,
        uint256 duration
    ) external nonReentrant returns (uint256 collateralId, uint256 loanId) {
        require(supportedNFTCollections[nftContract], "NFT collection not supported");
        require(supportedAssets[asset], "Asset not supported");
        
        // Deposit collateral
        collateralId = collateralManager.depositCollateral(nftContract, tokenId, loanAmount);
        
        // Create loan
        loanId = loanPool.createLoan(collateralId, loanAmount, duration);
        
        return (collateralId, loanId);
    }

    function repayLoanAndWithdrawCollateral(
        uint256 loanId,
        uint256 repaymentAmount
    ) external nonReentrant {
        // Repay loan
        loanPool.repayLoan(loanId, repaymentAmount);
        
        // Get collateral ID from loan
        ILoanPool.LoanInfo memory loan = loanPool.getLoanInfo(loanId);
        
        // Withdraw collateral if loan is fully repaid
        if (!loan.isActive) {
            collateralManager.withdrawCollateral(loan.collateralId);
        }
    }

    function provideLiquidity(address asset, uint256 amount) external nonReentrant {
        require(supportedAssets[asset], "Asset not supported");
        require(asset == address(loanPool.asset()), "Asset mismatch");
        
        loanPool.provideLiquidity(amount);
    }

    function withdrawLiquidity(uint256 shares) external nonReentrant {
        loanPool.withdrawLiquidity(shares);
    }

    function triggerLiquidation(uint256 collateralId) external {
        liquidationEngine.triggerLiquidation(collateralId);
    }

    function executeLiquidation(uint256 collateralId) external {
        liquidationEngine.executeLiquidation(collateralId);
    }

    function getProtocolInfo() external view returns (ProtocolInfo memory) {
        ILoanPool.PoolInfo memory poolInfo = loanPool.getPoolInfo();
        
        return ProtocolInfo({
            totalCollateralValue: 0, // Would need to be calculated from all collaterals
            totalLoansOutstanding: poolInfo.totalBorrowed,
            totalLiquidity: poolInfo.totalLiquidity,
            activeCollaterals: collateralManager.getCollateralCount(),
            activeLoans: loanPool.getLoanCount()
        });
    }

    function getUserCollaterals(address user) external view returns (uint256[] memory) {
        return collateralManager.getUserCollaterals(user);
    }

    function getUserLoans(address user) external view returns (uint256[] memory) {
        return loanPool.getUserLoans(user);
    }

    function getCollateralInfo(uint256 collateralId) external view returns (ICollateralManager.CollateralInfo memory) {
        return collateralManager.getCollateralInfo(collateralId);
    }

    function getLoanInfo(uint256 loanId) external view returns (ILoanPool.LoanInfo memory) {
        return loanPool.getLoanInfo(loanId);
    }

    function getPoolInfo() external view returns (ILoanPool.PoolInfo memory) {
        return loanPool.getPoolInfo();
    }

    function isCollateralHealthy(uint256 collateralId) external view returns (bool) {
        return collateralManager.isCollateralHealthy(collateralId);
    }

    function isLoanHealthy(uint256 loanId) external view returns (bool) {
        return loanPool.isLoanHealthy(loanId);
    }

    function calculateCollateralValue(address nftContract, uint256 tokenId) external view returns (uint256) {
        return collateralManager.calculateCollateralValue(nftContract, tokenId);
    }

    function calculateLoanInterest(uint256 loanId) external view returns (uint256) {
        return loanPool.calculateInterest(loanId);
    }

    function isLiquidationEligible(uint256 collateralId) external view returns (bool) {
        return liquidationEngine.isLiquidationEligible(collateralId);
    }

    function getLiquidationInfo(uint256 collateralId) external view returns (ILiquidationEngine.LiquidationInfo memory) {
        return liquidationEngine.getLiquidationInfo(collateralId);
    }
}
