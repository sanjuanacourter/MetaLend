// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Governor.sol";
import "./TimelockController.sol";

abstract contract GovernorTimelockControl is Governor {
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

    function queue(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) public virtual returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);

        require(state(proposalId) == ProposalState.Succeeded, "Governor: proposal not successful");

        uint256 delay = _timelock.getMinDelay();
        _timelockIds[proposalId] = _timelock.hashOperationBatch(targets, values, calldatas, 0, descriptionHash);
        _timelock.scheduleBatch(targets, values, calldatas, 0, descriptionHash, delay);

        emit ProposalQueued(proposalId, block.timestamp + delay);

        return proposalId;
    }

    function execute(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) public payable virtual override returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);

        require(state(proposalId) == ProposalState.Queued, "Governor: proposal not queued");

        _timelock.executeBatch{value: msg.value}(targets, values, calldatas, 0, descriptionHash);

        emit ProposalExecuted(proposalId);

        return proposalId;
    }

    function cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) public virtual override returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);

        require(state(proposalId) != ProposalState.Executed, "Governor: proposal already executed");

        _timelock.cancel(_timelockIds[proposalId]);

        emit ProposalCanceled(proposalId);

        return proposalId;
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

    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params) internal virtual override returns (uint256) {
        return super._castVote(proposalId, account, support, reason, params);
    }

    function _castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) internal virtual override returns (uint256) {
        return super._castVoteBySig(proposalId, support, v, r, s);
    }
}
