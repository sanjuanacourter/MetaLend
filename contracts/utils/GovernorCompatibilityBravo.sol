// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Governor.sol";
import "./IGovernorCompatibilityBravo.sol";

abstract contract GovernorCompatibilityBravo is Governor, IGovernorCompatibilityBravo {
    mapping(uint256 => ProposalDetails) private _proposalDetails;

    function getVotes(address account, uint256 blockNumber) public view virtual override(IGovernor, IGovernorCompatibilityBravo) returns (uint256) {
        return super.getVotes(account, blockNumber);
    }

    function getVotesWithParams(address account, uint256 blockNumber, bytes memory params) public view virtual override(IGovernor, IGovernorCompatibilityBravo) returns (uint256) {
        return super.getVotesWithParams(account, blockNumber, params);
    }

    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) public virtual override(IGovernor, IGovernorCompatibilityBravo) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function propose(address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas, string memory description) public virtual override returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function queue(uint256 proposalId) public virtual override {
        require(state(proposalId) == ProposalState.Succeeded, "Governor: proposal not successful");
        _queue(proposalId);
    }

    function execute(uint256 proposalId) public payable virtual override {
        require(state(proposalId) == ProposalState.Queued, "Governor: proposal not queued");
        _execute(proposalId);
    }

    function cancel(uint256 proposalId) public virtual override {
        require(state(proposalId) != ProposalState.Executed, "Governor: proposal already executed");
        _cancel(proposalId);
    }

    function castVote(uint256 proposalId, uint8 support) public virtual override(IGovernor, IGovernorCompatibilityBravo) returns (uint256) {
        return super.castVote(proposalId, support);
    }

    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) public virtual override(IGovernor, IGovernorCompatibilityBravo) returns (uint256) {
        return super.castVoteWithReason(proposalId, support, reason);
    }

    function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) public virtual override(IGovernor, IGovernorCompatibilityBravo) returns (uint256) {
        return super.castVoteBySig(proposalId, support, v, r, s);
    }

    function _queue(uint256 proposalId) internal virtual {
        address[] memory targets = _proposalDetails[proposalId].targets;
        uint256[] memory values = _proposalDetails[proposalId].values;
        bytes[] memory calldatas = _proposalDetails[proposalId].calldatas;
        bytes32 descriptionHash = keccak256(bytes(_proposalDetails[proposalId].description));

        _queue(targets, values, calldatas, descriptionHash);
    }

    function _execute(uint256 proposalId) internal virtual {
        address[] memory targets = _proposalDetails[proposalId].targets;
        uint256[] memory values = _proposalDetails[proposalId].values;
        bytes[] memory calldatas = _proposalDetails[proposalId].calldatas;
        bytes32 descriptionHash = keccak256(bytes(_proposalDetails[proposalId].description));

        _execute(targets, values, calldatas, descriptionHash);
    }

    function _cancel(uint256 proposalId) internal virtual {
        address[] memory targets = _proposalDetails[proposalId].targets;
        uint256[] memory values = _proposalDetails[proposalId].values;
        bytes[] memory calldatas = _proposalDetails[proposalId].calldatas;
        bytes32 descriptionHash = keccak256(bytes(_proposalDetails[proposalId].description));

        _cancel(targets, values, calldatas, descriptionHash);
    }

    function _storeProposalDetails(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) internal virtual returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        
        _proposalDetails[proposalId] = ProposalDetails({
            targets: targets,
            values: values,
            signatures: new string[](targets.length),
            calldatas: calldatas,
            description: description
        });

        return proposalId;
    }

    struct ProposalDetails {
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        string description;
    }
}
