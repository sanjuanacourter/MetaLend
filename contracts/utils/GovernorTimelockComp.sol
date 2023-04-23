// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Governor.sol";
import "./TimelockController.sol";

abstract contract GovernorTimelockComp is Governor {
    TimelockController private _timelock;
    mapping(uint256 => bytes32) private _timelockIds;

    event TimelockChange(address oldTimelock, address newTimelock);
    event ProposalQueued(uint256 proposalId, uint256 eta);

    constructor(TimelockController timelockAddress) {
        _updateTimelock(timelockAddress);
    }

    function timelock() public view virtual returns (address) {
        return address(_timelock);
    }

    function proposalEta(uint256 proposalId) public view virtual override returns (uint256) {
        uint256 eta = _timelock.getTimestamp(_timelockIds[proposalId]);
        return eta == 0 ? 0 : eta;
    }

    function queue(uint256 proposalId) public virtual override {
        require(state(proposalId) == ProposalState.Succeeded, "Governor: proposal not successful");

        uint256 delay = _timelock.getMinDelay();
        _timelockIds[proposalId] = _timelock.hashOperationBatch(_proposalDetails[proposalId].targets, _proposalDetails[proposalId].values, _proposalDetails[proposalId].calldatas, 0, keccak256(bytes(_proposalDetails[proposalId].description)));
        _timelock.scheduleBatch(_proposalDetails[proposalId].targets, _proposalDetails[proposalId].values, _proposalDetails[proposalId].calldatas, 0, keccak256(bytes(_proposalDetails[proposalId].description)), delay);

        emit ProposalQueued(proposalId, block.timestamp + delay);
    }

    function execute(uint256 proposalId) public payable virtual override {
        require(state(proposalId) == ProposalState.Queued, "Governor: proposal not queued");

        _timelock.executeBatch{value: msg.value}(_proposalDetails[proposalId].targets, _proposalDetails[proposalId].values, _proposalDetails[proposalId].calldatas, 0, keccak256(bytes(_proposalDetails[proposalId].description)));

        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) public virtual override {
        require(state(proposalId) != ProposalState.Executed, "Governor: proposal already executed");

        _timelock.cancel(_timelockIds[proposalId]);

        emit ProposalCanceled(proposalId);
    }

    function _updateTimelock(TimelockController newTimelock) private {
        emit TimelockChange(address(_timelock), address(newTimelock));
        _timelock = newTimelock;
    }

    function _execute(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) internal virtual override {
        _timelock.executeBatch{value: msg.value}(targets, values, calldatas, 0, descriptionHash);
    }

    function _cancel(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) internal virtual override returns (uint256) {
        _timelock.cancel(_timelockIds[proposalId]);
        return proposalId;
    }

    mapping(uint256 => ProposalDetails) private _proposalDetails;

    struct ProposalDetails {
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        string description;
    }
}
