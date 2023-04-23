const { ethers, upgrades } = require("hardhat");

async function main() {
  console.log("Starting MetaLend deployment...");

  // Get the contract factories
  const NFTOracle = await ethers.getContractFactory("NFTOracle");
  const CollateralManager = await ethers.getContractFactory("CollateralManager");
  const LoanPool = await ethers.getContractFactory("LoanPool");
  const LiquidationEngine = await ethers.getContractFactory("LiquidationEngine");
  const MetaLend = await ethers.getContractFactory("MetaLend");

  // Deploy NFTOracle first
  console.log("Deploying NFTOracle...");
  const ethPriceFeed = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419"; // ETH/USD on Ethereum mainnet
  const nftOracle = await NFTOracle.deploy(ethPriceFeed);
  await nftOracle.deployed();
  console.log("NFTOracle deployed to:", nftOracle.address);

  // Deploy CollateralManager
  console.log("Deploying CollateralManager...");
  const collateralManager = await CollateralManager.deploy(nftOracle.address);
  await collateralManager.deployed();
  console.log("CollateralManager deployed to:", collateralManager.address);

  // Deploy LoanPool (using USDC as the lending asset)
  console.log("Deploying LoanPool...");
  const usdcAddress = "0xA0b86a33E6441b8c4C8C0C4C0C4C0C4C0C4C0C4C"; // Mock USDC address
  const loanPool = await LoanPool.deploy(usdcAddress, collateralManager.address);
  await loanPool.deployed();
  console.log("LoanPool deployed to:", loanPool.address);

  // Deploy LiquidationEngine
  console.log("Deploying LiquidationEngine...");
  const liquidationEngine = await LiquidationEngine.deploy(
    collateralManager.address,
    loanPool.address,
    usdcAddress
  );
  await liquidationEngine.deployed();
  console.log("LiquidationEngine deployed to:", liquidationEngine.address);

  // Deploy main MetaLend contract
  console.log("Deploying MetaLend...");
  const metaLend = await MetaLend.deploy(
    collateralManager.address,
    loanPool.address,
    liquidationEngine.address,
    nftOracle.address
  );
  await metaLend.deployed();
  console.log("MetaLend deployed to:", metaLend.address);

  // Initialize the protocol
  console.log("Initializing protocol...");
  await metaLend.initializeProtocol();

  // Set up some initial supported collections (example)
  const baycAddress = "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"; // BAYC
  const cryptopunksAddress = "0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB"; // CryptoPunks
  
  console.log("Setting up supported NFT collections...");
  await metaLend.setSupportedNFTCollection(baycAddress, true);
  await metaLend.setSupportedNFTCollection(cryptopunksAddress, true);
  
  console.log("Setting up supported assets...");
  await metaLend.setSupportedAsset(usdcAddress, true);

  // Update oracle with initial floor prices
  console.log("Setting initial floor prices...");
  await nftOracle.updateFloorPrice(baycAddress, ethers.utils.parseEther("50")); // 50 ETH floor
  await nftOracle.updateFloorPrice(cryptopunksAddress, ethers.utils.parseEther("100")); // 100 ETH floor

  console.log("\n=== Deployment Summary ===");
  console.log("NFTOracle:", nftOracle.address);
  console.log("CollateralManager:", collateralManager.address);
  console.log("LoanPool:", loanPool.address);
  console.log("LiquidationEngine:", liquidationEngine.address);
  console.log("MetaLend:", metaLend.address);
  console.log("\nProtocol initialization completed successfully!");

  // Save deployment addresses to a file
  const deploymentInfo = {
    network: await ethers.provider.getNetwork(),
    timestamp: new Date().toISOString(),
    contracts: {
      NFTOracle: nftOracle.address,
      CollateralManager: collateralManager.address,
      LoanPool: loanPool.address,
      LiquidationEngine: liquidationEngine.address,
      MetaLend: metaLend.address
    },
    supportedAssets: [usdcAddress],
    supportedCollections: [baycAddress, cryptopunksAddress]
  };

  const fs = require('fs');
  fs.writeFileSync(
    'deployments.json',
    JSON.stringify(deploymentInfo, null, 2)
  );
  
  console.log("Deployment info saved to deployments.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
