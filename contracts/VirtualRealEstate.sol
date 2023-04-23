// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract VirtualRealEstate is ERC721, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;

    struct PropertyInfo {
        uint256 tokenId;
        string location;
        uint256 size; // in square meters
        uint256 landValue;
        uint256 buildingValue;
        uint256 totalValue;
        PropertyType propertyType;
        bool hasBuilding;
        uint256 rentYield; // annual yield percentage
        uint256 timestamp;
    }

    enum PropertyType {
        RESIDENTIAL,
        COMMERCIAL,
        INDUSTRIAL,
        RECREATIONAL,
        LAND_ONLY
    }

    Counters.Counter private _tokenIdCounter;
    
    mapping(uint256 => PropertyInfo) public properties;
    mapping(string => bool) public locationExists;
    mapping(PropertyType => uint256) public typeMultipliers;
    
    string public baseURI;
    uint256 public constant MAX_SUPPLY = 10000;
    
    event PropertyMinted(
        address indexed to,
        uint256 indexed tokenId,
        string location,
        PropertyType propertyType,
        uint256 totalValue
    );
    
    event PropertyValueUpdated(
        uint256 indexed tokenId,
        uint256 newLandValue,
        uint256 newBuildingValue,
        uint256 newTotalValue
    );
    
    event BuildingConstructed(
        uint256 indexed tokenId,
        uint256 buildingValue,
        uint256 rentYield
    );

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        // Initialize type multipliers
        typeMultipliers[PropertyType.RESIDENTIAL] = 10000; // 1x
        typeMultipliers[PropertyType.COMMERCIAL] = 12000; // 1.2x
        typeMultipliers[PropertyType.INDUSTRIAL] = 8000; // 0.8x
        typeMultipliers[PropertyType.RECREATIONAL] = 15000; // 1.5x
        typeMultipliers[PropertyType.LAND_ONLY] = 5000; // 0.5x
    }

    function mintProperty(
        address to,
        string calldata location,
        uint256 size,
        PropertyType propertyType,
        uint256 landValue
    ) external onlyOwner returns (uint256) {
        require(_tokenIdCounter.current() < MAX_SUPPLY, "Max supply reached");
        require(!locationExists[location], "Location already exists");
        require(landValue > 0, "Invalid land value");
        require(size > 0, "Invalid size");

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        uint256 buildingValue = 0;
        uint256 totalValue = landValue;
        
        // Apply type multiplier
        totalValue = (totalValue * typeMultipliers[propertyType]) / 10000;

        properties[tokenId] = PropertyInfo({
            tokenId: tokenId,
            location: location,
            size: size,
            landValue: landValue,
            buildingValue: buildingValue,
            totalValue: totalValue,
            propertyType: propertyType,
            hasBuilding: false,
            rentYield: 0,
            timestamp: block.timestamp
        });

        locationExists[location] = true;
        _mint(to, tokenId);

        emit PropertyMinted(to, tokenId, location, propertyType, totalValue);
        return tokenId;
    }

    function constructBuilding(
        uint256 tokenId,
        uint256 buildingValue,
        uint256 rentYield
    ) external {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not property owner");
        require(buildingValue > 0, "Invalid building value");
        require(rentYield <= 2000, "Rent yield too high"); // Max 20%

        PropertyInfo storage property = properties[tokenId];
        require(!property.hasBuilding, "Building already exists");

        property.buildingValue = buildingValue;
        property.rentYield = rentYield;
        property.hasBuilding = true;
        property.totalValue = property.landValue + buildingValue;

        emit BuildingConstructed(tokenId, buildingValue, rentYield);
        emit PropertyValueUpdated(tokenId, property.landValue, buildingValue, property.totalValue);
    }

    function updatePropertyValue(
        uint256 tokenId,
        uint256 newLandValue,
        uint256 newBuildingValue
    ) external onlyOwner {
        require(_exists(tokenId), "Token does not exist");

        PropertyInfo storage property = properties[tokenId];
        property.landValue = newLandValue;
        property.buildingValue = newBuildingValue;
        property.totalValue = newLandValue + newBuildingValue;

        emit PropertyValueUpdated(tokenId, newLandValue, newBuildingValue, property.totalValue);
    }

    function getPropertyInfo(uint256 tokenId) external view returns (PropertyInfo memory) {
        require(_exists(tokenId), "Token does not exist");
        return properties[tokenId];
    }

    function getPropertyValue(uint256 tokenId) external view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        return properties[tokenId].totalValue;
    }

    function calculateRentIncome(uint256 tokenId) external view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        PropertyInfo memory property = properties[tokenId];
        
        if (!property.hasBuilding || property.rentYield == 0) {
            return 0;
        }
        
        return (property.buildingValue * property.rentYield) / 10000;
    }

    function getPropertiesByType(PropertyType propertyType) external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](_tokenIdCounter.current());
        uint256 count = 0;
        
        for (uint256 i = 0; i < _tokenIdCounter.current(); i++) {
            if (properties[i].propertyType == propertyType) {
                result[count] = i;
                count++;
            }
        }
        
        // Resize array to actual count
        uint256[] memory finalResult = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            finalResult[i] = result[i];
        }
        
        return finalResult;
    }

    function getTotalSupply() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function setTypeMultiplier(PropertyType propertyType, uint256 multiplier) external onlyOwner {
        require(multiplier > 0 && multiplier <= 20000, "Invalid multiplier");
        typeMultipliers[propertyType] = multiplier;
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");
        
        PropertyInfo memory property = properties[tokenId];
        return string(abi.encodePacked(
            baseURI,
            tokenId.toString(),
            "?location=",
            property.location,
            "&type=",
            uint256(property.propertyType).toString(),
            "&value=",
            property.totalValue.toString()
        ));
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
