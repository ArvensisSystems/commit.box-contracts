// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ERC20 } from "solady/src/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    function name() public view virtual override returns (string memory) {
        return "Mock ERC20";
    }

    function symbol() public view virtual override returns (string memory) {
        return "MOCK";
    }

    function mint(address recv, uint256 value) public {
        _mint(recv, value);
    }
}
