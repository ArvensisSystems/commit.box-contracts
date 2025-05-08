// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.29;

// quick and dirty bitmap implementation
// a lot of code taken from solady
library LynBitmap8 {
    function set(uint8 bitmap, uint8 index) internal pure returns (uint8) {
        return bitmap | uint8(1 << (index & 0xff));
    }

    function unset(uint8 bitmap, uint8 index) internal pure returns (uint8) {
        return bitmap & ~uint8(1 << (index & 0xff));
    }

    function get(uint8 bitmap, uint8 index) internal pure returns (bool isSet) {
        uint256 b = (bitmap >> uint8(index & 0xff)) & 1;
        /// @solidity memory-safe-assembly
        assembly {
            isSet := b
        }
    }
}
