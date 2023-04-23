// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./GovernorVotesComp.sol";

abstract contract GovernorVotesQuorumFractionComp is GovernorVotesComp {
    uint256 private _quorumNumerator;

    event QuorumNumeratorUpdated(uint256 oldQuorumNumerator, uint256 newQuorumNumerator);

    constructor(uint256 quorumNumeratorValue) {
        _updateQuorumNumerator(quorumNumeratorValue);
    }

    function quorumNumerator() public view virtual returns (uint256) {
        return _quorumNumerator;
    }

    function quorumDenominator() public view virtual returns (uint256) {
        return 100;
    }

    function quorum(uint256 blockNumber) public view virtual override returns (uint256) {
        return (token.getPriorVotes(address(0), blockNumber) * quorumNumerator()) / quorumDenominator();
    }

    function updateQuorumNumerator(uint256 newQuorumNumerator) external virtual onlyGovernance {
        _updateQuorumNumerator(newQuorumNumerator);
    }

    function _updateQuorumNumerator(uint256 newQuorumNumerator) internal virtual {
        require(newQuorumNumerator <= quorumDenominator(), "GovernorVotesQuorumFractionComp: quorumNumerator over quorumDenominator");
        uint256 oldQuorumNumerator = _quorumNumerator;
        _quorumNumerator = newQuorumNumerator;
        emit QuorumNumeratorUpdated(oldQuorumNumerator, newQuorumNumerator);
    }
}
