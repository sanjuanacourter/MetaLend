// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IGovernanceDAO {
    enum ProposalType {
        PARAMETER_CHANGE,
        ASSET_SUPPORT,
        COLLATERAL_MANAGER_UPDATE,
        LIQUIDATION_PARAMETERS,
        PROTOCOL_UPGRADE,
        TREASURY_MANAGEMENT,
        EMERGENCY_PAUSE
    }

    enum ProposalStatus {
        PENDING,
        ACTIVE,
        CANCELLED,
        DEFEATED,
        SUCCEEDED,
        EXECUTED
    }

    struct Proposal {
        uint256 id;
        address proposer;
        ProposalType proposalType;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        ProposalStatus status;
        bytes calldata;
        uint256 timestamp;
    }

    struct VotingPower {
        uint256 balance;
        uint256 delegated;
        uint256 received;
        address delegate;
    }

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalType proposalType,
        string title
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 weight,
        string reason
    );

    event ProposalExecuted(uint256 indexed proposalId);

    event ProposalCancelled(uint256 indexed proposalId);

    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    event DelegateVotesChanged(
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );

    function propose(
        ProposalType proposalType,
        string calldata title,
        string calldata description,
        bytes calldata data
    ) external returns (uint256);

    function castVote(uint256 proposalId, uint8 support) external;

    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external;

    function execute(uint256 proposalId) external;

    function cancel(uint256 proposalId) external;

    function delegate(address delegatee) external;

    function getVotingPower(address account) external view returns (uint256);

    function getProposal(uint256 proposalId) external view returns (Proposal memory);

    function getProposalState(uint256 proposalId) external view returns (ProposalStatus);

    function hasVoted(uint256 proposalId, address account) external view returns (bool);

    function getVotes(address account, uint256 blockNumber) external view returns (uint256);

    function getProposalThreshold() external view returns (uint256);

    function getQuorumVotes() external view returns (uint256);

    function getVotingDelay() external view returns (uint256);

    function getVotingPeriod() external view returns (uint256);
}
