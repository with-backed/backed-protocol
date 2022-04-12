// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";

import "./IERC20Mintable.sol";

contract TestERC20 is IERC20Mintable, ERC20("TEST", "Test Token", 18) {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
