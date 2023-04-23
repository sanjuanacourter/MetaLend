// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./SafeCast.sol";

library Checkpoints {
    struct History {
        Checkpoint[] _checkpoints;
    }

    struct Checkpoint {
        uint32 _blockNumber;
        uint224 _value;
    }

    function length(History storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    function at(History storage self, uint256 index) internal view returns (Checkpoint memory) {
        return self._checkpoints[index];
    }

    function latest(History storage self) internal view returns (uint256) {
        uint256 pos = self._checkpoints.length;
        return pos == 0 ? 0 : self._checkpoints[pos - 1]._value;
    }

    function get(History storage self, uint256 blockNumber) internal view returns (uint256) {
        return self._checkpoints.length == 0 ? 0 : _upperBinaryLookup(self._checkpoints, SafeCast.toUint32(blockNumber));
    }

    function push(History storage self, uint256 value) internal returns (uint256, uint256) {
        return _insert(self._checkpoints, SafeCast.toUint32(block.number), SafeCast.toUint224(value));
    }

    function push(History storage self, uint256 value, uint256 delta) internal returns (uint256, uint256) {
        return _insert(self._checkpoints, SafeCast.toUint32(block.number), SafeCast.toUint224(value), delta);
    }

    function _insert(Checkpoint[] storage self, uint32 pos, uint224 newValue) private returns (uint224, uint224) {
        uint256 length = self.length;

        Checkpoint memory last = length == 0 ? Checkpoint(0, 0) : self[length - 1];

        if (last._blockNumber == pos) {
            self[length - 1] = Checkpoint(pos, newValue);
        } else {
            self.push(Checkpoint(pos, newValue));
        }

        return (last._value, newValue);
    }

    function _insert(Checkpoint[] storage self, uint32 pos, uint224 newValue, uint256 delta) private returns (uint224, uint224) {
        uint256 length = self.length;

        Checkpoint memory last = length == 0 ? Checkpoint(0, 0) : self[length - 1];

        uint224 oldValue = last._value;
        uint224 newValue = SafeCast.toUint224(oldValue + delta);

        if (last._blockNumber == pos) {
            self[length - 1] = Checkpoint(pos, newValue);
        } else {
            self.push(Checkpoint(pos, newValue));
        }

        return (oldValue, newValue);
    }

    function _upperBinaryLookup(Checkpoint[] storage self, uint32 pos) private view returns (uint224) {
        if (self.length == 0) {
            return 0;
        }

        uint256 length = self.length;
        uint256 low = 0;
        uint256 high = length;

        while (low < high) {
            uint256 mid = (low + high) >> 1;
            if (self[mid]._blockNumber > pos) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return high == 0 ? 0 : self[high - 1]._value;
    }
}
