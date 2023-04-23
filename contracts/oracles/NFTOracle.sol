// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract NFTOracle is Ownable {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        bool isValid;
    }

    mapping(address => mapping(uint256 => PriceData)) public nftPrices;
    mapping(address => bool) public supportedCollections;
    mapping(address => uint256) public floorPrices;
    
    uint256 public constant PRICE_VALIDITY_DURATION = 1 hours;
    uint256 public constant MAX_PRICE_DEVIATION = 2000; // 20%
    
    AggregatorV3Interface public ethPriceFeed;
    
    event PriceUpdated(address indexed nftContract, uint256 indexed tokenId, uint256 price);
    event FloorPriceUpdated(address indexed nftContract, uint256 floorPrice);
    event CollectionSupported(address indexed nftContract, bool supported);

    constructor(address _ethPriceFeed) {
        ethPriceFeed = AggregatorV3Interface(_ethPriceFeed);
    }

    function updateNFTPrice(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external onlyOwner {
        require(supportedCollections[nftContract], "Collection not supported");
        require(price > 0, "Invalid price");

        PriceData storage priceData = nftPrices[nftContract][tokenId];
        uint256 previousPrice = priceData.price;

        // Check price deviation if updating existing price
        if (previousPrice > 0) {
            uint256 deviation = price > previousPrice 
                ? ((price - previousPrice) * 10000) / previousPrice
                : ((previousPrice - price) * 10000) / previousPrice;
            
            require(deviation <= MAX_PRICE_DEVIATION, "Price deviation too high");
        }

        priceData.price = price;
        priceData.timestamp = block.timestamp;
        priceData.isValid = true;

        emit PriceUpdated(nftContract, tokenId, price);
    }

    function updateFloorPrice(address nftContract, uint256 floorPrice) external onlyOwner {
        require(supportedCollections[nftContract], "Collection not supported");
        require(floorPrice > 0, "Invalid floor price");

        floorPrices[nftContract] = floorPrice;
        emit FloorPriceUpdated(nftContract, floorPrice);
    }

    function setCollectionSupport(address nftContract, bool supported) external onlyOwner {
        supportedCollections[nftContract] = supported;
        emit CollectionSupported(nftContract, supported);
    }

    function getNFTPrice(address nftContract, uint256 tokenId) external view returns (uint256) {
        PriceData memory priceData = nftPrices[nftContract][tokenId];
        
        if (priceData.isValid && 
            block.timestamp <= priceData.timestamp + PRICE_VALIDITY_DURATION) {
            return priceData.price;
        }

        // Fallback to floor price
        return floorPrices[nftContract];
    }

    function getNFTPriceInUSD(address nftContract, uint256 tokenId) external view returns (uint256) {
        uint256 priceInETH = this.getNFTPrice(nftContract, tokenId);
        (, int256 ethPrice, , , ) = ethPriceFeed.latestRoundData();
        
        return (priceInETH * uint256(ethPrice)) / 1e8; // ETH price has 8 decimals
    }

    function isPriceValid(address nftContract, uint256 tokenId) external view returns (bool) {
        PriceData memory priceData = nftPrices[nftContract][tokenId];
        return priceData.isValid && 
               block.timestamp <= priceData.timestamp + PRICE_VALIDITY_DURATION;
    }

    function batchUpdatePrices(
        address[] calldata nftContracts,
        uint256[] calldata tokenIds,
        uint256[] calldata prices
    ) external onlyOwner {
        require(
            nftContracts.length == tokenIds.length && 
            tokenIds.length == prices.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < nftContracts.length; i++) {
            this.updateNFTPrice(nftContracts[i], tokenIds[i], prices[i]);
        }
    }

    function getCollectionFloorPrice(address nftContract) external view returns (uint256) {
        return floorPrices[nftContract];
    }

    function isCollectionSupported(address nftContract) external view returns (bool) {
        return supportedCollections[nftContract];
    }
}
