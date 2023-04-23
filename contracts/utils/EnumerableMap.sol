// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library EnumerableMap {
    struct Map {
        bytes32[] _keys;
        mapping(bytes32 => bytes32) _values;
        mapping(bytes32 => uint256) _indexes;
    }

    function _set(Map storage map, bytes32 key, bytes32 value) private returns (bool) {
        uint256 keyIndex = map._indexes[key];

        if (keyIndex == 0) {
            map._keys.push(key);
            map._indexes[key] = map._keys.length;
        }

        map._values[key] = value;
        return keyIndex == 0;
    }

    function _remove(Map storage map, bytes32 key) private returns (bool) {
        uint256 keyIndex = map._indexes[key];

        if (keyIndex != 0) {
            uint256 toDeleteIndex = keyIndex - 1;
            uint256 lastIndex = map._keys.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastKey = map._keys[lastIndex];
                map._keys[toDeleteIndex] = lastKey;
                map._indexes[lastKey] = keyIndex;
            }

            map._keys.pop();
            delete map._values[key];
            delete map._indexes[key];

            return true;
        } else {
            return false;
        }
    }

    function _contains(Map storage map, bytes32 key) private view returns (bool) {
        return map._indexes[key] != 0;
    }

    function _length(Map storage map) private view returns (uint256) {
        return map._keys.length;
    }

    function _at(Map storage map, uint256 index) private view returns (bytes32, bytes32) {
        require(map._keys.length > index, "EnumerableMap: index out of bounds");

        bytes32 key = map._keys[index];
        return (key, map._values[key]);
    }

    function _tryGet(Map storage map, bytes32 key) private view returns (bool, bytes32) {
        uint256 keyIndex = map._indexes[key];
        if (keyIndex == 0) {
            return (false, 0);
        } else {
            return (true, map._values[key]);
        }
    }

    function _get(Map storage map, bytes32 key) private view returns (bytes32) {
        uint256 keyIndex = map._indexes[key];
        require(keyIndex != 0, "EnumerableMap: nonexistent key");
        return map._values[key];
    }

    function _get(Map storage map, bytes32 key, string memory errorMessage) private view returns (bytes32) {
        uint256 keyIndex = map._indexes[key];
        require(keyIndex != 0, errorMessage);
        return map._values[key];
    }

    function _keys(Map storage map) private view returns (bytes32[] memory) {
        return map._keys;
    }

    // UintToAddressMap

    struct UintToAddressMap {
        Map _inner;
    }

    function set(UintToAddressMap storage map, uint256 key, address value) internal returns (bool) {
        return _set(map._inner, bytes32(key), bytes32(uint256(uint160(value))));
    }

    function remove(UintToAddressMap storage map, uint256 key) internal returns (bool) {
        return _remove(map._inner, bytes32(key));
    }

    function contains(UintToAddressMap storage map, uint256 key) internal view returns (bool) {
        return _contains(map._inner, bytes32(key));
    }

    function length(UintToAddressMap storage map) internal view returns (uint256) {
        return _length(map._inner);
    }

    function at(UintToAddressMap storage map, uint256 index) internal view returns (uint256, address) {
        (bytes32 key, bytes32 value) = _at(map._inner, index);
        return (uint256(key), address(uint160(uint256(value))));
    }

    function tryGet(UintToAddressMap storage map, uint256 key) internal view returns (bool, address) {
        (bool success, bytes32 value) = _tryGet(map._inner, bytes32(key));
        return (success, address(uint160(uint256(value))));
    }

    function get(UintToAddressMap storage map, uint256 key) internal view returns (address) {
        return address(uint160(uint256(_get(map._inner, bytes32(key)))));
    }

    function get(UintToAddressMap storage map, uint256 key, string memory errorMessage) internal view returns (address) {
        return address(uint160(uint256(_get(map._inner, bytes32(key), errorMessage))));
    }

    function keys(UintToAddressMap storage map) internal view returns (uint256[] memory) {
        bytes32[] memory store = _keys(map._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }

    // AddressToUintMap

    struct AddressToUintMap {
        Map _inner;
    }

    function set(AddressToUintMap storage map, address key, uint256 value) internal returns (bool) {
        return _set(map._inner, bytes32(uint256(uint160(key))), bytes32(value));
    }

    function remove(AddressToUintMap storage map, address key) internal returns (bool) {
        return _remove(map._inner, bytes32(uint256(uint160(key))));
    }

    function contains(AddressToUintMap storage map, address key) internal view returns (bool) {
        return _contains(map._inner, bytes32(uint256(uint160(key))));
    }

    function length(AddressToUintMap storage map) internal view returns (uint256) {
        return _length(map._inner);
    }

    function at(AddressToUintMap storage map, uint256 index) internal view returns (address, uint256) {
        (bytes32 key, bytes32 value) = _at(map._inner, index);
        return (address(uint160(uint256(key))), uint256(value));
    }

    function tryGet(AddressToUintMap storage map, address key) internal view returns (bool, uint256) {
        (bool success, bytes32 value) = _tryGet(map._inner, bytes32(uint256(uint160(key))));
        return (success, uint256(value));
    }

    function get(AddressToUintMap storage map, address key) internal view returns (uint256) {
        return uint256(_get(map._inner, bytes32(uint256(uint160(key)))));
    }

    function get(AddressToUintMap storage map, address key, string memory errorMessage) internal view returns (uint256) {
        return uint256(_get(map._inner, bytes32(uint256(uint160(key))), errorMessage));
    }

    function keys(AddressToUintMap storage map) internal view returns (address[] memory) {
        bytes32[] memory store = _keys(map._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
    }

    // Bytes32ToBytes32Map

    struct Bytes32ToBytes32Map {
        Map _inner;
    }

    function set(Bytes32ToBytes32Map storage map, bytes32 key, bytes32 value) internal returns (bool) {
        return _set(map._inner, key, value);
    }

    function remove(Bytes32ToBytes32Map storage map, bytes32 key) internal returns (bool) {
        return _remove(map._inner, key);
    }

    function contains(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool) {
        return _contains(map._inner, key);
    }

    function length(Bytes32ToBytes32Map storage map) internal view returns (uint256) {
        return _length(map._inner);
    }

    function at(Bytes32ToBytes32Map storage map, uint256 index) internal view returns (bytes32, bytes32) {
        return _at(map._inner, index);
    }

    function tryGet(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool, bytes32) {
        return _tryGet(map._inner, key);
    }

    function get(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bytes32) {
        return _get(map._inner, key);
    }

    function get(Bytes32ToBytes32Map storage map, bytes32 key, string memory errorMessage) internal view returns (bytes32) {
        return _get(map._inner, key, errorMessage);
    }

    function keys(Bytes32ToBytes32Map storage map) internal view returns (bytes32[] memory) {
        return _keys(map._inner);
    }

    // UintToUintMap

    struct UintToUintMap {
        Map _inner;
    }

    function set(UintToUintMap storage map, uint256 key, uint256 value) internal returns (bool) {
        return _set(map._inner, bytes32(key), bytes32(value));
    }

    function remove(UintToUintMap storage map, uint256 key) internal returns (bool) {
        return _remove(map._inner, bytes32(key));
    }

    function contains(UintToUintMap storage map, uint256 key) internal view returns (bool) {
        return _contains(map._inner, bytes32(key));
    }

    function length(UintToUintMap storage map) internal view returns (uint256) {
        return _length(map._inner);
    }

    function at(UintToUintMap storage map, uint256 index) internal view returns (uint256, uint256) {
        (bytes32 key, bytes32 value) = _at(map._inner, index);
        return (uint256(key), uint256(value));
    }

    function tryGet(UintToUintMap storage map, uint256 key) internal view returns (bool, uint256) {
        (bool success, bytes32 value) = _tryGet(map._inner, bytes32(key));
        return (success, uint256(value));
    }

    function get(UintToUintMap storage map, uint256 key) internal view returns (uint256) {
        return uint256(_get(map._inner, bytes32(key)));
    }

    function get(UintToUintMap storage map, uint256 key, string memory errorMessage) internal view returns (uint256) {
        return uint256(_get(map._inner, bytes32(key), errorMessage));
    }

    function keys(UintToUintMap storage map) internal view returns (uint256[] memory) {
        bytes32[] memory store = _keys(map._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}
