// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IGovernor.sol";

interface IGovernorCompatibilityBravo is IGovernor {
    function propose(address[] calldata targets, uint256[] calldata values, string[] calldata signatures, bytes[] calldata calldatas, string calldata description) external returns (uint256);
    function queue(uint256 proposalId) external;
    function execute(uint256 proposalId) external payable;
    function cancel(uint256 proposalId) external;
    function getVotes(address account, uint256 blockNumber) external view returns (uint256);
    function getVotesWithParams(address account, uint256 blockNumber, bytes calldata params) external view returns (uint256);
    function castVote(uint256 proposalId, uint8 support) external returns (uint256);
    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external returns (uint256);
    function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external returns (uint256);
}
