// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.29 <0.9.0;

import { CommitBox } from "src/CommitBox.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/guides/scripting-with-solidity
contract Deploy is BaseScript {
    function run() public broadcast returns (CommitBox box) {
        box = new CommitBox{ salt: keccak256("commit.box/0") }(
            address(0xC2f3F2c8084d6bc40887B0B867353d280e3D742D), address(0xC2f3F2c8084d6bc40887B0B867353d280e3D742D)
        );
    }
}
