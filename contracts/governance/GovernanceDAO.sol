// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IGovernanceDAO.sol";
import "./MetaLendToken.sol";

contract GovernanceDAO is 
    IGovernanceDAO,
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    Ownable
{
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => VotingPower) public votingPowers;
    
    uint256 public nextProposalId = 1;
    uint256 public proposalThreshold = 1000000 * 10**18; // 1M tokens
    uint256 public quorumVotes = 10000000 * 10**18; // 10M tokens
    uint256 public votingDelay = 1 days;
    uint256 public votingPeriod = 7 days;
    
    address public metaLend;
    address public collateralManager;
    address public loanPool;
    address public liquidationEngine;
    address public virtualAssetManager;

    constructor(
        address _token,
        address _timelock,
        address _metaLend
    ) 
        Governor("MetaLend DAO")
        GovernorSettings(votingDelay, votingPeriod, proposalThreshold)
        GovernorVotes(IVotes(_token))
        GovernorVotesQuorumFraction(10) // 10% quorum
        GovernorTimelockControl(TimelockController(payable(_timelock)))
    {
        metaLend = _metaLend;
    }

    function setProtocolAddresses(
        address _collateralManager,
        address _loanPool,
        address _liquidationEngine,
        address _virtualAssetManager
    ) external onlyOwner {
        collateralManager = _collateralManager;
        loanPool = _loanPool;
        liquidationEngine = _liquidationEngine;
        virtualAssetManager = _virtualAssetManager;
    }

    function propose(
        ProposalType proposalType,
        string calldata title,
        string calldata description,
        bytes calldata data
    ) external override returns (uint256) {
        require(getVotes(msg.sender, block.number - 1) >= proposalThreshold, "Insufficient voting power");
        
        uint256 proposalId = nextProposalId++;
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            proposalType: proposalType,
            title: title,
            description: description,
            startTime: block.timestamp + votingDelay,
            endTime: block.timestamp + votingDelay + votingPeriod,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            status: ProposalStatus.PENDING,
            calldata: data,
            timestamp: block.timestamp
        });

        emit ProposalCreated(proposalId, msg.sender, proposalType, title);
        return proposalId;
    }

    function castVote(uint256 proposalId, uint8 support) external override {
        _castVote(proposalId, support, "");
    }

    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external override {
        _castVote(proposalId, support, reason);
    }

    function _castVote(
        uint256 proposalId,
        uint8 support,
        string memory reason
    ) internal {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        require(support <= 2, "Invalid vote");

        uint256 weight = getVotes(msg.sender, proposal.startTime);
        require(weight > 0, "No voting power");

        hasVoted[proposalId][msg.sender] = true;

        if (support == 0) {
            proposal.againstVotes += weight;
        } else if (support == 1) {
            proposal.forVotes += weight;
        } else if (support == 2) {
            proposal.abstainVotes += weight;
        }

        emit VoteCast(msg.sender, proposalId, support, weight, reason);
    }

    function execute(uint256 proposalId) external override {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(proposal.status == ProposalStatus.SUCCEEDED, "Proposal not succeeded");
        require(block.timestamp >= proposal.endTime, "Voting not ended");

        proposal.status = ProposalStatus.EXECUTED;

        // Execute proposal based on type
        _executeProposal(proposalId, proposal.proposalType, proposal.calldata);

        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external override {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "Not proposer or owner"
        );
        require(proposal.status == ProposalStatus.PENDING, "Cannot cancel");

        proposal.status = ProposalStatus.CANCELLED;
        emit ProposalCancelled(proposalId);
    }

    function _executeProposal(
        uint256 proposalId,
        ProposalType proposalType,
        bytes calldata data
    ) internal {
        if (proposalType == ProposalType.PARAMETER_CHANGE) {
            _executeParameterChange(data);
        } else if (proposalType == ProposalType.ASSET_SUPPORT) {
            _executeAssetSupport(data);
        } else if (proposalType == ProposalType.LIQUIDATION_PARAMETERS) {
            _executeLiquidationParameters(data);
        } else if (proposalType == ProposalType.PROTOCOL_UPGRADE) {
            _executeProtocolUpgrade(data);
        } else if (proposalType == ProposalType.TREASURY_MANAGEMENT) {
            _executeTreasuryManagement(data);
        } else if (proposalType == ProposalType.EMERGENCY_PAUSE) {
            _executeEmergencyPause(data);
        }
    }

    function _executeParameterChange(bytes calldata data) internal {
        // Decode and execute parameter changes
        // This would contain encoded calls to update protocol parameters
    }

    function _executeAssetSupport(bytes calldata data) internal {
        // Decode and execute asset support changes
        // This would contain encoded calls to add/remove supported assets
    }

    function _executeLiquidationParameters(bytes calldata data) internal {
        // Decode and execute liquidation parameter changes
        // This would contain encoded calls to update liquidation settings
    }

    function _executeProtocolUpgrade(bytes calldata data) internal {
        // Decode and execute protocol upgrades
        // This would contain encoded calls to upgrade contracts
    }

    function _executeTreasuryManagement(bytes calldata data) internal {
        // Decode and execute treasury management
        // This would contain encoded calls to manage protocol treasury
    }

    function _executeEmergencyPause(bytes calldata data) internal {
        // Decode and execute emergency pause
        // This would contain encoded calls to pause protocol
    }

    function getProposal(uint256 proposalId) external view override returns (Proposal memory) {
        return proposals[proposalId];
    }

    function getProposalState(uint256 proposalId) external view override returns (ProposalStatus) {
        Proposal memory proposal = proposals[proposalId];
        if (proposal.id == 0) return ProposalStatus.PENDING;
        
        if (proposal.status == ProposalStatus.CANCELLED) return ProposalStatus.CANCELLED;
        if (block.timestamp < proposal.startTime) return ProposalStatus.PENDING;
        if (block.timestamp <= proposal.endTime) return ProposalStatus.ACTIVE;
        
        if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes) {
            return ProposalStatus.DEFEATED;
        }
        
        if (proposal.status == ProposalStatus.EXECUTED) return ProposalStatus.EXECUTED;
        
        return ProposalStatus.SUCCEEDED;
    }

    function hasVoted(uint256 proposalId, address account) external view override returns (bool) {
        return hasVoted[proposalId][account];
    }

    function getVotingPower(address account) external view override returns (uint256) {
        return getVotes(account, block.number - 1);
    }

    function getProposalThreshold() external view override returns (uint256) {
        return proposalThreshold;
    }

    function getQuorumVotes() external view override returns (uint256) {
        return quorumVotes;
    }

    function getVotingDelay() external view override returns (uint256) {
        return votingDelay;
    }

    function getVotingPeriod() external view override returns (uint256) {
        return votingPeriod;
    }

    function setProposalThreshold(uint256 newThreshold) external onlyOwner {
        proposalThreshold = newThreshold;
    }

    function setQuorumVotes(uint256 newQuorum) external onlyOwner {
        quorumVotes = newQuorum;
    }

    function setVotingDelay(uint256 newDelay) external onlyOwner {
        votingDelay = newDelay;
    }

    function setVotingPeriod(uint256 newPeriod) external onlyOwner {
        votingPeriod = newPeriod;
    }

    function getProposalCount() external view returns (uint256) {
        return nextProposalId - 1;
    }

    function getProposalsByType(ProposalType proposalType) external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](nextProposalId - 1);
        uint256 count = 0;
        
        for (uint256 i = 1; i < nextProposalId; i++) {
            if (proposals[i].proposalType == proposalType) {
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

    // Required overrides
    function votingDelay() public view override(IGovernor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(IGovernor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber) public view override(IGovernor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId) public view override(IGovernor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(IGovernor, Governor) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }
}
