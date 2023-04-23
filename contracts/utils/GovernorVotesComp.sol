// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./GovernorVotes.sol";
import "./IVotesComp.sol";

abstract contract GovernorVotesComp is GovernorVotes {
    IVotesComp public immutable token;

    constructor(IVotesComp tokenAddress) GovernorVotes(IVotesComp(tokenAddress)) {
        token = tokenAddress;
    }

    function getVotes(address account, uint256 blockNumber) public view virtual override returns (uint256) {
        return token.getPriorVotes(account, blockNumber);
    }

    function getVotesWithParams(address account, uint256 blockNumber, bytes memory params) public view virtual override returns (uint256) {
        return token.getPriorVotes(account, blockNumber);
    }

    function _getVotes(address account, uint256 blockNumber, bytes memory params) internal view virtual override returns (uint256) {
        return token.getPriorVotes(account, blockNumber);
    }
}
