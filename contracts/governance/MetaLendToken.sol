// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract MetaLendToken is ERC20, ERC20Votes, Ownable, Pausable {
    uint256 public constant INITIAL_SUPPLY = 1000000000 * 10**18; // 1 billion tokens
    uint256 public constant MAX_SUPPLY = 2000000000 * 10**18; // 2 billion tokens max
    
    mapping(address => bool) public minters;
    mapping(address => uint256) public stakingRewards;
    mapping(address => uint256) public stakingTimestamp;
    
    uint256 public stakingRewardRate = 1000; // 10% annual
    uint256 public constant PRECISION = 10000;
    
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event StakingRewardsClaimed(address indexed user, uint256 amount);
    event StakingRewardRateUpdated(uint256 newRate);

    modifier onlyMinter() {
        require(minters[msg.sender], "Only minter");
        _;
    }

    constructor() ERC20("MetaLend Token", "MLT") ERC20Permit("MetaLend Token") {
        _mint(msg.sender, INITIAL_SUPPLY);
        minters[msg.sender] = true;
    }

    function addMinter(address minter) external onlyOwner {
        require(minter != address(0), "Invalid minter");
        minters[minter] = true;
        emit MinterAdded(minter);
    }

    function removeMinter(address minter) external onlyOwner {
        minters[minter] = false;
        emit MinterRemoved(minter);
    }

    function mint(address to, uint256 amount) external onlyMinter {
        require(totalSupply() + amount <= MAX_SUPPLY, "Max supply exceeded");
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function stake(uint256 amount) external whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        // Claim existing rewards first
        if (stakingTimestamp[msg.sender] > 0) {
            claimStakingRewards();
        }

        _transfer(msg.sender, address(this), amount);
        stakingRewards[msg.sender] += amount;
        stakingTimestamp[msg.sender] = block.timestamp;
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        require(stakingRewards[msg.sender] >= amount, "Insufficient staked amount");

        // Claim rewards first
        claimStakingRewards();

        stakingRewards[msg.sender] -= amount;
        _transfer(address(this), msg.sender, amount);
    }

    function claimStakingRewards() public {
        require(stakingTimestamp[msg.sender] > 0, "No staking position");
        
        uint256 stakedAmount = stakingRewards[msg.sender];
        uint256 timeStaked = block.timestamp - stakingTimestamp[msg.sender];
        uint256 rewardAmount = (stakedAmount * stakingRewardRate * timeStaked) / (365 days * PRECISION);
        
        if (rewardAmount > 0) {
            stakingTimestamp[msg.sender] = block.timestamp;
            _mint(msg.sender, rewardAmount);
            emit StakingRewardsClaimed(msg.sender, rewardAmount);
        }
    }

    function setStakingRewardRate(uint256 newRate) external onlyOwner {
        require(newRate <= 5000, "Rate too high"); // Max 50%
        stakingRewardRate = newRate;
        emit StakingRewardRateUpdated(newRate);
    }

    function getStakingRewards(address user) external view returns (uint256) {
        if (stakingTimestamp[user] == 0) return 0;
        
        uint256 stakedAmount = stakingRewards[user];
        uint256 timeStaked = block.timestamp - stakingTimestamp[user];
        return (stakedAmount * stakingRewardRate * timeStaked) / (365 days * PRECISION);
    }

    function getStakedAmount(address user) external view returns (uint256) {
        return stakingRewards[user];
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}
