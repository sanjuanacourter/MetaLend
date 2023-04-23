# MetaLend Protocol

A decentralized lending protocol for metaverse and virtual assets, enabling users to use NFTs, virtual real estate, and gaming assets as collateral for cryptocurrency loans.

## 🌟 Features

### Core Functionality
- **NFT Collateralization**: Use ERC-721 and ERC-1155 tokens as collateral
- **Virtual Asset Support**: Support for virtual real estate, gaming assets, and metaverse land
- **Dynamic Pricing**: Oracle-based asset valuation with rarity and utility scoring
- **Liquidation Engine**: Automated liquidation system with Dutch auction mechanism
- **Multi-Asset Pools**: Support for multiple lending assets (ETH, USDC, DAI)

### Advanced Features
- **DAO Governance**: Decentralized governance with MLT token
- **Virtual Asset Manager**: Comprehensive virtual asset registration and management
- **Metaverse Integration**: Platform integration for cross-metaverse asset support
- **Staking Rewards**: Token staking with rewards for governance participation

## 🏗️ Architecture

### Core Contracts

#### MetaLend.sol
Main protocol contract that integrates all components and provides the primary interface for users.

#### CollateralManager.sol
Manages NFT collateral deposits, withdrawals, and health monitoring.

#### LoanPool.sol
Handles loan creation, repayment, and liquidity provision with dynamic interest rates.

#### LiquidationEngine.sol
Implements liquidation logic with configurable thresholds and bonus mechanisms.

#### VirtualAssetManager.sol
Manages virtual asset registration, valuation, and rarity/utility scoring.

#### GovernanceDAO.sol
Decentralized governance system with proposal creation, voting, and execution.

### Supporting Contracts

#### NFTOracle.sol
Price oracle for NFT valuations with floor price tracking and deviation controls.

#### VirtualRealEstate.sol
ERC-721 contract for virtual property management with building construction.

#### GamingAssets.sol
ERC-1155 contract for gaming asset management with upgrade and trading systems.

#### MetaLendToken.sol
Governance token with staking rewards and voting power delegation.

## 🚀 Getting Started

### Prerequisites
- Node.js 16+
- Hardhat
- Ethers.js

### Installation

```bash
# Clone the repository
git clone https://github.com/sanjuanacourter/MetaLend.git
cd MetaLend

# Install dependencies
npm install

# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Deploy to local network
npx hardhat run scripts/deploy.js --network localhost
```

### Environment Setup

Create a `.env` file with the following variables:

```env
PRIVATE_KEY=your_private_key
ETHEREUM_RPC_URL=your_ethereum_rpc_url
ARBITRUM_RPC_URL=your_arbitrum_rpc_url
OPTIMISM_RPC_URL=your_optimism_rpc_url
ETHERSCAN_API_KEY=your_etherscan_api_key
ARBISCAN_API_KEY=your_arbiscan_api_key
OPTIMISTIC_ETHERSCAN_API_KEY=your_optimistic_etherscan_api_key
```

## 📖 Usage

### Basic Lending Flow

```javascript
import MetaLendSDK from './sdk/MetaLendSDK.js';
import { ethers } from 'ethers';

// Initialize SDK
const provider = new ethers.providers.JsonRpcProvider('YOUR_RPC_URL');
const sdk = new MetaLendSDK(provider);

// Initialize with contract addresses
await sdk.initialize({
  metaLend: '0x...',
  collateralManager: '0x...',
  loanPool: '0x...',
  virtualAssetManager: '0x...',
  governanceDAO: '0x...'
});

// Deposit collateral and borrow
const result = await sdk.depositCollateralAndBorrow(
  '0x...', // NFT contract address
  1, // token ID
  '0x...', // lending asset address
  ethers.utils.parseEther('1'), // loan amount
  30 * 24 * 60 * 60, // duration (30 days)
  signer
);

console.log('Transaction result:', result);
```

### Virtual Asset Registration

```javascript
// Register a virtual asset
await sdk.registerVirtualAsset(
  '0x...', // asset contract
  1, // asset ID
  1, // asset type (VIRTUAL_REAL_ESTATE)
  '{"location": "Metaverse City", "size": 100}', // metadata
  signer
);
```

### Governance Participation

```javascript
// Create a proposal
await sdk.createProposal(
  0, // PARAMETER_CHANGE
  'Update Liquidation Threshold',
  'Proposal to update liquidation threshold to 75%',
  '0x...', // encoded call data
  signer
);

// Vote on a proposal
await sdk.voteOnProposal(
  1, // proposal ID
  1, // support (1 = for, 0 = against, 2 = abstain)
  'I support this proposal', // reason
  signer
);
```

## 🧪 Testing

The protocol includes comprehensive test suites for all major components:

```bash
# Run all tests
npm test

# Run specific test files
npx hardhat test test/CollateralManager.test.js
npx hardhat test test/LoanPool.test.js
npx hardhat test test/LiquidationEngine.test.js
npx hardhat test test/VirtualAssetManager.test.js
npx hardhat test test/GovernanceDAO.test.js
npx hardhat test test/MetaLend.integration.test.js
```

## 🔧 Development

### Contract Deployment

```bash
# Deploy to Ethereum mainnet
npx hardhat run scripts/deploy.js --network ethereum

# Deploy to Arbitrum
npx hardhat run scripts/deploy.js --network arbitrum

# Deploy to Optimism
npx hardhat run scripts/deploy.js --network optimism
```

### Gas Optimization

The contracts are optimized for gas efficiency with:
- Packed structs
- Efficient storage patterns
- Minimal external calls
- Optimized loops

### Security Considerations

- All contracts use OpenZeppelin's battle-tested libraries
- Reentrancy guards on all external functions
- Access control with role-based permissions
- Comprehensive input validation
- Emergency pause functionality

## 📊 Protocol Parameters

### Collateral Management
- **Liquidation Threshold**: 80% (configurable via governance)
- **Liquidation Bonus**: 5% (configurable via governance)
- **Liquidation Delay**: 1 hour (configurable via governance)

### Lending Parameters
- **Max Utilization**: 95%
- **Reserve Factor**: 10%
- **Base Interest Rate**: 5% (dynamic based on utilization)

### Governance Parameters
- **Proposal Threshold**: 1M MLT tokens
- **Quorum**: 10M MLT tokens (10% of total supply)
- **Voting Delay**: 1 day
- **Voting Period**: 7 days

## 🌐 Network Support

### Mainnet
- Ethereum Mainnet
- Arbitrum One
- Optimism

### Testnet
- Goerli
- Arbitrum Goerli
- Optimism Goerli

## 📈 Roadmap

### Phase 1: MVP (Completed)
- ✅ Core NFT lending functionality
- ✅ Basic liquidation system
- ✅ Oracle integration

### Phase 2: Virtual Assets (Completed)
- ✅ Virtual real estate support
- ✅ Gaming asset integration
- ✅ Enhanced collateral manager

### Phase 3: Governance (Completed)
- ✅ DAO implementation
- ✅ Governance token
- ✅ Proposal and voting system

### Phase 4: Ecosystem Integration (Completed)
- ✅ Metaverse platform integration
- ✅ SDK development
- ✅ Cross-platform asset support

### Future Enhancements
- 🔄 Multi-chain expansion
- 🔄 Advanced DeFi integrations
- 🔄 Mobile SDK
- 🔄 Analytics dashboard

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **Website**: [https://metalend.finance](https://metalend.finance)
- **Documentation**: [https://docs.metalend.finance](https://docs.metalend.finance)
- **Discord**: [https://discord.gg/metalend](https://discord.gg/metalend)
- **Twitter**: [@MetaLendFinance](https://twitter.com/MetaLendFinance)

## ⚠️ Disclaimer

This software is provided "as is" without warranty of any kind. Users should conduct their own research and due diligence before using this protocol. The protocol involves financial risks, and users should only invest what they can afford to lose.

## 📞 Support

For support and questions:
- Create an issue on GitHub
- Join our Discord community
- Contact us at support@metalend.finance

---

**Built with ❤️ by the MetaLend Team**
