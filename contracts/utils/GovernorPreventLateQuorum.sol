// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Governor.sol";

abstract contract GovernorPreventLateQuorum is Governor {
    uint256 private _quorumExtension;
    uint256 private _quorumDeadline;

    event QuorumExtensionSet(uint256 oldQuorumExtension, uint256 newQuorumExtension);

    constructor(uint256 quorumExtensionValue) {
        _updateQuorumExtension(quorumExtensionValue);
    }

    function quorumExtension() public view virtual returns (uint256) {
        return _quorumExtension;
    }

    function quorumDeadline() public view virtual returns (uint256) {
        return _quorumDeadline;
    }

    function updateQuorumExtension(uint256 newQuorumExtension) external virtual onlyGovernance {
        _updateQuorumExtension(newQuorumExtension);
    }

    function _updateQuorumExtension(uint256 newQuorumExtension) internal virtual {
        emit QuorumExtensionSet(_quorumExtension, newQuorumExtension);
        _quorumExtension = newQuorumExtension;
    }

    function _castVote(uint256 proposalId, address account, uint8 support, string memory reason, bytes memory params) internal virtual override returns (uint256) {
        uint256 weight = super._castVote(proposalId, account, support, reason, params);

        if (quorumExtension() > 0) {
            uint256 currentDeadline = proposalDeadline(proposalId);
            if (currentDeadline != 0 && block.timestamp + quorumExtension() >= currentDeadline) {
                _quorumDeadline = currentDeadline + quorumExtension();
            }
        }

        return weight;
    }

    function proposalDeadline(uint256 proposalId) public view virtual override returns (uint256) {
        uint256 currentDeadline = super.proposalDeadline(proposalId);
        if (currentDeadline != 0 && _quorumDeadline > currentDeadline) {
            return _quorumDeadline;
        }
        return currentDeadline;
    }
}
