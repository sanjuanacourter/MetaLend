// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Governor.sol";
import "./IVotes.sol";

abstract contract GovernorVotes is Governor {
    IVotes public immutable token;

    constructor(IVotes tokenAddress) {
        token = tokenAddress;
    }

    function getVotes(address account, uint256 blockNumber) public view virtual override returns (uint256) {
        return token.getPastVotes(account, blockNumber);
    }

    function getVotesWithParams(address account, uint256 blockNumber, bytes memory params) public view virtual override returns (uint256) {
        return token.getPastVotes(account, blockNumber);
    }

    function _getVotes(address account, uint256 blockNumber, bytes memory params) internal view virtual override returns (uint256) {
        return token.getPastVotes(account, blockNumber);
    }
}
