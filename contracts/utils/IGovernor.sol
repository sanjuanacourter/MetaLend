// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IGovernor {
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 startBlock, uint256 endBlock, string description);
    event ProposalCanceled(uint256 proposalId);
    event ProposalExecuted(uint256 proposalId);
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason);
    event VoteCastWithParams(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason, bytes params);

    function name() external view returns (string memory);
    function version() external view returns (string memory);
    function hashProposal(address[] calldata targets, uint256[] calldata values, bytes[] calldata calldatas, bytes32 descriptionHash) external pure returns (uint256);
    function state(uint256 proposalId) external view returns (ProposalState);
    function proposalSnapshot(uint256 proposalId) external view returns (uint256);
    function proposalDeadline(uint256 proposalId) external view returns (uint256);
    function proposalProposer(uint256 proposalId) external view returns (address);
    function proposalEta(uint256 proposalId) external view returns (uint256);
    function getVotes(address account, uint256 blockNumber) external view returns (uint256);
    function getVotesWithParams(address account, uint256 blockNumber, bytes calldata params) external view returns (uint256);
    function hasVoted(uint256 proposalId, address account) external view returns (bool);
    function quorum(uint256 blockNumber) external view returns (uint256);
    function COUNTING_MODE() external pure returns (string memory);
    function propose(address[] calldata targets, uint256[] calldata values, bytes[] calldata calldatas, string calldata description) external returns (uint256);
    function execute(address[] calldata targets, uint256[] calldata values, bytes[] calldata calldatas, bytes32 descriptionHash) external payable returns (uint256);
    function castVote(uint256 proposalId, uint8 support) external returns (uint256);
    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external returns (uint256);
    function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external returns (uint256);
    function castVoteWithReasonAndParams(uint256 proposalId, uint8 support, string calldata reason, bytes calldata params) external returns (uint256);
    function castVoteBySigWithParams(uint256 proposalId, uint8 support, string calldata reason, bytes calldata params, uint8 v, bytes32 r, bytes32 s) external returns (uint256);
    function cancel(address[] calldata targets, uint256[] calldata values, bytes[] calldata calldatas, bytes32 descriptionHash) external returns (uint256);
}
