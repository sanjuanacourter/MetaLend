/**
 * MetaLend SDK for JavaScript/TypeScript
 * Provides easy integration with MetaLend protocol
 */

import { ethers } from 'ethers';

class MetaLendSDK {
  constructor(provider, network = 'mainnet') {
    this.provider = provider;
    this.network = network;
    this.contracts = {};
    this.initialized = false;
  }

  /**
   * Initialize the SDK with contract addresses
   */
  async initialize(contractAddresses) {
    try {
      // Load contract ABIs
      const abis = await this.loadContractABIs();
      
      // Initialize contracts
      this.contracts.metaLend = new ethers.Contract(
        contractAddresses.metaLend,
        abis.metaLend,
        this.provider
      );
      
      this.contracts.collateralManager = new ethers.Contract(
        contractAddresses.collateralManager,
        abis.collateralManager,
        this.provider
      );
      
      this.contracts.loanPool = new ethers.Contract(
        contractAddresses.loanPool,
        abis.loanPool,
        this.provider
      );
      
      this.contracts.virtualAssetManager = new ethers.Contract(
        contractAddresses.virtualAssetManager,
        abis.virtualAssetManager,
        this.provider
      );
      
      this.contracts.governanceDAO = new ethers.Contract(
        contractAddresses.governanceDAO,
        abis.governanceDAO,
        this.provider
      );
      
      this.initialized = true;
      return true;
    } catch (error) {
      console.error('Failed to initialize MetaLend SDK:', error);
      throw error;
    }
  }

  /**
   * Load contract ABIs from local files
   */
  async loadContractABIs() {
    // In a real implementation, these would be loaded from JSON files
    return {
      metaLend: require('./abis/MetaLend.json'),
      collateralManager: require('./abis/CollateralManager.json'),
      loanPool: require('./abis/LoanPool.json'),
      virtualAssetManager: require('./abis/VirtualAssetManager.json'),
      governanceDAO: require('./abis/GovernanceDAO.json')
    };
  }

  /**
   * Deposit collateral and borrow in one transaction
   */
  async depositCollateralAndBorrow(
    nftContract,
    tokenId,
    asset,
    loanAmount,
    duration,
    signer
  ) {
    this.ensureInitialized();
    
    try {
      const tx = await this.contracts.metaLend
        .connect(signer)
        .depositCollateralAndBorrow(
          nftContract,
          tokenId,
          asset,
          loanAmount,
          duration
        );
      
      const receipt = await tx.wait();
      return this.parseTransactionReceipt(receipt);
    } catch (error) {
      throw new Error(`Failed to deposit collateral and borrow: ${error.message}`);
    }
  }

  /**
   * Repay loan and withdraw collateral
   */
  async repayLoanAndWithdrawCollateral(loanId, repaymentAmount, signer) {
    this.ensureInitialized();
    
    try {
      const tx = await this.contracts.metaLend
        .connect(signer)
        .repayLoanAndWithdrawCollateral(loanId, repaymentAmount);
      
      const receipt = await tx.wait();
      return this.parseTransactionReceipt(receipt);
    } catch (error) {
      throw new Error(`Failed to repay loan and withdraw collateral: ${error.message}`);
    }
  }

  /**
   * Provide liquidity to the protocol
   */
  async provideLiquidity(asset, amount, signer) {
    this.ensureInitialized();
    
    try {
      const tx = await this.contracts.metaLend
        .connect(signer)
        .provideLiquidity(asset, amount);
      
      const receipt = await tx.wait();
      return this.parseTransactionReceipt(receipt);
    } catch (error) {
      throw new Error(`Failed to provide liquidity: ${error.message}`);
    }
  }

  /**
   * Withdraw liquidity from the protocol
   */
  async withdrawLiquidity(shares, signer) {
    this.ensureInitialized();
    
    try {
      const tx = await this.contracts.metaLend
        .connect(signer)
        .withdrawLiquidity(shares);
      
      const receipt = await tx.wait();
      return this.parseTransactionReceipt(receipt);
    } catch (error) {
      throw new Error(`Failed to withdraw liquidity: ${error.message}`);
    }
  }

  /**
   * Register a virtual asset
   */
  async registerVirtualAsset(
    assetContract,
    assetId,
    assetType,
    metadata,
    signer
  ) {
    this.ensureInitialized();
    
    try {
      const tx = await this.contracts.virtualAssetManager
        .connect(signer)
        .registerVirtualAsset(assetContract, assetId, assetType, metadata);
      
      const receipt = await tx.wait();
      return this.parseTransactionReceipt(receipt);
    } catch (error) {
      throw new Error(`Failed to register virtual asset: ${error.message}`);
    }
  }

  /**
   * Create a governance proposal
   */
  async createProposal(
    proposalType,
    title,
    description,
    data,
    signer
  ) {
    this.ensureInitialized();
    
    try {
      const tx = await this.contracts.governanceDAO
        .connect(signer)
        .propose(proposalType, title, description, data);
      
      const receipt = await tx.wait();
      return this.parseTransactionReceipt(receipt);
    } catch (error) {
      throw new Error(`Failed to create proposal: ${error.message}`);
    }
  }

  /**
   * Vote on a governance proposal
   */
  async voteOnProposal(proposalId, support, reason = '', signer) {
    this.ensureInitialized();
    
    try {
      let tx;
      if (reason) {
        tx = await this.contracts.governanceDAO
          .connect(signer)
          .castVoteWithReason(proposalId, support, reason);
      } else {
        tx = await this.contracts.governanceDAO
          .connect(signer)
          .castVote(proposalId, support);
      }
      
      const receipt = await tx.wait();
      return this.parseTransactionReceipt(receipt);
    } catch (error) {
      throw new Error(`Failed to vote on proposal: ${error.message}`);
    }
  }

  /**
   * Get protocol information
   */
  async getProtocolInfo() {
    this.ensureInitialized();
    
    try {
      const protocolInfo = await this.contracts.metaLend.getProtocolInfo();
      return {
        totalCollateralValue: protocolInfo.totalCollateralValue.toString(),
        totalLoansOutstanding: protocolInfo.totalLoansOutstanding.toString(),
        totalLiquidity: protocolInfo.totalLiquidity.toString(),
        activeCollaterals: protocolInfo.activeCollaterals.toString(),
        activeLoans: protocolInfo.activeLoans.toString()
      };
    } catch (error) {
      throw new Error(`Failed to get protocol info: ${error.message}`);
    }
  }

  /**
   * Get user's collateral positions
   */
  async getUserCollaterals(userAddress) {
    this.ensureInitialized();
    
    try {
      const collateralIds = await this.contracts.metaLend.getUserCollaterals(userAddress);
      const collaterals = [];
      
      for (const collateralId of collateralIds) {
        const collateralInfo = await this.contracts.metaLend.getCollateralInfo(collateralId);
        collaterals.push({
          id: collateralId.toString(),
          nftContract: collateralInfo.nftContract,
          tokenId: collateralInfo.tokenId.toString(),
          collateralValue: collateralInfo.collateralValue.toString(),
          liquidationThreshold: collateralInfo.liquidationThreshold.toString(),
          isActive: collateralInfo.isActive,
          timestamp: collateralInfo.timestamp.toString()
        });
      }
      
      return collaterals;
    } catch (error) {
      throw new Error(`Failed to get user collaterals: ${error.message}`);
    }
  }

  /**
   * Get user's loan positions
   */
  async getUserLoans(userAddress) {
    this.ensureInitialized();
    
    try {
      const loanIds = await this.contracts.metaLend.getUserLoans(userAddress);
      const loans = [];
      
      for (const loanId of loanIds) {
        const loanInfo = await this.contracts.metaLend.getLoanInfo(loanId);
        loans.push({
          id: loanId.toString(),
          borrower: loanInfo.borrower,
          collateralId: loanInfo.collateralId.toString(),
          principalAmount: loanInfo.principalAmount.toString(),
          interestRate: loanInfo.interestRate.toString(),
          startTime: loanInfo.startTime.toString(),
          maturityTime: loanInfo.maturityTime.toString(),
          isActive: loanInfo.isActive,
          totalRepaid: loanInfo.totalRepaid.toString()
        });
      }
      
      return loans;
    } catch (error) {
      throw new Error(`Failed to get user loans: ${error.message}`);
    }
  }

  /**
   * Get pool information
   */
  async getPoolInfo() {
    this.ensureInitialized();
    
    try {
      const poolInfo = await this.contracts.metaLend.getPoolInfo();
      return {
        asset: poolInfo.asset,
        totalLiquidity: poolInfo.totalLiquidity.toString(),
        totalBorrowed: poolInfo.totalBorrowed.toString(),
        utilizationRate: poolInfo.utilizationRate.toString(),
        baseInterestRate: poolInfo.baseInterestRate.toString(),
        reserveFactor: poolInfo.reserveFactor.toString()
      };
    } catch (error) {
      throw new Error(`Failed to get pool info: ${error.message}`);
    }
  }

  /**
   * Calculate loan interest
   */
  async calculateLoanInterest(loanId) {
    this.ensureInitialized();
    
    try {
      const interest = await this.contracts.metaLend.calculateLoanInterest(loanId);
      return interest.toString();
    } catch (error) {
      throw new Error(`Failed to calculate loan interest: ${error.message}`);
    }
  }

  /**
   * Check if collateral is healthy
   */
  async isCollateralHealthy(collateralId) {
    this.ensureInitialized();
    
    try {
      return await this.contracts.metaLend.isCollateralHealthy(collateralId);
    } catch (error) {
      throw new Error(`Failed to check collateral health: ${error.message}`);
    }
  }

  /**
   * Check if loan is healthy
   */
  async isLoanHealthy(loanId) {
    this.ensureInitialized();
    
    try {
      return await this.contracts.metaLend.isLoanHealthy(loanId);
    } catch (error) {
      throw new Error(`Failed to check loan health: ${error.message}`);
    }
  }

  /**
   * Get governance proposal
   */
  async getProposal(proposalId) {
    this.ensureInitialized();
    
    try {
      const proposal = await this.contracts.governanceDAO.getProposal(proposalId);
      return {
        id: proposal.id.toString(),
        proposer: proposal.proposer,
        proposalType: proposal.proposalType.toString(),
        title: proposal.title,
        description: proposal.description,
        startTime: proposal.startTime.toString(),
        endTime: proposal.endTime.toString(),
        forVotes: proposal.forVotes.toString(),
        againstVotes: proposal.againstVotes.toString(),
        abstainVotes: proposal.abstainVotes.toString(),
        status: proposal.status.toString(),
        timestamp: proposal.timestamp.toString()
      };
    } catch (error) {
      throw new Error(`Failed to get proposal: ${error.message}`);
    }
  }

  /**
   * Get user's voting power
   */
  async getVotingPower(userAddress) {
    this.ensureInitialized();
    
    try {
      const votingPower = await this.contracts.governanceDAO.getVotingPower(userAddress);
      return votingPower.toString();
    } catch (error) {
      throw new Error(`Failed to get voting power: ${error.message}`);
    }
  }

  /**
   * Parse transaction receipt for events
   */
  parseTransactionReceipt(receipt) {
    const events = [];
    
    for (const log of receipt.logs) {
      try {
        const event = this.contracts.metaLend.interface.parseLog(log);
        events.push({
          name: event.name,
          args: event.args
        });
      } catch (e) {
        // Try other contracts
        for (const contractName in this.contracts) {
          try {
            const event = this.contracts[contractName].interface.parseLog(log);
            events.push({
              name: event.name,
              args: event.args,
              contract: contractName
            });
            break;
          } catch (e2) {
            // Continue to next contract
          }
        }
      }
    }
    
    return {
      transactionHash: receipt.transactionHash,
      blockNumber: receipt.blockNumber,
      gasUsed: receipt.gasUsed.toString(),
      events: events
    };
  }

  /**
   * Ensure SDK is initialized
   */
  ensureInitialized() {
    if (!this.initialized) {
      throw new Error('MetaLend SDK not initialized. Call initialize() first.');
    }
  }

  /**
   * Get contract instance
   */
  getContract(contractName) {
    this.ensureInitialized();
    return this.contracts[contractName];
  }

  /**
   * Get all contract instances
   */
  getContracts() {
    this.ensureInitialized();
    return this.contracts;
  }
}

export default MetaLendSDK;
